//
//  PythonSubprocess.swift
//  ttsui-mac
//
//  Python process manager for TTS generation
//

import Foundation
import Combine

/// Protocol for subprocess progress reporting
protocol PythonSubprocessDelegate: AnyObject {
    func subprocess(_ subprocess: PythonSubprocess, didOutputLog entry: LogEntry)
    func subprocess(_ subprocess: PythonSubprocess, didUpdateProgress percent: Int, message: String)
}

/// Manages Python subprocess execution for TTS generation
class PythonSubprocess: ObservableObject {
    weak var delegate: PythonSubprocessDelegate?

    @Published var isRunning: Bool = false
    @Published var currentProgress: Int = 0
    @Published var currentMessage: String = ""

    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    private let settings = TTSSettings.shared

    // Store stdout output for use in termination handler
    private var stdoutOutput: String?
    private var stdoutError: String?

    /// Get the path to the Python TTS script
    private func getScriptPath() -> URL? {
        let scriptName = "tts_generate.py"

        // Method 1: Resolve relative to this source file (works in development)
        // This file is at: ttsui-mac/Services/PythonSubprocess.swift
        // Script is at: python/tts_generate.py (project root)
        let sourceFileURL = URL(fileURLWithPath: #file)
        let projectRoot = sourceFileURL
            .deletingLastPathComponent()  // Services/
            .deletingLastPathComponent()  // ttsui-mac/
            .deletingLastPathComponent()  // project root
        let scriptRelativeToSource = projectRoot
            .appendingPathComponent("python")
            .appendingPathComponent(scriptName)

        if FileManager.default.fileExists(atPath: scriptRelativeToSource.path) {
            return scriptRelativeToSource
        }

        // Method 2: Try current working directory
        let cwdPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("python")
            .appendingPathComponent(scriptName)

        if FileManager.default.fileExists(atPath: cwdPath.path) {
            return cwdPath
        }

        // Method 3: Try in the app bundle (for release builds)
        if let bundlePath = Bundle.main.url(forResource: "tts_generate", withExtension: "py", subdirectory: "python") {
            return bundlePath
        }

        // Method 4: Try in the python folder relative to the bundle
        let bundlePythonPath = Bundle.main.bundleURL
            .appendingPathComponent("python")
            .appendingPathComponent(scriptName)
        if FileManager.default.fileExists(atPath: bundlePythonPath.path) {
            return bundlePythonPath
        }

        return nil
    }

    /// Run the TTS generation subprocess
    /// - Parameters:
    ///   - mode: TTS mode (clone, control, design)
    ///   - args: Command-line arguments for the script
    ///   - timeout: Maximum execution time in seconds
    /// - Returns: URL to the generated output file
    @discardableResult
    func run(mode: TTSMode, args: [String], timeout: TimeInterval = 1800) async throws -> URL {
        guard let scriptPath = getScriptPath() else {
            throw TTSUIError.scriptNotFound
        }

        let pythonPath = settings.pythonPath

        // Verify Python exists
        guard FileManager.default.fileExists(atPath: pythonPath) else {
            throw TTSUIError.pythonNotFound(pythonPath)
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Reset stored output values
            self.stdoutOutput = nil
            self.stdoutError = nil

            DispatchQueue.main.async {
                self.isRunning = true
                self.currentProgress = 0
                self.currentMessage = "Starting..."
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = [scriptPath.path] + args

            // Set up environment
            var environment = ProcessInfo.processInfo.environment
            environment["PYTHONUNBUFFERED"] = "1"
            process.environment = environment

            // Create pipes for stdout and stderr
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            self.process = process
            self.stdoutPipe = stdoutPipe
            self.stderrPipe = stderrPipe

            // Handle stdout
            stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                if let output = String(data: data, encoding: .utf8) {
                    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        let entry = LogEntry(timestamp: Date(), content: trimmed, type: .stdout)
                        DispatchQueue.main.async {
                            self?.delegate?.subprocess(self!, didOutputLog: entry)
                        }

                        // Store output for use in termination handler
                        if trimmed.hasPrefix("ERROR:") {
                            self?.stdoutError = trimmed
                        } else if trimmed.hasSuffix(".wav") {
                            self?.stdoutOutput = trimmed
                        }
                    }
                }
            }

            // Handle stderr (progress updates)
            stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
                    for line in lines {
                        let trimmedLine = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmedLine.isEmpty { continue }

                        let entry = LogEntry(timestamp: Date(), content: trimmedLine, type: .stderr)
                        DispatchQueue.main.async {
                            self?.delegate?.subprocess(self!, didOutputLog: entry)
                        }

                        // Check for progress update
                        if let progress = ProgressUpdate(from: trimmedLine) {
                            DispatchQueue.main.async {
                                self?.currentProgress = progress.percent
                                self?.currentMessage = progress.message
                                self?.delegate?.subprocess(self!, didUpdateProgress: progress.percent, message: progress.message)
                            }
                        }
                    }
                }
            }

            // Handle process termination
            process.terminationHandler = { [weak self] process in
                DispatchQueue.main.async {
                    self?.isRunning = false
                }

                // Read any remaining output
                if let stdoutData = try? stdoutPipe.fileHandleForReading.readToEnd(),
                   let output = String(data: stdoutData, encoding: .utf8) {
                    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        let entry = LogEntry(timestamp: Date(), content: trimmed, type: .stdout)
                        DispatchQueue.main.async {
                            self?.delegate?.subprocess(self!, didOutputLog: entry)
                        }

                        // Store for later use
                        if trimmed.hasPrefix("ERROR:") {
                            self?.stdoutError = trimmed
                        } else if trimmed.hasSuffix(".wav") {
                            self?.stdoutOutput = trimmed
                        }
                    }
                }

                // Check for error first (from stored output)
                if let errorOutput = self?.stdoutError, errorOutput.hasPrefix("ERROR:") {
                    let error = String(errorOutput.dropFirst("ERROR:".count)).trimmingCharacters(in: .whitespaces)
                    continuation.resume(throwing: TTSUIError.generationFailed(error))
                    return
                }

                // Check for output file path (from stored output)
                if let outputPath = self?.stdoutOutput, outputPath.hasSuffix(".wav") {
                    let url = URL(fileURLWithPath: outputPath)
                    continuation.resume(returning: url)
                    return
                }

                if process.terminationStatus != 0 {
                    continuation.resume(throwing: TTSUIError.processFailed(process.terminationStatus))
                } else {
                    continuation.resume(throwing: TTSUIError.noOutput)
                }
            }

            do {
                try process.run()
            } catch {
                DispatchQueue.main.async {
                    self.isRunning = false
                }
                continuation.resume(throwing: error)
            }
        }
    }

    /// Cancel the running process
    func cancel() {
        process?.terminate()
        process = nil
        isRunning = false
    }
}

/// Errors for TTSUI
enum TTSUIError: LocalizedError {
    case scriptNotFound
    case pythonNotFound(String)
    case generationFailed(String)
    case processFailed(Int32)
    case noOutput
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .scriptNotFound:
            return "TTS generation script not found"
        case .pythonNotFound(let path):
            return "Python not found at: \(path)"
        case .generationFailed(let message):
            return "TTS generation failed: \(message)"
        case .processFailed(let code):
            return "Process exited with code \(code)"
        case .noOutput:
            return "No output generated"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        }
    }
}
