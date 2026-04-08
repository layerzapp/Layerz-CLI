import Foundation
import AppKit
import Combine

extension Notification.Name {
    static let saveCurrentFile = Notification.Name("com.layerz.console.saveCurrentFile")
}

class AppState: ObservableObject {
    @Published var currentDirectory: URL = URL(fileURLWithPath: NSHomeDirectory()) {
        didSet {
            if let activeTab = tabs.first(where: { $0.id == activeTabID }) {
                activeTab.currentDirectory = currentDirectory
            }
        }
    }

    // MARK: - Opened File
    @Published var openedFile: URL? = nil
    @Published var fileContent: String = ""
    @Published var isDirty: Bool = false
    @Published var isMarkdownPreview: Bool = false
    @Published var isInfoMode: Bool = false

    var openedFileName: String { openedFile?.lastPathComponent ?? "" }
    var fileExtension: String { openedFile?.pathExtension.lowercased() ?? "" }
    var isMarkdownFile: Bool { ["md", "markdown"].contains(fileExtension) }

    enum FileViewMode { case code, image, pdf, info }

    static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "webp", "heic", "ico", "svg"
    ]

    var fileViewMode: FileViewMode {
        guard openedFile != nil else { return .code }
        if Self.imageExtensions.contains(fileExtension) { return .image }
        if fileExtension == "pdf" { return .pdf }
        if isInfoMode { return .info }
        return .code
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

    // MARK: - File Operations

    @objc private func handleSaveNotification() {
        saveFile()
    }

    func openFile(_ url: URL) {
        // Same file — do nothing
        if openedFile == url { return }

        selectedFilePath = url.path

        let ext = url.pathExtension.lowercased()
        let isBinary = Self.imageExtensions.contains(ext) || ext == "pdf"

        if isBinary {
            openedFile = url
            fileContent = ""
            isDirty = false
            isMarkdownPreview = false
            isInfoMode = false
        } else if let text = try? String(contentsOf: url, encoding: .utf8) {
            openedFile = url
            fileContent = text
            isDirty = false
            isMarkdownPreview = false
            isInfoMode = false
        } else {
            // Can't read as text — show file info panel
            openedFile = url
            fileContent = ""
            isDirty = false
            isMarkdownPreview = false
            isInfoMode = true
        }
    }

    func saveFile() {
        guard let url = openedFile, !fileContent.isEmpty else { return }
        try? fileContent.write(to: url, atomically: true, encoding: .utf8)
        isDirty = false
    }

    func closeFile() {
        openedFile = nil
        fileContent = ""
        isDirty = false
        isMarkdownPreview = false
        isInfoMode = false
        selectedFilePath = nil
    }

    func updateContent(_ content: String) {
        guard content != fileContent else { return }
        fileContent = content
        isDirty = true
    }
}
