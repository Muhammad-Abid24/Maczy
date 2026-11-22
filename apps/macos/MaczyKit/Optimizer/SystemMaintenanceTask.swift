import Foundation

public enum MaintenanceTaskId: String, CaseIterable, Identifiable, Sendable {
    case loginItemsReview = "login_items_review"
    case dnsCacheReview = "dns_cache_review"
    case quickLookCache = "quick_look_cache"
    case developerArtifacts = "developer_artifacts"
    case safeUserTempReview = "safe_user_temp_review"

    public var id: String { rawValue }
}

public enum MaintenanceRiskLevel: String, CaseIterable, Identifiable, Sendable {
    case low = "Low risk"
    case medium = "Review"
    case noChange = "No change"

    public var id: String { rawValue }
}

public struct MaintenanceAction: Identifiable, Equatable, Sendable {
    public let id: MaintenanceTaskId
    public let title: String
    public let category: String
    public let icon: String
    public let whatChanges: String
    public let expectedEffect: String
    public let reversible: String
    public let riskLevel: MaintenanceRiskLevel
    public let potentialImpact: String
    public let requiredPermission: String
    public let isExecutable: Bool

    public init(
        id: MaintenanceTaskId,
        title: String,
        category: String,
        icon: String,
        whatChanges: String,
        expectedEffect: String,
        reversible: String,
        riskLevel: MaintenanceRiskLevel,
        potentialImpact: String,
        requiredPermission: String = "User level",
        isExecutable: Bool = true
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.icon = icon
        self.whatChanges = whatChanges
        self.expectedEffect = expectedEffect
        self.reversible = reversible
        self.riskLevel = riskLevel
        self.potentialImpact = potentialImpact
        self.requiredPermission = requiredPermission
        self.isExecutable = isExecutable
    }

    public static let standardActions: [MaintenanceAction] = [
        MaintenanceAction(
            id: .loginItemsReview,
            title: "Review Login Items",
            category: "Startup & Login Items",
            icon: "sparkles",
            whatChanges: "Opens the supported macOS System Settings location; no silent modifications.",
            expectedEffect: "Fewer optional processes launch at sign-in, reducing cold-boot memory overhead.",
            reversible: "Yes, through System Settings.",
            riskLevel: .low,
            potentialImpact: "Background sync or menu bar helpers you disable.",
            requiredPermission: "Settings Access",
            isExecutable: true
        ),
        MaintenanceAction(
            id: .dnsCacheReview,
            title: "DNS Cache Review",
            category: "System Maintenance",
            icon: "network",
            whatChanges: "Flushes the local macOS mDNSResponder resolver cache.",
            expectedEffect: "Forces fresh DNS lookups; resolves stale domain routing and host resolution errors.",
            reversible: "Automatic (re-cached on next network request).",
            riskLevel: .low,
            potentialImpact: "Next request to recently visited domains takes a few extra milliseconds.",
            requiredPermission: "User level",
            isExecutable: true
        ),
        MaintenanceAction(
            id: .quickLookCache,
            title: "Quick Look Cache",
            category: "System Maintenance",
            icon: "eye.fill",
            whatChanges: "Resets the Quick Look thumbnail and preview cache via qlmanage.",
            expectedEffect: "Fixes broken thumbnail renders and frees stale preview cache storage.",
            reversible: "Automatic (thumbnails regenerate upon viewing files in Finder).",
            riskLevel: .low,
            potentialImpact: "Initial Finder preview generation may have brief render latency.",
            requiredPermission: "User level",
            isExecutable: true
        ),
        MaintenanceAction(
            id: .developerArtifacts,
            title: "Developer Artifacts",
            category: "Developer Maintenance",
            icon: "hammer.fill",
            whatChanges: "Cleans stale Xcode DerivedData, simulator caches, and package manager build caches.",
            expectedEffect: "Reclaims multi-gigabyte disk space without touching source code or git repos.",
            reversible: "Yes (Xcode and Cargo will recompile modules on next build).",
            riskLevel: .medium,
            potentialImpact: "First build after cleaning will be a clean build (longer compilation time).",
            requiredPermission: "User level",
            isExecutable: true
        ),
        MaintenanceAction(
            id: .safeUserTempReview,
            title: "Stale User Temp Files",
            category: "System Maintenance",
            icon: "clock.arrow.2.circlepath",
            whatChanges: "Safely analyzes orphaned temporary files older than 7 days in $TMPDIR.",
            expectedEffect: "Reclaims storage space from abandoned application runtime dumps.",
            reversible: "Moved to Trash rather than permanently erased.",
            riskLevel: .low,
            potentialImpact: "None for files older than 7 days.",
            requiredPermission: "User level",
            isExecutable: true
        )
    ]
}
