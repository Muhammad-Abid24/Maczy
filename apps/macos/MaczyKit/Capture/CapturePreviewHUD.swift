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
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 160),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = .floating
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
            let x = screenFrame.maxX - 240
            let y = screenFrame.minY + 24
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.orderFront(nil)

        // Auto-dismiss after 5 seconds
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss()
            }
        }
    }

    public func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        self.orderOut(nil)
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
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 160))
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        // Image Thumbnail
        let imageView = NSImageView(frame: NSRect(x: 10, y: 46, width: 200, height: 104))
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 6
        imageView.layer?.masksToBounds = true
        addSubview(imageView)

        // Actions Bar
        let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyClicked))
        copyButton.bezelStyle = .rounded
        copyButton.controlSize = .small
        copyButton.frame = NSRect(x: 10, y: 10, width: 60, height: 26)
        addSubview(copyButton)

        let openButton = NSButton(title: "Open", target: self, action: #selector(openClicked))
        openButton.bezelStyle = .rounded
        openButton.controlSize = .small
        openButton.frame = NSRect(x: 75, y: 10, width: 60, height: 26)
        addSubview(openButton)

        let dismissButton = NSButton(title: "✕", target: self, action: #selector(dismissClicked))
        dismissButton.bezelStyle = .rounded
        dismissButton.controlSize = .small
        dismissButton.frame = NSRect(x: 175, y: 10, width: 35, height: 26)
        addSubview(dismissButton)
    }

    @objc private func copyClicked() { onCopy() }
    @objc private func openClicked() { onOpen() }
    @objc private func dismissClicked() { onDismiss() }
}
