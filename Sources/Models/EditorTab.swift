import Foundation

/// Represents an open file in the editor pane.
class EditorTab: Identifiable, ObservableObject {
    let id = UUID()
    let url: URL
    @Published var content: String
    @Published var isDirty: Bool = false
    @Published var isMarkdownPreview: Bool = false

    var fileName: String { url.lastPathComponent }
    var fileExtension: String { url.pathExtension.lowercased() }
    var isMarkdownFile: Bool { ["md", "markdown"].contains(fileExtension) }
    var isBinary: Bool { Self.binaryExtensions.contains(fileExtension) }

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "webp", "heic", "ico", "svg"
    ]

    private static let binaryExtensions: Set<String> = {
        var s = imageExtensions
        s.insert("pdf")
        return s
    }()

    enum ViewMode {
        case code, image, pdf
    }

    var viewMode: ViewMode {
        if Self.imageExtensions.contains(fileExtension) { return .image }
        if fileExtension == "pdf" { return .pdf }
        return .code
    }

    init(url: URL, content: String = "") {
        self.url = url
        self.content = content
    }
}
