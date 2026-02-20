//
//  ProgressBar.swift
//  ttsui-mac
//
//  Progress bar component
//

import SwiftUI

/// A simple progress bar
struct ProgressBar: View {
    let value: Double
    var color: Color = .accentColor

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.2))

                // Progress
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geometry.size.width * min(max(value, 0), 1))
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ProgressBar(value: 0.0)
            .frame(height: 8)

        ProgressBar(value: 0.3)
            .frame(height: 8)

        ProgressBar(value: 0.7)
            .frame(height: 8)

        ProgressBar(value: 1.0)
            .frame(height: 8)
    }
    .padding()
    .frame(width: 300)
}
