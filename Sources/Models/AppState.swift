import Foundation
import AppKit
import Combine

extension Notification.Name {
    static let saveCurrentFile = Notification.Name("com.layerz.console.saveCurrentFile")
}

class AppState: ObservableObject {
    @Published var currentDirectory: URL = URL(fileURLWithPath: NSHomeDirectory()) {
        didSet {
            // Keep the active tab's directory in sync
            if let activeTab = tabs.first(where: { $0.id == activeTabID }) {
                activeTab.currentDirectory = currentDirectory
            }
        }
    }

    // MARK: - Editor Tabs
    @Published var editorTabs: [EditorTab] = []
    @Published var activeEditorTabID: UUID?

    var activeEditorTab: EditorTab? {
        guard let id = activeEditorTabID else { return nil }
        return editorTabs.first { $0.id == id }
    }

    // Computed compatibility properties
    var openedFile: URL? { activeEditorTab?.url }
    var openedFileName: String { activeEditorTab?.fileName ?? "" }
    var fileExtension: String { activeEditorTab?.fileExtension ?? "" }
    var isMarkdownFile: Bool { activeEditorTab?.isMarkdownFile ?? false }
    var fileContent: String {
        get { activeEditorTab?.content ?? "" }
        set { activeEditorTab?.content = newValue }
    }
    var isDirty: Bool {
        get { activeEditorTab?.isDirty ?? false }
        set { activeEditorTab?.isDirty = newValue ?? false }
    }
    var isMarkdownPreview: Bool {
        get { activeEditorTab?.isMarkdownPreview ?? false }
        set { activeEditorTab?.isMarkdownPreview = newValue ?? false }
    }

    enum FileViewMode { case code, image, pdf, info }

    static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "webp", "heic", "ico", "svg"
    ]

    var fileViewMode: FileViewMode {
        guard let tab = activeEditorTab else { return .code }
        switch tab.viewMode {
        case .image: return .image
        case .pdf: return .pdf
        case .code: return .code
        case .info: return .info
        }
    }

    // MARK: - Terminal Tabs
    @Published var tabs: [TerminalTab]
    @Published var activeTabID: UUID

    var activeTabIndex: Int {
        tabs.firstIndex { $0.id == activeTabID } ?? 0
    }

    // MARK: - Selected file (for highlight in file browser)
    @Published var selectedFilePath: String? = nil

    init() {
        let initialTab = TerminalTab()
        self.tabs = [initialTab]
        self.activeTabID = initialTab.id

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSaveNotification),
            name: .saveCurrentFile,
            object: nil
        )
    }

    // MARK: - Terminal Tab Management

    func addTab() {
        let tab = TerminalTab()
        tabs.append(tab)
        activeTabID = tab.id
    }

    func closeTab(_ id: UUID) {
        guard tabs.count > 1 else { return }
        if let idx = tabs.firstIndex(where: { $0.id == id }) {
            tabs.remove(at: idx)
            if activeTabID == id {
                activeTabID = tabs[min(idx, tabs.count - 1)].id
            }
        }
    }

    func selectTab(_ id: UUID) {
        if let outgoing = tabs.first(where: { $0.id == activeTabID }) {
            outgoing.currentDirectory = currentDirectory
        }
        activeTabID = id
        if let incoming = tabs.first(where: { $0.id == id }) {
            currentDirectory = incoming.currentDirectory
        }
    }

    // MARK: - Editor Tab Management

    func openFile(_ url: URL) {
        // If already open, just switch to it
        if let existing = editorTabs.first(where: { $0.url == url }) {
            activeEditorTabID = existing.id
            objectWillChange.send()
            return
        }

        let ext = url.pathExtension.lowercased()
        let isBinary = Self.imageExtensions.contains(ext) || ext == "pdf"

        let content: String
        var viewMode: EditorTab.ViewMode? = nil
        if isBinary {
            content = ""
        } else if let text = try? String(contentsOf: url, encoding: .utf8) {
            content = text
        } else {
            // Can't read as text (unknown binary) — show file info panel
            content = ""
            viewMode = .info
        }

        let tab = EditorTab(url: url, content: content, viewMode: viewMode)
        editorTabs.append(tab)
        activeEditorTabID = tab.id
        selectedFilePath = url.path
    }

    func closeEditorTab(_ id: UUID) {
        guard let idx = editorTabs.firstIndex(where: { $0.id == id }) else { return }
        editorTabs.remove(at: idx)
        if activeEditorTabID == id {
            if editorTabs.isEmpty {
                activeEditorTabID = nil
                selectedFilePath = nil
            } else {
                let newIdx = min(idx, editorTabs.count - 1)
                activeEditorTabID = editorTabs[newIdx].id
                selectedFilePath = editorTabs[newIdx].url.path
            }
        }
    }

    func selectEditorTab(_ id: UUID) {
        activeEditorTabID = id
        if let tab = editorTabs.first(where: { $0.id == id }) {
            selectedFilePath = tab.url.path
        }
        objectWillChange.send()
    }

    // MARK: - File Operations

    @objc private func handleSaveNotification() {
        saveFile()
    }

    func saveFile() {
        guard let tab = activeEditorTab else { return }
        try? tab.content.write(to: tab.url, atomically: true, encoding: .utf8)
        tab.isDirty = false
        objectWillChange.send()
    }

    func closeFile() {
        guard let id = activeEditorTabID else { return }
        closeEditorTab(id)
    }

    func updateContent(_ content: String) {
        guard let tab = activeEditorTab, content != tab.content else { return }
        tab.content = content
        tab.isDirty = true
        objectWillChange.send()
    }
}
