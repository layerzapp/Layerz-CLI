import SwiftUI
import WebKit

struct CodeEditorView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
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
        // Only push content when a new file is opened
        let coord = context.coordinator
        guard coord.lastOpenedFile != appState.openedFile else { return }
        coord.lastOpenedFile = appState.openedFile
        coord.pendingFile = (appState.fileContent, appState.fileExtension)
        if coord.isLoaded {
            coord.flushPending(to: nsView)
        }
    }

    private func loadEditor(in wv: WKWebView) {
        if let url = Bundle.main.url(forResource: "editor", withExtension: "html") {
            wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            // Inline fallback (no syntax highlighting)
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
        </script></body></html>
        """ }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let appState: AppState
        weak var webView: WKWebView?
        var lastOpenedFile: URL? = nil
        var pendingFile: (content: String, ext: String)? = nil
        var isLoaded = false

        init(appState: AppState) {
            self.appState = appState
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            // If no pending file set yet, push the current app state
            if pendingFile == nil {
                pendingFile = (appState.fileContent, appState.fileExtension)
            }
            flushPending(to: webView)
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
