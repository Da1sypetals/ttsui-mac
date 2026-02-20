//
//  AudioService.swift
//  ttsui-mac
//
//  Audio recording and playback service for macOS
//

import Foundation
import AVFoundation
import Combine

/// Manages audio recording and playback
class AudioService: NSObject, ObservableObject {
    static let shared = AudioService()

    // Recording state
    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var lastRecordedURL: URL?

    // Playback state
    @Published var isPlaying: Bool = false
    @Published var playbackProgress: Double = 0
    @Published var currentAudioURL: URL?
    @Published var audioDuration: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var playbackTimer: Timer?
    private var currentRecordingURL: URL?

    private let fileService = FileService.shared

    // MARK: - Recording

    override private init() {
        super.init()
    }

    /// Start recording audio (macOS doesn't require audio session configuration)
    func startRecording() throws {
        // Create recorder settings
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 24000.0,  // Match model sample rate
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // Ensure temp directory exists
        try fileService.ensureDirectoryExists(at: fileService.cloneTempAudioDirectory)

        // Generate a new timestamped recording path
        let outputURL = fileService.generateRecordingPath()
        currentRecordingURL = outputURL

        // Create and start recorder
        audioRecorder = try AVAudioRecorder(url: outputURL, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()
        audioRecorder?.record()

        isRecording = true
        recordingDuration = 0

        // Start timer to track duration
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingDuration = self?.audioRecorder?.currentTime ?? 0
        }
    }

    /// Stop recording audio
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        audioRecorder = nil

        recordingTimer?.invalidate()
        recordingTimer = nil

        isRecording = false

        // Return the actual recorded URL
        if let recordedURL = currentRecordingURL,
           FileManager.default.fileExists(atPath: recordedURL.path) {
            lastRecordedURL = recordedURL

            // Cleanup old recordings
            try? fileService.cleanupOldRecordings()

            currentRecordingURL = nil
            return recordedURL
        }

        currentRecordingURL = nil
        return nil
    }

    // MARK: - Playback

    /// Load and play audio from URL
    func play(url: URL) throws {
        // Stop current playback
        stopPlayback()

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            currentAudioURL = url
            audioDuration = audioPlayer?.duration ?? 0
            isPlaying = true

            // Start timer to track progress
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self, let player = self.audioPlayer else { return }
                self.playbackProgress = player.currentTime / player.duration
            }
        } catch {
            throw AudioError.playbackFailed(error.localizedDescription)
        }
    }

    /// Pause playback
    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
    }

    /// Resume playback
    func resumePlayback() {
        audioPlayer?.play()
        isPlaying = true
    }

    /// Stop playback
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil

        playbackTimer?.invalidate()
        playbackTimer = nil

        isPlaying = false
        playbackProgress = 0
    }

    /// Toggle play/pause
    func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            if let url = currentAudioURL {
                try? play(url: url)
            }
        }
    }

    /// Seek to position (0.0 - 1.0)
    func seek(to progress: Double) {
        guard let player = audioPlayer else { return }
        player.currentTime = progress * player.duration
        playbackProgress = progress
    }

    /// Format time as MM:SS
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        playbackProgress = 0
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
}

// MARK: - Errors

enum AudioError: LocalizedError {
    case permissionDenied
    case recordingFailed(String)
    case playbackFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission denied"
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        case .playbackFailed(let message):
            return "Playback failed: \(message)"
        }
    }
}
