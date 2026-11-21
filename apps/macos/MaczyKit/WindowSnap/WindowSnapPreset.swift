import Foundation

/// Supported window snap layout presets for Maczy Window Snap (MZ-019).
public enum WindowSnapPreset: String, CaseIterable, Sendable, Identifiable {
    case leftHalf = "Left Half"
    case rightHalf = "Right Half"
    case topHalf = "Top Half"
    case bottomHalf = "Bottom Half"
    case maximize = "Maximize"
    case center = "Center"
    
    // Thirds
    case leftThird = "Left Third"
    case centerThird = "Center Third"
    case rightThird = "Right Third"
    case leftTwoThirds = "Left Two Thirds"
    case rightTwoThirds = "Right Two Thirds"
    
    // Quarters
    case topLeftQuarter = "Top Left"
    case topRightQuarter = "Top Right"
    case bottomLeftQuarter = "Bottom Left"
    case bottomRightQuarter = "Bottom Right"

    public var id: String { rawValue }

    /// SF Symbol icon representation for the snap preset.
    public var iconName: String {
        switch self {
        case .leftHalf: return "rectangle.lefthalf.filled"
        case .rightHalf: return "rectangle.righthalf.filled"
        case .topHalf: return "rectangle.tophalf.filled"
        case .bottomHalf: return "rectangle.bottomhalf.filled"
        case .maximize: return "rectangle.fill"
        case .center: return "rectangle.center.inset.filled"
        case .leftThird: return "rectangle.split.3x1"
        case .centerThird: return "rectangle.split.3x1.fill"
        case .rightThird: return "rectangle.split.3x1"
        case .leftTwoThirds: return "rectangle.split.2x1"
        case .rightTwoThirds: return "rectangle.split.2x1"
        case .topLeftQuarter: return "rectangle.inset.topleft.filled"
        case .topRightQuarter: return "rectangle.inset.topright.filled"
        case .bottomLeftQuarter: return "rectangle.inset.bottomleft.filled"
        case .bottomRightQuarter: return "rectangle.inset.bottomright.filled"
        }
    }

    /// User-friendly shortcut display text.
    public var shortcutDisplay: String {
        switch self {
        case .leftHalf: return "⌃⌥←"
        case .rightHalf: return "⌃⌥→"
        case .topHalf: return "⌃⌥↑"
        case .bottomHalf: return "⌃⌥↓"
        case .maximize: return "⌃⌥↩"
        case .center: return "⌃⌥C"
        case .leftThird: return "⌃⌥D"
        case .centerThird: return "⌃⌥F"
        case .rightThird: return "⌃⌥G"
        case .leftTwoThirds: return "⌃⌥E"
        case .rightTwoThirds: return "⌃⌥T"
        case .topLeftQuarter: return "⌃⌥U"
        case .topRightQuarter: return "⌃⌥I"
        case .bottomLeftQuarter: return "⌃⌥J"
        case .bottomRightQuarter: return "⌃⌥K"
        }
    }
}
