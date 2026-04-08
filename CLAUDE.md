# Console — CLAUDE.md

macOS 네이티브 터미널 + 파일 브라우저 앱.
이 파일은 AI 에이전트가 코드베이스를 빠르게 파악하고 일관된 방식으로 기여하기 위한 가이드다.

---

## 프로젝트 핵심 컨텍스트

- **플랫폼**: macOS 13+ only (AppKit + SwiftUI 혼용)
- **언어**: Swift 5 (Xcode Swift 6.2 컴파일러, `SWIFT_STRICT_CONCURRENCY: minimal`)
- **빌드 시스템**: XcodeGen (`project.yml`) → `Console.xcodeproj`
- **패키지**: SwiftTerm (SPM), CodeMirror 5 (CDN), marked.js (CDN)

> `Console.xcodeproj`는 생성 산출물이다. **절대로 직접 수정하지 말고** `project.yml`을 수정한 뒤 `xcodegen generate`를 실행한다.

---

## 아키텍처 결정사항 (ADR)

### 1. 상태 관리: AppState (단일 ObservableObject)
`AppState`는 앱의 유일한 진실 원천이다. 모든 패널은 `@EnvironmentObject`로 이를 공유한다.
직접 패널 간 통신은 없다 — 반드시 AppState를 경유한다.

```
TerminalPaneView ──writes──▶ AppState.currentDirectory ──reads──▶ FileBrowserView
FileBrowserView  ──writes──▶ AppState.openedFile       ──reads──▶ EditorPaneView
CodeEditorView   ──writes──▶ AppState.fileContent      ──reads──▶ MarkdownPreviewView
```

### 2. 터미널: SwiftTerm + ZDOTDIR 기반 OSC 7
CWD 추적은 **폴링(proc_pidinfo) 대신 OSC 7** 이스케이프 시퀀스를 사용한다.
`TerminalPaneView.Coordinator.makeZdotdir()`이 임시 ZDOTDIR을 생성하고,
`.zshrc`에서 `chpwd` 훅으로 `printf '\033]7;file://...\033\\'`를 emit한다.
SwiftTerm이 이를 파싱해 `hostCurrentDirectoryUpdate(source:directory:)`를 호출한다.

```
zsh chpwd → OSC 7 이스케이프 → SwiftTerm 파싱 → Coordinator 콜백 → AppState 업데이트
```

### 3. 에디터: NSTextView + SyntaxHighlighter (네이티브)
에디터는 NSTextView 기반 네이티브 구현이다. 외부 의존성(CDN, WKWebView) 없음.
- `SyntaxHighlighter`: 정규식 기반 토큰화, 언어별 패턴 (Swift, Python, JS, Go, Rust 등 15개 언어)
- `LineNumberRulerView`: NSRulerView 서브클래스로 줄 번호 표시
- `EditorSettings`: 폰트 크기, 줄바꿈, 줄 번호 표시 등 사용자 설정 (UserDefaults 영속화)
- 변경 감지: NSTextViewDelegate.textDidChange → 디바운싱 → 하이라이팅 재적용

### 4. 파일 브라우저: FileManager + NSWorkspace 아이콘
`FileManager.contentsOfDirectory`는 `DispatchQueue.global`에서 비동기 실행,
결과는 `DispatchQueue.main.async`로 UI 업데이트한다.
`NSWorkspace.shared.icon(forFile:)`으로 실제 Finder 아이콘을 표시한다.

### 5. Markdown 프리뷰: marked.js (CDN) + WKWebView
`MarkdownPreviewView.updateNSView`에서 매번 전체 HTML을 재생성해 `loadHTMLString`으로 로드한다.
`baseURL`을 열린 파일의 부모 디렉토리로 설정해 상대 경로 이미지가 동작한다.

---

## 파일별 역할 요약

| 파일 | 역할 |
|---|---|
| `AppState.swift` | 전체 앱 공유 상태. currentDirectory, openedFile, fileContent, 탭 관리 |
| `EditorSettings.swift` | 에디터 환경 설정 (폰트 크기, 테마, 탭 크기 등). UserDefaults 영속화 |
| `TerminalTab.swift` | 터미널 탭 모델. 각 탭은 독립 터미널 세션 |
| `ConsoleApp.swift` | `@main` 진입점. WindowGroup, Settings, 메뉴 커맨드 |
| `ContentView.swift` | 루트 HSplitView + 탭 바 (Terminal \| FileBrowser \| Editor) |
| `TerminalPaneView.swift` | SwiftTerm NSViewRepresentable 래퍼. ZDOTDIR, OSC 7, 입력소스 전환 |
| `FileBrowserView.swift` | 파일 목록 SwiftUI List. FileItem 모델, DirectoryWatcher 포함 |
| `EditorPaneView.swift` | 에디터 툴바 + FileViewMode 분기 (code/image/pdf) |
| `CodeEditorView.swift` | NSTextView 기반 네이티브 코드 에디터. SyntaxHighlighter, LineNumberRulerView 포함 |
| `MarkdownPreviewView.swift` | WKWebView + marked.js HTML 렌더러 |
| `ImagePreviewView.swift` | NSScrollView + NSImageView 이미지 미리보기 |
| `PDFPreviewView.swift` | PDFKit 기반 PDF 미리보기 |
| `SettingsView.swift` | 에디터 환경 설정 UI (Cmd+,) |
| `project.yml` | XcodeGen 설정. 패키지 의존성 및 빌드 설정 |

