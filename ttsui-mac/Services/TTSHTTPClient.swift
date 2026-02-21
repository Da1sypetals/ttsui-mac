//
//  TTSHTTPClient.swift
//  ttsui-mac
//
//  HTTP client for TTS server communication
//

import Foundation

/// Errors for HTTP client
enum HTTPClientError: LocalizedError {
    case serverNotRunning
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case encodingError(Error)
    case timeout
    case connectionError(Error)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .serverNotRunning:
            return "Server is not running"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, let message):
            if let message = message {
                return "HTTP error \(statusCode): \(message)"
            }
            return "HTTP error \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out"
        case .connectionError(let error):
            return "Connection error: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

/// Protocol for SSE log streaming delegate
protocol TTSHTTPClientLogDelegate: AnyObject {
    func httpClient(_ client: TTSHTTPClient, didReceiveLogEntry entry: LogEntry)
    func httpClientDidDisconnect(_ client: TTSHTTPClient)
}

/// HTTP client for TTS server
class TTSHTTPClient: NSObject, URLSessionDataDelegate {
    static let shared = TTSHTTPClient()

    private let session: URLSession
    private let timeout: TimeInterval = 300 // 5 minutes for long generations

    // SSE streaming
    private var logStreamTask: URLSessionDataTask?
    private weak var logDelegate: TTSHTTPClientLogDelegate?
    private var accumulatedSSEData: Data = Data()

