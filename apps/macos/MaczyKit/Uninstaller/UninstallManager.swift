import Foundation
import Combine

@MainActor
public final class UninstallManager: ObservableObject {
    @Published public private(set) var installedApps: [InstalledApp] = []
    @Published public private(set) var selectedApp: InstalledApp?
    @Published public private(set) var selectedAppLeftovers: [AppLeftoverItem] = []
    @Published public private(set) var isScanningApps: Bool = false
    @Published public private(set) var isAnalyzingLeftovers: Bool = false
    @Published public var searchQuery: String = ""
    @Published public var sortBy: AppSortOption = .size
    @Published public private(set) var pendingUninstallManifest: UninstallManifest?
    @Published public private(set) var lastUninstallResult: UninstallResult?
    @Published public private(set) var operationHistory: [UninstallResult] = []

    private let inventoryProvider: AppInventoryProvider

    public init(inventoryProvider: AppInventoryProvider = NativeAppInventoryProvider()) {
        self.inventoryProvider = inventoryProvider
    }

    public var filteredApps: [InstalledApp] {
        var result = installedApps
        if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = searchQuery.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(q) ||
                ($0.bundleIdentifier?.lowercased().contains(q) ?? false)
            }
        }

        switch sortBy {
        case .size:
            result.sort(by: { $0.bundleSizeBytes > $1.bundleSizeBytes })
        case .name:
            result.sort(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        case .lastUsed:
            result.sort(by: { ($0.lastUsedDate ?? .distantPast) > ($1.lastUsedDate ?? .distantPast) })
        }
        return result
    }

    public func scanInstalledApps() {
        guard !isScanningApps else { return }
        isScanningApps = true

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let apps = try await self.inventoryProvider.discoverInstalledApps()
                self.installedApps = apps
                self.isScanningApps = false
                if self.selectedApp == nil, let first = apps.first {
                    self.selectApp(first)
                }
            } catch {
                self.isScanningApps = false
            }
        }
    }

    public func selectApp(_ app: InstalledApp) {
        selectedApp = app
        selectedAppLeftovers = []
        isAnalyzingLeftovers = true

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let leftovers = try await self.inventoryProvider.analyzeLeftovers(for: app)
                if self.selectedApp?.id == app.id {
                    self.selectedAppLeftovers = leftovers
                    self.isAnalyzingLeftovers = false
                }
            } catch {
                self.isAnalyzingLeftovers = false
            }
        }
    }

    public func toggleLeftoverSelection(id: UUID) {
        guard let idx = selectedAppLeftovers.firstIndex(where: { $0.id == id }) else { return }
        if selectedAppLeftovers[idx].safety != .protected {
            selectedAppLeftovers[idx].isSelected.toggle()
        }
    }

    public func prepareUninstallManifest() {
        guard let app = selectedApp else { return }
        pendingUninstallManifest = UninstallManifest(
            app: app,
            leftoverItems: selectedAppLeftovers
        )
    }

    public func dismissManifest() {
        pendingUninstallManifest = nil
    }

    @discardableResult
    public func confirmUninstallToTrash() throws -> UninstallResult {
        guard let manifest = pendingUninstallManifest else {
            throw NSError(domain: "MaczyUninstaller", code: 400, userInfo: [NSLocalizedDescriptionKey: "No pending uninstall manifest"])
        }

        guard manifest.canRemoveDirectlyToTrash else {
            let reason = manifest.blockingReason ?? "Removal blocked"
            throw NSError(domain: "MaczyUninstaller", code: 403, userInfo: [NSLocalizedDescriptionKey: reason])
        }

        var targets: [URL] = [manifest.app.bundleURL]
        for item in manifest.selectedLeftovers {
            targets.append(URL(fileURLWithPath: item.path))
        }

        var trashed: [String] = []
        var failed: [String] = []

        for target in targets {
            do {
                _ = try inventoryProvider.moveItemsToTrash(urls: [target])
                trashed.append(target.path)
            } catch {
                failed.append(target.path)
            }
        }

        let freedBytes = manifest.totalRemovalSizeBytes
        let result = UninstallResult(
            success: failed.isEmpty,
            trashedPaths: trashed,
            failedPaths: failed,
            totalFreedBytes: freedBytes,
            message: failed.isEmpty ?
                "Successfully moved \(manifest.app.name) and \(manifest.selectedLeftovers.count) associated items to Trash." :
                "Moved \(trashed.count) items to Trash; \(failed.count) items could not be removed."
        )

        self.lastUninstallResult = result
        self.operationHistory.append(result)
        self.pendingUninstallManifest = nil

        // Refresh app list
        self.installedApps.removeAll(where: { $0.id == manifest.app.id })
        self.selectedApp = self.installedApps.first
        if let next = self.selectedApp {
            self.selectApp(next)
        } else {
            self.selectedAppLeftovers = []
        }

        return result
    }
}
