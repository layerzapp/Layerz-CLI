import SwiftUI
import AppKit

struct CodeEditorView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var editorSettings: EditorSettings

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState, settings: editorSettings)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: CGFloat(editorSettings.fontSize), weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.textContainerInset = NSSize(width: 4, height: 8)

        // Dark appearance
        textView.backgroundColor = NSColor(red: 0.16, green: 0.16, blue: 0.21, alpha: 1)
        textView.insertionPointColor = .white
        scrollView.backgroundColor = textView.backgroundColor

        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        guard !context.coordinator.isEditing, textView.string != appState.fileContent else { return }

        let ranges = textView.selectedRanges
        textView.string = appState.fileContent
        let len = (appState.fileContent as NSString).length
        textView.selectedRanges = ranges.map {
            let r = $0.rangeValue
            return NSValue(range: NSRange(location: min(r.location, len), length: 0))
        }
        context.coordinator.applyHighlighting(to: textView)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        let appState: AppState
        let settings: EditorSettings
        var isEditing = false
        weak var textView: NSTextView?
        private lazy var highlighter = CodeHighlighter()

        init(appState: AppState, settings: EditorSettings) {
            self.appState = appState
            self.settings = settings
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            isEditing = true
            appState.updateContent(tv.string)
            isEditing = false
            applyHighlighting(to: tv)
        }

        func applyHighlighting(to tv: NSTextView) {
            let storage = tv.textStorage!
            let fullRange = NSRange(location: 0, length: storage.length)
            let font = NSFont.monospacedSystemFont(ofSize: CGFloat(settings.fontSize), weight: .regular)
            let defaultColor = NSColor(red: 0.97, green: 0.97, blue: 0.95, alpha: 1) // #f8f8f2

            storage.beginEditing()
            storage.setAttributes([
                .font: font,
                .foregroundColor: defaultColor
            ], range: fullRange)

            let ext = appState.fileExtension
            for token in highlighter.highlight(tv.string, language: ext) {
                storage.addAttributes(token.attributes, range: token.range)
            }
            storage.endEditing()
        }
    }
}

// MARK: - Code Syntax Highlighter

struct CodeHighlighter {

    struct HighlightRange {
        let range: NSRange
        let attributes: [NSAttributedString.Key: Any]
    }

    // Dracula palette
    private let keyword  = NSColor(red: 1.00, green: 0.47, blue: 0.66, alpha: 1) // #ff79c6
    private let string_  = NSColor(red: 0.94, green: 0.98, blue: 0.55, alpha: 1) // #f1fa8c
    private let comment  = NSColor(red: 0.38, green: 0.45, blue: 0.55, alpha: 1) // #6272a4
    private let number   = NSColor(red: 0.74, green: 0.58, blue: 0.97, alpha: 1) // #bd93f9
    private let type_    = NSColor(red: 0.55, green: 0.93, blue: 0.99, alpha: 1) // #8be9fd
    private let func_    = NSColor(red: 0.31, green: 0.97, blue: 0.48, alpha: 1) // #50fa7b

