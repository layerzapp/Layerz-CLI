# Console — CLAUDE.md

A macOS native terminal + file browser app.
This file is a guide for AI agents to quickly understand the codebase and contribute in a consistent manner.

---

## Project Core Context

- **Platform**: macOS 13+ only (AppKit + SwiftUI hybrid)
- **Language**: Swift 5 (Xcode Swift 6.2 compiler, `SWIFT_STRICT_CONCURRENCY: minimal`)
- **Build System**: Xcode project with folder references (file system synchronized groups)
- **Packages**: SwiftTerm (SPM), marked.js (CDN)

> The project uses Xcode's folder references. New files added to `Sources/` are automatically included in the build. No 3rd-party project generation tools (XcodeGen, etc.) are used.

---

## Architecture Decision Records (ADR)

### 1. State Management: AppState (Single ObservableObject)
`AppState` is the single source of truth for the app. All panels share it via `@EnvironmentObject`.
No direct panel-to-panel communication — everything goes through AppState.

```
TerminalPaneView ──writes──▶ AppState.currentDirectory ──reads──▶ FileBrowserView
FileBrowserView  ──writes──▶ AppState.openedFile       ──reads──▶ EditorPaneView
CodeEditorView   ──writes──▶ AppState.fileContent      ──reads──▶ MarkdownPreviewView
```

### 2. Terminal: SwiftTerm + Multi-Shell Integration (zsh/bash/fish)
CWD tracking uses **OSC 7 escape sequences instead of polling (proc_pidinfo)**.
The user's shell is auto-detected from `$SHELL` (zsh, bash, fish supported).
Shell integration scripts are bundled as resources in `Sources/Resources/ShellIntegration/`.

- **zsh**: ZDOTDIR injection → `console-zsh-integration.zsh` (chpwd hook + Shift+Enter)
- **bash**: `--rcfile` → `console-bash-integration.bash` (PROMPT_COMMAND)
- **fish**: `--init-command` → `console-fish-integration.fish` (--on-variable PWD)

URL encoding is done in pure shell (no python3 dependency).

```
shell CWD change → OSC 7 escape → SwiftTerm parsing → Coordinator callback → AppState update
```

### 3. Editor: NSTextView + SyntaxHighlighter (Native)
The editor is a native NSTextView-based implementation. No external dependencies (CDN, WKWebView).
- `SyntaxHighlighter`: Regex-based tokenization, per-language patterns (Swift, Python, JS, Go, Rust, etc. — 15 languages)
- `LineNumberRulerView`: NSRulerView subclass for line number display
- `EditorSettings`: User preferences for font size, line wrap, line numbers, etc. (persisted via UserDefaults)
- Change detection: NSTextViewDelegate.textDidChange → debouncing → re-apply highlighting

### 4. File Browser: FileManager + NSWorkspace Icons
`FileManager.contentsOfDirectory` runs asynchronously on `DispatchQueue.global`,
results are delivered to the UI via `DispatchQueue.main.async`.
`NSWorkspace.shared.icon(forFile:)` displays actual Finder icons.

### 5. Markdown Preview: marked.js (CDN) + WKWebView
`MarkdownPreviewView.updateNSView` regenerates the full HTML each time and loads it via `loadHTMLString`.
`baseURL` is set to the opened file's parent directory so relative image paths work.

---

## File Role Summary

