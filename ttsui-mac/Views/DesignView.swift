//
//  DesignView.swift
//  ttsui-mac
//
//  Design mode UI
//

import SwiftUI

/// View for Design mode - create any voice from text description
struct DesignView: View {
    @ObservedObject var viewModel: DesignViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Model Info with Load/Unload
                GroupBox(label: Label("Model", systemImage: "cpu")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Qwen3-TTS-12Hz-1.7B-VoiceDesign")
                                .fontWeight(.medium)
                            Text("(only option for voice design)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Load/Unload button
                        switch viewModel.modelState {
                        case .unloaded:
                            Button("Load") {
                                Task {
                                    await viewModel.loadModel()
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                        case .loading:
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                        case .loaded:
                            Button("Unload") {
                                Task {
                                    await viewModel.unloadModel()
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.red)

                        case .unloading:
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Unloading...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                        case .error:
                            Button("Retry") {
                                Task {
                                    await viewModel.loadModel()
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.orange)
                        }
                    }
                    .padding(.vertical, 4)

                    // Show error if any
                    if viewModel.modelState == .error, let info = viewModel.modelInfo, let error = info.error {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text("Error: \(error)")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .padding(.top, 4)
                    }
                }

                // Language Selection
                GroupBox(label: Label("Language", systemImage: "globe")) {
                    Picker("Language", selection: $viewModel.selectedLanguage) {
                        ForEach(TTSLanguage.allCases) { language in
                            Text(language.rawValue).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                }

                // Voice Description
                GroupBox(label: Label("Voice Description", systemImage: "person.crop.circle.badge.plus")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Describe the voice you want to create (required)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $viewModel.voiceDescription)
                            .frame(minHeight: 80, maxHeight: 120)
                            .font(.body)
                            .border(Color.secondary.opacity(0.2))

                        Text("Examples:")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\"A cheerful young female voice with high pitch and energetic tone\"")
                            Text("\"A deep, calm male voice with a professional demeanor\"")
                            Text("\"A warm, grandmotherly voice with a gentle, caring quality\"")
                        }
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 8)
                    }
                }

                // Target Text
                GroupBox(label: Label("Target Text", systemImage: "text.bubble")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Text to synthesize (required)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $viewModel.targetText)
                            .frame(minHeight: 80, maxHeight: 150)
                            .font(.body)
                            .border(Color.secondary.opacity(0.2))

                        Text("\(viewModel.targetText.count) characters")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Generation Controls
                HStack(spacing: 16) {
                    GenerateButton(
                        title: "Generate",
                        isLoading: viewModel.state.isProcessing,
                        progress: progressValue,
                        progressMessage: progressMessage,
                        isEnabled: viewModel.canGenerate,
                        cancelAction: {
                            viewModel.cancel()
                        },
                        action: {
                            Task {
                                await viewModel.generate()
                            }
                        }
                    )

                    if viewModel.generatedAudioURL != nil {
                        Button(action: { viewModel.saveGeneratedAudio() }) {
                            Label("Save As...", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }

                // Error message
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }

                // Audio Player
                if let audioURL = viewModel.generatedAudioURL {
                    AudioPlayerView(url: audioURL, title: "Generated Audio")
                }
            }
            .padding()
        }
    }

    private var progressValue: Int? {
        if case .generating(let progress, _) = viewModel.state {
            return progress
        }
        return nil
    }

    private var progressMessage: String? {
        if case .generating(_, let message) = viewModel.state {
            return message
        }
        return nil
    }
}

#Preview {
    DesignView(viewModel: DesignViewModel())
        .frame(width: 500, height: 800)
}
