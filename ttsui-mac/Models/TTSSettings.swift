//
//  TTSSettings.swift
//  ttsui-mac
//
//  App settings and configuration
//

import Foundation
import Combine

/// App-wide settings
class TTSSettings: ObservableObject {
    static let shared = TTSSettings()

    /// Python executable path
    @Published var pythonPath: String

    /// Default timeout for TTS generation (seconds)
    let defaultTimeout: TimeInterval = 1800

    private init() {
        // Python path resolution order:
        // 1. TTSUI_PYTHON environment variable
        // 2. .env file in app bundle
        // 3. Hardcoded fallback

        if let envPath = ProcessInfo.processInfo.environment["TTSUI_PYTHON"] {
            self.pythonPath = envPath
            return
        }

        // Try to load from .env file
        if let envURL = Bundle.main.url(forResource: ".env", withExtension: nil),
           let contents = try? String(contentsOf: envURL, encoding: .utf8) {
            for line in contents.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("TTSUI_PYTHON=") {
                    let path = String(trimmed.dropFirst("TTSUI_PYTHON=".count))
                    self.pythonPath = path
                    return
                }
            }
        }

        // Try .env in project root (for development)
        let projectEnvPath = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent(".env")
        if let contents = try? String(contentsOf: projectEnvPath, encoding: .utf8) {
            for line in contents.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("TTSUI_PYTHON=") {
                    let path = String(trimmed.dropFirst("TTSUI_PYTHON=".count))
                    self.pythonPath = path
                    return
                }
            }
        }

        // Hardcoded fallback
        self.pythonPath = "/Users/daisy/miniconda3/bin/python"
    }
}
