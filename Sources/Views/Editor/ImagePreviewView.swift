import SwiftUI
import AppKit

struct ImagePreviewView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = CenteringScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
        scrollView.drawsBackground = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = 10.0

        let imageView = NSImageView()
        imageView.imageScaling = .scaleNone
        imageView.imageAlignment = .alignCenter
        scrollView.documentView = imageView

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let fileURL = appState.openedFile else { return }

        let coord = context.coordinator
        guard coord.lastURL != fileURL else { return }
        coord.lastURL = fileURL

        guard let image = NSImage(contentsOf: fileURL),
              let imageView = nsView.documentView as? NSImageView else { return }

        imageView.image = image

        let imageSize = image.size
        imageView.frame = NSRect(origin: .zero, size: imageSize)

        // Reset zoom and center
        let viewSize = nsView.contentSize
        if imageSize.width <= viewSize.width && imageSize.height <= viewSize.height {
            // Image fits — show at 1x, centered
            nsView.magnification = 1.0
        } else {
            // Image larger than view — fit to view
            let scaleX = viewSize.width / imageSize.width
            let scaleY = viewSize.height / imageSize.height
            nsView.magnification = min(scaleX, scaleY)
        }

        // Scroll to center
        DispatchQueue.main.async {
            let docSize = imageView.frame.size
            let visibleSize = nsView.contentSize
            let x = max(0, (docSize.width * nsView.magnification - visibleSize.width) / 2)
            let y = max(0, (docSize.height * nsView.magnification - visibleSize.height) / 2)
            nsView.contentView.scroll(to: NSPoint(x: x, y: y))
        }
    }

    class Coordinator {
        weak var scrollView: NSScrollView?
        weak var imageView: NSImageView?
        var lastURL: URL?
    }
}

// MARK: - CenteringScrollView

/// An NSScrollView subclass that centers its document view when it's
/// smaller than the visible area (after magnification).
class CenteringScrollView: NSScrollView {
    override func tile() {
        super.tile()
        centerDocumentView()
    }

    override var magnification: CGFloat {
        didSet { centerDocumentView() }
    }

    private func centerDocumentView() {
        guard let docView = documentView else { return }
        let docFrame = docView.frame
        let clipBounds = contentView.bounds

        var origin = docFrame.origin

        if docFrame.width < clipBounds.width {
            origin.x = (clipBounds.width - docFrame.width) / 2
        }
        if docFrame.height < clipBounds.height {
            origin.y = (clipBounds.height - docFrame.height) / 2
        }

        if origin != docFrame.origin {
            docView.setFrameOrigin(origin)
        }
    }
}
