import SwiftUI
import AppKit

struct CodeEditorView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var editorSettings: EditorSettings

    var body: some View {
        NativeTextEditor(
            text: Binding(
                get: { appState.fileContent },
                set: { appState.updateContent($0) }
            ),
            fontSize: editorSettings.fontSize,
            lineWrapping: editorSettings.lineWrapping
        )
    }
}

// MARK: - NativeTextEditor

struct NativeTextEditor: NSViewRepresentable {
    @Binding var text: String
    let fontSize: Int
    let lineWrapping: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false

        let font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        textView.font = font
        textView.textColor = .white
        textView.backgroundColor = NSColor(red: 0.16, green: 0.16, blue: 0.21, alpha: 1)
        textView.insertionPointColor = .white
        textView.textContainerInset = NSSize(width: 4, height: 8)

        if !lineWrapping {
            textView.isHorizontallyResizable = true
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !lineWrapping
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = textView.backgroundColor

        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        if !context.coordinator.isEditing && textView.string != text {
            textView.string = text
            textView.font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
            textView.textColor = .white
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: NativeTextEditor
        weak var textView: NSTextView?
        var isEditing = false

        init(parent: NativeTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            isEditing = true
            parent.text = textView.string
            isEditing = false
        }
    }
}
