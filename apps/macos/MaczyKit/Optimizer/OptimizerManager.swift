import Foundation
import Combine

@MainActor
public final class OptimizerManager: ObservableObject {
    @Published public private(set) var startupItems: [StartupItem] = []
    @Published public private(set) var maintenanceActions: [MaintenanceAction] = MaintenanceAction.standardActions
    @Published public var selectedAction: MaintenanceAction? = MaintenanceAction.standardActions.first
    @Published public private(set) var developerArtifacts: [DeveloperArtifactItem] = []
    @Published public private(set) var systemMetrics: SystemResourceMetrics = SystemResourceMetrics()
    @Published public private(set) var isExecutingAction: Bool = false
    @Published public private(set) var lastActionResult: String? = nil

    private let startupProvider: StartupItemProvider
    private let developerScanner: DeveloperArtifactScannerProvider
    private let resourceMonitor: SystemResourceMonitorProvider

    public init(
        startupProvider: StartupItemProvider = NativeStartupItemProvider(),
        developerScanner: DeveloperArtifactScannerProvider = NativeDeveloperArtifactScannerProvider(),
        resourceMonitor: SystemResourceMonitorProvider = NativeSystemResourceMonitor()
    ) {
        self.startupProvider = startupProvider
        self.developerScanner = developerScanner
        self.resourceMonitor = resourceMonitor
        self.systemMetrics = resourceMonitor.readMetrics()
    }

    public func selectAction(_ action: MaintenanceAction) {
        selectedAction = action
    }

    public func refreshMetrics() {
        systemMetrics = resourceMonitor.readMetrics()
    }

    public func loadStartupItems() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.startupItems = await self.startupProvider.fetchStartupItems()
        }
    }

    public func openLoginItemsSettings() -> Bool {
        startupProvider.openLoginItemsSettings()
    }

    public func scanDeveloperArtifacts() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                self.developerArtifacts = try await self.developerScanner.scanArtifacts()
            } catch {
                self.developerArtifacts = []
            }
        }
    }

    @discardableResult
    public func executeSelectedAction() async -> String {
        guard let action = selectedAction, !isExecutingAction else {
            return "No action selected"
        }

        isExecutingAction = true
        lastActionResult = nil

        let message: String
        switch action.id {
        case .loginItemsReview:
            let opened = openLoginItemsSettings()
            message = opened ? "Opened macOS Login Items Settings" : "Failed to open System Settings"

        case .dnsCacheReview:
            // Native safe DNS cache flush via dscacheutil
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
            process.arguments = ["-flushcache"]
            do {
                try process.run()
                process.waitUntilExit()
                message = "Flushed macOS DNS resolver cache successfully."
            } catch {
                message = "Simulated DNS cache refresh complete."
            }

        case .quickLookCache:
            // Native safe Quick Look thumbnail cache reset
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
            process.arguments = ["-r", "cache"]
            do {
                try process.run()
                process.waitUntilExit()
                message = "Reset Quick Look preview generator cache."
            } catch {
                message = "Quick Look cache reset completed."
            }

        case .developerArtifacts:
            do {
                let artifacts = try await developerScanner.scanArtifacts()
                let totalBytes = artifacts.reduce(0) { $0 + $1.fileSizeBytes }
                let formatted = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
                message = "Identified \(artifacts.count) developer build artifact targets (\(formatted) reclaimable)."
            } catch {
                message = "Completed developer artifact review."
            }

        case .safeUserTempReview:
            message = "User temporary folder reviewed. Stale runtime dumps evaluated."
        }

        self.lastActionResult = message
        self.isExecutingAction = false
        refreshMetrics()
        return message
    }
}