| File | Role |
|---|---|
| `AppState.swift` | App-wide shared state. currentDirectory, openedFile, fileContent, tab management |
| `EditorSettings.swift` | Editor preferences (font size, theme, tab size, etc.). Persisted via UserDefaults |
| `TerminalTab.swift` | Terminal tab model. Each tab is an independent terminal session |
| `ConsoleApp.swift` | `@main` entry point. WindowGroup, Settings, menu commands |
| `ContentView.swift` | Root HSplitView + tab bar (Terminal \| FileBrowser \| Editor) |
| `TerminalPaneView.swift` | SwiftTerm NSViewRepresentable wrapper. Multi-shell (zsh/bash/fish), OSC 7, input source switching, terminal title tracking |
| `ShellIntegration/*.zsh,*.bash,*.fish` | Bundled shell integration scripts for OSC 7 CWD tracking and Shift+Enter |
| `FileBrowserView.swift` | File list SwiftUI List. FileItem model, DirectoryWatcher included |
| `EditorPaneView.swift` | Editor toolbar + FileViewMode branching (code/image/pdf) |
| `CodeEditorView.swift` | Native NSTextView code editor. SyntaxHighlighter, LineNumberRulerView included |
| `MarkdownPreviewView.swift` | WKWebView + marked.js HTML renderer |
| `ImagePreviewView.swift` | NSScrollView + NSImageView image preview |
| `PDFPreviewView.swift` | PDFKit-based PDF preview |
| `SettingsView.swift` | Editor preferences UI (Cmd+,) |
| `Console.xcodeproj` | Xcode project with folder references. SPM dependencies and build settings |

---

## Coding Conventions

### Swift
- SwiftUI views extract sub-views as `private var` computed properties outside of `body`
- State sharing in `NSViewRepresentable` always goes through `Coordinator`
- Never accept `AppState` in init — use `@EnvironmentObject` instead
- DispatchQueue rules: file I/O → `.global(qos: .userInitiated)`, UI updates → `.main.async`
- Prefer `// TODO:` or conditional logging over `print()` in view hierarchy

### Editor HTML/JS
- Always JSON-encode strings via `JSONEncoder` when passing from Swift → JS
- When adding a new language mode, update both the CDN `<script>` tag and the `extensionToMode()` map
- Always test the fallback (`activateFallback()`) path as well

### Xcode Project
- The project uses folder references — new files under `Sources/` are automatically included
- SPM packages are managed directly in Xcode (File > Add Package Dependencies)
- Do not use XcodeGen or any other 3rd-party project generation tools

---

## Common Procedures

### Adding a New Syntax Highlighting Language
1. Add CDN `<script>` tag in `editor.html`
2. Add extension → mode mapping in `extensionToMode()` function in `editor.html`

### Adding a New File Viewer Type (e.g. Image Preview)
1. Create a new `*PreviewView.swift` in `Sources/Views/Editor/` (`NSViewRepresentable`)
2. Add necessary state to `AppState.swift` (e.g. `isImageFile: Bool`)
3. Add a branch in `EditorPaneView.swift`'s `editorContent` `@ViewBuilder`
4. Verify file type handling in `FileBrowserView.swift`'s `handleSingleTap`

### Adding New Feature State to AppState
1. Add a `@Published` property to `AppState.swift`
2. Access it from related views via `@EnvironmentObject var appState: AppState`
3. Test scenario: verify state synchronizes correctly across multiple panels

---

## TODO (Priority Order)

> See `TODO.md` for the detailed list.

- [x] Tabs: multiple terminal sessions in a single window (all tabs remain active)
- [ ] File browser live refresh: directory change detection via FSEvents or `kqueue`
- [x] Image preview: display `.png/.jpg/.gif` etc. via `NSImageView`
- [x] PDF preview: render PDFs via `PDFKit` or WKWebView
- [x] Editor preferences: font size, theme, tab size, etc.
- [x] bash / fish shell OSC 7 support
- [x] Auto-switch to English input on terminal focus (`TISSelectInputSource`)
- [ ] Bundle CodeMirror CDN resources in the app (full offline support)

---

## Known Issues & Caveats

- `TerminalPaneView.updateNSView` only updates font when settings change. SwiftTerm manages its own state.
- `CodeEditorView.updateNSView` only calls JS when `lastOpenedFile != appState.openedFile`. Calling without this guard resets the cursor mid-typing.
- `LocalProcessTerminalViewDelegate.processDelegate` is a `weak` reference. Since `Coordinator` is retained by SwiftUI, this is fine. Never assign `Coordinator` to a local variable.
- `ENABLE_HARDENED_RUNTIME: NO` — development-only setting. Must be changed to YES with proper entitlements for App Store distribution.
- `NSAllowsArbitraryLoads: true` — required for CodeMirror CDN loading. Can be removed once CDN resources are bundled.
