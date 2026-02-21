//
//  LogPanel.swift
//  ttsui-mac
//
//  Read-only Python output log display
//

import SwiftUI
import AppKit

/// A panel that displays Python subprocess output
struct LogPanel: View {
    @Binding var logEntries: [LogEntry]
    var maxHeight: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Output Log")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: copyAllLogs) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Copy all logs")
                .disabled(logEntries.isEmpty)

                Button(action: { logEntries.removeAll() }) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Clear log")
                .disabled(logEntries.isEmpty)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(logEntries) { entry in
                            LogEntryView(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .frame(maxHeight: maxHeight)
                .onChange(of: logEntries.count) { _ in
                    if let lastEntry = logEntries.last {
                        proxy.scrollTo(lastEntry.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func copyAllLogs() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        let logText = logEntries.map { entry in
            "[\(formatter.string(from: entry.timestamp))] [\(entry.type.rawValue.uppercased())] \(entry.content)"
        }.joined(separator: "\n")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(logText, forType: .string)
    }
}

/// A single log entry view
struct LogEntryView: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(timeFormatter.string(from: entry.timestamp))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 60, alignment: .leading)

            // Type indicator
            Text(entry.type.rawValue.uppercased())
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.medium)
                .foregroundStyle(entry.type == .stderr ? .orange : .blue)
                .frame(width: 50, alignment: .leading)

            // Content
            Text(entry.content)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(contentColor)
        }
    }

    private var contentColor: Color {
        if entry.content.hasPrefix("ERROR:") {
            return .red
        } else if entry.content.hasPrefix("PROGRESS:") {
            return .green
        }
        return .primary
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var entries: [LogEntry] = [
            LogEntry(timestamp: Date(), content: "Loading model...", type: .stderr),
            LogEntry(timestamp: Date().addingTimeInterval(1), content: "PROGRESS: 20 Processing text...", type: .stderr),
            LogEntry(timestamp: Date().addingTimeInterval(2), content: "PROGRESS: 60 Generating audio...", type: .stderr),
            LogEntry(timestamp: Date().addingTimeInterval(3), content: "/path/to/output.wav", type: .stdout)
        ]

        var body: some View {
            LogPanel(logEntries: $entries)
                .padding()
                .frame(width: 500)
        }
    }

    return PreviewWrapper()
}
