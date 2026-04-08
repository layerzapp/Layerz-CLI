import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                tabBar
                Divider()
                terminalArea
            }
            .frame(minWidth: 340, maxWidth: .infinity, maxHeight: .infinity)

            FileBrowserView()
                .frame(minWidth: 200, idealWidth: 260, maxWidth: 380, maxHeight: .infinity)

            if appState.openedFile != nil {
                EditorPaneView()
                    .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(appState.tabs) { tab in
                TabItemView(tab: tab)
            }

            // New tab button
            Button(action: appState.addTab) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("New terminal tab")
            .padding(.leading, 4)

            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Terminal Area

    /// All terminal views are kept alive in a ZStack; only the active one is visible.
    private var terminalArea: some View {
        ZStack {
            ForEach(appState.tabs) { tab in
                TerminalPaneView()
                    .id(tab.id)
                    .opacity(tab.id == appState.activeTabID ? 1 : 0)
                    .allowsHitTesting(tab.id == appState.activeTabID)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - TabItemView

struct TabItemView: View {
    @ObservedObject var tab: TerminalTab
    @EnvironmentObject var appState: AppState

    private var isActive: Bool { tab.id == appState.activeTabID }

    var body: some View {
        HStack(spacing: 4) {
            Text(tab.title)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .lineLimit(1)
                .foregroundColor(isActive ? .primary : .secondary)

            if appState.tabs.count > 1 {
                Button(action: { appState.closeTab(tab.id) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(isActive ? 1 : 0.5)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { appState.selectTab(tab.id) }
    }
}
