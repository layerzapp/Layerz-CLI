import SwiftUI
import WebKit

struct MarkdownPreviewView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState

    func makeNSView(context: Context) -> WKWebView {
        let wv = WKWebView(frame: .zero)
        wv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        wv.setContentHuggingPriority(.defaultLow, for: .vertical)
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        renderMarkdown(appState.fileContent, in: nsView)
    }

    private func renderMarkdown(_ markdown: String, in wv: WKWebView) {
        // JSON-encode the markdown to safely pass it to JS
        guard let data = try? JSONEncoder().encode(markdown),
              let json = String(data: data, encoding: .utf8) else { return }

        let baseURL = appState.openedFile?.deletingLastPathComponent()
        let html = buildHTML(jsonMarkdown: json)
        wv.loadHTMLString(html, baseURL: baseURL)
    }

    private func buildHTML(jsonMarkdown: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="color-scheme" content="light dark">
        <style>
          :root { color-scheme: light dark; }
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            font-size: 14px; line-height: 1.75;
            max-width: 820px; margin: 0 auto; padding: 28px 36px;
            word-break: break-word;
          }
          @media (prefers-color-scheme: dark) {
            body  { background: #1e1e1e; color: #d4d4d4; }
            pre   { background: #2d2d2d !important; }
            :not(pre) > code { background: #2d2d2d !important; color: #ce9178 !important; }
            a     { color: #4da3ff; }
            blockquote { border-left-color: #555; color: #aaa; }
            table th { background: #2a2a2a; }
            table, th, td { border-color: #444 !important; }
            hr    { border-top-color: #444; }
            h1, h2 { border-bottom-color: #333; }
          }
          h1, h2 { border-bottom: 1px solid #eaecef; padding-bottom: 6px; margin-top: 24px; margin-bottom: 12px; }
          h3, h4, h5, h6 { margin-top: 18px; margin-bottom: 8px; }
          p { margin: 0 0 12px; }
          pre {
            background: #f6f8fa; border-radius: 6px;
            padding: 14px 16px; overflow-x: auto;
          }
          code { font-family: 'SF Mono', Menlo, Monaco, monospace; font-size: 0.88em; }
          :not(pre) > code {
            background: #f0f0f0; color: #c7254e;
            padding: 2px 5px; border-radius: 4px;
          }
          pre code { background: none; color: inherit; padding: 0; }
          blockquote {
            border-left: 4px solid #d0d7de; margin: 12px 0;
            padding: 4px 16px; color: #666;
          }
          table { border-collapse: collapse; width: 100%; margin-bottom: 14px; }
          th, td { border: 1px solid #d0d7de; padding: 8px 13px; }
          th { background: #f6f8fa; font-weight: 600; }
          tr:nth-child(even) td { background: rgba(0,0,0,0.02); }
          img { max-width: 100%; height: auto; border-radius: 4px; }
          a { color: #0969da; text-decoration: none; }
          a:hover { text-decoration: underline; }
          hr { border: none; border-top: 1px solid #eaecef; margin: 24px 0; }
          ul, ol { padding-left: 24px; margin-bottom: 12px; }
          li { margin-bottom: 4px; }
          /* Task list checkboxes */
          input[type=checkbox] { margin-right: 6px; }
          /* Code block syntax highlight via highlight.js */
          .hljs-keyword, .hljs-selector-tag, .hljs-built_in { color: #0086b3; }
          .hljs-string, .hljs-attr { color: #183691; }
          .hljs-comment { color: #969896; }
          @media (prefers-color-scheme: dark) {
            .hljs-keyword { color: #569cd6; }
            .hljs-string  { color: #ce9178; }
            .hljs-comment { color: #608b4e; }
          }
        </style>
        </head>
        <body>
        <div id="root"></div>
        <script src="https://cdn.jsdelivr.net/npm/marked@9/marked.min.js"></script>
        <script>
        var md = \(jsonMarkdown);
        marked.setOptions({
          gfm: true,
          breaks: false,
          mangle: false,
          headerIds: false
        });
        document.getElementById('root').innerHTML = marked.parse(md);

        // Make relative links open in the system browser
        document.querySelectorAll('a[href]').forEach(function(a) {
          a.addEventListener('click', function(e) {
            e.preventDefault();
            window.location.href = a.href;
          });
        });
        </script>
        </body>
        </html>
        """
    }
}
