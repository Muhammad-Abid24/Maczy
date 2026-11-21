import Foundation
import CoreGraphics

/// Preferred notch display mode configured by user.
public enum NotchDisplayMode: String, CaseIterable, Sendable, Codable {
    case auto = "Auto-Detect"
    case alwaysPhysical = "Force Physical Notch"
    case alwaysVirtual = "Force Virtual Island"
}

/// Dynamic expansion state of the notch overlay.
public enum NotchExpansionState: String, Sendable, Codable {
    case compact = "Compact"
    case expanded = "Expanded"
}

/// Calculated geometry and hardware profile of the target screen's notch.
public struct NotchScreenProfile: Sendable, Equatable {
    public let screenName: String
    public let screenFrame: CGRect
    public let hasPhysicalNotch: Bool
    public let notchRect: CGRect
    public let isVirtualIsland: Bool
    public let compactSize: CGSize
    public let expandedSize: CGSize

    public init(
        screenName: String,
        screenFrame: CGRect,
        hasPhysicalNotch: Bool,
        notchRect: CGRect,
        isVirtualIsland: Bool,
        compactSize: CGSize,
        expandedSize: CGSize
    ) {
        self.screenName = screenName
        self.screenFrame = screenFrame
        self.hasPhysicalNotch = hasPhysicalNotch
        self.notchRect = notchRect
        self.isVirtualIsland = isVirtualIsland
        self.compactSize = compactSize
        self.expandedSize = expandedSize
    }

    /// Default fallback profile for headless environments or unattached displays.
    public static let fallback = NotchScreenProfile(
        screenName: "Default Display",
        screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        hasPhysicalNotch: false,
        notchRect: CGRect(x: 630, y: 856, width: 180, height: 32),
        isVirtualIsland: true,
        compactSize: CGSize(width: 180, height: 32),
        expandedSize: CGSize(width: 420, height: 160)
    )
}
