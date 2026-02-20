//
//  CloneView.swift
//  ttsui-mac
//
//  Clone mode UI
//

import SwiftUI

/// View for Clone mode - voice cloning from reference audio
struct CloneView: View {
    @StateObject private var viewModel = CloneViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Model Selection
                GroupBox(label: Label("Model", systemImage: "cpu")) {
                    Picker("Model", selection: $viewModel.selectedModel) {
                        ForEach(CloneModel.allCases) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                // Reference Audio Section
                GroupBox(label: Label("Reference Audio", systemImage: "waveform")) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Recording controls
                        HStack(spacing: 12) {
                            RecordButton(
                                isRecording: viewModel.audioRecorder.isRecording,
                                duration: viewModel.audioRecorder.formattedDuration,
                                action: { viewModel.audioRecorder.toggleRecording() }
                            )

                            if viewModel.audioRecorder.hasRecordedAudio {
                                Button("Use Recorded") {
                                    viewModel.useRecordedAudio()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(viewModel.isRecordedAudioSelected)
                                .opacity(viewModel.isRecordedAudioSelected ? 0.5 : 1.0)
                            }
                        }

                        // Show current recorded file name
                        if let filename = viewModel.audioRecorder.currentRecordedFilename {
                            HStack {
                                Image(systemName: "waveform")
                                    .foregroundStyle(.secondary)
                                Text("Latest: \(filename)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        // File drop zone
                        DropZone(title: "Drop reference audio file") { url in
                            viewModel.useFile(url)
                        }

                        // Current reference audio indicator
                        if case .file(let url) = viewModel.referenceAudioSource {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundStyle(.green)
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                                Spacer()
                                Button(action: { viewModel.clearReferenceAudio() }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                        } else if case .recorded(let url) = viewModel.referenceAudioSource {
                            HStack {
                                Image(systemName: "mic.fill")
                                    .foregroundStyle(.green)
                                Text("Using: \(url.lastPathComponent)")
                                    .lineLimit(1)
                                Spacer()
                                Button(action: { viewModel.clearReferenceAudio() }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                        }

                        // Reference text (optional)
                        VStack(alignment: .leading) {
                            Text("Reference Text (optional)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextEditor(text: $viewModel.referenceText)
                                .frame(height: 60)
                                .font(.body)
                                .border(Color.secondary.opacity(0.2))
                        }
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

// MARK: - Record Button

struct RecordButton: View {
    let isRecording: Bool
    let duration: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isRecording {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white)
                        .frame(width: 12, height: 12)
                    Text("Stop (\(duration))")
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                } else {
                    Circle()
                        .fill(.red)
                        .frame(width: 12, height: 12)
                    Text("Record")
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(isRecording ? .red : .gray)
    }
}

#Preview {
    CloneView()
        .frame(width: 500, height: 800)
}
