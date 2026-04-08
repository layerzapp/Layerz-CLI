import SwiftUI
import WebKit
import Combine

struct CodeEditorView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var editorSettings: EditorSettings

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState, settings: editorSettings)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "contentChanged")
        config.userContentController.add(context.coordinator, name: "saveRequested")
        // Allow loading local file resources
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        wv.setContentHuggingPriority(.defaultLow, for: .vertical)
        context.coordinator.webView = wv

        loadEditor(in: wv)
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let coord = context.coordinator

        // Push content when a new file is opened
        if coord.lastOpenedFile != appState.openedFile {
            coord.lastOpenedFile = appState.openedFile
            coord.pendingFile = (appState.fileContent, appState.fileExtension)
            if coord.isLoaded {
                coord.flushPending(to: nsView)
            }
        }

        // Apply settings when they change
        coord.applySettingsIfNeeded(to: nsView)
    }

    private func loadEditor(in wv: WKWebView) {
        // Load editor.html as a string via loadHTMLString so that CDN scripts
        // (CodeMirror, language modes) are not blocked by file:// security policy.
        if let url = Bundle.main.url(forResource: "editor", withExtension: "html"),
           let html = try? String(contentsOf: url, encoding: .utf8) {
            wv.loadHTMLString(html, baseURL: URL(string: "https://cdn.jsdelivr.net"))
        } else {
            wv.loadHTMLString(fallbackHTML, baseURL: nil)
        }
    }

    private var fallbackHTML: String { """
        <!DOCTYPE html><html><body style="margin:0;background:#1e1e1e">
        <textarea id="e" style="width:100%;height:100vh;background:#1e1e1e;color:#d4d4d4;
            font:13px/1.5 'SF Mono',Menlo,monospace;border:none;padding:10px;
            resize:none;outline:none;box-sizing:border-box"></textarea>
        <script>
        var t=document.getElementById('e');
        t.oninput=function(){notify(t.value)};
        t.onkeydown=function(e){
            if((e.metaKey||e.ctrlKey)&&e.key==='s'){
                e.preventDefault();
                try{window.webkit.messageHandlers.saveRequested.postMessage('')}catch(_){}
            }
        };
        function notify(v){try{window.webkit.messageHandlers.contentChanged.postMessage(v)}catch(_){}}
        window.setContent=function(c,_){t.value=c||''};
        window.getContent=function(){return t.value};
        window.applySettings=function(o){if(o.fontSize)t.style.fontSize=o.fontSize+'px'};
        </script></body></html>
        """ }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let appState: AppState
        let settings: EditorSettings
        weak var webView: WKWebView?
        var lastOpenedFile: URL? = nil
        var pendingFile: (content: String, ext: String)? = nil
        var isLoaded = false

        // Track last-applied settings to avoid redundant JS calls
        private var appliedFontSize: Int = 0
        private var appliedTabSize: Int = 0
        private var appliedLineWrapping: Bool = false
        private var appliedLineNumbers: Bool = true
        private var appliedTheme: String = ""

        init(appState: AppState, settings: EditorSettings) {
            self.appState = appState
            self.settings = settings
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            // If no pending file set yet, push the current app state
            if pendingFile == nil {
                pendingFile = (appState.fileContent, appState.fileExtension)
            }
            flushPending(to: webView)
            // Apply initial settings
            forceApplySettings(to: webView)
        }

        func flushPending(to webView: WKWebView) {
            guard let (content, ext) = pendingFile else { return }
            pendingFile = nil
            pushContent(content, ext: ext, to: webView)
        }

        private func pushContent(_ content: String, ext: String, to webView: WKWebView) {
            guard let jsonData = try? JSONEncoder().encode(content),
                  let json = String(data: jsonData, encoding: .utf8) else { return }
            let js = "window.setContent(\(json), '\(ext)');"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func applySettingsIfNeeded(to webView: WKWebView) {
            guard isLoaded else { return }
            guard settings.fontSize != appliedFontSize ||
                  settings.tabSize != appliedTabSize ||
                  settings.lineWrapping != appliedLineWrapping ||
                  settings.showLineNumbers != appliedLineNumbers ||
                  settings.theme != appliedTheme else { return }
            forceApplySettings(to: webView)
        }

        private func forceApplySettings(to webView: WKWebView) {
            appliedFontSize = settings.fontSize
            appliedTabSize = settings.tabSize
            appliedLineWrapping = settings.lineWrapping
            appliedLineNumbers = settings.showLineNumbers
            appliedTheme = settings.theme

            // Map theme name for solarized dark
            let themeName = settings.theme == "solarized dark" ? "solarized dark" : settings.theme

            let js = """
            window.applySettings({
                fontSize: \(settings.fontSize),
                tabSize: \(settings.tabSize),
                lineWrapping: \(settings.lineWrapping),
                lineNumbers: \(settings.showLineNumbers),
                theme: '\(themeName)'
            });
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        // MARK: WKScriptMessageHandler

        func userContentController(
            _ ucc: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case "contentChanged":
                if let text = message.body as? String {
                    DispatchQueue.main.async { self.appState.updateContent(text) }
                }
            case "saveRequested":
                DispatchQueue.main.async { self.appState.saveFile() }
            default:
                break
            }
        }
    }
}
