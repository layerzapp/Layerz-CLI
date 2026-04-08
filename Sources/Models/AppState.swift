import Foundation
import AppKit
import Combine

extension Notification.Name {
    static let saveCurrentFile = Notification.Name("com.layerz.console.saveCurrentFile")
}

class AppState: ObservableObject {
    @Published var currentDirectory: URL = URL(fileURLWithPath: NSHomeDirectory())
    @Published var openedFile: URL? = nil
    @Published var fileContent: String = ""
    @Published var isDirty: Bool = false
    @Published var isMarkdownPreview: Bool = false

    var openedFileName: String { openedFile?.lastPathComponent ?? "" }
    var fileExtension: String { openedFile?.pathExtension.lowercased() ?? "" }
    var isMarkdownFile: Bool { ["md", "markdown"].contains(fileExtension) }

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSaveNotification),
            name: .saveCurrentFile,
            object: nil
        )
    }

    @objc private func handleSaveNotification() {
        saveFile()
    }

    func openFile(_ url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        openedFile = url
        fileContent = content
        isDirty = false
        isMarkdownPreview = false
    }

    func saveFile() {
        guard let url = openedFile else { return }
        try? fileContent.write(to: url, atomically: true, encoding: .utf8)
        isDirty = false
    }

    func closeFile() {
        openedFile = nil
        fileContent = ""
        isDirty = false
        isMarkdownPreview = false
    }

    func updateContent(_ content: String) {
        guard content != fileContent else { return }
        fileContent = content
        isDirty = true
    }
}
