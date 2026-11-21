import AppKit
import Foundation
import LocalAuthentication

/// Status of biometric (Touch ID) enrollment on the host Apple Silicon Mac.
public enum BiometricEnrollmentStatus: String, Sendable, Equatable {
    case enrolled = "Enrolled & Ready"
    case notEnrolled = "Touch ID Supported, but Not Enrolled"
    case hardwareUnavailable = "Touch ID Hardware Not Available"
    case passcodeNotSet = "System Password Not Configured"
    case lockedOut = "Biometrics Locked Out (Password Required)"
    case unknown = "Status Unknown"

    public var isOperational: Bool {
        self == .enrolled
    }
}

/// Overall biometric capability status report for macOS authentication.
public struct BiometricCapabilityStatus: Sendable, Equatable {
    public let isAvailable: Bool
    public let enrollmentStatus: BiometricEnrollmentStatus
    public let details: String

    public init(isAvailable: Bool, enrollmentStatus: BiometricEnrollmentStatus, details: String) {
        self.isAvailable = isAvailable
        self.enrollmentStatus = enrollmentStatus
        self.details = details
    }
}

/// Protocol for evaluating macOS biometric and credential capabilities.
public protocol BiometricStatusEvaluator: Sendable {
    func evaluateBiometricStatus() -> BiometricCapabilityStatus
    func evaluateDeviceOwnerAuth() -> Bool
}

/// Production biometric evaluator querying Apple LocalAuthentication framework.
public final class LABiometricStatusEvaluator: BiometricStatusEvaluator {
    public init() {}

    public func evaluateBiometricStatus() -> BiometricCapabilityStatus {
        let context = LAContext()
        var error: NSError?
        let canEvaluateBiometrics = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        if canEvaluateBiometrics {
            return BiometricCapabilityStatus(
                isAvailable: true,
                enrollmentStatus: .enrolled,
                details: "Touch ID is enrolled and ready for hardware-backed unlock."
            )
        }

        if let laErr = error {
            let status: BiometricEnrollmentStatus
            let details: String
            switch laErr.code {
            case LAError.biometryNotEnrolled.rawValue:
                status = .notEnrolled
                details = "Touch ID hardware detected, but no fingerprints are currently enrolled."
            case LAError.biometryNotAvailable.rawValue:
                status = .hardwareUnavailable
                details = "Touch ID hardware is not available on this Mac (or external display/keyboard without Touch ID)."
            case LAError.passcodeNotSet.rawValue:
                status = .passcodeNotSet
                details = "User account password is not configured."
            case LAError.biometryLockout.rawValue:
                status = .lockedOut
                details = "Touch ID is locked out due to multiple failed attempts; system password required."
            default:
                status = .unknown
                details = laErr.localizedDescription
            }
            return BiometricCapabilityStatus(
                isAvailable: false,
                enrollmentStatus: status,
                details: details
            )
        }

        return BiometricCapabilityStatus(
            isAvailable: false,
            enrollmentStatus: .unknown,
            details: "Unable to query LocalAuthentication state."
        )
    }

    public func evaluateDeviceOwnerAuth() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }
}

/// Mock evaluator enabling deterministic unit testing of all biometric states.
public final class MockBiometricStatusEvaluator: BiometricStatusEvaluator, @unchecked Sendable {
    public var statusToReturn: BiometricCapabilityStatus
    public var canAuthWithPasscode: Bool

    public init(
        statusToReturn: BiometricCapabilityStatus = BiometricCapabilityStatus(
            isAvailable: true,
            enrollmentStatus: .enrolled,
            details: "Mock Touch ID Ready"
        ),
        canAuthWithPasscode: Bool = true
    ) {
        self.statusToReturn = statusToReturn
        self.canAuthWithPasscode = canAuthWithPasscode
    }

    public func evaluateBiometricStatus() -> BiometricCapabilityStatus {
        statusToReturn
    }

    public func evaluateDeviceOwnerAuth() -> Bool {
        canAuthWithPasscode
    }
}

/// Coordinates native macOS unlock fallbacks (Touch ID, Apple Watch, Password)
/// and provides deep links to macOS System Settings per MZ-022.
@MainActor
public final class NativeUnlockFallbackManager: ObservableObject {
    public static let shared = NativeUnlockFallbackManager()

    /// Unbreakable security invariant: Maczy preserves native OS fallbacks and never intercepts credentials.
    nonisolated public static let securityStatement: String =
        "macOS enforces all lock screen session authentication through Apple Silicon Secure Enclave and loginwindow. Maczy strictly preserves native Touch ID, Apple Watch, and user password fallbacks. Maczy never collects, stores, or intercepts user passwords or biometric tokens."

    /// URL deep links for macOS System Settings (macOS 14+ Sonoma and macOS 15+ Sequoia).
    nonisolated public static let touchIDSettingsURL = URL(string: "x-apple.systempreferences:com.apple.Touch-ID-Settings.extension")
        ?? URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_TouchID")!

    nonisolated public static let passwordSettingsURL = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
        ?? URL(string: "x-apple.systempreferences:com.apple.preference.security")!

    nonisolated public static let appleWatchSettingsURL = URL(string: "x-apple.systempreferences:com.apple.Touch-ID-Settings.extension")
        ?? URL(string: "x-apple.systempreferences:com.apple.preference.security")!

    @Published public private(set) var currentBiometricStatus: BiometricCapabilityStatus
    @Published public private(set) var isDeviceOwnerAuthAvailable: Bool = true
    public private(set) var evaluator: BiometricStatusEvaluator

    public init(evaluator: BiometricStatusEvaluator = LABiometricStatusEvaluator()) {
        self.evaluator = evaluator
        self.currentBiometricStatus = evaluator.evaluateBiometricStatus()
        self.isDeviceOwnerAuthAvailable = evaluator.evaluateDeviceOwnerAuth()
    }

    public func setEvaluator(_ evaluator: BiometricStatusEvaluator) {
        self.evaluator = evaluator
        refreshStatus()
    }

    /// Re-evaluates biometric and authentication capabilities.
    public func refreshStatus() {
        self.currentBiometricStatus = evaluator.evaluateBiometricStatus()
        self.isDeviceOwnerAuthAvailable = evaluator.evaluateDeviceOwnerAuth()
    }

    /// Opens System Settings > Touch ID & Password.
    public func openTouchIDSettings() {
        NSWorkspace.shared.open(Self.touchIDSettingsURL)
    }

    /// Opens System Settings > Login Items & Password.
    public func openPasswordSettings() {
        NSWorkspace.shared.open(Self.passwordSettingsURL)
    }

    /// Opens System Settings > Apple Watch Auto Unlock.
    public func openAppleWatchSettings() {
        NSWorkspace.shared.open(Self.appleWatchSettingsURL)
    }
}
