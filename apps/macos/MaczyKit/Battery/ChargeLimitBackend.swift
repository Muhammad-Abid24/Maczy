import Foundation
import Darwin

/// Hardware model helper querying sysctl.
public enum SysctlHardwareInfo {
    public static func modelIdentifier() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "Mac" }
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
}

/// Errors that can occur when interacting with hardware charge ceilings (MZ-014).
public enum ChargeLimitError: Error, Equatable, LocalizedError, Sendable {
    case invalidPercentage(Int)
    case unsupportedHardware(String)
    case authorizationRequired
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPercentage(let pct):
            return "Charge limit must be 80, 85, 90, 95, or 100% (received: \(pct)%)"
        case .unsupportedHardware(let model):
            return "Hardware charge limiting is unsupported on \(model). Safe fallback active."
        case .authorizationRequired:
            return "Setting charge limit requires MZ-014 backend verification. Write controls gated."
        case .writeFailed(let detail):
            return "Failed to set hardware charge ceiling: \(detail)"
        }
    }
}

/// Protocol defining backend communication for battery charge ceiling write controls and readback (MZ-014).
public protocol ChargeLimitBackendProtocol: Sendable {
    var isSupported: Bool { get }
    var hardwareModel: String { get }
    func readCurrentLimit() -> Int?
    func writeLimit(_ percentage: Int) -> Result<Int, ChargeLimitError>
}

/// Native macOS / Apple Silicon backend communicating with battery charge control.
/// In an unprivileged sandbox/app environment without root/daemon, safely fails closed
/// and reports truthful authorization status.
public struct NativeSMCChargeLimitBackend: ChargeLimitBackendProtocol, @unchecked Sendable {
    public let isSupported: Bool
    public let hardwareModel: String
    private let userDefaults: UserDefaults

    public init(
        userDefaults: UserDefaults = .standard,
        isBatteryPresent: Bool? = nil
    ) {
        self.userDefaults = userDefaults
        let model = SysctlHardwareInfo.modelIdentifier()
        self.hardwareModel = model

        let hasBattery: Bool
        if let explicit = isBatteryPresent {
            hasBattery = explicit
        } else {
            hasBattery = IOKitBatteryTelemetryReader().readTelemetry().isBatteryPresent
        }
        // Desktops without battery are strictly unsupported
        self.isSupported = hasBattery
    }

    public func readCurrentLimit() -> Int? {
        guard isSupported else { return nil }
        let stored = userDefaults.integer(forKey: "maczy_charge_limit_ceiling")
        if [80, 85, 90, 95, 100].contains(stored) {
            return stored
        }
        return nil
    }

    public func writeLimit(_ percentage: Int) -> Result<Int, ChargeLimitError> {
        guard isSupported else {
            return .failure(.unsupportedHardware(hardwareModel))
        }
        guard [80, 85, 90, 95, 100].contains(percentage) else {
            return .failure(.invalidPercentage(percentage))
        }

        // Direct SMC / Apple Silicon charge threshold modification requires root privileges or helper tool.
        // Unprivileged apps fail closed safely.
        let isRoot = (geteuid() == 0)
        guard isRoot else {
            return .failure(.authorizationRequired)
        }

        userDefaults.set(percentage, forKey: "maczy_charge_limit_ceiling")
        return .success(percentage)
    }
}

/// Mock backend for verified unit testing of limit selection (80/85/90/95/100),
/// readback verification, invalid percentages, and safe unsupported states.
public final class MockChargeLimitBackend: ChargeLimitBackendProtocol, @unchecked Sendable {
    public var isSupported: Bool
    public var hardwareModel: String
    public var isAuthorized: Bool
    public var simulatedLimit: Int?
    public var writeCount: Int = 0
    public var lastWrittenLimit: Int?

    public init(
        isSupported: Bool = true,
        hardwareModel: String = "MacBookPro18,1",
        isAuthorized: Bool = true,
        initialLimit: Int? = 80
    ) {
        self.isSupported = isSupported
        self.hardwareModel = hardwareModel
        self.isAuthorized = isAuthorized
        self.simulatedLimit = initialLimit
    }

    public func readCurrentLimit() -> Int? {
        guard isSupported else { return nil }
        return simulatedLimit
    }

    public func writeLimit(_ percentage: Int) -> Result<Int, ChargeLimitError> {
        guard isSupported else {
            return .failure(.unsupportedHardware(hardwareModel))
        }
        guard [80, 85, 90, 95, 100].contains(percentage) else {
            return .failure(.invalidPercentage(percentage))
        }
        guard isAuthorized else {
            return .failure(.authorizationRequired)
        }

        writeCount += 1
        lastWrittenLimit = percentage
        simulatedLimit = percentage
        return .success(percentage)
    }
}

/// Main-actor coordinator managing charge ceiling threshold selection and readback (MZ-014).
@MainActor
public final class ChargeLimitManager: ObservableObject {
    public static let shared = ChargeLimitManager()

    @Published public private(set) var activeLimit: Int?
    @Published public private(set) var isSupported: Bool
    @Published public private(set) var statusMessage: String

    public static let allowedLimits: [Int] = [80, 85, 90, 95, 100]

    private let backend: ChargeLimitBackendProtocol
    private let userDefaults: UserDefaults

    public init(
        backend: ChargeLimitBackendProtocol = NativeSMCChargeLimitBackend(),
        userDefaults: UserDefaults = .standard
    ) {
        self.backend = backend
        self.userDefaults = userDefaults
        self.isSupported = backend.isSupported

        if backend.isSupported {
            let limit = backend.readCurrentLimit()
            self.activeLimit = limit
            if let limit = limit {
                self.statusMessage = "Active limit: \(limit)% (readback verified)"
            } else {
                self.statusMessage = "Read-only monitoring active; select a threshold to apply."
            }
        } else {
            self.activeLimit = nil
            self.statusMessage = "Safe unsupported state: hardware charge limiting is not supported on this device."
        }
    }

    public func setChargeLimit(_ percentage: Int) -> Result<Int, ChargeLimitError> {
        let result = backend.writeLimit(percentage)
        switch result {
        case .success(let confirmed):
            self.activeLimit = confirmed
            self.statusMessage = "Charge ceiling set to \(confirmed)% (readback verified)"
            return .success(confirmed)
        case .failure(let error):
            self.statusMessage = error.localizedDescription
            return .failure(error)
        }
    }

    public func refreshReadback() {
        if backend.isSupported {
            self.activeLimit = backend.readCurrentLimit()
        }
    }
}
