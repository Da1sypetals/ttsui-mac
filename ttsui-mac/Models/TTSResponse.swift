//
//  TTSResponse.swift
//  ttsui-mac
//
//  Parsed subprocess output models
//

import Foundation

/// Log entry type
enum LogType: String {
    case stdout
    case stderr
}

/// A single log entry from Python subprocess
struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let content: String
    let type: LogType

    static func == (lhs: LogEntry, rhs: LogEntry) -> Bool {
        lhs.id == rhs.id
    }
}

/// Progress update parsed from stderr
struct ProgressUpdate {
    let percent: Int
    let message: String

    init?(from string: String) {
        // Parse "PROGRESS: <percent> <message>" format
        guard string.hasPrefix("PROGRESS:") else { return nil }

        let parts = string.dropFirst("PROGRESS:".count).trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)

        guard parts.count >= 2,
              let percent = Int(parts[0]) else { return nil }

        self.percent = percent
        self.message = String(parts[1])
    }
}

/// Result from TTS generation
enum TTSResult {
    case success(outputURL: URL)
    case failure(error: String)
}

/// State of TTS generation
enum TTSState: Equatable {
    case idle
    case loading
    case generating(progress: Int, message: String)
    case saving
    case completed(outputURL: URL)
    case failed(error: String)

    var isProcessing: Bool {
        switch self {
        case .idle, .completed, .failed:
            return false
        default:
            return true
        }
    }

    static func == (lhs: TTSState, rhs: TTSState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.loading, .loading):
            return true
        case (.generating(let lp, let lm), .generating(let rp, let rm)):
            return lp == rp && lm == rm
        case (.saving, .saving):
            return true
        case (.completed(let l), .completed(let r)):
            return l == r
        case (.failed(let l), .failed(let r)):
            return l == r
        default:
            return false
        }
    }
}
