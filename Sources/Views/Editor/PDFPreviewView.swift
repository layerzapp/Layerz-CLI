import SwiftUI
import PDFKit

struct PDFPreviewView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
        pdfView.interpolationQuality = .high
        context.coordinator.pdfView = pdfView
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        guard let fileURL = appState.openedFile else {
            nsView.document = nil
            context.coordinator.lastURL = nil
            return
        }

        // Avoid reloading the same document
        guard context.coordinator.lastURL != fileURL else { return }
        context.coordinator.lastURL = fileURL

        if let doc = PDFDocument(url: fileURL) {
            nsView.document = doc
            // Scroll to first page
            if let firstPage = doc.page(at: 0) {
                nsView.go(to: firstPage)
            }
        } else {
            nsView.document = nil
        }
    }

    class Coordinator {
        weak var pdfView: PDFView?
        var lastURL: URL?
    }
}
