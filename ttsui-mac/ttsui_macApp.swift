//
//  ttsui_macApp.swift
//  ttsui-mac
//
//  App entry point
//

import SwiftUI

@main
struct ttsui_macApp: App {
    @StateObject private var serverManager = TTSServerManager.shared

    init() {
        // Start server on app launch
        Task {
            await TTSServerManager.shared.startServer()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serverManager)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    // Shut down server when app exits
                    TTSServerManager.shared.stopServer()
                }
                .frame(width: 780, height: 975)
                .background(WindowAccessor())
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.styleMask.remove(.resizable)
                window.setContentSize(NSSize(width: 780, height: 975))
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
