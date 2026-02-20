//
//  ModeSelector.swift
//  ttsui-mac
//
//  Tab picker component for selecting TTS mode
//

import SwiftUI

/// A segmented picker for selecting TTS mode
struct ModeSelector: View {
    @Binding var selectedMode: TTSMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TTSMode.allCases) { mode in
                ModeButton(
                    mode: mode,
                    isSelected: selectedMode == mode,
                    action: { selectedMode = mode }
                )
            }
        }
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

/// Individual mode button
struct ModeButton: View {
    let mode: TTSMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.title3)

                Text(mode.rawValue)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundStyle(isSelected ? .white : .primary)
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch mode {
        case .clone:
            return "waveform.badge.mic"
        case .control:
            return "slider.horizontal.3"
        case .design:
            return "paintbrush.pointed"
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var selectedMode: TTSMode = .clone

        var body: some View {
            VStack {
                ModeSelector(selectedMode: $selectedMode)

                Text("Selected: \(selectedMode.rawValue)")
                    .padding()

                Spacer()
            }
            .padding()
        }
    }

    return PreviewWrapper()
        .frame(width: 400, height: 200)
}
