//
//  ModelSelectionGroup.swift
//  ttsui-mac
//
//  Container for model rows with radio-style selection
//

import SwiftUI

/// Model info for selection group
struct ModelSelectionItem: Identifiable {
    let id: String
    let displayName: String
    let state: ModelState
    let errorMessage: String?

    init(modelInfo: ModelInfo, displayName: String) {
        self.id = modelInfo.modelId
        self.displayName = displayName
        self.state = modelInfo.state
        self.errorMessage = modelInfo.error
    }
}

/// Container for model rows with section header
struct ModelSelectionGroup: View {
    let title: String
    let systemImage: String
    let models: [ModelSelectionItem]
    @Binding var selectedModelId: String?
    let onLoad: (String) -> Void
    let onUnload: (String) -> Void

    var body: some View {
        GroupBox(label: Label(title, systemImage: systemImage)) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(models) { model in
                    ModelSelectionRow(
                        modelId: model.id,
                        displayName: model.displayName,
                        state: model.state,
                        isSelected: selectedModelId == model.id,
                        canSelect: model.state == .loaded,
                        errorMessage: model.errorMessage,
                        onSelect: {
                            if model.state == .loaded {
                                selectedModelId = model.id
                            }
                        },
                        onLoadUnload: {
                            switch model.state {
                            case .unloaded, .error:
                                onLoad(model.id)
                            case .loaded:
                                onUnload(model.id)
                            default:
                                break
                            }
                        }
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Preview

#Preview {
    let models = [
        ModelSelectionItem(
            modelInfo: ModelInfo(
                modelId: "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16",
                state: .unloaded,
                memory: MemoryStats(beforeMb: nil, afterMb: nil, deltaMb: nil),
                loadTimeSeconds: nil,
                error: nil
            ),
            displayName: "0.6B-Base (Fast)"
        ),
        ModelSelectionItem(
            modelInfo: ModelInfo(
                modelId: "mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16",
                state: .loaded,
                memory: MemoryStats(beforeMb: 256, afterMb: 2847, deltaMb: 2591),
                loadTimeSeconds: 8.2,
                error: nil
            ),
            displayName: "1.7B-Base (Quality)"
        )
    ]

    return ModelSelectionGroup(
        title: "Model",
        systemImage: "cpu",
        models: models,
        selectedModelId: .constant("mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16"),
        onLoad: { _ in },
        onUnload: { _ in }
    )
    .padding()
    .frame(width: 450)
}
