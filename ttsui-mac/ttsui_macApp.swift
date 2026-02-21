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
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
