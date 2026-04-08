import SwiftUI
import AppKit

struct CodeEditorView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var editorSettings: EditorSettings

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState, settings: editorSettings)
    }

    func makeNSView(context: Context) -> NSScrollView {
        // Use the system factory method — creates a properly wired ScrollView + TextView
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.borderType = .noBorder

        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false

        // Appearance
        textView.backgroundColor = NSColor(red: 0.16, green: 0.16, blue: 0.21, alpha: 1)
        textView.insertionPointColor = .white
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(red: 0.27, green: 0.28, blue: 0.35, alpha: 1)
        ]
        textView.textContainerInset = NSSize(width: 8, height: 8)

        // Font & text color
        let font = NSFont.monospacedSystemFont(ofSize: CGFloat(editorSettings.fontSize), weight: .regular)
        let textColor = NSColor(red: 0.97, green: 0.97, blue: 0.95, alpha: 1) // #f8f8f2
        textView.font = font
        textView.textColor = textColor
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: textColor
        ]

        // Horizontal scroll (no wrapping) setup
        if !editorSettings.lineWrapping {
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = [.height]
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.maxSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        // Line numbers
        let lineNumberView = LineNumberRulerView(textView: textView, settings: editorSettings)
        scrollView.verticalRulerView = lineNumberView
        scrollView.hasVerticalRuler = editorSettings.showLineNumbers
        scrollView.rulersVisible = editorSettings.showLineNumbers

        scrollView.backgroundColor = textView.backgroundColor

        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.rulerView = lineNumberView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let coord = context.coordinator
        guard let textView = coord.textView else { return }

        // Push content when a new file is opened
        if coord.lastOpenedFile != appState.openedFile {
            coord.lastOpenedFile = appState.openedFile
            coord.isUpdatingFromModel = true

            let text = appState.fileContent
            let font = NSFont.monospacedSystemFont(ofSize: CGFloat(coord.settings.fontSize), weight: .regular)
            let defaultColor = NSColor(red: 0.97, green: 0.97, blue: 0.95, alpha: 1)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: defaultColor
            ]
            textView.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: attrs))

            coord.isUpdatingFromModel = false
            coord.applySyntaxHighlighting()
            textView.scrollToBeginningOfDocument(nil)
        }

        // Apply settings changes
        coord.applySettings()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        let appState: AppState
        let settings: EditorSettings
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        weak var rulerView: LineNumberRulerView?
        var lastOpenedFile: URL?
        var isUpdatingFromModel = false
        private var highlighter: SyntaxHighlighter?
        private var appliedFontSize: Int = 0
        private var appliedLineWrapping: Bool = false
        private var appliedShowLineNumbers: Bool = true

        init(appState: AppState, settings: EditorSettings) {
            self.appState = appState
            self.settings = settings
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdatingFromModel, let textView else { return }
            appState.updateContent(textView.string)
            applySyntaxHighlightingDebounced()
            rulerView?.needsDisplay = true
        }

        private var highlightTimer: Timer?

        private func applySyntaxHighlightingDebounced() {
            highlightTimer?.invalidate()
            highlightTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                self?.applySyntaxHighlighting()
            }
        }

        func applySyntaxHighlighting() {
            guard let textView, let storage = textView.textStorage else { return }
            let ext = appState.fileExtension
            let highlighter = SyntaxHighlighter.forExtension(ext)
            let font = NSFont.monospacedSystemFont(ofSize: CGFloat(settings.fontSize), weight: .regular)
            let defaultColor = NSColor(red: 0.97, green: 0.97, blue: 0.95, alpha: 1) // #f8f8f2

            storage.beginEditing()

            // Reset to default
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.addAttributes([
                .font: font,
                .foregroundColor: defaultColor
            ], range: fullRange)

            // Apply syntax tokens
            let text = storage.string
            for token in highlighter.tokenize(text) {
                storage.addAttribute(.foregroundColor, value: token.color, range: token.range)
            }

            storage.endEditing()
            rulerView?.needsDisplay = true
        }

        func applySettings() {
            guard let textView, let scrollView else { return }

            let fontChanged = settings.fontSize != appliedFontSize
            let wrapChanged = settings.lineWrapping != appliedLineWrapping
            let lineNumChanged = settings.showLineNumbers != appliedShowLineNumbers

            guard fontChanged || wrapChanged || lineNumChanged else { return }

            appliedFontSize = settings.fontSize
            appliedLineWrapping = settings.lineWrapping
            appliedShowLineNumbers = settings.showLineNumbers

            if fontChanged {
                applySyntaxHighlighting()
            }

            if wrapChanged {
                textView.isHorizontallyResizable = !settings.lineWrapping
                textView.autoresizingMask = settings.lineWrapping ? [.width] : []
                if let tc = textView.textContainer {
                    tc.widthTracksTextView = settings.lineWrapping
                    tc.containerSize = NSSize(
                        width: settings.lineWrapping ? scrollView.contentSize.width : CGFloat.greatestFiniteMagnitude,
                        height: CGFloat.greatestFiniteMagnitude
                    )
                }
            }

            if lineNumChanged {
                scrollView.hasVerticalRuler = settings.showLineNumbers
                scrollView.rulersVisible = settings.showLineNumbers
            }
        }
    }
}

