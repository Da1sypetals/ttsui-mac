//
//  CloneView.swift
//  ttsui-mac
//
//  Clone mode UI
//

import SwiftUI

/// View for Clone mode - voice cloning from reference audio
struct CloneView: View {
    @ObservedObject var viewModel: CloneViewModel
    @State private var editedSpeakerName: String = ""

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

                // Speaker Selection
                GroupBox(label: Label("Speaker", systemImage: "person.wave.2")) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Speaker picker
                        Picker("", selection: Binding(
                            get: { viewModel.selectedSpeaker },
                            set: { speaker in
                                viewModel.selectSpeaker(speaker)
                                if let speaker = speaker {
                                    editedSpeakerName = speaker.name
                                } else {
                                    editedSpeakerName = ""
                                }
                            }
                        )) {
                            Text("(No Speaker)").tag(nil as CloneSpeaker?)
                            ForEach(viewModel.speakers) { speaker in
                                Text(speaker.name).tag(speaker as CloneSpeaker?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)

                        // Speaker info and controls when speaker is selected
                        if let speaker = viewModel.selectedSpeaker {
                            // Speaker details
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "waveform")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 16)
                                    Text("Audio: \(speaker.audioFileName)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }

                                HStack {
                                    Image(systemName: "text.alignleft")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 16)
                                    if let refText = speaker.textReference, !refText.isEmpty {
                                        Text(refText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    } else {
                                        Text("No reference text")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                            .italic()
                                    }
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(6)

                            // Name field and buttons
                            HStack(spacing: 12) {
                                TextField("Speaker name", text: $editedSpeakerName)
                                    .frame(width: 150)
                                    .onSubmit {
                                        viewModel.saveCurrentSpeaker(newName: editedSpeakerName)
                                    }

                                Button("Save") {
                                    viewModel.saveCurrentSpeaker(newName: editedSpeakerName)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button("Delete") {
                                    viewModel.deleteSpeaker(speaker)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(.red)
                            }
                        } else {
                            // Save as new speaker button
                            Button("Save as speaker...") {
                                viewModel.showSaveSpeakerSheet = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(viewModel.effectiveReferenceAudio == nil)
                        }
                    }
                    .onAppear {
                        if let speaker = viewModel.selectedSpeaker {
                            editedSpeakerName = speaker.name
                        }
                    }
                    .onChange(of: viewModel.selectedSpeaker) { _, newSpeaker in
                        if let speaker = newSpeaker {
                            editedSpeakerName = speaker.name
                        }
                    }
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
                        } else if case .speaker(let speaker) = viewModel.referenceAudioSource {
                            HStack {
                                Image(systemName: "person.wave.2.fill")
                                    .foregroundStyle(.green)
                                Text("Speaker: \(speaker.name)")
                                    .lineLimit(1)
                                Spacer()
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
        .sheet(isPresented: $viewModel.showSaveSpeakerSheet) {
            SaveSpeakerSheet(viewModel: viewModel)
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
    CloneView(viewModel: CloneViewModel())
        .frame(width: 500, height: 800)
}
