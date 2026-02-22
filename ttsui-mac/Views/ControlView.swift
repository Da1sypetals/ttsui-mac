//
//  ControlView.swift
//  ttsui-mac
//
//  Control mode UI
//

import SwiftUI

/// View for Control mode - predefined voices with emotion control
struct ControlView: View {
    @ObservedObject var viewModel: ControlViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Model Selection
                ModelSelectionGroup(
                    title: "Model",
                    systemImage: "cpu",
                    models: viewModel.modelSelectionItems,
                    selectedModelId: $viewModel.selectedModelId,
                    onLoad: { modelId in
                        Task {
                            await viewModel.loadModel(modelId: modelId)
                        }
                    },
                    onUnload: { modelId in
                        Task {
                            await viewModel.unloadModel(modelId: modelId)
                        }
                    }
                )

                // Voice Settings
                GroupBox(label: Label("Voice Settings", systemImage: "person.wave.2")) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Language Selection
                        HStack {
                            Text("Language:")
                                .frame(width: 80, alignment: .leading)

                            Picker("Language", selection: $viewModel.selectedLanguage) {
                                ForEach(TTSLanguage.allCases) { language in
                                    Text(language.rawValue).tag(language)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 200)
                        }

                        // Speaker Selection
                        HStack {
                            Text("Speaker:")
                                .frame(width: 80, alignment: .leading)

                            Picker("Speaker", selection: $viewModel.selectedSpeaker) {
                                ForEach(viewModel.availableSpeakers) { speaker in
                                    Text(speaker.displayName).tag(speaker)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 200)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Emotion/Style Instructions
                GroupBox(label: Label("Emotion & Style", systemImage: "theatermasks")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Describe the emotion or speaking style (optional)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $viewModel.emotionInstruct)
                            .frame(height: 60)
                            .font(.body)
                            .border(Color.secondary.opacity(0.2))

                        Text("Examples: \"Very happy and excited\", \"Calm and soothing\", \"Professional and formal\"")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
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
}

#Preview {
    ControlView(viewModel: ControlViewModel())
        .frame(width: 500, height: 800)
}
