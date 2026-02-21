//
//  ControlViewModel.swift
//  ttsui-mac
//
//  Control mode logic
//

import Foundation
import Combine

/// ViewModel for Control mode
class ControlViewModel: ObservableObject {
    // Model state
    @Published var selectedModelId: String?
    @Published var modelStates: [String: ModelInfo] = [:]

    // Input state
    @Published var selectedSpeaker: TTSSpeaker = .vivian
    @Published var selectedLanguage: TTSLanguage = .chinese
    @Published var targetText: String = ""
    @Published var emotionInstruct: String = ""

    // Generation state
    @Published var state: TTSState = .idle
    @Published var generatedAudioURL: URL?
    @Published var errorMessage: String?

    // Services
    private let ttsService = TTSService.shared
    private let fileService = FileService.shared
    private let audioService = AudioService.shared

    // MARK: - Available Models

    /// Available control models
    static let availableModels: [(id: String, displayName: String)] = [
        ("mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-bf16", "0.6B-CustomVoice (Fast)"),
        ("mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16", "1.7B-CustomVoice (Quality)")
    ]

    /// Model selection items for UI
    var modelSelectionItems: [ModelSelectionItem] {
        Self.availableModels.compactMap { (id, displayName) in
            guard let info = modelStates[id] else {
                return ModelSelectionItem(
                    modelInfo: ModelInfo(
                        modelId: id,
                        state: .unloaded,
                        memory: MemoryStats(beforeMb: nil, afterMb: nil, deltaMb: nil),
                        loadTimeSeconds: nil,
                        error: nil
                    ),
                    displayName: displayName
                )
            }
            return ModelSelectionItem(modelInfo: info, displayName: displayName)
        }
    }

    // MARK: - Computed Properties

