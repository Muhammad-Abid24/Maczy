import Foundation

/// Swift representation of the Rust maczy-core bridge.
public final class MaczyCoreBridge: @unchecked Sendable {
    public static let shared = MaczyCoreBridge()

    public let coreVersion: String = "0.1.0"
    public let targetArch: String = "arm64"
    public let minDeployment: String = "14.0"

    private init() {}

    /// Returns the exact count of Maczy modules (always 7).
    public var moduleCount: Int {
        return MaczyModuleId.allCases.count
    }

    /// Fetches initial status snapshots for all 7 modules.
    public func fetchAllModuleStatuses() -> [ModuleStatus] {
        return MaczyModuleId.allCases.map { id in
            let statusMessage: String
            let runtime: ModuleRuntimeState

            switch id {
            case .smartUnlock:
                statusMessage = "CRITICAL: macOS Lock Screen Face Unlock gated by MZ-023 feasibility & security review. Not implemented. Preserving native Touch ID/password fallback."
                runtime = .notImplemented
            case .batteryGuardian:
                statusMessage = "Monitoring scaffold ready. Charge write controls gated by MZ-014."
                runtime = .notImplemented
            case .systemCleaner:
                statusMessage = "Scan-only scaffold ready. Deletion gated by MZ-029."
                runtime = .notImplemented
            default:
                statusMessage = "Foundation scaffold placeholder (MZ-001)."
                runtime = .notImplemented
            }

            return ModuleStatus(
                id: id,
                isImplemented: false,
                runtimeState: runtime,
                statusMessage: statusMessage
            )
        }
    }
}
