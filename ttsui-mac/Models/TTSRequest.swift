//
//  TTSRequest.swift
//  ttsui-mac
//
//  Request models for each TTS mode
//

import Foundation

/// TTS operation modes
enum TTSMode: String, CaseIterable, Identifiable {
    case clone = "Clone"
    case control = "Control"
    case design = "Design"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .clone:
            return "Clone a voice from reference audio"
        case .control:
            return "Use predefined voices with emotion control"
        case .design:
            return "Create any voice from text description"
        }
    }
}

/// Available speakers for Control mode
enum TTSSpeaker: String, CaseIterable, Identifiable {
    // Chinese speakers
    case vivian = "Vivian"
    case serena = "Serena"
    case uncleFu = "Uncle_Fu"
    case dylan = "Dylan"  // Beijing Dialect
    case eric = "Eric"    // Sichuan Dialect

    // English speakers
    case ryan = "Ryan"
    case aiden = "Aiden"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .uncleFu:
            return "Uncle Fu"
        default:
            return rawValue
        }
    }

    var language: String {
        switch self {
        case .ryan, .aiden:
            return "English"
        default:
            return "Chinese"
        }
    }
}

/// Language options
enum TTSLanguage: String, CaseIterable, Identifiable {
    case chinese = "Chinese"
    case english = "English"

    var id: String { rawValue }
}

/// Clone mode model options
enum CloneModel: String, CaseIterable, Identifiable {
    case small = "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16"
    case large = "mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small:
            return "0.6B-Base (Fast)"
        case .large:
            return "1.7B-Base (Quality)"
        }
    }
}

/// Control mode model options
enum ControlModel: String, CaseIterable, Identifiable {
    case small = "mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-bf16"
    case large = "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small:
            return "0.6B-CustomVoice (Fast)"
        case .large:
            return "1.7B-CustomVoice (Quality)"
        }
    }
}

/// Request for Clone mode
struct CloneRequest {
    var model: CloneModel
    var text: String
    var refAudioURL: URL?
    var refText: String

    func toArguments(outputPath: String) -> [String] {
        var args = [
            "clone",
            "--model", model.rawValue,
            "--text", text,
            "--ref-audio", refAudioURL?.path ?? "",
            "--output", outputPath
        ]

        if !refText.isEmpty {
            args.append(contentsOf: ["--ref-text", refText])
        }

        return args
    }
}

/// Request for Control mode
struct ControlRequest {
    var model: ControlModel
    var text: String
    var speaker: TTSSpeaker
    var language: TTSLanguage
    var instruct: String

    func toArguments(outputPath: String) -> [String] {
        var args = [
            "control",
            "--model", model.rawValue,
            "--text", text,
            "--speaker", speaker.rawValue,
            "--language", language.rawValue,
            "--output", outputPath
        ]

        if !instruct.isEmpty {
            args.append(contentsOf: ["--instruct", instruct])
        }

        return args
    }
}

/// Request for Design mode
struct DesignRequest {
    var text: String
    var language: TTSLanguage
    var instruct: String

    func toArguments(outputPath: String) -> [String] {
        return [
            "design",
            "--text", text,
            "--language", language.rawValue,
            "--instruct", instruct,
            "--output", outputPath
        ]
    }
}
