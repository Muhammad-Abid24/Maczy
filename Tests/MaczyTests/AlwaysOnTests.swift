import XCTest
@testable import MaczyKit

@MainActor
final class AlwaysOnTests: XCTestCase {

    func testAlwaysOnPresetInitializationAndDurations() {
        let p15 = AlwaysOnPreset(minutes: 15)
        XCTAssertEqual(p15, .fifteenMinutes)
        XCTAssertEqual(p15.durationMinutes, 15)
        XCTAssertEqual(p15.durationSeconds, 900)
        XCTAssertEqual(p15.shortLabel, "15m")

        let p30 = AlwaysOnPreset(minutes: 30)
        XCTAssertEqual(p30, .thirtyMinutes)
        XCTAssertEqual(p30.durationMinutes, 30)
        XCTAssertEqual(p30.durationSeconds, 1800)
        XCTAssertEqual(p30.shortLabel, "30m")

        let p60 = AlwaysOnPreset(minutes: 60)
        XCTAssertEqual(p60, .oneHour)
        XCTAssertEqual(p60.durationMinutes, 60)
        XCTAssertEqual(p60.shortLabel, "1h")

        let p120 = AlwaysOnPreset(minutes: 120)
        XCTAssertEqual(p120, .twoHours)
        XCTAssertEqual(p120.durationMinutes, 120)
        XCTAssertEqual(p120.shortLabel, "2h")

        let pCustom = AlwaysOnPreset(minutes: 45)
        XCTAssertEqual(pCustom, .custom(minutes: 45))
        XCTAssertEqual(pCustom.durationMinutes, 45)
        XCTAssertEqual(pCustom.shortLabel, "45m")

        let pIndefinite = AlwaysOnPreset(minutes: nil)
        XCTAssertEqual(pIndefinite, .indefinite)
        XCTAssertNil(pIndefinite.durationMinutes)
        XCTAssertNil(pIndefinite.durationSeconds)
        XCTAssertEqual(pIndefinite.shortLabel, "∞")
    }

    func testSessionStartAndStopWithMockProvider() {
        let mock = MockPowerAssertionProvider()
        let manager = AlwaysOnManager(powerProvider: mock)

        XCTAssertFalse(manager.isActive)
        XCTAssertEqual(manager.formattedRemainingTime, "Idle")

        let success = manager.startSession(preset: .thirtyMinutes)
        XCTAssertTrue(success)
        XCTAssertTrue(manager.isActive)
        XCTAssertEqual(mock.createdCount, 1)
        XCTAssertEqual(mock.activeCount, 1)
        XCTAssertEqual(mock.lastCreatedType, AlwaysOnMode.systemAndDisplay.assertionType)

        manager.stopSession(reason: .manualStop)
        XCTAssertFalse(manager.isActive)
        XCTAssertEqual(mock.releasedCount, 1)
        XCTAssertEqual(mock.activeCount, 0)
        XCTAssertEqual(manager.formattedRemainingTime, "Idle")
        XCTAssertEqual(manager.lastReleaseReason, .manualStop)
    }

    func testSessionReplacedWhenStartingAnother() {
        let mock = MockPowerAssertionProvider()
        let manager = AlwaysOnManager(powerProvider: mock)

        _ = manager.startSession(preset: .thirtyMinutes)
        XCTAssertEqual(mock.createdCount, 1)
        XCTAssertEqual(mock.activeCount, 1)

        _ = manager.startSession(preset: .oneHour)
        // Should release the previous assertion and create a new one
        XCTAssertEqual(mock.createdCount, 2)
        XCTAssertEqual(mock.releasedCount, 1)
        XCTAssertEqual(mock.activeCount, 1)
        XCTAssertEqual(manager.activeSession?.preset, .oneHour)
    }

