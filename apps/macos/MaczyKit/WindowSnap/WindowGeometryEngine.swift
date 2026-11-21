import Foundation
import CoreGraphics

/// Pure mathematical calculation engine for window snapping presets and coordinate transforms.
public struct WindowGeometryEngine: Sendable {
    
    /// Calculates the target window rectangle in AppKit screen coordinates (origin at bottom-left).
    /// - Parameters:
    ///   - preset: The desired snap preset layout.
    ///   - screenVisibleFrame: The screen's visible frame (excluding Dock and MenuBar).
    ///   - margin: Optional window margin/gap in points (default: 0).
    /// - Returns: Computed window rectangle aligned to whole integer points.
    public static func calculateTargetRect(
        for preset: WindowSnapPreset,
        in screenVisibleFrame: CGRect,
        margin: CGFloat = 0
    ) -> CGRect {
        let m = max(0, margin)
        let vx = screenVisibleFrame.origin.x
        let vy = screenVisibleFrame.origin.y
        let vw = screenVisibleFrame.width
        let vh = screenVisibleFrame.height

        let halfW = m > 0 ? (vw - 3 * m) / 2 : vw / 2
        let halfH = m > 0 ? (vh - 3 * m) / 2 : vh / 2
        let thirdW = m > 0 ? (vw - 4 * m) / 3 : vw / 3

        var rect: CGRect

        switch preset {
        case .leftHalf:
            rect = CGRect(
                x: vx + m,
                y: vy + m,
                width: halfW,
                height: m > 0 ? vh - 2 * m : vh
            )

        case .rightHalf:
            rect = CGRect(
                x: m > 0 ? vx + halfW + 2 * m : vx + halfW,
                y: vy + m,
                width: halfW,
                height: m > 0 ? vh - 2 * m : vh
            )

        case .topHalf:
            rect = CGRect(
                x: vx + m,
                y: m > 0 ? vy + halfH + 2 * m : vy + halfH,
                width: m > 0 ? vw - 2 * m : vw,
                height: halfH
            )

        case .bottomHalf:
            rect = CGRect(
                x: vx + m,
                y: vy + m,
                width: m > 0 ? vw - 2 * m : vw,
                height: halfH
            )

        case .maximize:
            rect = CGRect(
                x: vx + m,
                y: vy + m,
                width: max(50, vw - 2 * m),
                height: max(50, vh - 2 * m)
            )

        case .center:
            let w = (vw * 0.70).rounded()
            let h = (vh * 0.80).rounded()
            rect = CGRect(
                x: vx + (vw - w) / 2,
                y: vy + (vh - h) / 2,
                width: w,
                height: h
            )

        case .leftThird:
            rect = CGRect(
                x: vx + m,
                y: vy + m,
                width: thirdW,
                height: m > 0 ? vh - 2 * m : vh
            )

        case .centerThird:
            rect = CGRect(
                x: m > 0 ? vx + thirdW + 2 * m : vx + thirdW,
                y: vy + m,
                width: thirdW,
                height: m > 0 ? vh - 2 * m : vh
            )

        case .rightThird:
            rect = CGRect(
                x: m > 0 ? vx + 2 * thirdW + 3 * m : vx + 2 * thirdW,
                y: vy + m,
                width: thirdW,
                height: m > 0 ? vh - 2 * m : vh
            )

        case .leftTwoThirds:
            let twoThirdsW = m > 0 ? (2 * thirdW + m) : (2 * thirdW)
            rect = CGRect(
                x: vx + m,
                y: vy + m,
                width: twoThirdsW,
                height: m > 0 ? vh - 2 * m : vh
            )

        case .rightTwoThirds:
            let twoThirdsW = m > 0 ? (2 * thirdW + m) : (2 * thirdW)
            rect = CGRect(
                x: m > 0 ? vx + thirdW + 2 * m : vx + thirdW,
                y: vy + m,
                width: twoThirdsW,
                height: m > 0 ? vh - 2 * m : vh
            )

        case .topLeftQuarter:
            rect = CGRect(
                x: vx + m,
                y: m > 0 ? vy + halfH + 2 * m : vy + halfH,
                width: halfW,
                height: halfH
            )

        case .topRightQuarter:
            rect = CGRect(
                x: m > 0 ? vx + halfW + 2 * m : vx + halfW,
                y: m > 0 ? vy + halfH + 2 * m : vy + halfH,
                width: halfW,
                height: halfH
            )

        case .bottomLeftQuarter:
            rect = CGRect(
                x: vx + m,
                y: vy + m,
                width: halfW,
                height: halfH
            )

        case .bottomRightQuarter:
            rect = CGRect(
                x: m > 0 ? vx + halfW + 2 * m : vx + halfW,
                y: vy + m,
                width: halfW,
                height: halfH
            )
        }

        // Align coordinates to crisp points
        return CGRect(
            x: rect.origin.x.rounded(),
            y: rect.origin.y.rounded(),
            width: rect.width.rounded(),
            height: rect.height.rounded()
        )
    }

    /// Converts an AppKit coordinate rect (origin at bottom-left of primary display)
    /// to Accessibility AX UI Element coordinate rect (origin at top-left of primary display).
    /// - Parameters:
    ///   - appKitRect: The rectangle in AppKit coordinates.
    ///   - primaryScreenHeight: The height of the primary display (screen with frame.origin == .zero).
    /// - Returns: The rectangle in top-left AX coordinates.
    public static func appKitToAX(rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        let axX = rect.origin.x
        let axY = primaryScreenHeight - rect.origin.y - rect.height
        return CGRect(
            x: axX.rounded(),
            y: axY.rounded(),
            width: rect.width.rounded(),
            height: rect.height.rounded()
        )
    }

    /// Converts an Accessibility AX UI Element coordinate rect (origin at top-left of primary display)
    /// back to AppKit coordinate rect (origin at bottom-left of primary display).
    /// - Parameters:
    ///   - axRect: The rectangle in AX coordinates.
    ///   - primaryScreenHeight: The height of the primary display.
    /// - Returns: The rectangle in bottom-left AppKit coordinates.
    public static func axToAppKit(rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        let appKitX = rect.origin.x
        let appKitY = primaryScreenHeight - rect.origin.y - rect.height
        return CGRect(
            x: appKitX.rounded(),
            y: appKitY.rounded(),
            width: rect.width.rounded(),
            height: rect.height.rounded()
        )
    }

    /// Computes the Notch Snap Drop Zone at the top edge of the display.
    /// If a dragged window center or cursor enters this zone, snap actions can be suggested.
    /// - Parameters:
    ///   - screenFrame: The entire screen frame.
    ///   - zoneWidth: The width of the activation zone (default: 260 pt).
    ///   - zoneHeight: The height of the activation zone (default: 48 pt).
    /// - Returns: Zone rect in AppKit coordinates.
    public static func notchSnapZone(
        screenFrame: CGRect,
        zoneWidth: CGFloat = 260,
        zoneHeight: CGFloat = 48
    ) -> CGRect {
        let x = screenFrame.origin.x + (screenFrame.width - zoneWidth) / 2
        let y = screenFrame.origin.y + screenFrame.height - zoneHeight
        return CGRect(x: x, y: y, width: zoneWidth, height: zoneHeight)
    }
}
