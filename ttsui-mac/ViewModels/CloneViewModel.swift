//
//  CloneViewModel.swift
//  ttsui-mac
//
//  Clone mode logic
//

import Foundation
import Combine

/// ViewModel for Clone mode
class CloneViewModel: ObservableObject {
    // Model state
    @Published var selectedModelId: String?
    @Published var modelStates: [String: ModelInfo] = [:]

    // Input state
    @Published var targetText: String = ""
    @Published var referenceText: String = ""
    @Published var referenceAudioURL: URL? {
        didSet {
            if let url = referenceAudioURL {
                referenceAudioSource = .file(url)
            }
        }
    }

    // Audio source
    @Published var referenceAudioSource: AudioSource = .none

    // Track the specific recorded audio being used
    @Published var selectedRecordedURL: URL?

    // Speaker management
    @Published var speakers: [CloneSpeaker] = []
    @Published var selectedSpeaker: CloneSpeaker?
    @Published var showSaveSpeakerSheet: Bool = false

    // Generation state
    @Published var state: TTSState = .idle
    @Published var generatedAudioURL: URL?
    @Published var errorMessage: String?

    // Audio recorder
    let audioRecorder = AudioRecorder()

    // Services
    private let ttsService = TTSService.shared
    private let fileService = FileService.shared
    private let audioService = AudioService.shared

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Available Models

