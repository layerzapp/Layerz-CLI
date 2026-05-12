![alt text](appicon.png)

# LCC

### Layerz Command Center

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

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
| **PTY Terminal** | Real shell (zsh/bash/fish auto-detected) — colors, tab completion, Vim, etc. all work |
| **Multi-Shell** | Auto-detects `$SHELL` — zsh, bash, fish all supported with bundled integration scripts |
| **Directory Sync** | OSC 7 escape sequence on `cd` instantly updates the file browser |
| **Code Editor** | Native NSTextView — syntax highlighting, line numbers, 15+ languages |
| **Markdown Preview** | `marked.js`-based rendering, Edit ↔ Preview toggle |
| **File Browser** | Finder-style, hidden file toggle, NSWorkspace icons |
| **Input Source** | Auto-switches to English input when terminal gains focus |
| **Terminal Tabs** | Multiple terminal sessions in a single window, all tabs remain active |

### Supported Languages (Editor Syntax Highlighting)

`Swift` `JavaScript/TypeScript` `Python` `Rust` `Go` `C/C++`
`Java/Kotlin` `Shell` `HTML` `CSS/SCSS` `Markdown` `YAML` `TOML` `JSON` `Ruby` `SQL`

---

## Install

### Homebrew (Recommended)

```bash
brew tap layerzapp/tap
brew install --cask lcc
```

### Build from Source

**Requirements**: macOS 13 Ventura or later, Xcode 16 or later

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
│   │   ├── AppState.swift             # Shared state (ObservableObject)
│   │   ├── EditorSettings.swift       # Editor preferences (UserDefaults)
│   │   └── TerminalTab.swift          # Terminal tab model
│   ├── Views/
│   │   ├── ContentView.swift          # HSplitView root layout + tab bar
│   │   ├── SettingsView.swift         # Editor preferences UI (Cmd+,)
│   │   ├── Terminal/
│   │   │   └── TerminalPaneView.swift # SwiftTerm wrapper + multi-shell + OSC 7
│   │   ├── FileBrowser/
│   │   │   └── FileBrowserView.swift  # Finder-style file browser
│   │   └── Editor/
│   │       ├── EditorPaneView.swift   # Editor toolbar + file view mode branching
│   │       ├── CodeEditorView.swift   # Native NSTextView code editor + syntax highlighting
│   │       ├── MarkdownPreviewView.swift # marked.js Markdown renderer
│   │       ├── ImagePreviewView.swift # Image preview (center fit, pinch-to-zoom)
│   │       ├── PDFPreviewView.swift   # PDFKit-based PDF preview
│   │       └── FileInfoView.swift     # Info panel for unsupported file types
│   └── Resources/
│       └── ShellIntegration/          # Bundled shell integration scripts
│           ├── console-zsh-integration.zsh
│           ├── console-bash-integration.bash
│           └── console-fish-integration.fish
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
  └→ shell hook (chpwd / PROMPT_COMMAND / --on-variable PWD)
       └→ OSC 7 escape sequence
            └→ SwiftTerm OSC 7 parsing
                 └→ hostCurrentDirectoryUpdate(directory:)
                      └→ AppState.currentDirectory update
                           └→ FileBrowserView auto-reload
```

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Cmd+S` | Save current file |

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI Framework | SwiftUI + AppKit |
| Terminal Emulator | [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) |
| Shell | Auto-detected `$SHELL` — zsh, bash, fish (PTY via SwiftTerm) |
| Code Editor | Native NSTextView + SyntaxHighlighter |
| Markdown Renderer | [marked.js](https://marked.js.org/) via WKWebView |
| Package Manager | Swift Package Manager |

---

## Known Limitations

- Markdown preview uses CDN (jsDelivr) for marked.js — requires internet connection

