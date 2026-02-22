//
//  TTSServerManager.swift
//  ttsui-mac
//
//  Server lifecycle manager for Python TTS server
//

import Foundation
import Combine

/// Server state
enum ServerState: Equatable {
    case stopped
    case starting
    case running
    case failed(String)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var isStarting: Bool {
        if case .starting = self { return true }
        return false
    }
}

/// Manages the Python TTS server lifecycle
class TTSServerManager: ObservableObject {
    static let shared = TTSServerManager()

    @Published var state: ServerState = .stopped
    @Published var serverLogs: [LogEntry] = []

    /// The actual port being used (found dynamically at startup)
    private(set) var currentPort: Int = 0

    private let settings = TTSSettings.shared
    private let httpClient = TTSHTTPClient.shared
    private var process: Process?
    private var healthCheckTimer: Timer?
    private var serverReadyContinuation: CheckedContinuation<Void, Error>?

    private init() {}

    // MARK: - Server Lifecycle

    /// Start the Python server
    func startServer() async {
        guard state == .stopped else { return }

        await MainActor.run {
            self.state = .starting
            self.serverLogs.removeAll()
        }

        // Find an available port
        guard let port = findAvailablePort(startingFrom: settings.serverPort) else {
            fatalError("No available port found. Cannot start application.")
        }
        currentPort = port

        // Get script path
        guard let scriptPath = getScriptPath() else {
            fatalError("Server script not found. Cannot start application.")
        }

        let pythonPath = settings.pythonPath

        // Verify Python exists
        guard FileManager.default.fileExists(atPath: pythonPath) else {
            fatalError("Python not found at: \(pythonPath). Cannot start application.")
        }

        // Create and configure process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [
            scriptPath.path,
            "--host", "127.0.0.1",
            "--port", "\(currentPort)"
        ]

        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"] = "1"
        process.environment = environment

        // Capture stdout AND stderr for logs
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        self.process = process

        // Handle stdout (main log source - Python prints to stderr for all logs)
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let output = String(data: data, encoding: .utf8) {
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    DispatchQueue.main.async {
                        let entry = LogEntry(timestamp: Date(), content: trimmed, type: .stdout)
                        self?.serverLogs.append(entry)
                        self?.handleLogEntry(entry)
                    }
                }
            }
        }

        // Handle stderr (errors and main log output)
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let output = String(data: data, encoding: .utf8) {
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    DispatchQueue.main.async {
                        let entry = LogEntry(timestamp: Date(), content: trimmed, type: .stderr)
                        self?.serverLogs.append(entry)
                        self?.handleLogEntry(entry)
                    }
                }
            }
        }

        // Handle process termination
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.healthCheckTimer?.invalidate()
                self?.healthCheckTimer = nil

                if let continuation = self?.serverReadyContinuation {
                    self?.serverReadyContinuation = nil
                    fatalError("Server process terminated during startup with code \(process.terminationStatus). Cannot start application.")
                }

                if case .running = self?.state ?? .stopped {
                    self?.state = .failed("Server process terminated unexpectedly")
                }
            }
        }

        do {
            try process.run()
        } catch {
            fatalError("Failed to start server process: \(error.localizedDescription). Cannot start application.")
        }

        // Wait for server to be ready
        do {
            try await waitForServerReady()
            await MainActor.run {
                self.state = .running
            }

            // Start health monitoring
            startHealthMonitoring()

        } catch {
            process.terminate()
            self.process = nil
            fatalError("Server failed to start: \(error.localizedDescription). Cannot start application.")
        }
    }

    /// Stop the Python server
    func stopServer() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil

        process?.terminate()
        process = nil

        state = .stopped
    }

    // MARK: - Private Methods

    /// Find an available port starting from the given port
    private func findAvailablePort(startingFrom basePort: Int) -> Int? {
        // Try ports from basePort to basePort + 100
        for port in basePort..<(basePort + 100) {
            if !isPortInUse(port) {
                return port
            }
        }
        return nil
    }

    /// Check if a port is already in use
    private func isPortInUse(_ port: Int) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "lsof -i :\(port) -sTCP:LISTEN"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func getScriptPath() -> URL? {
        let scriptName = "tts_server.py"

        // Method 1: Resolve relative to this source file
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

        // Method 3: Try in the app bundle
        if let bundlePath = Bundle.main.url(forResource: "tts_server", withExtension: "py", subdirectory: "python") {
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

    private func waitForServerReady() async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.serverReadyContinuation = continuation
            self.checkServerHealthWithRetry()
        }
    }

    private func checkServerHealthWithRetry(retryCount: Int = 0) {
        Task {
            let isHealthy = await httpClient.isServerHealthy(port: currentPort)

            if isHealthy {
                if let continuation = serverReadyContinuation {
                    serverReadyContinuation = nil
                    continuation.resume()
                }
            } else if retryCount < 30 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                checkServerHealthWithRetry(retryCount: retryCount + 1)
            } else {
                if let continuation = serverReadyContinuation {
                    serverReadyContinuation = nil
                    continuation.resume(throwing: ServerError.timeout)
                }
            }
        }
    }

    private func startHealthMonitoring() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                guard let self = self else { return }
                let isHealthy = await self.httpClient.isServerHealthy(port: self.currentPort)
                if !isHealthy && self.state.isRunning {
                    await MainActor.run {
                        self.state = .failed("Server health check failed")
                    }
                }
            }
        }
    }

    private func handleLogEntry(_ entry: LogEntry) {
        TTSService.shared.addLogEntry(entry)

        if let progress = ProgressUpdate(from: entry.content) {
            TTSService.shared.updateProgress(percent: progress.percent, message: progress.message)
        }
    }
}

// MARK: - Server Errors

enum ServerError: LocalizedError {
    case timeout

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Server startup timed out"
        }
    }
}
