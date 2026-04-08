import SwiftUI
import AppKit

struct FileInfoView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if let url = appState.openedFile {
            VStack(spacing: 16) {
                Spacer()

                // File icon
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 64, height: 64)

                // File name
                Text(url.lastPathComponent)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                // File details
                VStack(spacing: 6) {
                    infoRow("Kind", value: fileKind(url))
                    infoRow("Size", value: fileSize(url))
                    infoRow("Location", value: url.deletingLastPathComponent().path)
                    if let modified = fileModified(url) {
                        infoRow("Modified", value: modified)
                    }
                }
                .padding(.horizontal, 40)

                // Open with default app button
                Button(action: { NSWorkspace.shared.open(url) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.square")
                        Text("Open with Default App")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.system(size: 11))
                .lineLimit(2)
                .truncationMode(.middle)
            Spacer()
        }
    }

    private func fileKind(_ url: URL) -> String {
        let ext = url.pathExtension.uppercased()
        return ext.isEmpty ? "File" : "\(ext) File"
    }

    private func fileSize(_ url: URL) -> String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let bytes = attrs?[.size] as? Int64 ?? 0
        if bytes < 1_024 { return "\(bytes) bytes" }
        if bytes < 1_048_576 { return String(format: "%.1f KB", Double(bytes) / 1_024) }
        if bytes < 1_073_741_824 { return String(format: "%.1f MB", Double(bytes) / 1_048_576) }
        return String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }

    private func fileModified(_ url: URL) -> String? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        guard let date = attrs?[.modificationDate] as? Date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