// MARK: - Line Number Ruler

class LineNumberRulerView: NSRulerView {
    private weak var editorTextView: NSTextView?
    private let editorSettings: EditorSettings

    init(textView: NSTextView, settings: EditorSettings) {
        self.editorTextView = textView
        self.editorSettings = settings
        super.init(scrollView: nil, orientation: .verticalRuler)
        self.ruleThickness = 40
        self.clientView = textView

        NotificationCenter.default.addObserver(
            self, selector: #selector(textDidChange),
            name: NSText.didChangeNotification, object: textView
        )
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func textDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = editorTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let bgColor = NSColor(red: 0.14, green: 0.14, blue: 0.18, alpha: 1)
        bgColor.setFill()
        rect.fill()

        let font = NSFont.monospacedSystemFont(ofSize: CGFloat(editorSettings.fontSize) - 1, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(red: 0.38, green: 0.45, blue: 0.55, alpha: 1)
        ]

        let visibleRect = scrollView?.contentView.bounds ?? rect
        let textOffset = textView.textContainerInset.height

        let visibleGlyphRange = layoutManager.glyphRange(
            forBoundingRect: visibleRect, in: textContainer
        )
        let visibleCharRange = layoutManager.characterRange(
            forGlyphRange: visibleGlyphRange, actualGlyphRange: nil
        )

        let text = textView.string as NSString
        var lineNumber = 1

        // Count lines before visible range
        text.enumerateSubstrings(
            in: NSRange(location: 0, length: visibleCharRange.location),
            options: [.byLines, .substringNotRequired]
        ) { _, _, _, _ in lineNumber += 1 }

        // Draw line numbers for visible range
        text.enumerateSubstrings(
            in: visibleCharRange,
            options: [.byLines, .substringNotRequired]
        ) { _, substringRange, _, _ in
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: substringRange, actualCharacterRange: nil
            )
            var lineRect = layoutManager.boundingRect(
                forGlyphRange: glyphRange, in: textContainer
            )
            lineRect.origin.y += textOffset

            let numStr = "\(lineNumber)" as NSString
            let strSize = numStr.size(withAttributes: attrs)
            let x = self.ruleThickness - strSize.width - 6
            let y = lineRect.origin.y + (lineRect.height - strSize.height) / 2

            numStr.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
            lineNumber += 1
        }
    }
}

// MARK: - Syntax Highlighter

struct SyntaxToken {
    let range: NSRange
    let color: NSColor
}

struct SyntaxHighlighter {
    let patterns: [(NSRegularExpression, NSColor)]

