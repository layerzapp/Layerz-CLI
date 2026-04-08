import SwiftUI
import SwiftTerm
import AppKit

struct TerminalPaneView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let tv = LocalProcessTerminalView(frame: .zero)
        tv.processDelegate = context.coordinator
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultLow, for: .vertical)
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        context.coordinator.start(tv)
        return tv
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Terminal manages its own state; no updates needed from SwiftUI
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let appState: AppState

        init(appState: AppState) {
            self.appState = appState
        }

        func start(_ tv: LocalProcessTerminalView) {
            let zdotdir = makeZdotdir()
            var env = ProcessInfo.processInfo.environment
            env["TERM"] = "xterm-256color"
            env["COLORTERM"] = "truecolor"
            env["LANG"] = "en_US.UTF-8"
            env["LC_ALL"] = "en_US.UTF-8"
            env["ZDOTDIR"] = zdotdir

            tv.startProcess(
                executable: "/bin/zsh",
                args: [],
                environment: env.map { "\($0.key)=\($0.value)" },
                execName: "zsh"
            )
        }

        /// Create a temporary ZDOTDIR with a .zshrc that:
        ///  1. Sources the user's original ~/.zshrc
        ///  2. Installs a chpwd hook that emits OSC 7 (current-directory notification)
        private func makeZdotdir() -> String {
            let dir = NSTemporaryDirectory() + "Console_\(ProcessInfo.processInfo.processIdentifier)"
            try? FileManager.default.createDirectory(
                atPath: dir, withIntermediateDirectories: true
            )

            let home = NSHomeDirectory()
            let zdotdir = dir   // capture for interpolation inside the heredoc

            let zshrc = """
# ─── Console.app shell init ──────────────────────────────────────
# 1. Source the user's own .zshrc (if any)
if [[ -f "\(home)/.zshrc" ]]; then
    ZDOTDIR="\(home)"
    source "\(home)/.zshrc"
    ZDOTDIR="\(zdotdir)"
fi

# 2. OSC 7 – notify Console.app whenever the working directory changes
_console_notify_cwd() {
    local encoded_path
    encoded_path=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe='/'))" "$PWD" 2>/dev/null || echo "$PWD")
    printf '\\033]7;file://localhost%s\\033\\\\\\\\' "$encoded_path"
}

autoload -U add-zsh-hook
add-zsh-hook chpwd _console_notify_cwd
_console_notify_cwd   # emit immediately on startup
"""
            try? zshrc.write(toFile: dir + "/.zshrc", atomically: true, encoding: .utf8)
            return dir
        }

        // MARK: LocalProcessTerminalViewDelegate

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            guard var raw = directory, !raw.isEmpty else { return }

            // Strip scheme: "file://localhost/path" or "file:///path"
            if raw.hasPrefix("file://localhost") {
                raw = String(raw.dropFirst("file://localhost".count))
            } else if raw.hasPrefix("file://") {
                raw = String(raw.dropFirst("file://".count))
            }

            guard let path = raw.removingPercentEncoding, !path.isEmpty else { return }

            let url = URL(fileURLWithPath: path)
            DispatchQueue.main.async {
                if self.appState.currentDirectory != url {
                    self.appState.currentDirectory = url
                }
            }
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {}
    }
}
