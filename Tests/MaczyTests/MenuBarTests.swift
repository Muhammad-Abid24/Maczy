import XCTest
@testable import MaczyKit

@MainActor
final class MenuBarTests: XCTestCase {
    func testStandardShortcutsContainRequiredActions() {
        let shortcuts = MenuBarViewModel.standardShortcuts
        XCTAssertGreaterThanOrEqual(shortcuts.count, 7, "Menu bar must provide shortcuts for core module actions")

        let actionIds = shortcuts.map { $0.id }
        XCTAssertTrue(actionIds.contains("cap_area"))
        XCTAssertTrue(actionIds.contains("cap_window"))
        XCTAssertTrue(actionIds.contains("cap_fullscreen"))
        XCTAssertTrue(actionIds.contains("rec_toggle"))
        XCTAssertTrue(actionIds.contains("notch_toggle"))
        XCTAssertTrue(actionIds.contains("clean_scan"))
        XCTAssertTrue(actionIds.contains("update_check"))
    }

    func testMenuBarViewModelExecutesActionThroughPipeline() {
        let appState = AppState(capabilityRegistry: CapabilityRegistry(), eventBus: EventBus())
        let viewModel = MenuBarViewModel()

        // 1. Gated Smart Unlock action executed through MenuBar
        let resultUnlock = viewModel.executeAction(.triggerSessionUnlock, on: appState)
        XCTAssertFalse(resultUnlock.ok)
        XCTAssertEqual(resultUnlock.errorCode, "CAPABILITY_UNSUPPORTED")
        XCTAssertEqual(viewModel.lastActionResult?.errorCode, "CAPABILITY_UNSUPPORTED")

        // 2. Gated Battery write executed through MenuBar
        let resultBattery = viewModel.executeAction(.selectChargeLimit(percentage: 80), on: appState)
        XCTAssertFalse(resultBattery.ok)
        XCTAssertEqual(resultBattery.errorCode, "GATE_MZ_014")
        XCTAssertEqual(viewModel.lastActionResult?.errorCode, "GATE_MZ_014")

        // 3. Permitted action executed through MenuBar
        appState.setPermissionState(.screenRecording, state: .granted)
        let resultCapture = viewModel.executeAction(.captureScreenshot(mode: "area"), on: appState)
        XCTAssertTrue(resultCapture.ok)
        XCTAssertTrue(viewModel.lastActionResult?.ok == true)
    }

    func testMenuBarAlwaysOnPresets() {
        let appState = AppState(capabilityRegistry: CapabilityRegistry(), eventBus: EventBus())
        let viewModel = MenuBarViewModel()

        let resultAwake = viewModel.executeAction(.startAwakeSession(durationMinutes: 30), on: appState)
        XCTAssertTrue(resultAwake.ok)
        XCTAssertEqual(appState.status(for: .alwaysOn)?.runtimeState, .running)

        let resultStop = viewModel.executeAction(.stopAwakeSession, on: appState)
        XCTAssertTrue(resultStop.ok)
        XCTAssertEqual(appState.status(for: .alwaysOn)?.runtimeState, .idle)
    }

    func testMenuBarCleanerScanTrigger() {
        let appState = AppState(capabilityRegistry: CapabilityRegistry(), eventBus: EventBus())
        let viewModel = MenuBarViewModel()

        let resultScan = viewModel.executeAction(.startCleanerScan, on: appState)
        XCTAssertTrue(resultScan.ok)
        XCTAssertEqual(appState.status(for: .systemCleaner)?.runtimeState, .running)

        let resultCancel = viewModel.executeAction(.cancelCleanerScan, on: appState)
        XCTAssertTrue(resultCancel.ok)
        XCTAssertEqual(appState.status(for: .systemCleaner)?.runtimeState, .idle)
    }
}