    /// Available clone models
    static let availableModels: [(id: String, displayName: String)] = [
        ("mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16", "0.6B-Base (Fast)"),
        ("mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16", "1.7B-Base (Quality)")
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

    // MARK: - Initialization

    init() {
        // Forward audioRecorder's objectWillChange to this view model
        audioRecorder.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Load speakers from storage
        loadSpeakers()

        // Load initial model states
        Task {
            await refreshModelStates()
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

    // MARK: - Audio Source

    enum AudioSource: Equatable {
        case none
        case file(URL)
        case recorded(URL)
        case speaker(CloneSpeaker)

        var displayText: String? {
            switch self {
            case .none:
                return nil
            case .file(let url):
                return url.lastPathComponent
            case .recorded(let url):
                return url.lastPathComponent
            case .speaker(let speaker):
                return speaker.audioFileName
            }
        }
    }

    // MARK: - Computed Properties

    /// Whether the form is valid for generation
    var canGenerate: Bool {
        let trimmedText = targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return false }
        guard effectiveReferenceAudio != nil else { return false }
        guard !state.isProcessing else { return false }
        guard let modelId = selectedModelId else { return false }
        guard let modelInfo = modelStates[modelId], modelInfo.state == .loaded else { return false }
        return true
    }

    /// The effective reference audio URL based on source
    var effectiveReferenceAudio: URL? {
        switch referenceAudioSource {
        case .none:
            return nil
        case .file(let url):
            return url
        case .recorded(let url):
            return url
        case .speaker(let speaker):
            return speaker.audioURL
        }
    }

    // MARK: - Actions

    /// Use recorded audio as reference
    func useRecordedAudio() {
        if let url = audioRecorder.recordedAudioURL {
            referenceAudioSource = .recorded(url)
            selectedRecordedURL = url
            referenceAudioURL = nil
        }
    }

    /// Check if the current recorded audio is already selected
    var isRecordedAudioSelected: Bool {
        if case .recorded(let url) = referenceAudioSource {
            return url == audioRecorder.recordedAudioURL
        }
        return false
    }

    /// Use file as reference
    func useFile(_ url: URL) {
        referenceAudioSource = .file(url)
        referenceAudioURL = url
    }

    /// Clear reference audio
    func clearReferenceAudio() {
        referenceAudioSource = .none
        referenceAudioURL = nil
        selectedSpeaker = nil
    }

    /// Generate audio
    func generate() async {
        guard let refAudio = effectiveReferenceAudio else {
            errorMessage = "Reference audio is required"
            return
        }

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
            // Find the CloneModel enum from the modelId
            let cloneModel: CloneModel
            if modelId.contains("0.6B") {
                cloneModel = .small
            } else {
                cloneModel = .large
            }

            let outputURL = try await ttsService.clone(
                model: cloneModel,
                text: trimmedText,
                refAudio: refAudio,
                refText: referenceText.isEmpty ? nil : referenceText
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

        guard let destinationURL = fileService.showSavePanel(defaultName: "clone_output.wav") else {
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

    // MARK: - Speaker Management

    /// Load speakers from storage
    func loadSpeakers() {
        speakers = fileService.loadSpeakers()
    }

    /// Select a speaker and load its audio and text
    func selectSpeaker(_ speaker: CloneSpeaker?) {
        guard let speaker = speaker else {
            selectedSpeaker = nil
            referenceAudioSource = .none
            referenceText = ""
            return
        }

        selectedSpeaker = speaker
        referenceAudioSource = .speaker(speaker)
        referenceText = speaker.textReference ?? ""
    }

    /// Save current configuration as a new speaker
    func saveAsNewSpeaker(name: String) {
        // Validate name
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName.count <= 16 else { return }

        guard let audioURL = effectiveReferenceAudio else { return }

        do {
            // Copy audio to speakers directory
            let audioFileName = try fileService.copyAudioToSpeakers(from: audioURL)

            // Create new speaker
            let newSpeaker = CloneSpeaker(
                id: UUID(),
                name: trimmedName,
                audioFileName: audioFileName,
                textReference: referenceText.isEmpty ? nil : referenceText
            )

            // Add to speakers list and save
            speakers.append(newSpeaker)
            try fileService.saveSpeakers(speakers)

            // Select the new speaker
            selectSpeaker(newSpeaker)
        } catch {
            errorMessage = "Failed to save speaker: \(error.localizedDescription)"
        }
    }

    /// Save current configuration to the selected speaker
    /// - Parameter newName: Optional new name for the speaker (if nil, keeps current name)
    func saveCurrentSpeaker(newName: String? = nil) {
        guard let speaker = selectedSpeaker else { return }
        guard let audioURL = effectiveReferenceAudio else { return }

        // Determine the name to use
        let finalName: String
        if let newName = newName {
            let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= 16 else { return }
            finalName = trimmed
        } else {
            finalName = speaker.name
        }

        do {
            // Copy new audio if source is not the speaker's own audio
            let newAudioFileName: String
            if case .speaker = referenceAudioSource {
                // Already using speaker's audio, no need to copy
                newAudioFileName = speaker.audioFileName
            } else {
                // Different audio source, copy to speakers directory
                newAudioFileName = try fileService.copyAudioToSpeakers(from: audioURL)
            }

            // Update speaker in list
            if let index = speakers.firstIndex(where: { $0.id == speaker.id }) {
                speakers[index] = CloneSpeaker(
                    id: speaker.id,
                    name: finalName,
                    audioFileName: newAudioFileName,
                    textReference: referenceText.isEmpty ? nil : referenceText
                )
                try fileService.saveSpeakers(speakers)

                // Update selected speaker reference
                selectedSpeaker = speakers[index]
                referenceAudioSource = .speaker(speakers[index])
            }
        } catch {
            errorMessage = "Failed to update speaker: \(error.localizedDescription)"
        }
    }

    /// Delete a speaker
    func deleteSpeaker(_ speaker: CloneSpeaker) {
        guard let index = speakers.firstIndex(where: { $0.id == speaker.id }) else { return }

        // Remove from list
        speakers.remove(at: index)

        // Delete audio file
        do {
            try fileService.deleteSpeakerAudio(filename: speaker.audioFileName)
        } catch {
            print("Failed to delete speaker audio: \(error)")
        }

        // Save updated list
        do {
            try fileService.saveSpeakers(speakers)
        } catch {
            errorMessage = "Failed to save speakers: \(error.localizedDescription)"
        }

        // Clear selection if this was the selected speaker
        if selectedSpeaker?.id == speaker.id {
            selectedSpeaker = nil
            referenceAudioSource = .none
            referenceText = ""
        }
    }
}
