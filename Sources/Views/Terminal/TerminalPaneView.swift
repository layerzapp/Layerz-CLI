import SwiftUI
import SwiftTerm
import AppKit
import Carbon.HIToolbox

struct TerminalPaneView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: EditorSettings

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let tv = LocalProcessTerminalView(frame: .zero)

        let fontSize = CGFloat(settings.terminalFontSize)
        tv.font = NSFont(name: settings.terminalFontName, size: fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        tv.processDelegate = context.coordinator
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultLow, for: .vertical)
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        context.coordinator.terminalView = tv
        context.coordinator.start(tv)
        context.coordinator.installInputSourceMonitor()
        return tv
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        let desired = NSFont(name: settings.terminalFontName, size: CGFloat(settings.terminalFontSize))
            ?? NSFont.monospacedSystemFont(ofSize: CGFloat(settings.terminalFontSize), weight: .regular)
        if nsView.font != desired {
            nsView.font = desired
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let appState: AppState
        weak var terminalView: LocalProcessTerminalView?
        private var eventMonitor: Any?

        init(appState: AppState) {
            self.appState = appState
        }

        deinit {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func start(_ tv: LocalProcessTerminalView) {
            let zdotdir = makeZdotdir()
            var env = ProcessInfo.processInfo.environment
            env["TERM"] = "xterm-256color"
            env["COLORTERM"] = "truecolor"
            env["TERM_PROGRAM"] = "Console"
            env["LANG"] = "en_US.UTF-8"
            env["LC_ALL"] = "en_US.UTF-8"
            env["ZDOTDIR"] = zdotdir

            tv.startProcess(
                executable: "/bin/zsh",
                args: [],
                environment: env.map { "\($0.key)=\($0.value)" },
                execName: "zsh",
                currentDirectory: NSHomeDirectory()
            )
        }

        /// Monitor mouse clicks to detect when the terminal gains focus,
        /// then switch to ASCII input source.
        func installInputSourceMonitor() {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
                guard let self, let tv = self.terminalView else { return event }
                // Check if the click landed inside the terminal view
                let point = event.locationInWindow
                if let window = tv.window,
                   event.window == window {
                    let localPoint = tv.convert(point, from: nil)
                    if tv.bounds.contains(localPoint) {
                        self.switchToASCIIInputSource()
                    }
                }
                return event
            }
        }

        private func switchToASCIIInputSource() {
            guard let sources = TISCreateASCIICapableInputSourceList()?.takeRetainedValue()
                    as? [TISInputSource],
                  let asciiSource = sources.first else { return }
            TISSelectInputSource(asciiSource)
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