    /// Whether the form is valid for generation
    var canGenerate: Bool {
        let trimmedText = targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return false }
        guard !state.isProcessing else { return false }
        guard let modelId = selectedModelId else { return false }
        guard let modelInfo = modelStates[modelId], modelInfo.state == .loaded else { return false }
        return true
    }

    /// Available speakers for the selected language
    var availableSpeakers: [TTSSpeaker] {
        TTSSpeaker.allCases.filter { $0.language == selectedLanguage.rawValue }
    }

    // MARK: - Initialization

    init() {
        // Update speaker when language changes
        $selectedLanguage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] language in
                self?.updateSpeakerForLanguage(language)
            }
            .store(in: &cancellables)

        // Load initial model states
        Task {
            await refreshModelStates()
        }
    }

    private var cancellables = Set<AnyCancellable>()

    private func updateSpeakerForLanguage(_ language: TTSLanguage) {
        // Select first available speaker for the language
        let speakers = TTSSpeaker.allCases.filter { $0.language == language.rawValue }
        if let firstSpeaker = speakers.first, !speakers.contains(selectedSpeaker) {
            selectedSpeaker = firstSpeaker
        }
    }

    // MARK: - Model Management

    /// Refresh model states from server
    func refreshModelStates() async {
        do {
            let response = try await ttsService.listModels()
            await MainActor.run {
                var newStates: [String: ModelInfo] = [:]
                for model in response.models {
                    if Self.availableModels.contains(where: { $0.id == model.modelId }) {
                        newStates[model.modelId] = model
                    }
                }
                self.modelStates = newStates
            }
        } catch {
            print("Failed to refresh model states: \(error)")
        }
    }

    /// Load a model
    func loadModel(modelId: String) async {
        // Update state to loading
        await MainActor.run {
            modelStates[modelId] = ModelInfo(
                modelId: modelId,
                state: .loading,
                memory: MemoryStats(beforeMb: nil, afterMb: nil, deltaMb: nil),
                loadTimeSeconds: nil,
                error: nil
            )
        }

        do {
            let response = try await ttsService.loadModel(modelId: modelId)
            await MainActor.run {
                modelStates[modelId] = ModelInfo(
                    modelId: response.modelId,
                    state: ModelState(rawValue: response.state) ?? .error,
                    memory: MemoryStats(
                        beforeMb: response.memory.beforeMb,
                        afterMb: response.memory.afterMb,
                        deltaMb: response.memory.deltaMb
                    ),
                    loadTimeSeconds: response.loadTimeSeconds,
                    error: response.error
                )
            }
        } catch {
            await MainActor.run {
                modelStates[modelId] = ModelInfo(
                    modelId: modelId,
                    state: .error,
                    memory: MemoryStats(beforeMb: nil, afterMb: nil, deltaMb: nil),
                    loadTimeSeconds: nil,
                    error: error.localizedDescription
                )
            }
        }
    }

    /// Unload a model
    func unloadModel(modelId: String) async {
        // Update state to unloading
        await MainActor.run {
            modelStates[modelId] = ModelInfo(
                modelId: modelId,
                state: .unloading,
                memory: MemoryStats(beforeMb: nil, afterMb: nil, deltaMb: nil),
                loadTimeSeconds: nil,
                error: nil
            )
        }

        do {
            let response = try await ttsService.unloadModel(modelId: modelId)
            await MainActor.run {
                modelStates[modelId] = ModelInfo(
                    modelId: response.modelId,
                    state: ModelState(rawValue: response.state) ?? .unloaded,
                    memory: MemoryStats(
                        beforeMb: response.memory.beforeMb,
                        afterMb: response.memory.afterMb,
                        deltaMb: response.memory.deltaMb
                    ),
                    loadTimeSeconds: nil,
                    error: response.error
                )

                // Deselect if this was the selected model
                if selectedModelId == modelId {
                    selectedModelId = nil
                }
            }
        } catch {
            await MainActor.run {
                modelStates[modelId] = ModelInfo(
                    modelId: modelId,
                    state: .error,
                    memory: MemoryStats(beforeMb: nil, afterMb: nil, deltaMb: nil),
                    loadTimeSeconds: nil,
                    error: error.localizedDescription
                )
            }
        }
    }

    // MARK: - Actions

    /// Generate audio
    func generate() async {
        guard let modelId = selectedModelId else {
            errorMessage = "Please select a model"
            return
        }

        guard let modelInfo = modelStates[modelId], modelInfo.state == .loaded else {
            errorMessage = "Selected model is not loaded"
            return
        }

        let trimmedText = targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            errorMessage = "Target text is required"
            return
        }

        await MainActor.run {
            state = .loading
            errorMessage = nil
        }

        do {
            // Find the ControlModel enum from the modelId
            let controlModel: ControlModel
            if modelId.contains("0.6B") {
                controlModel = .small
            } else {
                controlModel = .large
            }

            let outputURL = try await ttsService.control(
                model: controlModel,
                text: trimmedText,
                speaker: selectedSpeaker,
                language: selectedLanguage,
                instruct: emotionInstruct.isEmpty ? nil : emotionInstruct
            )

            await MainActor.run {
                self.generatedAudioURL = outputURL
                self.state = .completed(outputURL: outputURL)
            }
        } catch {
            await MainActor.run {
                self.state = .failed(error: error.localizedDescription)
                self.errorMessage = error.localizedDescription
            }
        }
    }

    /// Cancel generation
    func cancel() {
        ttsService.cancel()
        state = .idle
    }

    /// Save generated audio to user-selected location
    func saveGeneratedAudio() -> Bool {
        guard let sourceURL = generatedAudioURL else { return false }

        guard let destinationURL = fileService.showSavePanel(defaultName: "control_output.wav") else {
            return false
        }

        do {
            try fileService.saveGeneratedAudio(from: sourceURL, to: destinationURL)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Play generated audio
    func playGeneratedAudio() {
        guard let url = generatedAudioURL else { return }
        try? audioService.play(url: url)
    }

    /// Stop playback
    func stopPlayback() {
        audioService.stopPlayback()
    }
}
