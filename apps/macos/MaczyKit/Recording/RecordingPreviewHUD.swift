import Foundation
import AppKit
import CoreGraphics
import AVFoundation

/// Floating thumbnail preview HUD appearing upon video screen recording completion.
@MainActor
public final class RecordingPreviewHUD: NSPanel {
    public static let shared = RecordingPreviewHUD()

    private var dismissTimer: Timer?
    private var currentFileURL: URL?

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 210),
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

    /// Generates a representative video frame thumbnail from an MP4 file.
    public static func generateVideoThumbnail(for url: URL) -> CGImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 320)
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
            return cgImage
        }
        return nil
    }

    /// Displays the floating video preview with thumbnail, metadata, and quick action buttons.
    public func present(videoURL: URL) {
        self.currentFileURL = videoURL
        dismissTimer?.invalidate()

        let thumbnail = Self.generateVideoThumbnail(for: videoURL)

        let contentView = RecordingPreviewHUDContentView(
            videoURL: videoURL,
            thumbnail: thumbnail,
            onPlay: { [weak self] in
                NSWorkspace.shared.open(videoURL)
                self?.dismiss()
            },
            onReveal: { [weak self] in
                NSWorkspace.shared.activateFileViewerSelecting([videoURL])
                self?.dismiss()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        self.contentView = contentView

        // Position at bottom-right of primary screen above dock
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let width: CGFloat = 280
            let height: CGFloat = 210
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

        // Auto-dismiss after 8 seconds
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
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

private final class RecordingPreviewHUDContentView: NSView {
    private let videoURL: URL
    private let thumbnail: CGImage?
    private let onPlay: () -> Void
    private let onReveal: () -> Void
    private let onDismiss: () -> Void

    init(
        videoURL: URL,
        thumbnail: CGImage?,
        onPlay: @escaping () -> Void,
        onReveal: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.videoURL = videoURL
        self.thumbnail = thumbnail
        self.onPlay = onPlay
        self.onReveal = onReveal
        self.onDismiss = onDismiss
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 210))
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92).cgColor
        layer?.borderColor = NSColor(MaczyDesignTokens.brandPurple).withAlphaComponent(0.35).cgColor
        layer?.borderWidth = 1.0

        // Visual effect background
        let visualEffect = NSVisualEffectView(frame: bounds)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .withinWindow
        visualEffect.state = .active
        visualEffect.autoresizingMask = [.width, .height]
        addSubview(visualEffect)

        // Close button
        let closeBtn = NSButton(frame: NSRect(x: bounds.width - 26, y: bounds.height - 26, width: 20, height: 20))
        closeBtn.bezelStyle = .regularSquare
        closeBtn.isBordered = false
        closeBtn.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Dismiss")
        closeBtn.contentTintColor = .secondaryLabelColor
        closeBtn.target = self
        closeBtn.action = #selector(didClickDismiss)
        addSubview(closeBtn)

        // Header Title
        let titleLabel = NSTextField(labelWithString: "Screen Recording Saved")
        titleLabel.frame = NSRect(x: 14, y: bounds.height - 28, width: bounds.width - 48, height: 18)
        titleLabel.font = .systemFont(ofSize: 12, weight: .bold)
        titleLabel.textColor = .labelColor
        addSubview(titleLabel)

        // Thumbnail / Video View
        let thumbHeight: CGFloat = 100
        let thumbRect = NSRect(x: 14, y: bounds.height - 34 - thumbHeight, width: bounds.width - 28, height: thumbHeight)
        let thumbView = NSImageView(frame: thumbRect)
        thumbView.wantsLayer = true
        thumbView.layer?.cornerRadius = 8
        thumbView.layer?.masksToBounds = true
        thumbView.layer?.backgroundColor = NSColor.black.cgColor
        thumbView.imageScaling = .scaleProportionallyUpOrDown

        if let cgThumb = thumbnail {
            thumbView.image = NSImage(cgImage: cgThumb, size: NSSize(width: thumbRect.width, height: thumbRect.height))
        } else {
            thumbView.image = NSImage(systemSymbolName: "film.fill", accessibilityDescription: "Video")
            thumbView.contentTintColor = .white.withAlphaComponent(0.7)
        }
        addSubview(thumbView)

        // Play badge icon overlay in center of thumbnail
        let playOverlay = NSImageView(frame: NSRect(x: thumbRect.midX - 16, y: thumbRect.midY - 16, width: 32, height: 32))
        playOverlay.image = NSImage(systemSymbolName: "play.circle.fill", accessibilityDescription: "Play")
        playOverlay.contentTintColor = .white.withAlphaComponent(0.9)
        addSubview(playOverlay)

        // Filename label
        let filenameLabel = NSTextField(labelWithString: videoURL.lastPathComponent)
        filenameLabel.frame = NSRect(x: 14, y: 44, width: bounds.width - 28, height: 16)
        filenameLabel.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        filenameLabel.textColor = .secondaryLabelColor
        filenameLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(filenameLabel)

        // Action Buttons Row
        let playBtn = NSButton(title: "Play", target: self, action: #selector(didClickPlay))
        playBtn.frame = NSRect(x: 14, y: 12, width: 75, height: 26)
        playBtn.bezelStyle = .rounded
        playBtn.contentTintColor = NSColor(MaczyDesignTokens.brandPurple)
        addSubview(playBtn)

        let revealBtn = NSButton(title: "Reveal in Finder", target: self, action: #selector(didClickReveal))
        revealBtn.frame = NSRect(x: 95, y: 12, width: 125, height: 26)
        revealBtn.bezelStyle = .rounded
        addSubview(revealBtn)
    }

    @objc private func didClickPlay() {
        onPlay()
    }

    @objc private func didClickReveal() {
        onReveal()
    }

    @objc private func didClickDismiss() {
        onDismiss()
    }
}
