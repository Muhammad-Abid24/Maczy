import Foundation

/// Enumeration of target macOS unlock scenarios evaluated in the MZ-023 feasibility audit.
public enum LockScreenScenario: String, CaseIterable, Sendable, Identifiable {
    case scenarioA_lockedSession = "Scenario A: Locked Active Session"
    case scenarioB_afterLogout = "Scenario B: Login After Logout"
    case scenarioC_firstLoginAfterBoot = "Scenario C: First Login After Boot"
    case scenarioD_fileVaultPreboot = "Scenario D: FileVault EFI Preboot"
    case scenarioE_fastUserSwitching = "Scenario E: Fast User Switching / MDM"
    case scenarioF_clamshellOrBlocked = "Scenario F: Clamshell / Camera Blocked"

    public var id: String { rawValue }

    public var shortTitle: String {
        switch self {
        case .scenarioA_lockedSession: return "Locked Active Session"
        case .scenarioB_afterLogout: return "After Logout"
        case .scenarioC_firstLoginAfterBoot: return "First Login Post-Boot"
        case .scenarioD_fileVaultPreboot: return "FileVault Preboot"
        case .scenarioE_fastUserSwitching: return "Fast User Switching"
        case .scenarioF_clamshellOrBlocked: return "Clamshell / Obstructed"
        }
    }
}

/// Technical mechanisms evaluated for implementing third-party camera unlock.
public enum TechnicalPathway: String, CaseIterable, Sendable, Identifiable {
    case localAuthentication = "LocalAuthentication (LAContext)"
    case authorizationPlugin = "Authorization Services Plugin"
    case syntheticKeystrokes = "Synthetic Keystrokes (AX / CGEvent)"
    case privilegedDaemon = "Privileged Daemon + Password Vault"

    public var id: String { rawValue }

    public var assessment: String {
        switch self {
        case .localAuthentication:
            return "Zero public APIs exist to unlock system loginwindow from user-space."
        case .authorizationPlugin:
            return "Modifying auth.db requires root and risks bricking loginwindow across OS updates."
        case .syntheticKeystrokes:
            return "Kernel blocks event synthesis into loginwindow Audit Session; storing passwords violates SECURITY.md."
        case .privilegedDaemon:
            return "Storing plaintext or reversible credentials violates fail-closed security policy."
        }
    }
}

/// Safety and architectural feasibility verdict.
public enum FeasibilityVerdict: String, Sendable, Equatable {
    case blocked = "BLOCKED"
    case impossible = "IMPOSSIBLE"
    case unsupported = "UNSUPPORTED"

    public var isExecutable: Bool {
        false
    }
}

/// Detailed audit entry for a specific unlock scenario.
public struct ScenarioAuditResult: Sendable, Identifiable, Equatable {
    public let scenario: LockScreenScenario
    public let verdict: FeasibilityVerdict
    public let obstacle: String

    public var id: String { scenario.rawValue }

    public init(scenario: LockScreenScenario, verdict: FeasibilityVerdict, obstacle: String) {
        self.scenario = scenario
        self.verdict = verdict
        self.obstacle = obstacle
    }
}

/// Programmatic access to the MZ-023 Feasibility Audit findings and security gate.
public struct FaceUnlockFeasibilityReport: Sendable {
    
    /// The universal verdict governing MZ-024 implementation.
    public static let overallVerdict: FeasibilityVerdict = .blocked

    /// Absolute security gate: automated camera session unlock is prohibited without owner authorization.
    public static let isMZ024ImplementationAuthorized: Bool = false

    /// Audited scenario matrix data per PRD §5 and ADR-0002.
    public static let scenarioResults: [ScenarioAuditResult] = [
        ScenarioAuditResult(
            scenario: .scenarioA_lockedSession,
            verdict: .blocked,
            obstacle: "loginwindow isolation; no public Apple API to dismiss lock screen from user-space."
        ),
        ScenarioAuditResult(
            scenario: .scenarioB_afterLogout,
            verdict: .blocked,
            obstacle: "User session is completely terminated; user keybag not initialized."
        ),
        ScenarioAuditResult(
            scenario: .scenarioC_firstLoginAfterBoot,
            verdict: .impossible,
            obstacle: "Secure Enclave hardware requires primary user password to unlock disk encryption."
        ),
        ScenarioAuditResult(
            scenario: .scenarioD_fileVaultPreboot,
            verdict: .impossible,
            obstacle: "Preboot EFI environment executes before macOS kernel and drivers are loaded."
        ),
        ScenarioAuditResult(
            scenario: .scenarioE_fastUserSwitching,
            verdict: .blocked,
            obstacle: "Enterprise MDM profiles and Multi-user session boundaries prohibit bypass."
        ),
        ScenarioAuditResult(
            scenario: .scenarioF_clamshellOrBlocked,
            verdict: .blocked,
            obstacle: "FaceTime HD camera is physically occluded in clamshell or covered setups."
        )
    ]

    /// Fetches the audit finding for a specific scenario.
    public static func finding(for scenario: LockScreenScenario) -> ScenarioAuditResult? {
        scenarioResults.first { $0.scenario == scenario }
    }
}
