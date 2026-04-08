import Foundation
import Combine

class EditorSettings: ObservableObject {
    @Published var fontSize: Int {
        didSet { UserDefaults.standard.set(fontSize, forKey: "editorFontSize") }
    }
    @Published var tabSize: Int {
        didSet { UserDefaults.standard.set(tabSize, forKey: "editorTabSize") }
    }
    @Published var lineWrapping: Bool {
        didSet { UserDefaults.standard.set(lineWrapping, forKey: "editorLineWrapping") }
    }
    @Published var showLineNumbers: Bool {
        didSet { UserDefaults.standard.set(showLineNumbers, forKey: "editorShowLineNumbers") }
    }

    static let themes = ["dracula", "material-darker", "monokai", "nord", "solarized dark"]

    @Published var theme: String {
        didSet { UserDefaults.standard.set(theme, forKey: "editorTheme") }
    }

    init() {
        let defaults = UserDefaults.standard
        self.fontSize = defaults.object(forKey: "editorFontSize") as? Int ?? 13
        self.tabSize = defaults.object(forKey: "editorTabSize") as? Int ?? 2
        self.lineWrapping = defaults.object(forKey: "editorLineWrapping") as? Bool ?? false
        self.showLineNumbers = defaults.object(forKey: "editorShowLineNumbers") as? Bool ?? true
        self.theme = defaults.string(forKey: "editorTheme") ?? "dracula"
    }
}
