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
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    appState.addTab()
                }
                .keyboardShortcut("t", modifiers: .command)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    NotificationCenter.default.post(name: .saveCurrentFile, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
            }
            CommandMenu("Tab") {
                Button("Next Tab") {
                    let idx = (appState.activeTabIndex + 1) % appState.tabs.count
                    appState.selectTab(appState.tabs[idx].id)
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                Button("Previous Tab") {
                    let idx = (appState.activeTabIndex - 1 + appState.tabs.count) % appState.tabs.count
                    appState.selectTab(appState.tabs[idx].id)
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Divider()

                Button("Close Tab") {
                    appState.closeTab(appState.activeTabID)
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(appState.tabs.count <= 1)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(editorSettings)
        }
    }
}
