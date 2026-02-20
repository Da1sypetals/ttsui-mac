//
//  DropZone.swift
//  ttsui-mac
//
//  File drop component for audio files
//

import SwiftUI
import UniformTypeIdentifiers

/// A drop zone for accepting audio file drops
struct DropZone: View {
    let title: String
    let acceptedTypes: [UTType]
    let onDrop: (URL) -> Void

    @State private var isTargeted = false

    init(
        title: String = "Drop audio file here",
        acceptedTypes: [UTType] = [.audio, .wav, .mp3],
        onDrop: @escaping (URL) -> Void
    ) {
        self.title = title
        self.acceptedTypes = acceptedTypes
        self.onDrop = onDrop
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 32))
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("or click to browse")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary.opacity(0.5))
        )
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onDrop(of: acceptedTypes, isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .onTapGesture {
            openFilePicker()
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }

            DispatchQueue.main.async {
                onDrop(url)
            }
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = acceptedTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            onDrop(url)
        }
    }
}

#Preview {
    DropZone { url in
        print("Dropped: \(url)")
    }
    .padding()
    .frame(width: 300)
}
