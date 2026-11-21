import SwiftUI

/// Dashboard tab selection matching the OpenDesign navigation hierarchy.
public enum DashboardTab: Hashable, Identifiable, Sendable {
    case overview
    case module(MaczyModuleId)
    case permissions
    case settings

    public var id: String {
        switch self {
        case .overview: return "overview"
        case .module(let m): return m.rawValue
        case .permissions: return "permissions"
        case .settings: return "settings"
        }
    }

    public var displayName: String {
        switch self {
        case .overview: return "Overview"
        case .module(let m): return m.displayName
        case .permissions: return "Permissions"
        case .settings: return "Settings"
        }
    }

    public var iconName: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .module(let m): return m.iconName
        case .permissions: return "hand.raised.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
