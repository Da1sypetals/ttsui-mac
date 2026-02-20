//
//  ttsui_macApp.swift
//  ttsui-mac
//
//  App entry point
//

import SwiftUI

@main
struct ttsui_macApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
