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
    // Input state
    @Published var selectedModel: CloneModel = .large
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

    init() {
        // Forward audioRecorder's objectWillChange to this view model
        // so SwiftUI re-renders when recorder state changes
        audioRecorder.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Audio Source

    enum AudioSource: Equatable {
        case none
        case file(URL)
        case recorded(URL)

        var displayText: String? {
            switch self {
            case .none:
                return nil
            case .file(let url):
                return url.lastPathComponent
            case .recorded(let url):
                return url.lastPathComponent
            }
        }
    }

    // MARK: - Computed Properties

    /// Whether the form is valid for generation
    var canGenerate: Bool {
        let trimmedText = targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedText.isEmpty && effectiveReferenceAudio != nil && !state.isProcessing
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
    }

    /// Generate audio
    func generate() async {
        guard let refAudio = effectiveReferenceAudio else {
            errorMessage = "Reference audio is required"
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
            let outputURL = try await ttsService.clone(
                model: selectedModel,
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
}