    func highlight(_ text: String, language ext: String) -> [HighlightRange] {
        let rules = self.rules(for: ext)
        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        var result: [HighlightRange] = []

        for (regex, color) in rules {
            regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                guard let match else { return }
                result.append(HighlightRange(
                    range: match.range,
                    attributes: [.foregroundColor: color]
                ))
            }
        }
        return result
    }

    private func rules(for ext: String) -> [(NSRegularExpression, NSColor)] {
        switch ext {
        case "swift": return swiftRules
        case "py", "pyw": return pythonRules
        case "js", "mjs", "cjs", "ts", "tsx", "jsx": return jsRules
        case "c", "h", "cpp", "cc", "cxx", "hpp", "java", "kt", "cs": return clikeRules
        case "go": return goRules
        case "rs": return rustRules
        case "rb": return rubyRules
        case "sh", "bash", "zsh": return shellRules
        case "html", "htm", "xml", "svg": return htmlRules
        case "css", "scss", "less": return cssRules
        case "json": return jsonRules
        case "yaml", "yml": return yamlRules
        case "sql": return sqlRules
        case "md", "markdown": return markdownRules
        default: return genericRules
        }
    }

    // MARK: - Regex helpers

    private func re(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    }
    private func reML(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
    }

    // MARK: - Language Rules

    private var genericRules: [(NSRegularExpression, NSColor)] {[
        (reML(#"/\*[\s\S]*?\*/"#), comment),
        (re(#"//.*$"#), comment),
        (re(#"#.*$"#), comment),
        (re(#""(?:[^"\\]|\\.)*""#), string_),
        (re(#"'(?:[^'\\]|\\.)*'"#), string_),
        (re(#"\b\d+\.?\d*\b"#), number),
    ]}

    private var swiftRules: [(NSRegularExpression, NSColor)] {[
        (reML(#"/\*[\s\S]*?\*/"#), comment),
        (re(#"//.*$"#), comment),
        (re(#""(?:[^"\\]|\\.)*""#), string_),
        (re(#"\b(import|class|struct|enum|protocol|extension|func|var|let|if|else|guard|switch|case|default|for|while|repeat|return|break|continue|throw|throws|try|catch|do|in|as|is|self|Self|super|init|deinit|nil|true|false|static|private|public|internal|fileprivate|open|override|mutating|weak|unowned|lazy|some|any|async|await|actor|where|typealias|subscript|defer|@objc|@Published|@State|@Binding|@EnvironmentObject|@StateObject|@ObservedObject|@ViewBuilder|@main|@available|@escaping)\b"#), keyword),
        (re(#"\b[A-Z][A-Za-z0-9_]*\b"#), type_),
        (re(#"\b\d+\.?\d*\b"#), number),
    ]}

    private var pythonRules: [(NSRegularExpression, NSColor)] {[
        (re(#"#.*$"#), comment),
        (reML(#"\"\"\"[\s\S]*?\"\"\""#), string_),
        (reML(#"'''[\s\S]*?'''"#), string_),
        (re(#""(?:[^"\\]|\\.)*""#), string_),
        (re(#"'(?:[^'\\]|\\.)*'"#), string_),
        (re(#"\b(import|from|class|def|return|if|elif|else|for|while|break|continue|pass|raise|try|except|finally|with|as|yield|lambda|and|or|not|in|is|True|False|None|self|global|nonlocal|async|await|del|assert)\b"#), keyword),
        (re(#"\b[A-Z][A-Za-z0-9_]*\b"#), type_),
        (re(#"\b\d+\.?\d*\b"#), number),
    ]}

    private var jsRules: [(NSRegularExpression, NSColor)] {[
        (reML(#"/\*[\s\S]*?\*/"#), comment),
        (re(#"//.*$"#), comment),
        (re(#"`(?:[^`\\]|\\.)*`"#), string_),
        (re(#""(?:[^"\\]|\\.)*""#), string_),
        (re(#"'(?:[^'\\]|\\.)*'"#), string_),
        (re(#"\b(import|export|from|default|const|let|var|function|class|extends|return|if|else|for|while|do|switch|case|break|continue|throw|try|catch|finally|new|delete|typeof|instanceof|in|of|this|super|async|await|yield|true|false|null|undefined|void|static|get|set|interface|type|enum|implements|public|private|protected|readonly|abstract|as|is)\b"#), keyword),
        (re(#"\b[A-Z][A-Za-z0-9_]*\b"#), type_),
        (re(#"\b\d+\.?\d*\b"#), number),
    ]}

    private var clikeRules: [(NSRegularExpression, NSColor)] {[
        (reML(#"/\*[\s\S]*?\*/"#), comment),
        (re(#"//.*$"#), comment),
        (re(#""(?:[^"\\]|\\.)*""#), string_),
        (re(#"'(?:[^'\\]|\\.)*'"#), string_),
        (re(#"\b(auto|break|case|char|const|continue|default|do|double|else|enum|extern|float|for|goto|if|int|long|register|return|short|signed|sizeof|static|struct|switch|typedef|union|unsigned|void|volatile|while|class|namespace|template|typename|using|virtual|public|private|protected|new|delete|this|throw|try|catch|inline|override|final|abstract|interface|extends|implements|import|package|boolean|byte|null|true|false|super)\b"#), keyword),
        (re(#"#\s*(include|define|ifdef|ifndef|endif|pragma|if|else|elif|undef)\b.*$"#), keyword),
        (re(#"\b[A-Z][A-Za-z0-9_]*\b"#), type_),
        (re(#"\b\d+\.?\d*[fFlLuU]?\b"#), number),
    ]}

    private var goRules: [(NSRegularExpression, NSColor)] {[
        (reML(#"/\*[\s\S]*?\*/"#), comment),
        (re(#"//.*$"#), comment),
        (re(#"`[^`]*`"#), string_),
        (re(#""(?:[^"\\]|\\.)*""#), string_),
        (re(#"\b(package|import|func|var|const|type|struct|interface|map|chan|range|return|if|else|for|switch|case|default|break|continue|goto|fallthrough|defer|go|select|true|false|nil|iota|make|new|len|cap|append|copy|delete|panic|recover)\b"#), keyword),
        (re(#"\b[A-Z][A-Za-z0-9_]*\b"#), type_),
        (re(#"\b\d+\.?\d*\b"#), number),
    ]}

    private var rustRules: [(NSRegularExpression, NSColor)] {[
        (reML(#"/\*[\s\S]*?\*/"#), comment),
        (re(#"//.*$"#), comment),
        (re(#""(?:[^"\\]|\\.)*""#), string_),
        (re(#"\b(fn|let|mut|const|static|struct|enum|impl|trait|type|pub|mod|use|crate|super|self|Self|return|if|else|for|while|loop|match|break|continue|move|ref|as|in|where|async|await|unsafe|extern|dyn|true|false|Some|None|Ok|Err)\b"#), keyword),
        (re(#"\b[A-Z][A-Za-z0-9_]*\b"#), type_),
        (re(#"\b\d+\.?\d*\b"#), number),
    ]}

    private var rubyRules: [(NSRegularExpression, NSColor)] {[
        (re(#"#.*$"#), comment),
        (re(#""(?:[^"\\]|\\.)*""#), string_),
        (re(#"'(?:[^'\\]|\\.)*'"#), string_),
        (re(#"\b(require|include|module|class|def|end|if|elsif|else|unless|case|when|while|until|for|do|begin|rescue|ensure|raise|return|yield|self|super|true|false|nil|and|or|not|in|then|puts|print|attr_accessor|attr_reader|attr_writer|private|public|protected)\b"#), keyword),
        (re(#"\b[A-Z][A-Za-z0-9_]*\b"#), type_),
        (re(#"\b\d+\.?\d*\b"#), number),
        (re(#":[A-Za-z_][A-Za-z0-9_]*"#), string_),
    ]}

    private var shellRules: [(NSRegularExpression, NSColor)] {[
        (re(#"#.*$"#), comment),
        (re(#""(?:[^"\\]|\\.)*""#), string_),
        (re(#"'[^']*'"#), string_),
        (re(#"\b(if|then|else|elif|fi|case|esac|for|while|until|do|done|in|function|return|exit|local|export|source|alias|set|unset|shift|break|continue|eval|exec|trap|read|echo|printf|test|true|false)\b"#), keyword),
        (re(#"\$\{?[A-Za-z_][A-Za-z0-9_]*\}?"#), type_),
        (re(#"\b\d+\b"#), number),
    ]}

    private var htmlRules: [(NSRegularExpression, NSColor)] {[
        (reML(#"<!--[\s\S]*?-->"#), comment),
        (re(#""[^"]*""#), string_),
        (re(#"'[^']*'"#), string_),
        (re(#"</?[A-Za-z][A-Za-z0-9-]*"#), keyword),
        (re(#"/?\s*>"#), keyword),
        (re(#"\b[A-Za-z-]+=(?=")"#), type_),
    ]}

    private var cssRules: [(NSRegularExpression, NSColor)] {[
        (reML(#"/\*[\s\S]*?\*/"#), comment),
        (re(#""[^"]*""#), string_),
        (re(#"'[^']*'"#), string_),
        (re(#"[.#][A-Za-z_-][A-Za-z0-9_-]*"#), keyword),
        (re(#"[A-Za-z-]+(?=\s*:)"#), type_),
        (re(#"#[0-9A-Fa-f]{3,8}\b"#), number),
        (re(#"\b\d+\.?\d*(px|em|rem|%|vh|vw|s|ms)?\b"#), number),
    ]}

    private var jsonRules: [(NSRegularExpression, NSColor)] {[
        (re(#""(?:[^"\\]|\\.)*"\s*(?=:)"#), type_),
        (re(#""(?:[^"\\]|\\.)*""#), string_),
        (re(#"\b(true|false|null)\b"#), keyword),
        (re(#"-?\b\d+\.?\d*([eE][+-]?\d+)?\b"#), number),
    ]}

    private var yamlRules: [(NSRegularExpression, NSColor)] {[
        (re(#"#.*$"#), comment),
        (re(#"^[A-Za-z_][A-Za-z0-9_ -]*(?=\s*:)"#), type_),
        (re(#""(?:[^"\\]|\\.)*""#), string_),
        (re(#"'[^']*'"#), string_),
        (re(#"\b(true|false|null|yes|no)\b"#), keyword),
        (re(#"\b\d+\.?\d*\b"#), number),
    ]}

    private var sqlRules: [(NSRegularExpression, NSColor)] {[
        (re(#"--.*$"#), comment),
        (reML(#"/\*[\s\S]*?\*/"#), comment),
        (re(#"'(?:[^'\\]|\\.)*'"#), string_),
        (re(#"(?i)\b(SELECT|FROM|WHERE|INSERT|INTO|UPDATE|SET|DELETE|CREATE|DROP|ALTER|TABLE|INDEX|VIEW|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AND|OR|NOT|IN|IS|NULL|AS|ORDER|BY|GROUP|HAVING|LIMIT|OFFSET|UNION|ALL|DISTINCT|EXISTS|BETWEEN|LIKE|CASE|WHEN|THEN|ELSE|END|BEGIN|COMMIT|ROLLBACK|PRIMARY|KEY|FOREIGN|REFERENCES|DEFAULT|VALUES|COUNT|SUM|AVG|MIN|MAX|INT|INTEGER|VARCHAR|TEXT|BOOLEAN|DATE|TIMESTAMP)\b"#), keyword),
        (re(#"\b\d+\.?\d*\b"#), number),
    ]}

    private var markdownRules: [(NSRegularExpression, NSColor)] {[
        (re(#"^#{1,6}\s+.*$"#), keyword),
        (re(#"\*\*[^*]+\*\*"#), type_),
        (re(#"\*[^*]+\*"#), func_),
        (re(#"`[^`]+`"#), string_),
        (re(#"^\s*[-*+]\s"#), keyword),
        (re(#"^\s*\d+\.\s"#), keyword),
        (re(#"\[([^\]]+)\]\([^)]+\)"#), type_),
    ]}
}
