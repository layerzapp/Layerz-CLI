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

        // Make the terminal the first responder so it receives keyboard input immediately
        DispatchQueue.main.async {
            tv.window?.makeFirstResponder(tv)
        }

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
        private var clickMonitor: Any?
        private var keyMonitor: Any?

        init(appState: AppState) {
            self.appState = appState
        }

        deinit {
            if let m = clickMonitor { NSEvent.removeMonitor(m) }
            if let m = keyMonitor { NSEvent.removeMonitor(m) }
        }

        // MARK: - Shell Detection & Launch

        /// Detect the user's preferred shell from $SHELL, falling back to /bin/zsh.
        private var detectedShell: (path: String, kind: ShellKind) {
            let shellPath = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            let name = (shellPath as NSString).lastPathComponent
            let kind: ShellKind
            switch name {
            case "bash": kind = .bash
            case "fish": kind = .fish
            default:     kind = .zsh
            }
            return (shellPath, kind)
        }

        func start(_ tv: LocalProcessTerminalView) {
            let shell = detectedShell
            var env = ProcessInfo.processInfo.environment
            env["TERM"] = "xterm-256color"
            env["COLORTERM"] = "truecolor"
            env["TERM_PROGRAM"] = "Console"
            env["LANG"] = "en_US.UTF-8"
            env["LC_ALL"] = "en_US.UTF-8"

            var args: [String] = []
            let execName = (shell.path as NSString).lastPathComponent

            switch shell.kind {
            case .zsh:
                let zdotdir = makeZshIntegrationDir()
                env["ZDOTDIR"] = zdotdir

            case .bash:
                let rcfile = makeBashIntegrationFile()
                args = ["--rcfile", rcfile]

            case .fish:
                let initCmd = makeFishInitCommand()
                args = ["--init-command", initCmd]
            }

            tv.startProcess(
                executable: shell.path,
                args: args,
                environment: env.map { "\($0.key)=\($0.value)" },
                execName: execName,
                currentDirectory: NSHomeDirectory()
            )
        }

        // MARK: - Shell Integration Setup

        /// Locate a bundled shell integration script by filename.
        private func bundledIntegrationScript(named filename: String) -> String? {
            Bundle.main.path(forResource: filename, ofType: nil)
        }

        /// Create a temporary ZDOTDIR whose .zshrc loads the bundled zsh integration.
        /// Saves the user's original ZDOTDIR as CONSOLE_ZSH_ZDOTDIR so it can be restored.
        private func makeZshIntegrationDir() -> String {
            let dir = NSTemporaryDirectory() + "Console_\(ProcessInfo.processInfo.processIdentifier)"
            try? FileManager.default.createDirectory(
                atPath: dir, withIntermediateDirectories: true
            )

            if let scriptPath = bundledIntegrationScript(named: "console-zsh-integration.zsh") {
                // Save original ZDOTDIR and source the bundled integration
                let originalZdotdir = ProcessInfo.processInfo.environment["ZDOTDIR"] ?? NSHomeDirectory()
                let zshrc = """
                export CONSOLE_ZSH_ZDOTDIR="\(originalZdotdir)"
                source "\(scriptPath)"
                """
                try? zshrc.write(toFile: dir + "/.zshrc", atomically: true, encoding: .utf8)
            } else {
                // Fallback: inline integration if resource not found
                let home = NSHomeDirectory()
                let zshrc = """
                if [[ -f "\(home)/.zshrc" ]]; then
                    ZDOTDIR="\(home)"
                    source "\(home)/.zshrc"
                    ZDOTDIR="\(dir)"
                fi
                _console_notify_cwd() {
                    printf '\\033]7;file://localhost%s\\033\\\\' "$PWD"
                }
                autoload -U add-zsh-hook
                add-zsh-hook chpwd _console_notify_cwd
                _console_notify_cwd
                """
                try? zshrc.write(toFile: dir + "/.zshrc", atomically: true, encoding: .utf8)
            }

            return dir
        }

        /// Create a temporary rcfile that sources the bundled bash integration.
        private func makeBashIntegrationFile() -> String {
            let dir = NSTemporaryDirectory() + "Console_\(ProcessInfo.processInfo.processIdentifier)"
            try? FileManager.default.createDirectory(
                atPath: dir, withIntermediateDirectories: true
            )

            let rcPath = dir + "/.console_bashrc"

            if let scriptPath = bundledIntegrationScript(named: "console-bash-integration.bash") {
                let rc = "source \"\(scriptPath)\"\n"
                try? rc.write(toFile: rcPath, atomically: true, encoding: .utf8)
            } else {
                // Fallback: inline integration
                let rc = """
                [[ -r "$HOME/.bashrc" ]] && source "$HOME/.bashrc"
                _console_notify_cwd() {
                    printf '\\033]7;file://localhost%s\\033\\\\' "$PWD"
                }
                PROMPT_COMMAND="_console_notify_cwd${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
                _console_notify_cwd
                """
                try? rc.write(toFile: rcPath, atomically: true, encoding: .utf8)
            }

            return rcPath
        }

        /// Build an --init-command string that sources the bundled fish integration.
        private func makeFishInitCommand() -> String {
            if let scriptPath = bundledIntegrationScript(named: "console-fish-integration.fish") {
                return "source \"\(scriptPath)\""
            }
            // Fallback: inline OSC 7
            return """
            function __console_notify_cwd --on-variable PWD; \
                printf '\\033]7;file://localhost%s\\033\\\\' $PWD; \
            end; \
            __console_notify_cwd
            """
        }

        // MARK: - Input Source Monitoring

        /// Monitor mouse clicks to detect when the terminal gains focus,
        /// then switch to ASCII input source.
        func installInputSourceMonitor() {
            clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
                guard let self, let tv = self.terminalView else { return event }
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

            // Intercept Shift+Enter and send CSI 13;2u so zsh can insert a newline
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard let self, let tv = self.terminalView else { return event }
                if event.keyCode == 36 && event.modifierFlags.contains(.shift) {
                    if let window = tv.window, event.window == window {
                        // ESC [ 1 3 ; 2 u
                        tv.send([0x1b, 0x5b, 0x31, 0x33, 0x3b, 0x32, 0x75])
                        return nil  // consume the event
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

        // MARK: - LocalProcessTerminalViewDelegate

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            DispatchQueue.main.async {
                guard let tab = self.appState.tabs.first(where: { $0.id == self.appState.activeTabID }) else { return }
                let displayTitle = title.isEmpty ? "Terminal" : String(title.prefix(30))
                if tab.title != displayTitle {
                    tab.title = displayTitle
                }
            }
        }

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

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            DispatchQueue.main.async {
                // If multiple tabs exist, close the terminated tab
                if self.appState.tabs.count > 1 {
                    self.appState.closeTab(self.appState.activeTabID)
                } else {
                    // Last tab: update title to show exit status
                    if let tab = self.appState.tabs.first(where: { $0.id == self.appState.activeTabID }) {
                        let code = exitCode ?? 0
                        tab.title = code == 0 ? "Terminal (exited)" : "Terminal (exit \(code))"
                    }
                }
            }
        }
    }
}

// MARK: - ShellKind

private enum ShellKind {
    case zsh, bash, fish
}
