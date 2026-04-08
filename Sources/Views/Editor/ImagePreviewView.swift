import SwiftUI
import AppKit

struct ImagePreviewView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
        scrollView.drawsBackground = true

        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        scrollView.documentView = imageView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let imageView = nsView.documentView as? NSImageView,
              let fileURL = appState.openedFile else { return }

        guard let image = NSImage(contentsOf: fileURL) else { return }
        imageView.image = image

        // Size the document view to the image's natural size so scrolling works
        let imageSize = image.size
        imageView.frame = NSRect(origin: .zero, size: imageSize)
    }
}
