//
//  HTTPModels.swift
//  ttsui-mac
//
//  Codable models for HTTP API communication
//

import Foundation

// MARK: - Model State

/// Model loading state
enum ModelState: String, Codable {
    case unloaded
    case loading
    case loaded
    case unloading
    case error
}

// MARK: - Memory Stats

/// Memory statistics for model load/unload operations
struct MemoryStats: Codable {
    let beforeMb: Double?
    let afterMb: Double?
    let deltaMb: Double?

    enum CodingKeys: String, CodingKey {
        case beforeMb = "before_mb"
        case afterMb = "after_mb"
        case deltaMb = "delta_mb"
    }
}

// MARK: - Model Info

/// Information about a model
struct ModelInfo: Codable, Identifiable {
    let modelId: String
    let state: ModelState
    let memory: MemoryStats
    let loadTimeSeconds: Double?
    let error: String?

    var id: String { modelId }

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case state
        case memory
        case loadTimeSeconds = "load_time_seconds"
        case error
    }
}

/// Response for listing models
struct ModelsListResponse: Codable {
    let models: [ModelInfo]
}

// MARK: - Load/Unload Model

/// Request to load or unload a model
struct LoadModelRequest: Codable {
    let modelId: String

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
    }
}

/// Response from load model endpoint
struct LoadModelResponse: Codable {
    let modelId: String
    let state: String
    let memory: MemoryStats
    let loadTimeSeconds: Double?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case state
        case memory
        case loadTimeSeconds = "load_time_seconds"
        case error
    }
}

/// Response from unload model endpoint
struct UnloadModelResponse: Codable {
    let modelId: String
    let state: String
    let memory: MemoryStats
    let error: String?

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case state
        case memory
        case error
    }
}

// MARK: - Generation Requests

/// Request for clone mode generation
struct GenerateCloneRequest: Codable {
    let modelId: String
    let text: String
    let refAudioPath: String
    let refText: String?
    let outputPath: String

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case text
        case refAudioPath = "ref_audio_path"
        case refText = "ref_text"
        case outputPath = "output_path"
    }
}

/// Request for control mode generation
struct GenerateControlRequest: Codable {
    let modelId: String
    let text: String
    let speaker: String
    let language: String
    let instruct: String?
    let outputPath: String

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case text
        case speaker
        case language
        case instruct
        case outputPath = "output_path"
    }
}

/// Request for design mode generation
struct GenerateDesignRequest: Codable {
    let text: String
    let language: String
    let instruct: String
    let outputPath: String

    enum CodingKeys: String, CodingKey {
        case text
        case language
        case instruct
        case outputPath = "output_path"
    }
}

/// Response from generation endpoints
struct GenerateResponse: Codable {
    let outputPath: String
    let success: Bool
    let error: String?

    enum CodingKeys: String, CodingKey {
        case outputPath = "output_path"
        case success
        case error
    }
}

// MARK: - Health Check

/// Health check response
struct HealthResponse: Codable {
    let status: String
    let timestamp: String?
    let loadedModelsCount: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case timestamp
        case loadedModelsCount = "loaded_models_count"
    }
}

// MARK: - Log Entry (for SSE stream)

/// Log entry from server
struct ServerLogEntry: Codable, Identifiable {
    let timestamp: String
    let level: String
    let message: String

    var id: String { "\(timestamp)-\(level)-\(message)" }

    /// Convert to UI LogEntry
    func toLogEntry() -> LogEntry {
        let logType: LogType
        switch level.uppercased() {
        case "ERROR", "CRITICAL":
            logType = .stderr
        default:
            logType = .stdout
        }

        // Parse timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss,SSS"
        let date = formatter.date(from: timestamp) ?? Date()

        // Format message with level prefix
        let formattedContent = "[\(level)] \(message)"

        return LogEntry(timestamp: date, content: formattedContent, type: logType)
    }
}

/// Response from logs endpoint
struct LogsResponse: Codable {
    let logs: [ServerLogEntry]
}
