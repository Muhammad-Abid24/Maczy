import Foundation

/// High-level user or system action dispatched to a Maczy module.
public enum MaczyAction: Sendable {
    // Capture & Recording
    case captureScreenshot(mode: String)
    case startScreenRecording(target: String, systemAudio: Bool, microphone: Bool)
    case stopScreenRecording

    // Battery Guardian
    case selectChargeLimit(percentage: Int)

    // Dynamic Notch
    case toggleNotchExpanded

    // Smart Unlock (Gated by MZ-023)
    case requestFaceUnlockEnrollment
    case triggerSessionUnlock

    // Updates
    case checkForUpdates

    // Always On
    case startAwakeSession(durationMinutes: Int?)
    case stopAwakeSession

    // System Cleaner
    case startCleanerScan
    case cancelCleanerScan

    public var targetModuleId: MaczyModuleId {
        switch self {
        case .captureScreenshot, .startScreenRecording, .stopScreenRecording:
            return .captureAndRecording
        case .selectChargeLimit:
            return .batteryGuardian
        case .toggleNotchExpanded:
            return .dynamicNotch
        case .requestFaceUnlockEnrollment, .triggerSessionUnlock:
            return .smartUnlock
        case .checkForUpdates:
            return .updates
        case .startAwakeSession, .stopAwakeSession:
            return .alwaysOn
        case .startCleanerScan, .cancelCleanerScan:
            return .systemCleaner
        }
    }
}

/// Output result of an executed command or action pipeline per ARCHITECTURE.md.
public struct CommandResult: Sendable, Equatable {
    public let ok: Bool
    public let observedValue: String?
    public let errorCode: String?
    public let message: String?

    public init(
        ok: Bool,
        observedValue: String? = nil,
        errorCode: String? = nil,
        message: String? = nil
    ) {
        self.ok = ok
        self.observedValue = observedValue
        self.errorCode = errorCode
        self.message = message
    }

    public static func success(message: String, observedValue: String? = nil) -> CommandResult {
        CommandResult(ok: true, observedValue: observedValue, errorCode: nil, message: message)
    }

    public static func failure(errorCode: String, message: String) -> CommandResult {
        CommandResult(ok: false, observedValue: nil, errorCode: errorCode, message: message)
    }
}
