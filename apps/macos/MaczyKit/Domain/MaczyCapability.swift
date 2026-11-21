import Foundation

/// Declares system capabilities, platform compatibility, and permission prerequisites per ARCHITECTURE.md.
public struct ModuleCapability: Sendable, Equatable {
    public let moduleId: MaczyModuleId
    public let isSupported: Bool
    public let reason: String?
    public let requiredPermissions: [MaczyPermission]
    public let backend: String?

    public init(
        moduleId: MaczyModuleId,
        isSupported: Bool,
        reason: String?,
        requiredPermissions: [MaczyPermission] = [],
        backend: String? = nil
    ) {
        self.moduleId = moduleId
        self.isSupported = isSupported
        self.reason = reason
        self.requiredPermissions = requiredPermissions
        self.backend = backend
    }

    public static func defaultFor(moduleId: MaczyModuleId) -> ModuleCapability {
        switch moduleId {
        case .captureAndRecording:
            return ModuleCapability(
                moduleId: moduleId,
                isSupported: true,
                reason: "ScreenCaptureKit available on macOS 14+",
                requiredPermissions: [.screenRecording],
                backend: "ScreenCaptureKit"
            )
        case .batteryGuardian:
            return ModuleCapability(
                moduleId: moduleId,
                isSupported: true,
                reason: "Battery health monitoring available; write controls gated by MZ-014",
                requiredPermissions: [],
                backend: "IOKit"
            )
        case .dynamicNotch:
            return ModuleCapability(
                moduleId: moduleId,
                isSupported: true,
                reason: "Hardware notch or virtual island overlay",
                requiredPermissions: [],
                backend: "AppKit Overlay"
            )
        case .smartUnlock:
            return ModuleCapability(
                moduleId: moduleId,
                isSupported: false, // Strictly false until MZ-023 feasibility passes
                reason: "CRITICAL: macOS Lock Screen Face Unlock gated by MZ-023 feasibility and security review. Not implemented. Preserving native Touch ID/password fallback.",
                requiredPermissions: [.camera],
                backend: nil
            )
        case .updates:
            return ModuleCapability(
                moduleId: moduleId,
                isSupported: true,
                reason: "Sparkle 2 EdDSA signed appcast delivery",
                requiredPermissions: [],
                backend: "Sparkle 2"
            )
        case .alwaysOn:
            return ModuleCapability(
                moduleId: moduleId,
                isSupported: true,
                reason: "IOPM scoped power assertions",
                requiredPermissions: [],
                backend: "IOPMAssertion"
            )
        case .systemCleaner:
            return ModuleCapability(
                moduleId: moduleId,
                isSupported: true,
                reason: "Mole-inspired safe read-only scanner; non-destructive defaults; deletion gated by MZ-029",
                requiredPermissions: [],
                backend: "ReadOnlyScanner"
            )
        }
    }
}

/// Registry managing capabilities across all 7 Maczy modules.
public final class CapabilityRegistry: @unchecked Sendable {
    private var capabilities: [MaczyModuleId: ModuleCapability]

    public init() {
        var caps: [MaczyModuleId: ModuleCapability] = [:]
        for id in MaczyModuleId.allCases {
            caps[id] = ModuleCapability.defaultFor(moduleId: id)
        }
        self.capabilities = caps
    }

    public func capability(for id: MaczyModuleId) -> ModuleCapability? {
        capabilities[id]
    }

    public func setCapability(_ capability: ModuleCapability) {
        capabilities[capability.moduleId] = capability
    }
}
