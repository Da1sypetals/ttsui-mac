//
//  TTSService.swift
//  ttsui-mac
//
//  High-level TTS API with model selection
//

import Foundation
import Combine

/// High-level TTS service that coordinates HTTP communication with Python server
class TTSService: ObservableObject {
    static let shared = TTSService()

    @Published var state: TTSState = .idle
    @Published var logEntries: [LogEntry] = []

    private let httpClient = TTSHTTPClient.shared
    private let fileService = FileService.shared

    private init() {}

    /// Get the current server port
    private var port: Int {
        TTSServerManager.shared.currentPort
    }

    // MARK: - Log and Progress Handling (called from TTSServerManager)

    /// Add a log entry (called from TTSServerManager SSE stream)
    func addLogEntry(_ entry: LogEntry) {
        logEntries.append(entry)
    }

    /// Update progress state (called from TTSServerManager SSE stream)
    func updateProgress(percent: Int, message: String) {
        state = .generating(progress: percent, message: message)
    }

    // MARK: - Model Management

    /// Load a model
    func loadModel(modelId: String) async throws -> LoadModelResponse {
        return try await httpClient.loadModel(port: port, modelId: modelId)
    }

    /// Unload a model
    func unloadModel(modelId: String) async throws -> UnloadModelResponse {
        return try await httpClient.unloadModel(port: port, modelId: modelId)
    }

    /// List all models
    func listModels() async throws -> ModelsListResponse {
        return try await httpClient.listModels(port: port)
    }

    // MARK: - TTS Generation Methods

    /// Generate audio using Clone mode
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
        try fileService.ensureDirectoryExists(for: .clone)

        // Set loading state
        await MainActor.run {
            self.state = .loading
        }

        do {
            let response = try await httpClient.generateClone(
                port: port,
                modelId: model.rawValue,
                text: trimmedText,
                refAudioPath: refAudio.path,
                refText: refText,
                outputPath: outputPath.path
            )

            if response.success {
                let outputURL = URL(fileURLWithPath: response.outputPath)
                await MainActor.run {
                    self.state = .completed(outputURL: outputURL)
                }
                return outputURL
            } else {
                throw TTSUIError.generationFailed(response.error ?? "Unknown error")
            }
        } catch {
            await MainActor.run {
                self.state = .failed(error: error.localizedDescription)
            }
            throw error
        }
    }

    /// Generate audio using Control mode
    func control(model: ControlModel, text: String, speaker: TTSSpeaker, language: TTSLanguage, instruct: String?) async throws -> URL {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw TTSUIError.invalidInput("Target text is required")
        }

        // Create output path
        let outputPath = fileService.generateOutputPath(mode: .control)
        try fileService.ensureDirectoryExists(for: .control)

        // Set loading state
        await MainActor.run {
            self.state = .loading
        }

        do {
            let response = try await httpClient.generateControl(
                port: port,
                modelId: model.rawValue,
                text: trimmedText,
                speaker: speaker.rawValue,
                language: language.rawValue,
                instruct: instruct,
                outputPath: outputPath.path
            )

            if response.success {
                let outputURL = URL(fileURLWithPath: response.outputPath)
                await MainActor.run {
                    self.state = .completed(outputURL: outputURL)
                }
                return outputURL
            } else {
                throw TTSUIError.generationFailed(response.error ?? "Unknown error")
            }
        } catch {
            await MainActor.run {
                self.state = .failed(error: error.localizedDescription)
            }
            throw error
        }
    }

    /// Generate audio using Design mode
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
        try fileService.ensureDirectoryExists(for: .design)

        // Set loading state
        await MainActor.run {
            self.state = .loading
        }

        do {
            let response = try await httpClient.generateDesign(
                port: port,
                text: trimmedText,
                language: language.rawValue,
                instruct: trimmedInstruct,
                outputPath: outputPath.path
            )

            if response.success {
                let outputURL = URL(fileURLWithPath: response.outputPath)
                await MainActor.run {
                    self.state = .completed(outputURL: outputURL)
                }
                return outputURL
            } else {
                throw TTSUIError.generationFailed(response.error ?? "Unknown error")
            }
        } catch {
            await MainActor.run {
                self.state = .failed(error: error.localizedDescription)
            }
            throw error
        }
    }

    /// Cancel current generation
    func cancel() {
        state = .idle
    }
}
