# Console

macOS 네이티브 터미널 + 파일 브라우저 통합 앱.
PTY 기반 실제 셸을 내장하고, `cd` 한 번으로 오른쪽 파일 브라우저가 즉시 동기화된다.

---

## 스크린샷

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

## 핵심 기능

| 기능 | 설명 |
|---|---|
| **PTY 터미널** | 실제 `/bin/zsh` 셸 — 색상, 탭 완성, Vim 등 모두 동작 |
| **디렉토리 동기화** | `cd` 시 OSC 7 이스케이프 시퀀스로 파일 브라우저 즉시 갱신 |
| **코드 에디터** | CodeMirror 5 — 신택스 하이라이팅, 라인 번호, 15개 이상 언어 |
| **Markdown 프리뷰** | `marked.js` 기반 렌더링, Edit ↔ Preview 토글 |
| **파일 브라우저** | Finder 스타일, 숨김 파일 토글, NSWorkspace 아이콘 |
| **오프라인 폴백** | CDN 불가 시 에디터가 plain textarea로 자동 전환 |

### 지원 언어 (에디터 신택스 하이라이팅)

`Swift` `JavaScript/TypeScript` `Python` `Rust` `Go` `C/C++`
`Java/Kotlin` `Shell` `HTML` `CSS/SCSS` `Markdown` `YAML` `TOML` `JSON` `Ruby` `SQL`

---

## 빌드 & 실행

### 요구사항

- macOS 13 Ventura 이상
- Xcode 15 이상
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### 빠른 시작

```bash
# 1. 저장소 클론
git clone <repo-url>
cd console

# 2. Xcode 프로젝트 생성
xcodegen generate

# 3. Xcode로 열어서 빌드
open Console.xcodeproj
```

또는 커맨드라인 빌드:

```bash
xcodebuild -project Console.xcodeproj -scheme Console -configuration Debug build
```

> **참고** — 첫 빌드 시 Xcode가 SwiftTerm SPM 패키지를 자동 다운로드합니다.
> 인터넷 연결이 필요합니다.

---

## 프로젝트 구조

```
console/
├── project.yml                        # XcodeGen 설정 (소스 오브 트루스)
├── Info.plist                         # 앱 메타데이터
├── Sources/
│   ├── App/
│   │   └── ConsoleApp.swift           # @main, Scene, 글로벌 단축키
│   ├── Models/
│   │   └── AppState.swift             # 공유 상태 (ObservableObject)
│   ├── Views/
│   │   ├── ContentView.swift          # HSplitView 루트 레이아웃
│   │   ├── Terminal/
│   │   │   └── TerminalPaneView.swift # SwiftTerm 래퍼 + OSC 7 CWD 추적
│   │   ├── FileBrowser/
│   │   │   └── FileBrowserView.swift  # Finder 스타일 파일 브라우저
│   │   └── Editor/
│   │       ├── EditorPaneView.swift   # 에디터 툴바 + Save/Close
│   │       ├── CodeEditorView.swift   # WKWebView + CodeMirror 5
│   │       └── MarkdownPreviewView.swift # marked.js 마크다운 렌더러
│   └── Resources/
│       └── editor.html                # CodeMirror 5 번들 (CDN)
└── Console.xcodeproj/                 # 생성된 Xcode 프로젝트 (xcodegen)
```

> `Console.xcodeproj`는 `xcodegen generate`로 재생성 가능합니다.
> 수동으로 수정하지 말고 `project.yml`만 수정하세요.

---

## 아키텍처

### 상태 흐름

```
AppState (ObservableObject)
 ├── currentDirectory: URL     ← TerminalPaneView가 업데이트 (OSC 7)
 ├── openedFile: URL?          ← FileBrowserView가 업데이트 (파일 클릭)
 ├── fileContent: String       ← CodeEditorView ↔ Swift 양방향 동기화
 ├── isDirty: Bool
 └── isMarkdownPreview: Bool
```

### 터미널 CWD 동기화 흐름

```
사용자: $ cd ~/Desktop
  └→ zsh chpwd hook
       └→ printf '\033]7;file://localhost/Users/.../Desktop\033\\'
            └→ SwiftTerm OSC 7 파싱
                 └→ hostCurrentDirectoryUpdate(directory:)
                      └→ AppState.currentDirectory 업데이트
                           └→ FileBrowserView 자동 리로드
```

### 에디터 ↔ Swift 통신

```
Swift → JS : webView.evaluateJavaScript("setContent(json, ext)")
JS → Swift : window.webkit.messageHandlers.contentChanged.postMessage(text)
             window.webkit.messageHandlers.saveRequested.postMessage('')
```

---

## 단축키

| 단축키 | 동작 |
|---|---|
| `Cmd+S` | 현재 파일 저장 |
| `Cmd+S` (에디터 포커스) | CodeMirror 내장 저장 트리거 |

---

## 기술 스택

| 레이어 | 기술 |
|---|---|
| UI 프레임워크 | SwiftUI + AppKit |
| 터미널 에뮬레이터 | [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) |
| 셸 | `/bin/zsh` (PTY via SwiftTerm) |
| 코드 에디터 | [CodeMirror 5](https://codemirror.net/5/) via WKWebView |
| Markdown 렌더러 | [marked.js](https://marked.js.org/) via WKWebView |
| 프로젝트 생성 | [XcodeGen](https://github.com/yonaskolb/XcodeGen) |
| 패키지 매니저 | Swift Package Manager |

---

## 알려진 제한사항

- 코드 에디터는 CDN(jsDelivr) 사용 → 오프라인 시 plain textarea로 폴백
- bash / fish 셸은 OSC 7 자동 설정 미지원 (zsh only)
- 앱 샌드박스 비활성화 상태 (배포 시 entitlements 추가 필요)

---

## 향후 계획

`TODO.md` 참조.
