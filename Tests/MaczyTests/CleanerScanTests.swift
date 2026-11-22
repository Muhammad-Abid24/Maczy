import XCTest
@testable import MaczyKit

@MainActor
final class CleanerScanTests: XCTestCase {

    func testCleanCategoryMappings() {
        XCTAssertEqual(CleanCategory.allCases.count, 6)
        for category in CleanCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty)
            XCTAssertFalse(category.icon.isEmpty)
            XCTAssertFalse(category.candidateDirectories.isEmpty)
        }
    }

    func testCleanerExclusionsStrictProtection() {
        // System paths
        XCTAssertTrue(CleanerExclusions.isProtected(path: "/System/Library/CoreServices").isProtected)
        XCTAssertTrue(CleanerExclusions.isProtected(path: "/usr/bin/python3").isProtected)
        XCTAssertTrue(CleanerExclusions.isProtected(path: "/bin/sh").isProtected)

        // User personal directories
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertTrue(CleanerExclusions.isProtected(path: "\(home)/Documents/report.pdf").isProtected)
        XCTAssertTrue(CleanerExclusions.isProtected(path: "\(home)/Desktop/screenshot.png").isProtected)
        XCTAssertTrue(CleanerExclusions.isProtected(path: "\(home)/Downloads/installer.dmg").isProtected)

        // Credential and VCS repositories
        XCTAssertTrue(CleanerExclusions.isProtected(path: "\(home)/Project/.git/config").isProtected)
        XCTAssertTrue(CleanerExclusions.isProtected(path: "\(home)/.ssh/id_ed25519").isProtected)
        XCTAssertTrue(CleanerExclusions.isProtected(path: "\(home)/.gnupg/pubring.kbx").isProtected)
        XCTAssertTrue(CleanerExclusions.isProtected(path: "\(home)/Library/Keychains/login.keychain-db").isProtected)
        XCTAssertTrue(CleanerExclusions.isProtected(path: "\(home)/Library/Application Support/1Password/data").isProtected)
        XCTAssertTrue(CleanerExclusions.isProtected(path: "\(home)/Library/Application Support/Bitwarden").isProtected)

        // Databases and cryptographic keys
        XCTAssertTrue(CleanerExclusions.isProtected(path: "/tmp/app.sqlite").isProtected)
        XCTAssertTrue(CleanerExclusions.isProtected(path: "/tmp/cert.pem").isProtected)
        XCTAssertTrue(CleanerExclusions.isProtected(path: "/tmp/private.key").isProtected)

        // Safe cache file should not be protected
        XCTAssertFalse(CleanerExclusions.isProtected(path: "\(home)/Library/Caches/com.apple.Safari/fsCachedData/file1").isProtected)
    }

    func testCleanerScanManifestComputation() {
        let item1 = CleanerManifestItem(
            path: "/path/1",
            name: "item1",
            category: .userCaches,
            fileSizeBytes: 100_000,
            isSafeToPurge: true
        )
        let item2 = CleanerManifestItem(
            path: "/path/2",
            name: "item2",
            category: .userCaches,
            fileSizeBytes: 200_000,
            isSafeToPurge: true
        )
        let item3 = CleanerManifestItem(
            path: "/path/3",
            name: "item3",
            category: .xcodeDerivedData,
            fileSizeBytes: 700_000,
            isSafeToPurge: true
        )
        let unsafeItem = CleanerManifestItem(
            path: "/path/4",
            name: "item4",
            category: .systemLogs,
            fileSizeBytes: 50_000,
            isSafeToPurge: false
        )

        let manifest = CleanerScanManifest(items: [item1, item2, item3, unsafeItem])

        XCTAssertEqual(manifest.totalScanSizeBytes, 1_050_000)
        XCTAssertEqual(manifest.reclaimableSizeBytes, 1_000_000)
        XCTAssertEqual(manifest.categoryBreakdown[.userCaches], 300_000)
        XCTAssertEqual(manifest.categoryBreakdown[.xcodeDerivedData], 700_000)
        XCTAssertNil(manifest.categoryBreakdown[.systemLogs]) // unsafe item omitted from reclaimable breakdown
        XCTAssertEqual(manifest.categoryCounts[.userCaches], 2)
        XCTAssertEqual(manifest.categoryCounts[.systemLogs], 1)
        XCTAssertFalse(manifest.formattedReclaimableSize.isEmpty)
    }

    func testMockCleanerScannerScan() async throws {
        let mock = MockCleanerScannerProvider()
        let manifest = try await mock.scan(categories: [.browserCaches, .systemLogs], onProgress: nil)

        XCTAssertEqual(manifest.items.count, 2)
        XCTAssertTrue(manifest.items.contains(where: { $0.category == .browserCaches }))
        XCTAssertTrue(manifest.items.contains(where: { $0.category == .systemLogs }))
        XCTAssertFalse(manifest.items.contains(where: { $0.category == .xcodeDerivedData }))
    }

    func testCleanerManagerLifecycle() async {
        let mock = MockCleanerScannerProvider()
        let manager = CleanerManager(scanner: mock)

        XCTAssertFalse(manager.isScanning)
        XCTAssertNil(manager.lastManifest)

        manager.startScan()
        XCTAssertTrue(manager.isScanning)

        // Wait a brief moment for the async task to complete
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertFalse(manager.isScanning)
        XCTAssertNotNil(manager.lastManifest)
        XCTAssertEqual(manager.progress, 1.0)
    }

    func testCleanerManagerCategoryToggle() {
        let mock = MockCleanerScannerProvider()
        let manager = CleanerManager(scanner: mock)

        XCTAssertTrue(manager.selectedCategories.contains(.browserCaches))
        manager.toggleCategory(.browserCaches)
        XCTAssertFalse(manager.selectedCategories.contains(.browserCaches))

        manager.toggleCategory(.browserCaches)
        XCTAssertTrue(manager.selectedCategories.contains(.browserCaches))
    }

    func testMZ029DeletionGateFailsClosed() {
        let mock = MockCleanerScannerProvider()
        let manager = CleanerManager(scanner: mock)

        // Strict Security Invariant: Any deletion attempt is rejected with GATE_MZ_029
        let result = manager.requestCleanupExecution()
        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.errorCode, "GATE_MZ_029")
    }

    func testAppStateCleanerActions() {
        let mock = MockCleanerScannerProvider()
        let manager = CleanerManager(scanner: mock)
        let appState = AppState(cleanerManager: manager)

        let startResult = appState.dispatch(.startCleanerScan)
        XCTAssertTrue(startResult.ok)
        XCTAssertEqual(appState.status(for: .systemCleaner)?.runtimeState, .running)

        let cancelResult = appState.dispatch(.cancelCleanerScan)
        XCTAssertTrue(cancelResult.ok)
        XCTAssertEqual(appState.status(for: .systemCleaner)?.runtimeState, .idle)

        // MZ-029 Action Gating
        let purgeUnconfirmed = appState.dispatch(.executeCleanerPurge(confirmed: false))
        XCTAssertFalse(purgeUnconfirmed.ok)
        XCTAssertEqual(purgeUnconfirmed.errorCode, "GATE_MZ_029")

        let purgeConfirmed = appState.dispatch(.executeCleanerPurge(confirmed: true))
        XCTAssertTrue(purgeConfirmed.ok)
    }

    func testMZ029ExecutionMovesItemsToTrashInDisposableFixture() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("maczy_fixture_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dummyCache = tempDir.appendingPathComponent("test_cache.dat")
        try "test-data-payload".write(to: dummyCache, atomically: true, encoding: .utf8)

        let item = CleanerManifestItem(
            path: dummyCache.path,
            name: "test_cache.dat",
            category: .userCaches,
            fileSizeBytes: 17,
            isSafeToPurge: true
        )

        let mockScanner = MockCleanerScannerProvider(cannedItems: [item])
        let mockExecution = MockCleanupExecutionProvider()
        let manager = CleanerManager(
            scanner: mockScanner,
            executionProvider: mockExecution,
            initiallyApproved: true
        )

        manager.startScan()
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertNotNil(manager.lastManifest)
        XCTAssertEqual(manager.lastManifest?.items.count, 1)

        let cleanupResult = try await manager.executeCleanup()
        XCTAssertTrue(cleanupResult.success)
        XCTAssertEqual(cleanupResult.trashedPaths, [dummyCache.path])
        XCTAssertEqual(cleanupResult.totalReclaimedBytes, 17)
        XCTAssertTrue(mockExecution.trashedURLs.contains(dummyCache))
        XCTAssertNil(manager.lastManifest) // All items cleaned
        XCTAssertNotNil(manager.lastCleanupResult)
    }

    func testMZ029ExecutionStrictlyRejectsProtectedFiles() async throws {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let protectedGit = CleanerManifestItem(
            path: "\(home)/Project/.git/config",
            name: "config",
            category: .userCaches,
            fileSizeBytes: 100,
            isSafeToPurge: true
        )
        let protectedDoc = CleanerManifestItem(
            path: "\(home)/Documents/secret.pdf",
            name: "secret.pdf",
            category: .userCaches,
            fileSizeBytes: 200,
            isSafeToPurge: true
        )

        let mockScanner = MockCleanerScannerProvider(cannedItems: [protectedGit, protectedDoc])
        let mockExecution = MockCleanupExecutionProvider()
        let manager = CleanerManager(
            scanner: mockScanner,
            executionProvider: mockExecution,
            initiallyApproved: true
        )

        manager.startScan()
        try await Task.sleep(nanoseconds: 50_000_000)

        let result = try await manager.executeCleanup()
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.trashedPaths.count, 0)
        XCTAssertEqual(result.failedPaths.count, 2)
        XCTAssertEqual(mockExecution.trashedURLs.count, 0)
    }

    func testAppStateEmptyTrashAction() {
        let mock = MockCleanerScannerProvider()
        let manager = CleanerManager(scanner: mock)
        let appState = AppState(cleanerManager: manager)

        let emptyUnconfirmed = appState.dispatch(.emptyTrash(confirmed: false))
        XCTAssertFalse(emptyUnconfirmed.ok)
        XCTAssertEqual(emptyUnconfirmed.errorCode, "GATE_MZ_029")

        let emptyConfirmed = appState.dispatch(.emptyTrash(confirmed: true))
        XCTAssertTrue(emptyConfirmed.ok)
    }

    func testCleanerManagerWorkflowReset() {
        let mock = MockCleanerScannerProvider()
        let manager = CleanerManager(scanner: mock, initiallyApproved: true)

        manager.resetCleanerWorkflow()
        XCTAssertNil(manager.lastManifest)
        XCTAssertNil(manager.lastCleanupResult)
        XCTAssertFalse(manager.isCleanupApproved)
        XCTAssertFalse(manager.trashEmptied)
        XCTAssertNil(manager.trashEmptyMessage)
    }
}
