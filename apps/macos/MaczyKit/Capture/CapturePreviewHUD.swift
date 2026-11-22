import Foundation
import AppKit
import CoreGraphics

/// Floating thumbnail preview HUD appearing upon capture completion.
@MainActor
public final class CapturePreviewHUD: NSPanel {
    public static let shared = CapturePreviewHUD()

    private var dismissTimer: Timer?
    private var currentFileURL: URL?

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 180),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = NSWindow.Level(Int(CGWindowLevelForKey(.maximumWindow)))
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.hidesOnDeactivate = false
    }

    /// Displays the floating preview with thumbnail and quick actions.
    public func present(image: CGImage, fileURL: URL?) {
        self.currentFileURL = fileURL
        dismissTimer?.invalidate()

        let contentView = CapturePreviewHUDContentView(
            image: image,
            fileURL: fileURL,
            onCopy: { [weak self] in
                CaptureExportManager.shared.copyToPasteboard(image)
                self?.dismiss()
            },
            onOpen: { [weak self] in
                if let url = self?.currentFileURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                self?.dismiss()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        self.contentView = contentView

        // Position at bottom-right of primary screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let width: CGFloat = 260
            let height: CGFloat = 180
            let x = screenFrame.maxX - width - 24
            let y = screenFrame.minY + 24
            self.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        }

        self.alphaValue = 0.0
        self.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            self.animator().alphaValue = 1.0
        }

        // Auto-dismiss after 6 seconds
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss()
            }
        }
    }

    public func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
}

private final class CapturePreviewHUDContentView: NSView {
    private let image: CGImage
    private let fileURL: URL?
    private let onCopy: () -> Void
    private let onOpen: () -> Void
    private let onDismiss: () -> Void

    init(
        image: CGImage,
        fileURL: URL?,
        onCopy: @escaping () -> Void,
        onOpen: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.image = image
        self.fileURL = fileURL
        self.onCopy = onCopy
        self.onOpen = onOpen
        self.onDismiss = onDismiss
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 180))
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96).cgColor
        layer?.borderWidth = 1.5
        layer?.borderColor = NSColor(MaczyDesignTokens.brandPurple).withAlphaComponent(0.4).cgColor

        // Image Thumbnail
        let imageView = NSImageView(frame: NSRect(x: 10, y: 48, width: 240, height: 122))
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 8
        imageView.layer?.masksToBounds = true
        imageView.layer?.borderWidth = 1
        imageView.layer?.borderColor = NSColor.separatorColor.cgColor
        addSubview(imageView)

        // Actions Bar
        let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyClicked))
        copyButton.bezelStyle = .rounded
        copyButton.controlSize = .small
        copyButton.frame = NSRect(x: 10, y: 10, width: 54, height: 28)
        addSubview(copyButton)

        let ocrButton = NSButton(title: "OCR", target: self, action: #selector(ocrClicked))
        ocrButton.bezelStyle = .rounded
        ocrButton.controlSize = .small
        ocrButton.frame = NSRect(x: 68, y: 10, width: 50, height: 28)
        addSubview(ocrButton)

        let openButton = NSButton(title: "Open", target: self, action: #selector(openClicked))
        openButton.bezelStyle = .rounded
        openButton.controlSize = .small
        openButton.frame = NSRect(x: 122, y: 10, width: 54, height: 28)
        addSubview(openButton)

        let dismissButton = NSButton(title: "✕", target: self, action: #selector(dismissClicked))
        dismissButton.bezelStyle = .rounded
        dismissButton.controlSize = .small
        dismissButton.frame = NSRect(x: 216, y: 10, width: 34, height: 28)
        addSubview(dismissButton)
    }

    @objc private func copyClicked() { onCopy() }
    @objc private func openClicked() { onOpen() }
    @objc private func dismissClicked() { onDismiss() }
    @objc private func ocrClicked() {
        Task {
            if let result = try? await VisionOCREngine.shared.recognizeText(in: image), !result.isEmpty {
                VisionOCREngine.shared.copyToPasteboard(result.fullText)
            }
            onDismiss()
        }
    }
}
