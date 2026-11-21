import XCTest
import Combine
@testable import MaczyKit

@MainActor
final class MaczyTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()

    func testModuleCountIsExactlySeven() {
        XCTAssertEqual(MaczyModuleId.allCases.count, 7, "Maczy must have exactly 7 defined modules per PRD")
    }

    func testAllSevenModulesHaveDisplayNamesAndIcons() {
        for module in MaczyModuleId.allCases {
            XCTAssertFalse(module.displayName.isEmpty, "Module \(module.rawValue) must have a non-empty display name")
            XCTAssertFalse(module.iconName.isEmpty, "Module \(module.rawValue) must have an icon")
            XCTAssertFalse(module.summary.isEmpty, "Module \(module.rawValue) must have a summary")
        }
    }

    func testCoreBridgeModuleStatusReporting() {
        let bridge = MaczyCoreBridge.shared
        XCTAssertEqual(bridge.moduleCount, 7)
        XCTAssertEqual(bridge.targetArch, "arm64")
        XCTAssertEqual(bridge.minDeployment, "14.0")

        let statuses = bridge.fetchAllModuleStatuses()
        XCTAssertEqual(statuses.count, 7)
    }

    func testCapabilityGateBlocksSmartUnlock() {
        let appState = AppState(capabilityRegistry: CapabilityRegistry(), eventBus: EventBus())
        let result = appState.dispatch(.triggerSessionUnlock)

        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.errorCode, "CAPABILITY_UNSUPPORTED")

        let smartUnlockStatus = appState.status(for: .smartUnlock)
        XCTAssertNotNil(smartUnlockStatus)
        XCTAssertEqual(smartUnlockStatus?.runtimeState, .blocked)
    }

    func testPermissionGateBlocksCaptureWhenUnauthorized() {
        let appState = AppState(capabilityRegistry: CapabilityRegistry(), eventBus: EventBus())
        // ScreenRecording permission is .notDetermined initially
        let result = appState.dispatch(.captureScreenshot(mode: "area"))

        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.errorCode, "PERMISSION_REQUIRED")

        let captureStatus = appState.status(for: .captureAndRecording)
        XCTAssertEqual(captureStatus?.runtimeState, .idle)
    }

    func testCaptureActionSucceedsWhenPermissionGranted() {
        let appState = AppState(capabilityRegistry: CapabilityRegistry(), eventBus: EventBus())
        appState.setPermissionState(.screenRecording, state: .granted)

        let result = appState.dispatch(.captureScreenshot(mode: "area"))
        XCTAssertTrue(result.ok)
        XCTAssertTrue(result.message?.contains("captured") == true)

        let captureStatus = appState.status(for: .captureAndRecording)
        XCTAssertEqual(captureStatus?.runtimeState, .running)
    }

    func testChargeLimitWriteGatedByMZ014() {
        let appState = AppState(capabilityRegistry: CapabilityRegistry(), eventBus: EventBus())
        let result = appState.dispatch(.selectChargeLimit(percentage: 80))

        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.errorCode, "GATE_MZ_014")
    }

    func testDebounceThresholdIgnoresDuplicateRapidActions() {
        let appState = AppState(capabilityRegistry: CapabilityRegistry(), eventBus: EventBus())
        appState.setPermissionState(.screenRecording, state: .granted)

        let result1 = appState.dispatch(.captureScreenshot(mode: "fullscreen"))
        XCTAssertTrue(result1.ok)

        let result2 = appState.dispatch(.captureScreenshot(mode: "fullscreen"))
        XCTAssertFalse(result2.ok)
        XCTAssertEqual(result2.errorCode, "ACTION_DEBOUNCED")
    }

    func testEventBusDeliversStateUpdates() {
        let eventBus = EventBus()
        let appState = AppState(capabilityRegistry: CapabilityRegistry(), eventBus: eventBus)
        appState.setPermissionState(.screenRecording, state: .granted)

        var receivedEvents: [AppEvent] = []
        let expectation = self.expectation(description: "Event received")
        expectation.expectedFulfillmentCount = 2 // moduleRuntimeChanged + commandExecuted

        eventBus.events
            .sink { event in
                receivedEvents.append(event)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        let _ = appState.dispatch(.captureScreenshot(mode: "window"))
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(receivedEvents.count, 2)
    }
}