    private override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: config, delegate: nil, delegateQueue: .main)
        super.init()
    }

    /// Get a session that uses self as delegate for SSE streaming
    private lazy var sseSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 0
        config.timeoutIntervalForResource = 0
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    private func baseURL(port: Int) -> URL {
        URL(string: "http://127.0.0.1:\(port)")!
    }

    // MARK: - Generic Request Methods

    private func get<T: Codable>(port: Int, path: String) async throws -> T {
        let url = baseURL(port: port).appendingPathComponent(path)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPClientError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let message = try? JSONDecoder().decode(ErrorResponse.self, from: data).detail
                throw HTTPClientError.httpError(statusCode: httpResponse.statusCode, message: message)
            }

            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw HTTPClientError.decodingError(error)
            }
        } catch let error as HTTPClientError {
            throw error
        } catch {
            throw HTTPClientError.connectionError(error)
        }
    }

    private func post<T: Codable, R: Codable>(port: Int, path: String, body: T) async throws -> R {
        let url = baseURL(port: port).appendingPathComponent(path)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw HTTPClientError.encodingError(error)
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPClientError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let message = try? JSONDecoder().decode(ErrorResponse.self, from: data).detail
                throw HTTPClientError.httpError(statusCode: httpResponse.statusCode, message: message)
            }

            do {
                return try JSONDecoder().decode(R.self, from: data)
            } catch {
                throw HTTPClientError.decodingError(error)
            }
        } catch let error as HTTPClientError {
            throw error
        } catch {
            throw HTTPClientError.connectionError(error)
        }
    }

    // MARK: - Health Check

    /// Check if server is healthy on the given port
    func isServerHealthy(port: Int) async -> Bool {
        do {
            let response: HealthResponse = try await get(port: port, path: "/health")
            return response.status == "healthy" || response.status == "ok"
        } catch {
            return false
        }
    }

    // MARK: - Model Management

    /// List all models
    func listModels(port: Int) async throws -> ModelsListResponse {
        return try await get(port: port, path: "/models")
    }

    /// Load a model
    func loadModel(port: Int, modelId: String) async throws -> LoadModelResponse {
        let request = LoadModelRequest(modelId: modelId)
        return try await post(port: port, path: "/models/load", body: request)
    }

    /// Unload a model
    func unloadModel(port: Int, modelId: String) async throws -> UnloadModelResponse {
        let request = LoadModelRequest(modelId: modelId)
        return try await post(port: port, path: "/models/unload", body: request)
    }

    // MARK: - Generation

    /// Generate audio using clone mode
    func generateClone(port: Int, modelId: String, text: String, refAudioPath: String, refText: String?, outputPath: String) async throws -> GenerateResponse {
        let request = GenerateCloneRequest(
            modelId: modelId,
            text: text,
            refAudioPath: refAudioPath,
            refText: refText,
            outputPath: outputPath
        )
        return try await post(port: port, path: "/generate/clone", body: request)
    }

    /// Generate audio using control mode
    func generateControl(port: Int, modelId: String, text: String, speaker: String, language: String, instruct: String?, outputPath: String) async throws -> GenerateResponse {
        let request = GenerateControlRequest(
            modelId: modelId,
            text: text,
            speaker: speaker,
            language: language,
            instruct: instruct,
            outputPath: outputPath
        )
        return try await post(port: port, path: "/generate/control", body: request)
    }

    /// Generate audio using design mode
    func generateDesign(port: Int, text: String, language: String, instruct: String, outputPath: String) async throws -> GenerateResponse {
        let request = GenerateDesignRequest(
            text: text,
            language: language,
            instruct: instruct,
            outputPath: outputPath
        )
        return try await post(port: port, path: "/generate/design", body: request)
    }

    // MARK: - Logs

    /// Get all accumulated logs
    func getLogs(port: Int) async throws -> LogsResponse {
        return try await get(port: port, path: "/logs")
    }

    // MARK: - SSE Log Streaming

    /// Start receiving log updates via SSE
    func startLogStream(delegate: TTSHTTPClientLogDelegate, port: Int) {
        stopLogStream()

        logDelegate = delegate
        accumulatedSSEData = Data()

        let url = baseURL(port: port).appendingPathComponent("/logs/stream")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 0 // No timeout for SSE

        // Create a data task using the SSE session (with self as delegate)
        logStreamTask = sseSession.dataTask(with: request)
        logStreamTask?.resume()
    }

    /// Stop log stream
    func stopLogStream() {
        logStreamTask?.cancel()
        logStreamTask = nil
        accumulatedSSEData = Data()
        logDelegate = nil
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard dataTask == logStreamTask else { return }

        accumulatedSSEData.append(data)
        parseAccumulatedSSEData()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard task == logStreamTask else { return }

        if let error = error {
            print("SSE connection error: \(error)")
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.logDelegate?.httpClientDidDisconnect(self)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard dataTask == logStreamTask else {
            completionHandler(.allow)
            return
        }

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 200 {
            completionHandler(.allow)
        } else {
            completionHandler(.cancel)
        }
    }

    // MARK: - SSE Parsing

    private func parseAccumulatedSSEData() {
        guard let text = String(data: accumulatedSSEData, encoding: .utf8) else { return }

        let events = text.components(separatedBy: "\n\n")

        for i in 0..<(events.count - 1) {
            let eventText = events[i]
            if !eventText.isEmpty {
                parseSSEEvent(eventText)
            }
        }

        if events.count > 0 {
            let lastEvent = events.last ?? ""
            if let lastEventData = lastEvent.data(using: .utf8) {
                accumulatedSSEData = lastEventData
            }
        }
    }

    private func parseSSEEvent(_ eventText: String) {
        let lines = eventText.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            let trimmedLine = String(line).trimmingCharacters(in: .whitespaces)

            if trimmedLine.hasPrefix(":") {
                continue
            }

            if trimmedLine.hasPrefix("data:") {
                let jsonString = String(trimmedLine.dropFirst("data:".count)).trimmingCharacters(in: .whitespaces)

                guard let jsonData = jsonString.data(using: .utf8) else { continue }

                do {
                    let serverEntry = try JSONDecoder().decode(ServerLogEntry.self, from: jsonData)
                    let logEntry = serverEntry.toLogEntry()

                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.logDelegate?.httpClient(self, didReceiveLogEntry: logEntry)
                    }
                } catch {
                    print("Failed to decode SSE log entry: \(error), json: \(jsonString)")
                }
            }
        }
    }
}

// MARK: - Helper Types

struct EmptyRequest: Codable {}

struct ErrorResponse: Codable {
    let detail: String
}
