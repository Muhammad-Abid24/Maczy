import XCTest
@testable import MaczyKit

@MainActor
final class UninstallerTests: XCTestCase {

    func testInstalledAppPropertiesAndFormatting() {
        let app = InstalledApp(
            name: "DemoApp",
            bundleIdentifier: "com.example.DemoApp",
            version: "2.1.0",
            publisher: "Example Inc.",
            bundleURL: URL(fileURLWithPath: "/Applications/DemoApp.app"),
            bundleSizeBytes: 150_000_000,
            isSystemApp: false,
            isRunning: false
        )

        XCTAssertEqual(app.name, "DemoApp")
        XCTAssertEqual(app.bundleIdentifier, "com.example.DemoApp")
        XCTAssertEqual(app.version, "2.1.0")
        XCTAssertFalse(app.isSystemApp)
        XCTAssertFalse(app.isRunning)
        XCTAssertFalse(app.formattedBundleSize.isEmpty)
        XCTAssertEqual(app.locationPath, "/Applications/DemoApp.app")
    }

    func testLeftoverItemSafetyClassification() {
        let safeCache = AppLeftoverItem(
            path: "/Users/test/Library/Caches/com.example.DemoApp",
            name: "Cache",
            locationType: .caches,
            fileSizeBytes: 25_000_000,
            safety: .safe
        )
        XCTAssertEqual(safeCache.safety, .safe)
        XCTAssertTrue(safeCache.isSelected)

        let reviewConfig = AppLeftoverItem(
            path: "/Users/test/Library/Application Support/DemoApp",
            name: "App Support",
            locationType: .applicationSupport,
            fileSizeBytes: 50_000_000,
            safety: .reviewRequired
        )
        XCTAssertEqual(reviewConfig.safety, .reviewRequired)

        let protectedDb = AppLeftoverItem(
            path: "/Users/test/Library/Keychains/login.keychain-db",
            name: "Keychain",
            locationType: .other,
            fileSizeBytes: 10_000,
            safety: .protected,
            isSelected: false
        )
        XCTAssertEqual(protectedDb.safety, .protected)
    }

    func testUninstallManifestCalculations() {
        let app = InstalledApp(
            name: "DemoApp",
            bundleIdentifier: "com.example.DemoApp",
            bundleURL: URL(fileURLWithPath: "/Applications/DemoApp.app"),
            bundleSizeBytes: 100_000_000,
            isSystemApp: false,
            isRunning: false
        )

        let leftover1 = AppLeftoverItem(
            path: "/Users/test/Library/Caches/com.example.DemoApp",
            name: "Cache",
            locationType: .caches,
            fileSizeBytes: 20_000_000,
            isSelected: true
        )

        let leftover2 = AppLeftoverItem(
            path: "/Users/test/Library/Logs/DemoApp.log",
            name: "Log",
            locationType: .logs,
            fileSizeBytes: 5_000_000,
            isSelected: false
        )

        let manifest = UninstallManifest(
            app: app,
            leftoverItems: [leftover1, leftover2]
        )

        XCTAssertEqual(manifest.selectedLeftovers.count, 1)
        XCTAssertEqual(manifest.totalRemovalSizeBytes, 120_000_000)
        XCTAssertTrue(manifest.canRemoveDirectlyToTrash)
        XCTAssertNil(manifest.blockingReason)
    }

    func testSystemAppBlockedFromUninstall() {
        let sysApp = InstalledApp(
            name: "Safari",
            bundleIdentifier: "com.apple.Safari",
            bundleURL: URL(fileURLWithPath: "/System/Applications/Safari.app"),
            bundleSizeBytes: 50_000_000,
            isSystemApp: true,
            isRunning: false
        )

        let manifest = UninstallManifest(app: sysApp, leftoverItems: [])
        XCTAssertFalse(manifest.canRemoveDirectlyToTrash)
        XCTAssertNotNil(manifest.blockingReason)
        XCTAssertTrue(manifest.blockingReason!.contains("System applications"))
    }

    func testRunningAppBlockedFromUninstall() {
        let runningApp = InstalledApp(
            name: "ActiveApp",
            bundleIdentifier: "com.example.Active",
            bundleURL: URL(fileURLWithPath: "/Applications/ActiveApp.app"),
            bundleSizeBytes: 50_000_000,
            isSystemApp: false,
            isRunning: true
        )

        let manifest = UninstallManifest(app: runningApp, leftoverItems: [])
        XCTAssertFalse(manifest.canRemoveDirectlyToTrash)
        XCTAssertNotNil(manifest.blockingReason)
        XCTAssertTrue(manifest.blockingReason!.contains("currently running"))
    }

    func testUninstallManagerDiscoveryAndFiltering() async {
        let mock = MockAppInventoryProvider()
        let manager = UninstallManager(inventoryProvider: mock)

        manager.scanInstalledApps()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(manager.installedApps.count, 3)
        XCTAssertEqual(manager.selectedApp?.name, "Figma")

        // Search query filter
        manager.searchQuery = "Figma"
        XCTAssertEqual(manager.filteredApps.count, 1)
        XCTAssertEqual(manager.filteredApps.first?.name, "Figma")

        manager.searchQuery = "nonexistent"
        XCTAssertTrue(manager.filteredApps.isEmpty)
    }

    func testUninstallManagerLeftoverSelectionToggle() async {
        let mock = MockAppInventoryProvider()
        let manager = UninstallManager(inventoryProvider: mock)

        manager.scanInstalledApps()
        try? await Task.sleep(nanoseconds: 50_000_000)

        if let figma = manager.installedApps.first(where: { $0.name == "Figma" }) {
            manager.selectApp(figma)
            try? await Task.sleep(nanoseconds: 50_000_000)

            XCTAssertFalse(manager.selectedAppLeftovers.isEmpty)
            let firstId = manager.selectedAppLeftovers[0].id
            let wasSelected = manager.selectedAppLeftovers[0].isSelected

            manager.toggleLeftoverSelection(id: firstId)
            XCTAssertEqual(manager.selectedAppLeftovers[0].isSelected, !wasSelected)
        }
    }

    func testUninstallManagerConfirmMoveToTrashWithMock() async throws {
        let mock = MockAppInventoryProvider()
        let manager = UninstallManager(inventoryProvider: mock)

        manager.scanInstalledApps()
        try? await Task.sleep(nanoseconds: 50_000_000)

        if let figma = manager.installedApps.first(where: { $0.name == "Figma" }) {
            manager.selectApp(figma)
            try? await Task.sleep(nanoseconds: 50_000_000)

            manager.prepareUninstallManifest()
            XCTAssertNotNil(manager.pendingUninstallManifest)

            let result = try manager.confirmUninstallToTrash()
            XCTAssertTrue(result.success)
            XCTAssertFalse(mock.trashedURLs.isEmpty)
            XCTAssertNil(manager.pendingUninstallManifest)
            XCTAssertEqual(manager.operationHistory.count, 1)
            XCTAssertFalse(manager.installedApps.contains(where: { $0.id == figma.id }))
        }
    }

    func testDisposableFixtureTrashOperation() throws {
        // Safe disposable fixture test on temporary disk location
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dummyAppURL = tempDir.appendingPathComponent("DisposableTest.app")
        try "fake binary".write(to: dummyAppURL, atomically: true, encoding: .utf8)

        let provider = NativeAppInventoryProvider()
        let trashed = try provider.moveItemsToTrash(urls: [dummyAppURL])

        XCTAssertFalse(trashed.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dummyAppURL.path))
    }
}
