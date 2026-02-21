//
//  ModelSelectionRow.swift
//  ttsui-mac
//
//  Individual model row component with load/unload functionality
//

import SwiftUI

/// Row displaying a single model with load/unload button
struct ModelSelectionRow: View {
    let modelId: String
    let displayName: String
    let state: ModelState
    let isSelected: Bool
    let canSelect: Bool
    let errorMessage: String?
    let onSelect: () -> Void
    let onLoadUnload: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox for selection (only enabled when loaded)
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canSelect)
            .opacity(canSelect ? 1.0 : 0.5)

            // Model name
            Text(displayName)
                .font(.body)
                .lineLimit(1)

            // Load/Unload/Loading/Error button (right after model name)
            actionButton

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if canSelect {
                onSelect()
            }
        }

        // Error message row
        if let error = errorMessage, state == .error {
            HStack {
                Spacer()
                    .frame(width: 32) // Align with checkbox
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .unloaded:
            Button(action: onLoadUnload) {
                Text("Load")
                    .font(.callout)
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
            Button(action: onLoadUnload) {
                Text("Unload")
                    .font(.callout)
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
            Button(action: onLoadUnload) {
                Text("Retry")
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.orange)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        ModelSelectionRow(
            modelId: "model-1",
            displayName: "0.6B-Base (Fast)",
            state: .unloaded,
            isSelected: false,
            canSelect: false,
            errorMessage: nil,
            onSelect: {},
            onLoadUnload: {}
        )

        ModelSelectionRow(
            modelId: "model-2",
            displayName: "1.7B-Base (Quality)",
            state: .loaded,
            isSelected: true,
            canSelect: true,
            errorMessage: nil,
            onSelect: {},
            onLoadUnload: {}
        )

        ModelSelectionRow(
            modelId: "model-3",
            displayName: "0.6B-Base (Fast)",
            state: .loading,
            isSelected: false,
            canSelect: false,
            errorMessage: nil,
            onSelect: {},
            onLoadUnload: {}
        )

        ModelSelectionRow(
            modelId: "model-4",
            displayName: "1.7B-Base (Quality)",
            state: .error,
            isSelected: false,
            canSelect: false,
            errorMessage: "Out of memory",
            onSelect: {},
            onLoadUnload: {}
        )
    }
    .padding()
    .frame(width: 400)
}