    func testSessionExpirationOnTick() {
        let mock = MockPowerAssertionProvider()
        let manager = AlwaysOnManager(powerProvider: mock)

        let start = Date()
        _ = manager.startSession(preset: .fifteenMinutes, startedAt: start)
        XCTAssertTrue(manager.isActive)
        XCTAssertEqual(manager.remainingSeconds, 900)

        // Advance 10 minutes (600 seconds)
        let mid = start.addingTimeInterval(600)
        manager.tick(at: mid)
        XCTAssertTrue(manager.isActive)
        XCTAssertEqual(manager.remainingSeconds, 300)
        XCTAssertEqual(manager.formattedRemainingTime, "05:00")

        // Advance past expiration (901 seconds)
        let end = start.addingTimeInterval(901)
        manager.tick(at: end)
        XCTAssertFalse(manager.isActive)
        XCTAssertEqual(manager.lastReleaseReason, .timerExpired)
        XCTAssertEqual(mock.releasedCount, 1)
        XCTAssertEqual(mock.activeCount, 0)
    }

    func testModeSwitchRenewsAssertion() {
        let mock = MockPowerAssertionProvider()
        let manager = AlwaysOnManager(powerProvider: mock)

        _ = manager.startSession(preset: .indefinite, mode: .systemAndDisplay)
        XCTAssertEqual(mock.lastCreatedType, AlwaysOnMode.systemAndDisplay.assertionType)

        manager.setMode(.systemOnly)
        XCTAssertEqual(manager.currentMode, .systemOnly)
        XCTAssertEqual(mock.lastCreatedType, AlwaysOnMode.systemOnly.assertionType)
        XCTAssertEqual(mock.createdCount, 2)
        XCTAssertEqual(mock.releasedCount, 1)
        XCTAssertEqual(mock.activeCount, 1)
    }

    func testLowBatteryAutoReleaseGuardrail() {
        let mock = MockPowerAssertionProvider()
        let manager = AlwaysOnManager(
            powerProvider: mock,
            safetyConfig: AlwaysOnSafetyConfig(minBatteryPercentage: 15.0)
        )

        _ = manager.startSession(preset: .indefinite)
        XCTAssertTrue(manager.isActive)

        // 50% battery discharging -> no release
        manager.checkBatterySafety(percentage: 50.0, isCharging: false)
        XCTAssertTrue(manager.isActive)

        // 12% battery while connected to AC power -> no release
        manager.checkBatterySafety(percentage: 12.0, isCharging: true)
        XCTAssertTrue(manager.isActive)

        // 12% battery discharging -> triggers auto-release
        manager.checkBatterySafety(percentage: 12.0, isCharging: false)
        XCTAssertFalse(manager.isActive)
        XCTAssertEqual(manager.lastReleaseReason, .lowBatteryAutoRelease(percentage: 12.0))
        XCTAssertEqual(mock.releasedCount, 1)
    }

    func testThermalProtectionAutoReleaseGuardrail() {
        let mock = MockPowerAssertionProvider()
        let manager = AlwaysOnManager(
            powerProvider: mock,
            safetyConfig: AlwaysOnSafetyConfig(maxAllowedThermalState: .fair)
        )

        _ = manager.startSession(preset: .indefinite)
        XCTAssertTrue(manager.isActive)

        manager.checkThermalSafety(state: .nominal)
        XCTAssertTrue(manager.isActive)

        manager.checkThermalSafety(state: .fair)
        XCTAssertTrue(manager.isActive)

        // Thermal state escalates to .serious
        manager.checkThermalSafety(state: .serious)
        XCTAssertFalse(manager.isActive)
        XCTAssertEqual(manager.lastReleaseReason, .thermalProtectionAutoRelease(state: .serious))
        XCTAssertEqual(mock.releasedCount, 1)
    }

    func testAppStateDispatchIntegration() {
        let mock = MockPowerAssertionProvider()
        let manager = AlwaysOnManager(powerProvider: mock)
        let appState = AppState(alwaysOnManager: manager)

        let startResult = appState.dispatch(.startAwakeSession(durationMinutes: 30))
        XCTAssertTrue(startResult.ok)
        XCTAssertTrue(appState.alwaysOnManager.isActive)
        XCTAssertEqual(appState.status(for: .alwaysOn)?.runtimeState, .running)

        let stopResult = appState.dispatch(.stopAwakeSession)
        XCTAssertTrue(stopResult.ok)
        XCTAssertFalse(appState.alwaysOnManager.isActive)
        XCTAssertEqual(appState.status(for: .alwaysOn)?.runtimeState, .idle)
    }
}
