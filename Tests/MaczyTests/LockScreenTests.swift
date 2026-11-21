import XCTest
@testable import MaczyKit

final class LockScreenTests: XCTestCase {

    @MainActor
    func testMockSystemLockSuccess() {
        let mock = MockSystemLockProvider(shouldSucceed: true)
        let manager = SystemLockManager(provider: mock)

        let result = manager.lockScreen()
        XCTAssertTrue(result.ok)
        XCTAssertEqual(result.observedValue, "locked")
        XCTAssertNotNil(result.message)
        XCTAssertEqual(mock.lockCount, 1)
        XCTAssertNotNil(manager.lastLockAttemptDate)
        XCTAssertEqual(manager.lastResult, result)
    }

    @MainActor
    func testMockSystemLockFailure() {
        let mock = MockSystemLockProvider(shouldSucceed: false)
        let manager = SystemLockManager(provider: mock)

        let result = manager.lockScreen()
        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.errorCode, "LOCK_ERROR")
        XCTAssertEqual(mock.lockCount, 1)
        XCTAssertNotNil(manager.lastLockAttemptDate)
    }

    @MainActor
    func testProviderSwapping() {
        let mock1 = MockSystemLockProvider(shouldSucceed: true)
        let mock2 = MockSystemLockProvider(shouldSucceed: true)
        let manager = SystemLockManager(provider: mock1)

        _ = manager.lockScreen()
        XCTAssertEqual(mock1.lockCount, 1)
        XCTAssertEqual(mock2.lockCount, 0)

        manager.setProvider(mock2)
        _ = manager.lockScreen()
        XCTAssertEqual(mock1.lockCount, 1)
        XCTAssertEqual(mock2.lockCount, 1)
    }

    @MainActor
    func testAppStateLockScreenActionDispatch() {
        let mock = MockSystemLockProvider(shouldSucceed: true)
        SystemLockManager.shared.setProvider(mock)

        let appState = AppState(debounceInterval: 0.0)
        let result = appState.dispatch(.lockScreen)

        XCTAssertTrue(result.ok)
        XCTAssertEqual(mock.lockCount, 1)

        // Restore native provider for safety
        SystemLockManager.shared.setProvider(NativeSystemLockProvider())
    }

    @MainActor
    func testAppStateLockScreenDebounce() {
        let mock = MockSystemLockProvider(shouldSucceed: true)
        SystemLockManager.shared.setProvider(mock)

        let appState = AppState(debounceInterval: 1.0)
        let result1 = appState.dispatch(.lockScreen)
        XCTAssertTrue(result1.ok)

        let result2 = appState.dispatch(.lockScreen)
        XCTAssertFalse(result2.ok)
        XCTAssertEqual(result2.errorCode, "ACTION_DEBOUNCED")
        XCTAssertEqual(mock.lockCount, 1)

        // Restore native provider
        SystemLockManager.shared.setProvider(NativeSystemLockProvider())
    }
}
