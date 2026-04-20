import Foundation
import Combine

class EditorSettings: ObservableObject {
    @Published var fontSize: Int {
        didSet { UserDefaults.standard.set(fontSize, forKey: "editorFontSize") }
    }
    @Published var tabSize: Int {
        didSet { UserDefaults.standard.set(tabSize, forKey: "editorTabSize") }
    }
    @Published var terminalFontName: String {
        didSet { UserDefaults.standard.set(terminalFontName, forKey: "terminalFontName") }
    }
    @Published var terminalFontSize: Int {
        didSet { UserDefaults.standard.set(terminalFontSize, forKey: "terminalFontSize") }
    }

    init() {
        let defaults = UserDefaults.standard
        self.fontSize = defaults.object(forKey: "editorFontSize") as? Int ?? 13
        self.tabSize = defaults.object(forKey: "editorTabSize") as? Int ?? 2
        self.terminalFontName = defaults.string(forKey: "terminalFontName") ?? "MesloLGS NF"
        self.terminalFontSize = defaults.object(forKey: "terminalFontSize") as? Int ?? 13
    }
}
