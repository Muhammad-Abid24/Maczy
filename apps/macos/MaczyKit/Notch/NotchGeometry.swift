import AppKit
import CoreGraphics

/// Precision geometry engine for calculating hardware notch and virtual island bounds.
public enum NotchGeometry {
    // Default metrics (in AppKit points)
    public static let defaultVirtualCompactSize = CGSize(width: 350, height: 32)
    public static let defaultVirtualExpandedSize = CGSize(width: 420, height: 160)
    public static let defaultPhysicalExpandedSize = CGSize(width: 460, height: 180)
    public static let defaultVirtualTopPadding: CGFloat = 7.0

    /// Calculate physical notch rect from raw screen parameters.
    public static func calculatePhysicalNotchRect(
        screenFrame: CGRect,
        safeAreaTop: CGFloat,
        auxLeftWidth: CGFloat,
        auxRightWidth: CGFloat
    ) -> CGRect? {
        guard safeAreaTop > 0, auxLeftWidth > 0, auxRightWidth > 0 else { return nil }
        let notchWidth = screenFrame.width - (auxLeftWidth + auxRightWidth)
        guard notchWidth > 0 else { return nil }

        let notchX = screenFrame.minX + auxLeftWidth
        let notchY = screenFrame.maxY - safeAreaTop
        return CGRect(x: notchX, y: notchY, width: notchWidth, height: safeAreaTop)
    }

    /// Calculate virtual island pill rect centered at top of display.
    public static func calculateVirtualIslandRect(
        screenFrame: CGRect,
        compactSize: CGSize = defaultVirtualCompactSize,
        topPadding: CGFloat = defaultVirtualTopPadding
    ) -> CGRect {
        let x = screenFrame.midX - (compactSize.width / 2.0)
        let y = screenFrame.maxY - compactSize.height - topPadding
        return CGRect(x: x, y: y, width: compactSize.width, height: compactSize.height)
    }

    /// Calculate bounding rect for the expanded state anchored to the compact position.
    public static func calculateExpandedRect(
        anchorRect: CGRect,
        expandedSize: CGSize,
        isPhysicalNotch: Bool
    ) -> CGRect {
        let x = anchorRect.midX - (expandedSize.width / 2.0)
        let y = anchorRect.maxY - expandedSize.height
        return CGRect(x: x, y: y, width: expandedSize.width, height: expandedSize.height)
    }

    /// Detect notch hardware profile for a given screen or main display.
    public static func detectProfile(
        for screen: NSScreen? = NSScreen.main ?? NSScreen.screens.first,
        mode: NotchDisplayMode = .auto,
        customCompactSize: CGSize? = nil,
        customExpandedSize: CGSize? = nil
    ) -> NotchScreenProfile {
        guard let screen = screen else {
            let base = NotchScreenProfile.fallback
            let compact = customCompactSize ?? base.compactSize
            let expanded = customExpandedSize ?? base.expandedSize
            let rect = CGRect(
                x: base.notchRect.midX - (compact.width / 2.0),
                y: base.notchRect.maxY - compact.height,
                width: compact.width,
                height: compact.height
            )
            return NotchScreenProfile(
                screenName: base.screenName,
                screenFrame: base.screenFrame,
                hasPhysicalNotch: base.hasPhysicalNotch,
                notchRect: rect,
                isVirtualIsland: base.isVirtualIsland,
                compactSize: compact,
                expandedSize: expanded
            )
        }

        let frame = screen.frame
        let screenName = screen.localizedName

        switch mode {
        case .alwaysVirtual:
            let compact = customCompactSize ?? defaultVirtualCompactSize
            let expanded = customExpandedSize ?? defaultVirtualExpandedSize
            let virtualRect = calculateVirtualIslandRect(screenFrame: frame, compactSize: compact)
            return NotchScreenProfile(
                screenName: screenName,
                screenFrame: frame,
                hasPhysicalNotch: false,
                notchRect: virtualRect,
                isVirtualIsland: true,
                compactSize: compact,
                expandedSize: expanded
            )

        case .alwaysPhysical:
            // Force physical style metrics even if on non-notch screen
            let safeTop = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 34.0
            let auxLeft = (frame.width - 220.0) / 2.0
            let auxRight = auxLeft
            let baseNotchRect =
                calculatePhysicalNotchRect(
                    screenFrame: frame,
                    safeAreaTop: safeTop,
                    auxLeftWidth: auxLeft,
                    auxRightWidth: auxRight
                )
                ?? CGRect(
                    x: frame.midX - 110.0, y: frame.maxY - safeTop, width: 220.0, height: safeTop)

            let compact = customCompactSize ?? CGSize(width: baseNotchRect.width, height: baseNotchRect.height)
            let notchRect = CGRect(
                x: frame.midX - (compact.width / 2.0),
                y: frame.maxY - compact.height,
                width: compact.width,
                height: compact.height
            )
            let expanded = customExpandedSize ?? defaultPhysicalExpandedSize

            return NotchScreenProfile(
                screenName: screenName,
                screenFrame: frame,
                hasPhysicalNotch: true,
                notchRect: notchRect,
                isVirtualIsland: false,
                compactSize: compact,
                expandedSize: expanded
            )

        case .auto:
            var detectedPhysicalRect: CGRect?
            if #available(macOS 12.0, *) {
                let safeTop = screen.safeAreaInsets.top
                if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea
                {
                    detectedPhysicalRect = calculatePhysicalNotchRect(
                        screenFrame: frame,
                        safeAreaTop: safeTop,
                        auxLeftWidth: left.width,
                        auxRightWidth: right.width
                    )
                }
            }

            if let physicalRect = detectedPhysicalRect {
                let compact = customCompactSize ?? CGSize(width: physicalRect.width, height: physicalRect.height)
                let notchRect = CGRect(
                    x: frame.midX - (compact.width / 2.0),
                    y: frame.maxY - compact.height,
                    width: compact.width,
                    height: compact.height
                )
                let expanded = customExpandedSize ?? defaultPhysicalExpandedSize

                return NotchScreenProfile(
                    screenName: screenName,
                    screenFrame: frame,
                    hasPhysicalNotch: true,
                    notchRect: notchRect,
                    isVirtualIsland: false,
                    compactSize: compact,
                    expandedSize: expanded
                )
            } else {
                let compact = customCompactSize ?? defaultVirtualCompactSize
                let expanded = customExpandedSize ?? defaultVirtualExpandedSize
                let virtualRect = calculateVirtualIslandRect(screenFrame: frame, compactSize: compact)
                return NotchScreenProfile(
                    screenName: screenName,
                    screenFrame: frame,
                    hasPhysicalNotch: false,
                    notchRect: virtualRect,
                    isVirtualIsland: true,
                    compactSize: compact,
                    expandedSize: expanded
                )
            }
        }
    }
}
