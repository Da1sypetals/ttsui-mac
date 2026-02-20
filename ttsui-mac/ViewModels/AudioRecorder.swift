//
//  AudioRecorder.swift
//  ttsui-mac
//
//  Recording state management
//

import Foundation
import Combine

/// Manages audio recording state for Clone mode
class AudioRecorder: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var hasRecordedAudio: Bool = false
    @Published var currentRecordedURL: URL?

    private let audioService = AudioService.shared
    private let fileService = FileService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Bind to audio service state
        audioService.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)

        audioService.$recordingDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordingDuration)

        audioService.$lastRecordedURL
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                self?.currentRecordedURL = url
                self?.hasRecordedAudio = url != nil
            }
            .store(in: &cancellables)

        // Check for existing recorded audio
        updateHasRecordedAudio()
    }

    /// Update the hasRecordedAudio flag and current recording info
    func updateHasRecordedAudio() {
        let recentAudio = fileService.mostRecentRecordedAudio
        if currentRecordedURL == nil {
            currentRecordedURL = recentAudio
        }
        hasRecordedAudio = currentRecordedURL != nil || recentAudio != nil
    }

    /// Start recording
    func startRecording() {
        do {
            try audioService.startRecording()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    /// Stop recording
    func stopRecording() {
        if let url = audioService.stopRecording() {
            currentRecordedURL = url
            hasRecordedAudio = true
            print("Recording saved to: \(url.path)")
        }
    }

    /// Toggle recording
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    /// Get the URL of the most recent recorded audio
    var recordedAudioURL: URL? {
        currentRecordedURL ?? fileService.mostRecentRecordedAudio
    }

    /// Get the filename of the current recorded audio (computed property for reactivity)
    var currentRecordedFilename: String? {
        currentRecordedURL?.lastPathComponent
    }

    /// Format recording duration as MM:SS
    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
