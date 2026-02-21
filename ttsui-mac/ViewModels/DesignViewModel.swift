//
//  DesignViewModel.swift
//  ttsui-mac
//
//  Design mode logic
//

import Foundation
import Combine

/// ViewModel for Design mode
class DesignViewModel: ObservableObject {
    // Model state (Design mode uses a fixed VoiceDesign model)
    @Published var modelState: ModelState = .unloaded
    @Published var modelInfo: ModelInfo?

    // Input state
    @Published var selectedLanguage: TTSLanguage = .english
    @Published var targetText: String = ""
    @Published var voiceDescription: String = ""

    // Generation state
    @Published var state: TTSState = .idle
    @Published var generatedAudioURL: URL?
    @Published var errorMessage: String?

    // Services
    private let ttsService = TTSService.shared
    private let fileService = FileService.shared
    private let audioService = AudioService.shared

    // The VoiceDesign model ID
    static let modelId = "mlx-community/Qwen3-TTS-12Hz-1.7B-VoiceDesign-bf16"

    // MARK: - Computed Properties

    /// Whether the form is valid for generation
    var canGenerate: Bool {
        let trimmedText = targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = voiceDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return false }
        guard !trimmedDescription.isEmpty else { return false }
        guard !state.isProcessing else { return false }
        guard modelState == .loaded else { return false }
        return true
    }

    // MARK: - Initialization

    init() {
        // Load initial model state
        Task {
            await refreshModelState()
        }
    }

    // MARK: - Model Management

    /// Refresh model state from server
    func refreshModelState() async {
        do {
            let response = try await ttsService.listModels()
            await MainActor.run {
                if let model = response.models.first(where: { $0.modelId == Self.modelId }) {
                    self.modelInfo = model
                    self.modelState = model.state
                }
            }
        } catch {
            print("Failed to refresh model state: \(error)")
        }
    }

    /// Load the VoiceDesign model
    func loadModel() async {
        await MainActor.run {
            self.modelState = .loading
        }

        do {
            let response = try await ttsService.loadModel(modelId: Self.modelId)
            await MainActor.run {
                self.modelState = ModelState(rawValue: response.state) ?? .error
                self.modelInfo = ModelInfo(
                    modelId: response.modelId,
                    state: self.modelState,
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
                self.modelState = .error
                self.modelInfo = ModelInfo(
                    modelId: Self.modelId,
                    state: .error,
                    memory: MemoryStats(beforeMb: nil, afterMb: nil, deltaMb: nil),
                    loadTimeSeconds: nil,
                    error: error.localizedDescription
                )
            }
        }
    }

    /// Unload the VoiceDesign model
    func unloadModel() async {
        await MainActor.run {
            self.modelState = .unloading
        }

        do {
            let response = try await ttsService.unloadModel(modelId: Self.modelId)
            await MainActor.run {
                self.modelState = ModelState(rawValue: response.state) ?? .unloaded
                self.modelInfo = ModelInfo(
                    modelId: response.modelId,
                    state: self.modelState,
                    memory: MemoryStats(
                        beforeMb: response.memory.beforeMb,
                        afterMb: response.memory.afterMb,
                        deltaMb: response.memory.deltaMb
                    ),
                    loadTimeSeconds: nil,
                    error: response.error
                )
            }
        } catch {
            await MainActor.run {
                self.modelState = .error
                self.modelInfo = ModelInfo(
                    modelId: Self.modelId,
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
        guard modelState == .loaded else {
            errorMessage = "VoiceDesign model is not loaded"
            return
        }

        let trimmedText = targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = voiceDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            errorMessage = "Target text is required"
            return
        }

        guard !trimmedDescription.isEmpty else {
            errorMessage = "Voice description is required"
            return
        }

        await MainActor.run {
            state = .loading
            errorMessage = nil
        }

        do {
            let outputURL = try await ttsService.design(
                text: trimmedText,
                language: selectedLanguage,
                instruct: trimmedDescription
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

        guard let destinationURL = fileService.showSavePanel(defaultName: "design_output.wav") else {
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
