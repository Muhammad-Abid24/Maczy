import Foundation

public struct AlwaysOnSafetyConfig: Equatable, Sendable {
    /// Discharging battery threshold percentage (0-100) below which Always On automatically releases.
    public var minBatteryPercentage: Double

    /// Maximum thermal state before Always On releases to protect Apple Silicon hardware.
    public var maxAllowedThermalState: ProcessInfo.ThermalState

    public init(
        minBatteryPercentage: Double = 15.0,
        maxAllowedThermalState: ProcessInfo.ThermalState = .fair
    ) {
        self.minBatteryPercentage = minBatteryPercentage
        self.maxAllowedThermalState = maxAllowedThermalState
    }
}

public enum AlwaysOnReleaseReason: Equatable, Sendable {
    case manualStop
    case timerExpired
    case lowBatteryAutoRelease(percentage: Double)
    case thermalProtectionAutoRelease(state: ProcessInfo.ThermalState)
    case sessionReplaced

    public var message: String {
        switch self {
        case .manualStop:
            return "Session stopped by user"
        case .timerExpired:
            return "Timer expired normally"
        case .lowBatteryAutoRelease(let percentage):
            return String(format: "Auto-released: Low battery (%.0f%%)", percentage)
        case .thermalProtectionAutoRelease(let state):
            return "Auto-released: Thermal guardrail triggered (\(state.displayString))"
        case .sessionReplaced:
            return "Replaced by new awake session"
        }
    }
}

extension ProcessInfo.ThermalState {
    public var displayString: String {
        switch self {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
