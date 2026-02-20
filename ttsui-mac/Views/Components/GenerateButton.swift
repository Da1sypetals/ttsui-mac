//
//  GenerateButton.swift
//  ttsui-mac
//
//  Generate button with progress indicator
//

import SwiftUI

/// A generate button that shows progress during generation
struct GenerateButton: View {
    let title: String
    let isLoading: Bool
    let progress: Int?
    let progressMessage: String?
    let isEnabled: Bool
    let action: () -> Void

    init(
        title: String = "Generate",
        isLoading: Bool = false,
        progress: Int? = nil,
        progressMessage: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.progress = progress
        self.progressMessage = progressMessage
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "waveform.circle.fill")
                    }

                    Text(isLoading ? (progressMessage ?? "Generating...") : title)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isEnabled || isLoading)

            if isLoading, let progress = progress {
                ProgressBar(value: Double(progress) / 100.0)
                    .frame(height: 4)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GenerateButton(
            title: "Generate",
            isLoading: false,
            isEnabled: true,
            action: {}
        )

        GenerateButton(
            title: "Generate",
            isLoading: true,
            progress: 45,
            progressMessage: "Generating audio...",
            isEnabled: true,
            action: {}
        )

        GenerateButton(
            title: "Generate",
            isLoading: false,
            isEnabled: false,
            action: {}
        )
    }
    .padding()
    .frame(width: 300)
}
