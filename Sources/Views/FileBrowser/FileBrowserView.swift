import SwiftUI
import AppKit

struct FileBrowserView: View {
    @EnvironmentObject var appState: AppState
    @State private var items: [FileItem] = []
    @State private var showHidden: Bool = false
    @StateObject private var watcher = DirectoryWatcher()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            fileList
        }
        .onChange(of: appState.currentDirectory) { newDir in
            watcher.watch(newDir) { loadItems() }
            loadItems()
        }
        .onChange(of: showHidden) { _ in loadItems() }
        .onAppear {
            watcher.watch(appState.currentDirectory) { loadItems() }
            loadItems()
        }
    }

    // MARK: - Subviews

    private var toolbar: some View {
        HStack(spacing: 6) {
            Button(action: goUp) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(appState.currentDirectory.path == "/")
            .help("Parent directory")

            VStack(alignment: .leading, spacing: 1) {
                Text(appState.currentDirectory.lastPathComponent.isEmpty
                     ? "/"
                     : appState.currentDirectory.lastPathComponent)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(abbreviatedPath)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Spacer()

            Button(action: { showHidden.toggle() }) {
                Image(systemName: showHidden ? "eye.slash" : "eye")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help(showHidden ? "Hide hidden files" : "Show hidden files")

            Button(action: loadItems) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var fileList: some View {
        List(items, id: \.path) { item in
            FileItemRow(item: item)
                .onTapGesture(count: 2) { handleDoubleTap(item) }
                .onTapGesture(count: 1) { handleSingleTap(item) }
                .contentShape(Rectangle())
        }
        .listStyle(.inset)
    }

    // MARK: - Helpers

    private var abbreviatedPath: String {
        let path = appState.currentDirectory.path
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private func goUp() {
        appState.currentDirectory = appState.currentDirectory.deletingLastPathComponent()
    }

    private func handleSingleTap(_ item: FileItem) {
        // Always update selection highlight
        appState.selectedFilePath = item.path

        if !item.isDirectory {
            appState.openFile(URL(fileURLWithPath: item.path))
        }
    }

    private func handleDoubleTap(_ item: FileItem) {
        if item.isDirectory {
            appState.currentDirectory = URL(fileURLWithPath: item.path)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: item.path))
        }
    }

    private func loadItems() {
        let dir = appState.currentDirectory
        let includeHidden = showHidden
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { return }

            let gitStatuses = loadGitStatus(for: dir)

            let filtered = includeHidden ? names : names.filter { !$0.hasPrefix(".") }
            let result: [FileItem] = filtered.compactMap { name in
                let path = dir.appendingPathComponent(name).path
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return nil }
                let attrs = try? fm.attributesOfItem(atPath: path)
                return FileItem(
                    name: name,
                    path: path,
                    isDirectory: isDir.boolValue,
                    size: attrs?[.size] as? Int64 ?? 0,
                    modified: attrs?[.modificationDate] as? Date,
                    gitStatus: gitStatuses[path] ?? .none
                )
            }
            .sorted {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

            DispatchQueue.main.async { self.items = result }
        }
    }
}

// MARK: - FileItemRow

struct FileItemRow: View {
    let item: FileItem
    @EnvironmentObject var appState: AppState

    private var isSelected: Bool {
        appState.selectedFilePath == item.path
    }

    private var gitStatusColor: Color {
        if isSelected { return .accentColor }
        if item.gitStatus != .none { return item.gitStatus.color }
        return .primary
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(nsImage: item.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 16, height: 16)

            Text(item.name)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(gitStatusColor)

            Spacer()

            if item.gitStatus != .none {
                Text(item.gitStatus.symbol)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(item.gitStatus.color)
            }

            if !item.isDirectory {
                Text(item.formattedSize)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
    }
}

// MARK: - DirectoryWatcher

/// Watches a directory for changes using kqueue (DispatchSource).
class DirectoryWatcher: ObservableObject {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    func watch(_ directory: URL, onChange: @escaping () -> Void) {
        stop()

        fileDescriptor = open(directory.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: .main
        )

        source?.setEventHandler { onChange() }
        source?.setCancelHandler { [fd = fileDescriptor] in close(fd) }
        source?.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }

    deinit { stop() }
}

// MARK: - FileItem Model

struct FileItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modified: Date?
    let gitStatus: GitFileStatus

    var icon: NSImage { NSWorkspace.shared.icon(forFile: path) }

    var formattedSize: String {
        let bytes = size
        if bytes < 1_024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return String(format: "%.0f KB", Double(bytes) / 1_024) }
        if bytes < 1_073_741_824 { return String(format: "%.1f MB", Double(bytes) / 1_048_576) }
        return String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }
}

// MARK: - Git Status

enum GitFileStatus: String {
    case none = ""
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case untracked = "?"
    case conflicted = "U"

    var color: Color {
        switch self {
        case .modified: return .orange
        case .added, .untracked: return .green
        case .deleted: return .red
        case .renamed: return .blue
        case .conflicted: return .purple
        case .none: return .clear
        }
    }

    var symbol: String {
        switch self {
        case .modified: return "M"
        case .added: return "A"
        case .deleted: return "D"
        case .renamed: return "R"
        case .untracked: return "U"
        case .conflicted: return "C"
        case .none: return ""
        }
    }
}

/// Runs `git status --porcelain` and returns a dictionary mapping
/// file paths (relative to repo root) to their status.
func loadGitStatus(for directory: URL) -> [String: GitFileStatus] {
    // Find git repo root
    let rootProcess = Process()
    rootProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    rootProcess.arguments = ["-C", directory.path, "rev-parse", "--show-toplevel"]
    let rootPipe = Pipe()
    rootProcess.standardOutput = rootPipe
    rootProcess.standardError = Pipe()
    try? rootProcess.run()
    rootProcess.waitUntilExit()
    guard rootProcess.terminationStatus == 0 else { return [:] }

    let rootData = rootPipe.fileHandleForReading.readDataToEndOfFile()
    let repoRoot = String(data: rootData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !repoRoot.isEmpty else { return [:] }

    // Get status
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = ["-C", repoRoot, "status", "--porcelain", "-uall"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    try? process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return [:] }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else { return [:] }

    var statuses: [String: GitFileStatus] = [:]
    let repoRootURL = URL(fileURLWithPath: repoRoot)

    for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
        guard line.count >= 4 else { continue }
        let index = line.index(line.startIndex, offsetBy: 0)
        let worktree = line.index(line.startIndex, offsetBy: 1)
        let filePath = String(line.dropFirst(3))

        let fullPath = repoRootURL.appendingPathComponent(filePath).path

        // Use worktree status primarily, fall back to index status
        let wtChar = String(line[worktree])
        let idxChar = String(line[index])

        let status: GitFileStatus
        if wtChar == "?" { status = .untracked }
        else if wtChar == "M" || idxChar == "M" { status = .modified }
        else if wtChar == "A" || idxChar == "A" { status = .added }
        else if wtChar == "D" || idxChar == "D" { status = .deleted }
        else if wtChar == "R" || idxChar == "R" { status = .renamed }
        else if wtChar == "U" || idxChar == "U" { status = .conflicted }
        else { continue }

        statuses[fullPath] = status

        // Also mark parent directories as modified
        var parent = URL(fileURLWithPath: fullPath).deletingLastPathComponent()
        while parent.path.hasPrefix(repoRoot) && parent.path != repoRoot {
            if statuses[parent.path] == nil {
                statuses[parent.path] = .modified
            }
            parent = parent.deletingLastPathComponent()
        }
    }

    return statuses
}
