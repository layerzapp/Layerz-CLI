import Foundation

/// Represents a single terminal session tab.
class TerminalTab: Identifiable, ObservableObject {
    let id = UUID()
    @Published var title: String

    init(title: String = "Terminal") {
        self.title = title
    }
}
