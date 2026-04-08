import Foundation

/// Represents a single terminal session tab.
class TerminalTab: Identifiable, ObservableObject {
    let id = UUID()
    @Published var title: String
    @Published var currentDirectory: URL

    init(title: String = "Terminal", currentDirectory: URL = URL(fileURLWithPath: NSHomeDirectory())) {
        self.title = title
        self.currentDirectory = currentDirectory
    }
}
