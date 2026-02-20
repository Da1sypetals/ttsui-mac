//
//  FileService.swift
//  ttsui-mac
//
//  File I/O operations for TTSUI
//

import Foundation
import AppKit
import UniformTypeIdentifiers

/// Manages file operations for TTSUI
class FileService {
    static let shared = FileService()

    private let fileManager = FileManager.default

    /// Maximum number of temporary recordings to keep (can be overridden via env var)
    var maxTempRecordings: Int {
        if let envValue = ProcessInfo.processInfo.environment["TTSUI_MAX_TEMP_RECORD"],
           let parsed = Int(envValue), parsed > 0 {
            return parsed
        }
        return 20
    }

    /// Base directory for all TTSUI data
    var baseDirectory: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".ttsui")
    }

    /// Directory for Clone mode
    var cloneDirectory: URL {
        baseDirectory.appendingPathComponent("clone")
    }

    /// Directory for temporary audio in Clone mode
    var cloneTempAudioDirectory: URL {
        cloneDirectory.appendingPathComponent("tmp_audio")
    }

    /// Directory for generated Clone audio
    var cloneGeneratedDirectory: URL {
        cloneDirectory.appendingPathComponent("generated")
    }

    /// Directory for Control mode
    var controlDirectory: URL {
        baseDirectory.appendingPathComponent("control")
    }

    /// Directory for generated Control audio
    var controlGeneratedDirectory: URL {
        controlDirectory.appendingPathComponent("generated")
    }

    /// Directory for Design mode
    var designDirectory: URL {
        baseDirectory.appendingPathComponent("design")
    }

    /// Directory for generated Design audio
    var designGeneratedDirectory: URL {
        designDirectory.appendingPathComponent("generated")
    }

    private init() {}

    /// Ensure the base directory structure exists
    func ensureBaseDirectoryExists() throws {
        try ensureDirectoryExists(at: baseDirectory)
    }

    /// Ensure directories for a specific mode exist
    func ensureDirectoryExists(for mode: TTSMode) throws {
        switch mode {
        case .clone:
            try ensureDirectoryExists(at: cloneTempAudioDirectory)
            try ensureDirectoryExists(at: cloneGeneratedDirectory)
        case .control:
            try ensureDirectoryExists(at: controlGeneratedDirectory)
        case .design:
            try ensureDirectoryExists(at: designGeneratedDirectory)
        }
    }

    /// Create directory if it doesn't exist
    func ensureDirectoryExists(at url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// Generate a timestamped output path for the given mode
    func generateOutputPath(mode: TTSMode) -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "+", with: "Z")

        let directory: URL
        switch mode {
        case .clone:
            directory = cloneGeneratedDirectory
        case .control:
            directory = controlGeneratedDirectory
        case .design:
            directory = designGeneratedDirectory
        }

        return directory.appendingPathComponent("\(timestamp).wav")
    }

    /// Generate a new timestamped recording path
    func generateRecordingPath() -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        // Generate 8-character UUID
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8).lowercased()

        return cloneTempAudioDirectory.appendingPathComponent("\(timestamp)_\(uuid).wav")
    }

    /// Get the most recent recorded audio file
    var mostRecentRecordedAudio: URL? {
        getRecordedAudioFiles().first
    }

    /// Check if any recorded audio exists
    var hasRecordedAudio: Bool {
        getRecordedAudioFiles().first != nil
    }

    /// Get all recorded audio files, sorted by modification date (newest first)
    func getRecordedAudioFiles() -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: cloneTempAudioDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return []
        }

        var files: [(url: URL, date: Date)] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "wav" else { continue }
            if let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                files.append((url, date))
            }
        }

        return files.sorted { $0.date > $1.date }.map { $0.url }
    }

    /// Clean up old recordings, keeping only the most recent maxTempRecordings
    func cleanupOldRecordings() throws {
        let files = getRecordedAudioFiles()
        guard files.count > maxTempRecordings else { return }

        // Delete oldest files (they're sorted newest first)
        for file in files.dropFirst(maxTempRecordings) {
            try fileManager.removeItem(at: file)
        }
    }

    /// Legacy path for backward compatibility (points to most recent if exists)
    var recordedAudioPath: URL {
        mostRecentRecordedAudio ?? cloneTempAudioDirectory.appendingPathComponent("recorded.wav")
    }

    /// Show save panel and return selected URL
    func showSavePanel(defaultName: String = "output.wav") -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.wav]
        panel.nameFieldStringValue = defaultName
        panel.message = "Choose where to save the generated audio"

        let response = panel.runModal()
        return response == .OK ? panel.url : nil
    }

    /// Copy generated audio to user-specified location
    func saveGeneratedAudio(from source: URL, to destination: URL) throws {
        // Remove existing file at destination
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.copyItem(at: source, to: destination)
    }
}
