import Foundation

/// Classification of operating system support tiers per ADR-0003.
public enum OSSupportTier: String, Sendable, Equatable {
    case tier1Supported = "Tier 1: Fully Supported (macOS 14–15)"
    case tier2ForwardProjected = "Tier 2: Forward-Compatible (macOS 16–27)"
    case unsupported = "Unsupported (< macOS 14.0)"

    public var isExecutable: Bool {
        self != .unsupported
    }
}

/// Severity classification of system API usage risks.
public enum APIRiskLevel: String, Sendable, Equatable {
    case low = "Low Risk (Public Stable API)"
    case medium = "Medium Risk (TCC / Dynamic Fallback)"
    case critical = "Critical Risk (Security Gated)"
}

/// Risk evaluation entry for a specific Maczy functional module.
public struct ModuleRiskAssessment: Sendable, Identifiable, Equatable {
    public let id: String
    public let moduleName: String
    public let primaryAPI: String
    public let riskLevel: APIRiskLevel
    public let mitigation: String

    public init(id: String, moduleName: String, primaryAPI: String, riskLevel: APIRiskLevel, mitigation: String) {
        self.id = id
        self.moduleName = moduleName
        self.primaryAPI = primaryAPI
        self.riskLevel = riskLevel
        self.mitigation = mitigation
    }
}

/// Third-party dependency open-source license information.
public struct ThirdPartyLicenseEntry: Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let version: String
    public let license: String
    public let isCopyleft: Bool

    public init(name: String, version: String, license: String, isCopyleft: Bool = false) {
        self.id = name
        self.name = name
        self.version = version
        self.license = license
        self.isCopyleft = isCopyleft
    }
}

/// Programmatic compatibility, API risk register, and license audit engine (MZ-025).
public struct CompatibilityMatrix: Sendable {
    
    /// Minimum required macOS version: macOS 14.0 Sonoma.
    public static let minimumSupportedOSVersion = OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0)

    /// Highest projected macOS version audited for forward compatibility: macOS 27.
    public static let maxProjectedOSVersion = OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)

    /// Audited third-party open-source dependency registry.
    public static let dependencyLicenses: [ThirdPartyLicenseEntry] = [
        ThirdPartyLicenseEntry(name: "serde", version: "1.0", license: "MIT OR Apache-2.0"),
        ThirdPartyLicenseEntry(name: "serde_derive", version: "1.0", license: "MIT OR Apache-2.0"),
        ThirdPartyLicenseEntry(name: "syn", version: "2.0", license: "MIT OR Apache-2.0"),
        ThirdPartyLicenseEntry(name: "quote", version: "1.0", license: "MIT OR Apache-2.0"),
        ThirdPartyLicenseEntry(name: "proc-macro2", version: "1.0", license: "MIT OR Apache-2.0"),
        ThirdPartyLicenseEntry(name: "unicode-ident", version: "1.0", license: "(MIT OR Apache-2.0) AND Unicode-DFS-2016"),
        ThirdPartyLicenseEntry(name: "Sparkle", version: "2.x", license: "MIT")
    ]

    /// System API Risk Register across all functional modules.
    public static let apiRiskRegister: [ModuleRiskAssessment] = [
        ModuleRiskAssessment(
            id: "capture",
            moduleName: "Screen Capture & OCR",
            primaryAPI: "ScreenCaptureKit & Apple Vision",
            riskLevel: .low,
            mitigation: "Preflight permission check with graceful fallback to unauthorized state."
        ),
        ModuleRiskAssessment(
            id: "recording",
            moduleName: "Display & Window Recording",
            primaryAPI: "ScreenCaptureKit + AVAssetWriter (HEVC/AAC)",
            riskLevel: .low,
            mitigation: "Strict hardware-accelerated pipeline; clean file closure on cancellation."
        ),
        ModuleRiskAssessment(
            id: "battery",
            moduleName: "Battery Guardian",
            primaryAPI: "IOKit IOPowerSources & AppleSmartBattery",
            riskLevel: .low,
            mitigation: "Safe SBS 1.1 dictionary parsing; AC Power fallback on desktop Macs."
        ),
        ModuleRiskAssessment(
            id: "notch",
            moduleName: "Dynamic Notch & Islands",
            primaryAPI: "AppKit NSPanel (.floating, .canJoinAllSpaces)",
            riskLevel: .low,
            mitigation: "Precision physical notch detection with virtual pill fallback on external screens."
        ),
        ModuleRiskAssessment(
            id: "snap",
            moduleName: "Window Snap",
            primaryAPI: "ApplicationServices AXUIElement",
            riskLevel: .medium,
            mitigation: "Protected process blacklist (Dock/WindowServer); bounded FIFO undo stack."
        ),
        ModuleRiskAssessment(
            id: "lock",
            moduleName: "Lock Screen Quick Action",
            primaryAPI: "SACLockScreenImmediate via login.framework",
            riskLevel: .medium,
            mitigation: "Dynamic symbol binding with automatic fallback to CGSession -suspend."
        ),
        ModuleRiskAssessment(
            id: "tws",
            moduleName: "AirPods / TWS Animation",
            primaryAPI: "IOBluetooth notification & IORegistry",
            riskLevel: .low,
            mitigation: "Auto-dismissing toast; mockable observer injection."
        ),
        ModuleRiskAssessment(
            id: "unlock",
            moduleName: "Smart Unlock",
            primaryAPI: "LocalAuthentication & Camera",
            riskLevel: .critical,
            mitigation: "GATED by MZ-023. Lock screen Face Unlock remains BLOCKED to preserve system security."
        )
    ]

    /// Evaluates whether an OS version satisfies Maczy requirements and determines its support tier.
    public static func evaluateOSVersion(_ version: OperatingSystemVersion) -> OSSupportTier {
        if version.majorVersion < 14 {
            return .unsupported
        } else if version.majorVersion <= 15 {
            return .tier1Supported
        } else {
            return .tier2ForwardProjected
        }
    }

    /// Evaluates hardware architecture compatibility (Apple Silicon arm64 only).
    public static func isArchitectureSupported(_ arch: String) -> Bool {
        arch.lowercased().contains("arm64") || arch.lowercased().contains("aarch64")
    }

    /// Validates system compatibility.
    public static func validateSystem(
        osVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion,
        architecture: String = "arm64"
    ) -> (isSupported: Bool, tier: OSSupportTier, reason: String) {
        let tier = evaluateOSVersion(osVersion)
        guard tier.isExecutable else {
            return (
                false,
                tier,
                "macOS version \(osVersion.majorVersion).\(osVersion.minorVersion) is unsupported. Minimum required is macOS 14.0 (Sonoma)."
            )
        }

        guard isArchitectureSupported(architecture) else {
            return (
                false,
                tier,
                "Architecture '\(architecture)' is unsupported. Maczy is built exclusively for Apple Silicon (arm64)."
            )
        }

        return (true, tier, "System is compatible: \(tier.rawValue)")
    }

    /// Validates license compliance: guarantees zero copyleft licenses exist.
    public static func verifyLicenseCompliance() -> Bool {
        !dependencyLicenses.contains { $0.isCopyleft }
    }
}
