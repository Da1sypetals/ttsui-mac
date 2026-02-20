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

    // MARK: - Computed Properties

    /// Whether the form is valid for generation
    var canGenerate: Bool {
        let trimmedText = targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = voiceDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedText.isEmpty && !trimmedDescription.isEmpty && !state.isProcessing
    }

    // MARK: - Actions

    /// Generate audio
    func generate() async {
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
