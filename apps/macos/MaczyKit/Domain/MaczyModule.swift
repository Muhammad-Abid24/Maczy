import Foundation
import SwiftUI

/// Canonical identifiers for all seven Maczy modules per PRD.
public enum MaczyModuleId: String, CaseIterable, Identifiable, Sendable {
    case captureAndRecording = "capture_and_recording"
    case batteryGuardian = "battery_guardian"
    case dynamicNotch = "dynamic_notch"
    case smartUnlock = "smart_unlock"
    case updates = "updates"
    case alwaysOn = "always_on"
    case systemCleaner = "system_cleaner"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .captureAndRecording: return "Capture & Recording"
        case .batteryGuardian: return "Battery Guardian"
        case .dynamicNotch: return "Dynamic Notch"
        case .smartUnlock: return "Smart Unlock"
        case .updates: return "Updates"
        case .alwaysOn: return "Always On"
        case .systemCleaner: return "System Cleaner"
        }
    }

    public var iconName: String {
        switch self {
        case .captureAndRecording: return "camera.viewfinder"
        case .batteryGuardian: return "battery.100.bolt"
        case .dynamicNotch: return "macbook.gen2"
        case .smartUnlock: return "lock.trianglebadge.exclamationmark"
        case .updates: return "arrow.triangle.2.circlepath"
        case .alwaysOn: return "sun.max.fill"
        case .systemCleaner: return "sparkles"
        }
    }

    public var summary: String {
        switch self {
        case .captureAndRecording:
            return "Screenshots (area, window, scrolling), OCR, and recording with independent audio toggles."
        case .batteryGuardian:
            return "Battery monitoring and charge threshold selection (80%, 85%, 90%, 95%, 100%)."
        case .dynamicNotch:
            return "Now Playing, notifications, HUDs, window snap, and native contextual notch controls."
        case .smartUnlock:
            return "macOS Lock Screen Face Unlock feasibility research; preserves native Touch ID/password fallback."
        case .updates:
            return "Sparkle 2 EdDSA signed update checks and release channels."
        case .alwaysOn:
            return "Scoped IOPM power assertions to prevent idle sleep with power-aware safeguards."
        case .systemCleaner:
            return "Mole-inspired read-only scanner, preview manifests, and safe confirmed cleanup."
        }
    }
}

/// Runtime state of a module.
public enum ModuleRuntimeState: String, Sendable {
    case notImplemented = "Not Implemented"
    case idle = "Idle"
    case running = "Running"
    case paused = "Paused"
    case blocked = "Blocked"
    case error = "Error"
}

/// Metadata and status snapshot for a module.
public struct ModuleStatus: Identifiable, Sendable {
    public let id: MaczyModuleId
    public let name: String
    public let summary: String
    public let iconName: String
    public let isImplemented: Bool
    public let runtimeState: ModuleRuntimeState
    public let statusMessage: String

    public init(
        id: MaczyModuleId,
        isImplemented: Bool = false,
        runtimeState: ModuleRuntimeState = .notImplemented,
        statusMessage: String = "Foundation scaffold placeholder (MZ-001)"
    ) {
        self.id = id
        self.name = id.displayName
        self.summary = id.summary
        self.iconName = id.iconName
        self.isImplemented = isImplemented
        self.runtimeState = runtimeState
        self.statusMessage = statusMessage
    }
}
