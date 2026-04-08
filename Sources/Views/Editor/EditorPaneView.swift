import SwiftUI

struct EditorPaneView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            editorTabBar
            Divider()
            toolbar
            Divider()
            editorContent
        }
    }

    // MARK: - Editor Tab Bar

    private var editorTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(appState.editorTabs) { tab in
                    EditorTabItemView(tab: tab)
                }
            }
        }
        .frame(height: 28)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            // Dirty indicator
            if appState.isDirty {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 7, height: 7)
                    .help("Unsaved changes")
            }

            // File icon + name
            if let file = appState.openedFile {
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.path))
                    .resizable()
                    .frame(width: 14, height: 14)
            }

            Text(appState.openedFileName)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if appState.fileViewMode == .code {
                // Markdown toggle
                if appState.isMarkdownFile {
                    Picker("", selection: $appState.isMarkdownPreview) {
                        Text("Edit").tag(false)
                        Text("Preview").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                    .controlSize(.small)
                }

                // Save button
                Button(action: appState.saveFile) {
                    HStack(spacing: 3) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 11))
                        Text("Save")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!appState.isDirty)
                .keyboardShortcut("s", modifiers: .command)
            }

            // Close button
            Button(action: appState.closeFile) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("Close file")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Editor / Preview

    @ViewBuilder
    private var editorContent: some View {
        switch appState.fileViewMode {
        case .image:
            ImagePreviewView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .pdf:
            PDFPreviewView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .code:
            if appState.isMarkdownPreview {
                MarkdownPreviewView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CodeEditorView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - EditorTabItemView

struct EditorTabItemView: View {
    @ObservedObject var tab: EditorTab
    @EnvironmentObject var appState: AppState

    private var isActive: Bool { tab.id == appState.activeEditorTabID }

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: tab.url.path))
                .resizable()
                .frame(width: 12, height: 12)

            Text(tab.fileName)
                .font(.system(size: 11, weight: isActive ? .medium : .regular))
                .lineLimit(1)
                .foregroundColor(isActive ? .primary : .secondary)

            if tab.isDirty {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 5, height: 5)
            }

            Button(action: { appState.closeEditorTab(tab.id) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isActive ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            isActive
                ? Color(NSColor.windowBackgroundColor)
                : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture { appState.selectEditorTab(tab.id) }
    }
}
