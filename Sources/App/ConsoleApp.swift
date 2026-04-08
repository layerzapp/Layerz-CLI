import SwiftUI

@main
struct ConsoleApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var editorSettings = EditorSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(editorSettings)
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1400, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    NotificationCenter.default.post(name: .saveCurrentFile, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(editorSettings)
        }
    }
}
