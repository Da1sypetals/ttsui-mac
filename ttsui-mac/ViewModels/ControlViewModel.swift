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
    // Input state
    @Published var selectedModel: ControlModel = .large
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

    // MARK: - Computed Properties

    /// Whether the form is valid for generation
    var canGenerate: Bool {
        let trimmedText = targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedText.isEmpty && !state.isProcessing
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
    }

    private var cancellables = Set<AnyCancellable>()

    private func updateSpeakerForLanguage(_ language: TTSLanguage) {
        // Select first available speaker for the language
        let speakers = TTSSpeaker.allCases.filter { $0.language == language.rawValue }
        if let firstSpeaker = speakers.first, !speakers.contains(selectedSpeaker) {
            selectedSpeaker = firstSpeaker
        }
    }

    // MARK: - Actions

    /// Generate audio
    func generate() async {
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
            let outputURL = try await ttsService.control(
                model: selectedModel,
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
