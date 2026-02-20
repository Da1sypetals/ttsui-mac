//
//  TTSService.swift
//  ttsui-mac
//
//  High-level TTS API with model selection
//

import Foundation
import Combine

/// High-level TTS service that coordinates Python subprocess execution
class TTSService: ObservableObject, PythonSubprocessDelegate {
    static let shared = TTSService()

    @Published var state: TTSState = .idle
    @Published var logEntries: [LogEntry] = []

    private let subprocess = PythonSubprocess()
    private let fileService = FileService.shared

    private init() {
        subprocess.delegate = self
    }

    // MARK: - PythonSubprocessDelegate

    func subprocess(_ subprocess: PythonSubprocess, didOutputLog entry: LogEntry) {
        DispatchQueue.main.async {
            self.logEntries.append(entry)
        }
    }

    func subprocess(_ subprocess: PythonSubprocess, didUpdateProgress percent: Int, message: String) {
        DispatchQueue.main.async {
            self.state = .generating(progress: percent, message: message)
        }
    }

    // MARK: - TTS Generation Methods

    /// Generate audio using Clone mode
    /// - Parameters:
    ///   - model: Model to use (0.6B or 1.7B)
    ///   - text: Target text to synthesize
    ///   - refAudio: Reference audio file URL
    ///   - refText: Transcript of reference audio (optional)
    /// - Returns: URL to generated audio file
    func clone(model: CloneModel, text: String, refAudio: URL?, refText: String?) async throws -> URL {
        guard let refAudio = refAudio else {
            throw TTSUIError.invalidInput("Reference audio is required")
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw TTSUIError.invalidInput("Target text is required")
        }

        // Create output path
        let outputPath = fileService.generateOutputPath(mode: .clone)

        let request = CloneRequest(
            model: model,
            text: trimmedText,
            refAudioURL: refAudio,
            refText: refText ?? ""
        )

        let args = request.toArguments(outputPath: outputPath.path)

        return try await runGeneration(mode: .clone, args: args, outputPath: outputPath)
    }

    /// Generate audio using Control mode
    /// - Parameters:
    ///   - model: Model to use (0.6B or 1.7B)
    ///   - text: Target text to synthesize
    ///   - speaker: Speaker name
    ///   - language: Language (Chinese or English)
    ///   - instruct: Emotion/style instructions (optional)
    /// - Returns: URL to generated audio file
    func control(model: ControlModel, text: String, speaker: TTSSpeaker, language: TTSLanguage, instruct: String?) async throws -> URL {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw TTSUIError.invalidInput("Target text is required")
        }

        // Create output path
        let outputPath = fileService.generateOutputPath(mode: .control)

        let request = ControlRequest(
            model: model,
            text: trimmedText,
            speaker: speaker,
            language: language,
            instruct: instruct ?? ""
        )

        let args = request.toArguments(outputPath: outputPath.path)

        return try await runGeneration(mode: .control, args: args, outputPath: outputPath)
    }

    /// Generate audio using Design mode
    /// - Parameters:
    ///   - text: Target text to synthesize
    ///   - language: Language (Chinese or English)
    ///   - instruct: Voice description
    /// - Returns: URL to generated audio file
    func design(text: String, language: TTSLanguage, instruct: String) async throws -> URL {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw TTSUIError.invalidInput("Target text is required")
        }

        let trimmedInstruct = instruct.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInstruct.isEmpty else {
            throw TTSUIError.invalidInput("Voice description is required")
        }

        // Create output path
        let outputPath = fileService.generateOutputPath(mode: .design)

        let request = DesignRequest(
            text: trimmedText,
            language: language,
            instruct: trimmedInstruct
        )

        let args = request.toArguments(outputPath: outputPath.path)

        return try await runGeneration(mode: .design, args: args, outputPath: outputPath)
    }

    /// Run generation with common handling
    private func runGeneration(mode: TTSMode, args: [String], outputPath: URL) async throws -> URL {
        // Ensure output directory exists
        try fileService.ensureDirectoryExists(for: mode)

        // Clear previous logs
        await MainActor.run {
            self.logEntries.removeAll()
            self.state = .loading
        }

        do {
            let result = try await subprocess.run(mode: mode, args: args)

            await MainActor.run {
                self.state = .completed(outputURL: result)
            }

            return result
        } catch {
            await MainActor.run {
                self.state = .failed(error: error.localizedDescription)
            }
            throw error
        }
    }

    /// Cancel current generation
    func cancel() {
        subprocess.cancel()
        state = .idle
    }

    /// Clear log entries
    func clearLogs() {
        logEntries.removeAll()
    }
}