    func tokenize(_ text: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        for (regex, color) in patterns {
            regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                guard let match else { return }
                tokens.append(SyntaxToken(range: match.range, color: color))
            }
        }
        return tokens
    }

    // MARK: Colors (Dracula-inspired)

    private static let keyword  = NSColor(red: 1.00, green: 0.47, blue: 0.66, alpha: 1) // #ff79c6
    private static let string   = NSColor(red: 0.94, green: 0.98, blue: 0.55, alpha: 1) // #f1fa8c
    private static let comment  = NSColor(red: 0.38, green: 0.45, blue: 0.55, alpha: 1) // #6272a4
    private static let number   = NSColor(red: 0.74, green: 0.58, blue: 0.97, alpha: 1) // #bd93f9
    private static let type     = NSColor(red: 0.55, green: 0.93, blue: 0.99, alpha: 1) // #8be9fd
    private static let function_ = NSColor(red: 0.31, green: 0.97, blue: 0.48, alpha: 1) // #50fa7b

    // MARK: Language Patterns

    static func forExtension(_ ext: String) -> SyntaxHighlighter {
        switch ext {
        case "swift":
            return swift
        case "py", "pyw":
            return python
        case "js", "mjs", "cjs", "ts", "tsx", "jsx":
            return javascript
        case "c", "h", "cpp", "cc", "cxx", "hpp", "java", "kt", "cs":
            return clike
        case "go":
            return golang
        case "rs":
            return rust
        case "rb":
            return ruby
        case "sh", "bash", "zsh":
            return shell
        case "html", "htm", "xml", "svg":
            return html
        case "css", "scss", "less":
            return css
        case "json":
            return json
        case "yaml", "yml":
            return yaml
        case "md", "markdown":
            return markdown
        case "sql":
            return sql
        default:
            return generic
        }
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    }

    private static func regexML(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
    }

    static let generic = SyntaxHighlighter(patterns: [
        (regexML(#"/\*[\s\S]*?\*/"#), comment),            // block comments
        (regex(#"//.*$"#), comment),                         // line comments
        (regex(#"#.*$"#), comment),                          // hash comments
        (regex(#""(?:[^"\\]|\\.)*""#), string),              // double-quoted strings
        (regex(#"'(?:[^'\\]|\\.)*'"#), string),              // single-quoted strings
        (regex(#"\b\d+\.?\d*\b"#), number),                  // numbers
    ])

    static let swift = SyntaxHighlighter(patterns: [
        (regexML(#"/\*[\s\S]*?\*/"#), comment),
        (regex(#"//.*$"#), comment),
        (regex(#""(?:[^"\\]|\\.)*""#), string),
        (regex(#"\b(import|class|struct|enum|protocol|extension|func|var|let|if|else|guard|switch|case|default|for|while|repeat|return|break|continue|throw|throws|try|catch|do|in|as|is|self|Self|super|init|deinit|nil|true|false|static|private|public|internal|fileprivate|open|override|mutating|weak|unowned|lazy|some|any|async|await|actor|where|typealias|associatedtype|subscript|willSet|didSet|get|set|inout|defer|fallthrough|@objc|@Published|@State|@Binding|@EnvironmentObject|@StateObject|@ObservedObject|@ViewBuilder|@main|@available|@escaping)\b"#), keyword),
        (regex(#"\b[A-Z][A-Za-z0-9_]*\b"#), type),
        (regex(#"\b\d+\.?\d*\b"#), number),
        (regex(#"\b(func|init)\s+([A-Za-z_][A-Za-z0-9_]*)"#), function_),
    ])

    static let python = SyntaxHighlighter(patterns: [
        (regex(#"#.*$"#), comment),
        (regexML(#"\"\"\"[\s\S]*?\"\"\""#), string),
        (regexML(#"'''[\s\S]*?'''"#), string),
        (regex(#""(?:[^"\\]|\\.)*""#), string),
        (regex(#"'(?:[^'\\]|\\.)*'"#), string),
        (regex(#"\b(import|from|class|def|return|if|elif|else|for|while|break|continue|pass|raise|try|except|finally|with|as|yield|lambda|and|or|not|in|is|True|False|None|self|global|nonlocal|async|await|del|assert)\b"#), keyword),
        (regex(#"\b[A-Z][A-Za-z0-9_]*\b"#), type),
        (regex(#"\b\d+\.?\d*\b"#), number),
        (regex(#"\bdef\s+([A-Za-z_][A-Za-z0-9_]*)"#), function_),
    ])

    static let javascript = SyntaxHighlighter(patterns: [
        (regexML(#"/\*[\s\S]*?\*/"#), comment),
        (regex(#"//.*$"#), comment),
        (regex(#"`(?:[^`\\]|\\.)*`"#), string),
        (regex(#""(?:[^"\\]|\\.)*""#), string),
        (regex(#"'(?:[^'\\]|\\.)*'"#), string),
        (regex(#"\b(import|export|from|default|const|let|var|function|class|extends|return|if|else|for|while|do|switch|case|break|continue|throw|try|catch|finally|new|delete|typeof|instanceof|in|of|this|super|async|await|yield|true|false|null|undefined|void|static|get|set|interface|type|enum|implements|public|private|protected|readonly|abstract|as|is|keyof|namespace|declare|module|require)\b"#), keyword),
        (regex(#"\b[A-Z][A-Za-z0-9_]*\b"#), type),
        (regex(#"\b\d+\.?\d*\b"#), number),
        (regex(#"\b(function|class)\s+([A-Za-z_$][A-Za-z0-9_$]*)"#), function_),
    ])

    static let clike = SyntaxHighlighter(patterns: [
        (regexML(#"/\*[\s\S]*?\*/"#), comment),
        (regex(#"//.*$"#), comment),
        (regex(#""(?:[^"\\]|\\.)*""#), string),
        (regex(#"'(?:[^'\\]|\\.)*'"#), string),
        (regex(#"\b(auto|break|case|char|const|continue|default|do|double|else|enum|extern|float|for|goto|if|int|long|register|return|short|signed|sizeof|static|struct|switch|typedef|union|unsigned|void|volatile|while|class|namespace|template|typename|using|virtual|public|private|protected|new|delete|this|throw|try|catch|inline|override|final|abstract|interface|extends|implements|import|package|boolean|byte|null|true|false|super)\b"#), keyword),
        (regex(#"#\s*(include|define|ifdef|ifndef|endif|pragma|if|else|elif|undef)\b.*$"#), keyword),
        (regex(#"\b[A-Z][A-Za-z0-9_]*\b"#), type),
        (regex(#"\b\d+\.?\d*[fFlLuU]?\b"#), number),
    ])

    static let golang = SyntaxHighlighter(patterns: [
        (regexML(#"/\*[\s\S]*?\*/"#), comment),
        (regex(#"//.*$"#), comment),
        (regex(#"`[^`]*`"#), string),
        (regex(#""(?:[^"\\]|\\.)*""#), string),
        (regex(#"\b(package|import|func|var|const|type|struct|interface|map|chan|range|return|if|else|for|switch|case|default|break|continue|goto|fallthrough|defer|go|select|true|false|nil|iota|make|new|len|cap|append|copy|delete|panic|recover)\b"#), keyword),
        (regex(#"\b[A-Z][A-Za-z0-9_]*\b"#), type),
        (regex(#"\b\d+\.?\d*\b"#), number),
    ])

    static let rust = SyntaxHighlighter(patterns: [
        (regexML(#"/\*[\s\S]*?\*/"#), comment),
        (regex(#"//.*$"#), comment),
        (regex(#""(?:[^"\\]|\\.)*""#), string),
        (regex(#"\b(fn|let|mut|const|static|struct|enum|impl|trait|type|pub|mod|use|crate|super|self|Self|return|if|else|for|while|loop|match|break|continue|move|ref|as|in|where|async|await|unsafe|extern|dyn|true|false|Some|None|Ok|Err|Box|Vec|String|Option|Result)\b"#), keyword),
        (regex(#"\b[A-Z][A-Za-z0-9_]*\b"#), type),
        (regex(#"\b\d+\.?\d*\b"#), number),
    ])

    static let ruby = SyntaxHighlighter(patterns: [
        (regex(#"#.*$"#), comment),
        (regex(#""(?:[^"\\]|\\.)*""#), string),
        (regex(#"'(?:[^'\\]|\\.)*'"#), string),
        (regex(#"\b(require|include|module|class|def|end|if|elsif|else|unless|case|when|while|until|for|do|begin|rescue|ensure|raise|return|yield|block_given\?|self|super|true|false|nil|and|or|not|in|then|puts|print|attr_accessor|attr_reader|attr_writer|private|public|protected)\b"#), keyword),
        (regex(#"\b[A-Z][A-Za-z0-9_]*\b"#), type),
        (regex(#"\b\d+\.?\d*\b"#), number),
        (regex(#":[A-Za-z_][A-Za-z0-9_]*"#), string),
    ])

    static let shell = SyntaxHighlighter(patterns: [
        (regex(#"#.*$"#), comment),
        (regex(#""(?:[^"\\]|\\.)*""#), string),
        (regex(#"'[^']*'"#), string),
        (regex(#"\b(if|then|else|elif|fi|case|esac|for|while|until|do|done|in|function|return|exit|local|export|source|alias|unalias|set|unset|shift|break|continue|eval|exec|trap|read|echo|printf|test|true|false)\b"#), keyword),
        (regex(#"\$\{?[A-Za-z_][A-Za-z0-9_]*\}?"#), type),
        (regex(#"\b\d+\b"#), number),
    ])

    static let html = SyntaxHighlighter(patterns: [
        (regexML(#"<!--[\s\S]*?-->"#), comment),
        (regex(#""[^"]*""#), string),
        (regex(#"'[^']*'"#), string),
        (regex(#"</?[A-Za-z][A-Za-z0-9-]*"#), keyword),
        (regex(#"/?\s*>"#), keyword),
        (regex(#"\b[A-Za-z-]+=(?=")"#), type),
    ])

    static let css = SyntaxHighlighter(patterns: [
        (regexML(#"/\*[\s\S]*?\*/"#), comment),
        (regex(#""[^"]*""#), string),
        (regex(#"'[^']*'"#), string),
        (regex(#"[.#][A-Za-z_-][A-Za-z0-9_-]*"#), keyword),
        (regex(#"[A-Za-z-]+(?=\s*:)"#), type),
        (regex(#"#[0-9A-Fa-f]{3,8}\b"#), number),
        (regex(#"\b\d+\.?\d*(px|em|rem|%|vh|vw|s|ms)?\b"#), number),
        (regex(#"@(media|import|keyframes|font-face|supports)\b"#), keyword),
    ])

    static let json = SyntaxHighlighter(patterns: [
        (regex(#""(?:[^"\\]|\\.)*"\s*(?=:)"#), type),
        (regex(#""(?:[^"\\]|\\.)*""#), string),
        (regex(#"\b(true|false|null)\b"#), keyword),
        (regex(#"-?\b\d+\.?\d*([eE][+-]?\d+)?\b"#), number),
    ])

    static let yaml = SyntaxHighlighter(patterns: [
        (regex(#"#.*$"#), comment),
        (regex(#"^[A-Za-z_][A-Za-z0-9_ -]*(?=\s*:)"#), type),
        (regex(#""(?:[^"\\]|\\.)*""#), string),
        (regex(#"'[^']*'"#), string),
        (regex(#"\b(true|false|null|yes|no)\b"#), keyword),
        (regex(#"\b\d+\.?\d*\b"#), number),
    ])

    static let markdown = SyntaxHighlighter(patterns: [
        (regex(#"^#{1,6}\s+.*$"#), keyword),
        (regex(#"\*\*[^*]+\*\*"#), type),
        (regex(#"\*[^*]+\*"#), function_),
        (regex(#"`[^`]+`"#), string),
        (regex(#"^\s*[-*+]\s"#), keyword),
        (regex(#"^\s*\d+\.\s"#), keyword),
        (regex(#"\[([^\]]+)\]\([^)]+\)"#), type),
    ])

    static let sql = SyntaxHighlighter(patterns: [
        (regex(#"--.*$"#), comment),
        (regexML(#"/\*[\s\S]*?\*/"#), comment),
        (regex(#"'(?:[^'\\]|\\.)*'"#), string),
        (regex(#"(?i)\b(SELECT|FROM|WHERE|INSERT|INTO|UPDATE|SET|DELETE|CREATE|DROP|ALTER|TABLE|INDEX|VIEW|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AND|OR|NOT|IN|IS|NULL|AS|ORDER|BY|GROUP|HAVING|LIMIT|OFFSET|UNION|ALL|DISTINCT|EXISTS|BETWEEN|LIKE|CASE|WHEN|THEN|ELSE|END|BEGIN|COMMIT|ROLLBACK|GRANT|REVOKE|PRIMARY|KEY|FOREIGN|REFERENCES|DEFAULT|CHECK|CONSTRAINT|VALUES|COUNT|SUM|AVG|MIN|MAX|INT|INTEGER|VARCHAR|TEXT|BOOLEAN|DATE|TIMESTAMP|FLOAT|DOUBLE|DECIMAL)\b"#), keyword),
        (regex(#"\b\d+\.?\d*\b"#), number),
    ])
}
