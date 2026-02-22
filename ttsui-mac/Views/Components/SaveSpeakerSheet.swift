//
//  SaveSpeakerSheet.swift
//  ttsui-mac
//
//  Modal sheet for saving a new speaker
//

import SwiftUI

struct SaveSpeakerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CloneViewModel

    @State private var speakerName: String = ""
    @FocusState private var isNameFieldFocused: Bool

    let maxNameLength = 16

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Save Speaker")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Name field
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Speaker name", text: $speakerName)
                    .focused($isNameFieldFocused)
                    .onSubmit {
                        saveIfValid()
                    }

                Text("\(speakerName.count)/\(maxNameLength)")
                    .font(.caption)
                    .foregroundColor(speakerName.count > maxNameLength ? .red : .secondary)
            }

            // Audio info
            VStack(alignment: .leading, spacing: 4) {
                Text("Audio")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Image(systemName: "waveform")
                        .foregroundStyle(.green)
                    Text(viewModel.effectiveReferenceAudio?.lastPathComponent ?? "No audio selected")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
            }

            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Save") {
                    saveIfValid()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .keyboardShortcut(.return)
            }
        }
        .padding(20)
        .frame(width: 320)
        .onAppear {
            isNameFieldFocused = true
        }
    }

    private var isValid: Bool {
        let trimmed = speakerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= maxNameLength
    }

    private func saveIfValid() {
        guard isValid else { return }
        viewModel.saveAsNewSpeaker(name: speakerName)
        dismiss()
    }
}

#Preview {
    SaveSpeakerSheet(viewModel: CloneViewModel())
}
