import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HSplitView {
            TerminalPaneView()
                .frame(minWidth: 340, maxWidth: .infinity, maxHeight: .infinity)

            FileBrowserView()
                .frame(minWidth: 200, idealWidth: 260, maxWidth: 380, maxHeight: .infinity)

            if appState.openedFile != nil {
                EditorPaneView()
                    .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
