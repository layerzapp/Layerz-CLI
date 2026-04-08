import SwiftUI
import PDFKit

struct PDFPreviewView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        guard let fileURL = appState.openedFile else {
            nsView.document = nil
            return
        }
        // Avoid reloading the same document
        if nsView.document?.documentURL == fileURL { return }
        nsView.document = PDFDocument(url: fileURL)
    }
}
