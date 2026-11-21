import XCTest
@testable import MaczyKit

@MainActor
final class OptimizerTests: XCTestCase {

    func testStandardMaintenanceActionsConfiguration() {
        let actions = MaintenanceAction.standardActions
        XCTAssertEqual(actions.count, 5)

        for action in actions {
            XCTAssertFalse(action.title.isEmpty)
            XCTAssertFalse(action.category.isEmpty)
            XCTAssertFalse(action.whatChanges.isEmpty)
            XCTAssertFalse(action.expectedEffect.isEmpty)
            XCTAssertFalse(action.reversible.isEmpty)
            XCTAssertFalse(action.potentialImpact.isEmpty)
            XCTAssertFalse(action.requiredPermission.isEmpty)
        }

        // Verify specific tasks exist
        XCTAssertTrue(actions.contains(where: { $0.id == .loginItemsReview }))
        XCTAssertTrue(actions.contains(where: { $0.id == .dnsCacheReview }))
        XCTAssertTrue(actions.contains(where: { $0.id == .quickLookCache }))
        XCTAssertTrue(actions.contains(where: { $0.id == .developerArtifacts }))
        XCTAssertTrue(actions.contains(where: { $0.id == .safeUserTempReview }))
    }

    func testStartupItemProviderMock() async {
        let mock = MockStartupItemProvider()
        let items = await mock.fetchStartupItems()

        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items.contains(where: { $0.name == "Docker Desktop" }))

        let opened = mock.openLoginItemsSettings()
        XCTAssertTrue(opened)
        XCTAssertEqual(mock.openedSettingsCount, 1)
    }

    func testDeveloperArtifactScannerMock() async throws {
        let mock = MockDeveloperArtifactScannerProvider()
        let items = try await mock.scanArtifacts()

        XCTAssertEqual(items.count, 5)
        XCTAssertTrue(items.contains(where: { $0.category == .xcodeDerivedData }))
        XCTAssertTrue(items.contains(where: { $0.category == .cargoCaches }))
        XCTAssertTrue(items.contains(where: { $0.category == .nodeCaches }))

        let totalBytes = items.reduce(0) { $0 + $1.fileSizeBytes }
        XCTAssertGreaterThan(totalBytes, 4_000_000_000)
    }

    func testSystemResourceMonitorMetrics() {
        let metrics = SystemResourceMetrics(
            cpuUsagePercent: 15.5,
            memoryUsedBytes: 12_000_000_000,
            memoryTotalBytes: 32_000_000_000,
            memoryPressurePercent: 40.0,
            diskFreeBytes: 250_000_000_000,
            diskTotalBytes: 1_000_000_000_000,
            heavyAppsCount: 3
        )

        XCTAssertEqual(metrics.cpuUsagePercent, 15.5)
        XCTAssertEqual(metrics.heavyAppsCount, 3)
        XCTAssertFalse(metrics.formattedMemory.isEmpty)
        XCTAssertFalse(metrics.formattedDiskFree.isEmpty)

        let mockMonitor = MockSystemResourceMonitor(cannedMetrics: metrics)
        let read = mockMonitor.readMetrics()
        XCTAssertEqual(read.cpuUsagePercent, 15.5)
    }

    func testOptimizerManagerLifecycleAndExecution() async {
        let startupMock = MockStartupItemProvider()
        let devMock = MockDeveloperArtifactScannerProvider()
        let monitorMock = MockSystemResourceMonitor()

        let manager = OptimizerManager(
            startupProvider: startupMock,
            developerScanner: devMock,
            resourceMonitor: monitorMock
        )

        XCTAssertNotNil(manager.selectedAction)
        manager.refreshMetrics()
        XCTAssertEqual(manager.systemMetrics.heavyAppsCount, 0)

        // Switch action to login items review
        if let loginAction = manager.maintenanceActions.first(where: { $0.id == .loginItemsReview }) {
            manager.selectAction(loginAction)
            XCTAssertEqual(manager.selectedAction?.id, .loginItemsReview)

            let result = await manager.executeSelectedAction()
            XCTAssertTrue(result.contains("Login Items"))
            XCTAssertEqual(startupMock.openedSettingsCount, 1)
        }

        // Switch to developer artifacts review
        if let devAction = manager.maintenanceActions.first(where: { $0.id == .developerArtifacts }) {
            manager.selectAction(devAction)
            let result = await manager.executeSelectedAction()
            XCTAssertTrue(result.contains("developer build artifact"))
        }
    }

    func testEvidenceFirstSafetyCheck() {
        // Architecture invariant: No unsupported optimizations or speculative speed boosters
        for action in MaintenanceAction.standardActions {
            XCTAssertNotEqual(action.riskLevel, MaintenanceRiskLevel(rawValue: "Dangerous"))
            XCTAssertTrue(action.isExecutable)
            XCTAssertFalse(action.expectedEffect.contains("100% speedup"))
        }
    }
}
