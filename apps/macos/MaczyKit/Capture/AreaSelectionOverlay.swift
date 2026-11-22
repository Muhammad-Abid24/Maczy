import Foundation
import AppKit
import CoreGraphics

/// Purpose of the area selection session.
public enum AreaSelectionPurpose: Sendable {
    case captureArea
    case scrollingCapture
}

/// Delegate receiving user selection coordinates from the interactive overlay.
@MainActor
public protocol AreaSelectionOverlayDelegate: AnyObject {
    func areaSelectionDidSelectRect(_ rect: CGRect, on displayID: CGDirectDisplayID)
    func areaSelectionDidCancel()
}

/// Transparent overlay window allowing interactive click-and-drag area capture.
@MainActor
public final class AreaSelectionOverlayWindowController: NSWindowController {
    public weak var delegate: AreaSelectionOverlayDelegate?
    public let purpose: AreaSelectionPurpose

    fileprivate var startPoint: CGPoint = .zero
    fileprivate var currentPoint: CGPoint = .zero
    fileprivate var isDragging: Bool = false
    private let targetScreen: NSScreen

    public init(screen: NSScreen = NSScreen.main ?? NSScreen.screens[0], purpose: AreaSelectionPurpose = .captureArea) {
        self.purpose = purpose
        self.targetScreen = screen
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        super.init(window: window)
        let view = AreaSelectionCanvasView(frame: screen.frame)
        view.controller = self
        window.contentView = view
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func present() {
        guard let window = self.window else { return }
        window.makeKeyAndOrderFront(nil)
        NSCursor.crosshair.push()
    }

    public func dismiss() {
        NSCursor.pop()
        window?.orderOut(nil)
    }

    fileprivate func handleMouseDown(at point: CGPoint) {
        startPoint = point
        currentPoint = point
        isDragging = true
        window?.contentView?.needsDisplay = true
    }

    fileprivate func handleMouseDragged(to point: CGPoint) {
        currentPoint = point
        window?.contentView?.needsDisplay = true
    }

    fileprivate func handleMouseUp() {
        isDragging = false
        dismiss()

        let selectionRect = calculateNormalizedRect(p1: startPoint, p2: currentPoint)
        guard selectionRect.width > 2 && selectionRect.height > 2 else {
            delegate?.areaSelectionDidCancel()
            return
        }

        let displayID = targetScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            ?? CGMainDisplayID()
        delegate?.areaSelectionDidSelectRect(selectionRect, on: displayID)
    }

    fileprivate func handleCancel() {
        dismiss()
        delegate?.areaSelectionDidCancel()
    }

    public func calculateNormalizedRect(p1: CGPoint, p2: CGPoint) -> CGRect {
        let x = min(p1.x, p2.x)
        let y = min(p1.y, p2.y)
        let w = abs(p1.x - p2.x)
        let h = abs(p1.y - p2.y)
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

private final class AreaSelectionCanvasView: NSView {
    weak var controller: AreaSelectionOverlayWindowController?

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        controller?.handleMouseDown(at: point)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        controller?.handleMouseDragged(to: point)
    }

    override func mouseUp(with event: NSEvent) {
        controller?.handleMouseUp()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            controller?.handleCancel()
        } else {
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let controller = controller else { return }
        let bounds = self.bounds

        // Semi-transparent dim overlay
        NSColor.black.withAlphaComponent(0.28).setFill()
        bounds.fill()

        // Top instruction pill
        let isScrolling = (controller.purpose == .scrollingCapture)
        let hintText = isScrolling
            ? "Drag to select scrolling capture region • Press ESC to cancel"
            : "Drag to select screenshot area • Press ESC to cancel"
        let hintFont = NSFont.systemFont(ofSize: 13, weight: .medium)
        let hintAttrs: [NSAttributedString.Key: Any] = [
            .font: hintFont,
            .foregroundColor: NSColor.white
        ]
        let hintSize = hintText.size(withAttributes: hintAttrs)
        let topBarRect = CGRect(
            x: (bounds.width - hintSize.width - 28) / 2,
            y: bounds.height - hintSize.height - 40,
            width: hintSize.width + 28,
            height: hintSize.height + 14
        )
        let topBarPath = NSBezierPath(roundedRect: topBarRect, xRadius: 8, yRadius: 8)
        NSColor.black.withAlphaComponent(0.72).setFill()
        topBarPath.fill()
        hintText.draw(at: CGPoint(x: topBarRect.minX + 14, y: topBarRect.minY + 7), withAttributes: hintAttrs)

        guard controller.isDragging else { return }

        let rect = controller.calculateNormalizedRect(p1: controller.startPoint, p2: controller.currentPoint)

        // Punch out clear selection area
        NSColor.clear.setFill()
        rect.fill(using: .clear)

        // Purple border around selection
        let borderPath = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        borderPath.lineWidth = 1.5
        NSColor(MaczyDesignTokens.brandPurple).setStroke()
        borderPath.stroke()

        // Dimension indicator tag (e.g. "1280 × 720 • Scrolling Area")
        let dimensionText = "\(Int(rect.width)) × \(Int(rect.height))" + (isScrolling ? " • Scrolling Area" : "")
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let textSize = dimensionText.size(withAttributes: attrs)
        let tagRect = CGRect(
            x: rect.midX - (textSize.width + 12) / 2,
            y: rect.minY - (textSize.height + 8) - 6 > 10 ? rect.minY - (textSize.height + 8) - 6 : rect.maxY + 6,
            width: textSize.width + 12,
            height: textSize.height + 8
        )

        let tagPath = NSBezierPath(roundedRect: tagRect, xRadius: 6, yRadius: 6)
        NSColor.black.withAlphaComponent(0.75).setFill()
        tagPath.fill()
        dimensionText.draw(at: CGPoint(x: tagRect.minX + 6, y: tagRect.minY + 4), withAttributes: attrs)
    }
}