---

## 코딩 컨벤션

### Swift
- SwiftUI 뷰는 `body` 외 서브뷰를 `private var` computed property로 분리한다
- `NSViewRepresentable`의 상태 공유는 항상 `Coordinator`를 통한다
- `AppState`를 직접 init에서 받지 말고 `@EnvironmentObject`를 사용한다
- DispatchQueue 규칙: 파일 I/O → `.global(qos: .userInitiated)`, UI 업데이트 → `.main.async`
- 뷰 계층에서 `print()`보다 `// TODO:` 또는 조건부 로깅을 사용한다

### 에디터 HTML/JS
- Swift → JS 문자열 전달 시 반드시 `JSONEncoder`를 통해 JSON 인코딩한다
- 새 언어 모드 추가 시 CDN `<script>` 태그와 `extensionToMode()` 맵 두 곳 모두 수정한다
- 폴백(`activateFallback()`) 경로도 항상 함께 테스트한다

### XcodeGen
- 새 소스 파일 추가는 그냥 `Sources/` 하위에 만들면 자동으로 포함된다
- 새 리소스(이미지, HTML 등)는 `project.yml`의 `resources:` 섹션에 명시적으로 추가한다
- SPM 패키지 추가: `project.yml`의 `packages:` 와 `dependencies:` 두 곳 모두 수정한다

---

## 흔한 작업 절차

### 새 언어 신택스 하이라이팅 추가
1. `editor.html`에 CDN `<script>` 태그 추가
2. `editor.html`의 `extensionToMode()` 함수에 확장자 → 모드 매핑 추가

### 새 파일 뷰어 타입 추가 (e.g. 이미지 프리뷰)
1. `Sources/Views/Editor/`에 새 `*PreviewView.swift` 생성 (`NSViewRepresentable`)
2. `AppState.swift`에 필요한 상태 추가 (e.g. `isImageFile: Bool`)
3. `EditorPaneView.swift`의 `editorContent` `@ViewBuilder`에 분기 추가
4. `FileBrowserView.swift`의 `handleSingleTap`에서 해당 파일 타입 처리 확인

### AppState에 새 기능 상태 추가
1. `AppState.swift`에 `@Published` 프로퍼티 추가
2. 관련 뷰에서 `@EnvironmentObject var appState: AppState`로 접근
3. 테스트 시나리오: 여러 패널 간 상태가 올바르게 동기화되는지 확인

### XcodeGen 프로젝트 재생성
```bash
xcodegen generate
```
반드시 Xcode에서 프로젝트를 닫은 뒤 실행하거나, 실행 후 Xcode에서 "File > Packages > Resolve Package Versions"를 수행한다.

---

## TODO (우선순위 순)

> 상세 목록은 `TODO.md` 참조.

- [ ] 탭 기능: 하나의 윈도우에서 여러 터미널 세션 동시 운용 (모든 탭 활성 유지)
- [ ] 파일 브라우저 실시간 갱신: FSEvents 또는 `kqueue`로 디렉토리 변경 감지
- [ ] 이미지 프리뷰: `NSImageView`로 `.png/.jpg/.gif` 등 표시
- [ ] PDF 프리뷰: `PDFKit` 또는 WKWebView로 PDF 렌더링
- [ ] 에디터 환경 설정: 폰트 크기, 테마, 탭 크기 등 사용자 설정
- [ ] bash / fish 셸 OSC 7 지원
- [ ] 터미널 포커스 시 자동 영어 입력 전환 (`TISSelectInputSource`)
- [ ] CodeMirror CDN 리소스 앱 번들 내 포함 (오프라인 완전 지원)

---

## 알려진 이슈 & 주의사항

- `TerminalPaneView.updateNSView`는 의도적으로 비어 있다. SwiftTerm이 자체 상태를 관리한다.
- `CodeEditorView.updateNSView`는 `lastOpenedFile != appState.openedFile` 조건으로만 JS를 호출한다. 이 조건 없이 호출하면 타이핑 중 커서가 초기화된다.
- `LocalProcessTerminalViewDelegate.processDelegate`는 `weak` 참조다. `Coordinator`가 SwiftUI에 의해 retain되므로 문제없다. 절대로 `Coordinator`를 로컬 변수에 할당하지 말 것.
- `ENABLE_HARDENED_RUNTIME: NO` — 개발용 설정이다. App Store 배포 시 YES로 변경하고 entitlements를 추가해야 한다.
- `NSAllowsArbitraryLoads: true` — CodeMirror CDN 로드를 위한 설정이다. CDN을 번들로 포함하면 제거 가능하다.
