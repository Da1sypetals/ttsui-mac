//
//  ContentView.swift
//  ttsui-mac
//
//  Main view with mode tabs
//

import SwiftUI

/// Main content view with mode selector and panel switching
struct ContentView: View {
    @State private var selectedMode: TTSMode = .clone
    @ObservedObject private var ttsService = TTSService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color.accentColor)

                Text("TTSUI")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Text("Qwen3-TTS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Mode Selector
            ModeSelector(selectedMode: $selectedMode)
                .padding(.bottom, 8)

            Divider()

            // Content Area
            Group {
                switch selectedMode {
                case .clone:
                    CloneView()
                case .control:
                    ControlView()
                case .design:
                    DesignView()
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            // Log Panel
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Python Output")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if ttsService.state.isProcessing {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.mini)
                            Text("Processing...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal)

                LogPanel(logEntries: $ttsService.logEntries, maxHeight: 120)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .frame(minWidth: 550, minHeight: 600)
        .onAppear {
            // Initialize base directories
            try? FileService.shared.ensureBaseDirectoryExists()
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 600, height: 800)
}
