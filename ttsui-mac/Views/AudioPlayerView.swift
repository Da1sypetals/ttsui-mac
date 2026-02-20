//
//  AudioPlayerView.swift
//  ttsui-mac
//
//  Audio playback controls
//

import SwiftUI

/// A view for playing audio with playback controls
struct AudioPlayerView: View {
    let url: URL
    let title: String?

    @ObservedObject private var audioService = AudioService.shared

    init(url: URL, title: String? = nil) {
        self.url = url
        self.title = title
    }

    var body: some View {
        GroupBox(label: Label(title ?? "Audio Player", systemImage: "play.circle")) {
            VStack(spacing: 12) {
                // File info
                HStack {
                    Image(systemName: "waveform")
                        .foregroundStyle(Color.accentColor)
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text(url.fileSizeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Progress slider
                HStack(spacing: 8) {
                    Text(audioService.formatTime(audioService.audioDuration * audioService.playbackProgress))
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 45, alignment: .leading)

                    Slider(
                        value: $audioService.playbackProgress,
                        in: 0...1,
                        onEditingChanged: { isEditing in
                            if isEditing {
                                // Preview during drag
                            } else {
                                audioService.seek(to: audioService.playbackProgress)
                            }
                        }
                    )
                    .disabled(audioService.audioDuration == 0)

                    Text(audioService.formatTime(audioService.audioDuration))
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 45, alignment: .trailing)
                }

                // Playback controls
                HStack(spacing: 20) {
                    // Rewind button
                    Button(action: {
                        let newProgress = max(0, audioService.playbackProgress - 0.1)
                        audioService.seek(to: newProgress)
                    }) {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .disabled(audioService.audioDuration == 0)

                    // Play/Pause button
                    Button(action: {
                        if audioService.currentAudioURL != url {
                            try? audioService.play(url: url)
                        } else {
                            audioService.togglePlayback()
                        }
                    }) {
                        Image(systemName: audioService.isPlaying && audioService.currentAudioURL == url ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)

                    // Forward button
                    Button(action: {
                        let newProgress = min(1, audioService.playbackProgress + 0.1)
                        audioService.seek(to: newProgress)
                    }) {
                        Image(systemName: "goforward.10")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .disabled(audioService.audioDuration == 0)
                }

                // Open in Finder button
                HStack {
                    Spacer()
                    Button(action: { NSWorkspace.shared.activateFileViewerSelecting([url]) }) {
                        Label("Show in Finder", systemImage: "folder")
                    }
                    .buttonStyle(.link)
                    .controlSize(.small)
                }
            }
            .padding(4)
        }
        .onAppear {
            // Preload audio to get duration
            if audioService.currentAudioURL != url {
                // Just load to get duration, don't play
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    audioService.audioDuration = player.duration
                }
            }
        }
    }
}

import AVFoundation

// Extension to get file size string
extension URL {
    var fileSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file

        if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
           let fileSize = attributes[.size] as? UInt64 {
            return formatter.string(fromByteCount: Int64(fileSize))
        }
        return "Unknown"
    }
}

#Preview {
    AudioPlayerView(
        url: URL(fileURLWithPath: "/path/to/audio.wav"),
        title: "Generated Audio"
    )
    .padding()
    .frame(width: 400)
}
