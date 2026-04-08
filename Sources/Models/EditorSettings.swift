import Foundation
import Combine

class EditorSettings: ObservableObject {
    @Published var fontSize: Int {
        didSet { UserDefaults.standard.set(fontSize, forKey: "editorFontSize") }
    }
    @Published var tabSize: Int {
        didSet { UserDefaults.standard.set(tabSize, forKey: "editorTabSize") }
    }

    init() {
        let defaults = UserDefaults.standard
        self.fontSize = defaults.object(forKey: "editorFontSize") as? Int ?? 13
        self.tabSize = defaults.object(forKey: "editorTabSize") as? Int ?? 2
    }
}
