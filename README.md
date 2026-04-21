# Console

A macOS native terminal + file browser integrated app.
Embeds a real PTY-based shell — a single `cd` instantly syncs the file browser on the right.

---

## Screenshot

```
┌──────────────────────┬───────────────┬──────────────────────────┐
│   Terminal (PTY)     │  File Browser │    Code Editor           │
│                      │               │                          │
│  $ cd ~/Projects     │  📁 Projects  │  1  import SwiftUI       │
│  $ ls -la            │  📁 Console   │  2                       │
│  total 48            │  📄 README.md │  3  struct ContentView:  │
│  ...                 │  📄 app.swift │  ...                     │
│  $                   │               │  [Edit] [Preview]        │
└──────────────────────┴───────────────┴──────────────────────────┘
```

---

## Key Features

| Feature | Description |
|---|---|
| **PTY Terminal** | Real `/bin/zsh` shell — colors, tab completion, Vim, etc. all work |
| **Directory Sync** | OSC 7 escape sequence on `cd` instantly updates the file browser |
| **Code Editor** | Native NSTextView — syntax highlighting, line numbers, 15+ languages |
| **Markdown Preview** | `marked.js`-based rendering, Edit ↔ Preview toggle |
| **File Browser** | Finder-style, hidden file toggle, NSWorkspace icons |
| **Offline Fallback** | Editor automatically falls back to plain textarea when CDN is unavailable |

### Supported Languages (Editor Syntax Highlighting)

`Swift` `JavaScript/TypeScript` `Python` `Rust` `Go` `C/C++`
`Java/Kotlin` `Shell` `HTML` `CSS/SCSS` `Markdown` `YAML` `TOML` `JSON` `Ruby` `SQL`

---

## Build & Run

### Requirements

- macOS 13 Ventura or later
- Xcode 16 or later

### Quick Start

```bash
# 1. Clone the repository
git clone <repo-url>
cd console

# 2. Open in Xcode and build
open Console.xcodeproj
```

Or build from the command line:

```bash
xcodebuild -project Console.xcodeproj -scheme Console -configuration Debug build
```

> **Note** — On first build, Xcode will automatically download the SwiftTerm SPM package.
> An internet connection is required.

---

## Project Structure

```
console/
├── Console.xcodeproj/                 # Xcode project (folder references)
├── Info.plist                         # App metadata
├── Sources/
│   ├── App/
│   │   └── ConsoleApp.swift           # @main, Scene, global shortcuts
│   ├── Models/
│   │   └── AppState.swift             # Shared state (ObservableObject)
│   ├── Views/
│   │   ├── ContentView.swift          # HSplitView root layout
│   │   ├── Terminal/
│   │   │   └── TerminalPaneView.swift # SwiftTerm wrapper + OSC 7 CWD tracking
│   │   ├── FileBrowser/
│   │   │   └── FileBrowserView.swift  # Finder-style file browser
│   │   └── Editor/
│   │       ├── EditorPaneView.swift   # Editor toolbar + Save/Close
│   │       ├── CodeEditorView.swift   # Native NSTextView code editor
│   │       └── MarkdownPreviewView.swift # marked.js Markdown renderer
│   └── Resources/
│       └── editor.html                # CodeMirror 5 bundle (CDN)
```

> The project uses Xcode's folder references (file system synchronized groups).
> New files added to `Sources/` are automatically included in the build.

---

## Architecture

### State Flow

```
AppState (ObservableObject)
 ├── currentDirectory: URL     ← Updated by TerminalPaneView (OSC 7)
 ├── openedFile: URL?          ← Updated by FileBrowserView (file click)
 ├── fileContent: String       ← Bidirectional sync: CodeEditorView ↔ Swift
 ├── isDirty: Bool
 └── isMarkdownPreview: Bool
```

### Terminal CWD Sync Flow

```
User: $ cd ~/Desktop
  └→ zsh chpwd hook
       └→ printf '\033]7;file://localhost/Users/.../Desktop\033\\'
            └→ SwiftTerm OSC 7 parsing
                 └→ hostCurrentDirectoryUpdate(directory:)
                      └→ AppState.currentDirectory update
                           └→ FileBrowserView auto-reload
```

### Editor ↔ Swift Communication

```
Swift → JS : webView.evaluateJavaScript("setContent(json, ext)")
JS → Swift : window.webkit.messageHandlers.contentChanged.postMessage(text)
             window.webkit.messageHandlers.saveRequested.postMessage('')
```

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Cmd+S` | Save current file |
| `Cmd+S` (editor focused) | Triggers CodeMirror built-in save |

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI Framework | SwiftUI + AppKit |
| Terminal Emulator | [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) |
| Shell | `/bin/zsh` (PTY via SwiftTerm) |
| Code Editor | Native NSTextView + SyntaxHighlighter |
| Markdown Renderer | [marked.js](https://marked.js.org/) via WKWebView |
| Package Manager | Swift Package Manager |

---

## Known Limitations

- Markdown preview uses CDN (jsDelivr) — falls back to plain textarea when offline
- bash / fish shells do not support automatic OSC 7 setup (zsh only)
- App sandbox is disabled (entitlements must be added for distribution)

---

## Future Plans

See `TODO.md`.
