# Release Notes

## v1.1.0 (2026-05-12)

### Highlights

Multi-shell support, hardened runtime, and Homebrew distribution.

### New Features

- **Multi-Shell Support (zsh/bash/fish)**
  - Auto-detects user's `$SHELL` environment variable
  - Bundled shell integration scripts for each shell (no manual setup required)
  - OSC 7 CWD tracking works across all three shells
  - URL encoding in pure shell — no python3 dependency
- **Terminal Tabs** — Multiple terminal sessions in a single window, all tabs remain active
- **Auto Input Source Switching** — Automatically switches to English input when terminal gains focus (`TISSelectInputSource`)
- **Image Preview** — Display `.png/.jpg/.gif` etc. with center fit and pinch-to-zoom
- **PDF Preview** — Render PDFs via PDFKit
- **File Info Panel** — Info view for unsupported file types (file size, dates, kind)
- **Editor Preferences** — Font size, tab size, and other settings (Cmd+,)
- **Native Code Editor** — Replaced CodeMirror (CDN) with native NSTextView + SyntaxHighlighter (15+ languages)
- **Terminal Focus on Launch** — Terminal pane automatically gains focus when the app starts

### Improvements

- Hardened Runtime enabled (`ENABLE_HARDENED_RUNTIME = YES`)
- Homebrew Cask distribution (`brew install --cask lcc`)
- App icon added
- Migrated from XcodeGen to native Xcode project with folder references

### Supported Languages (Syntax Highlighting)

`Swift` `JavaScript/TypeScript` `Python` `Rust` `Go` `C/C++`
`Java/Kotlin` `Shell` `HTML` `CSS/SCSS` `Markdown` `YAML` `TOML` `JSON` `Ruby` `SQL`

---

## v1.0.0

Initial release — basic terminal + file browser + code editor.
