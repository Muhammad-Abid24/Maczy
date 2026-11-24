import XCTest
@testable import MaczyKit

final class NotchGeometryTests: XCTestCase {

    func testMacBookPro14PhysicalNotchCalculation() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1800, height: 1169)
        let safeAreaTop: CGFloat = 38
        let auxLeft: CGFloat = 790
        let auxRight: CGFloat = 790

        let rect = NotchGeometry.calculatePhysicalNotchRect(
            screenFrame: screenFrame,
            safeAreaTop: safeAreaTop,
            auxLeftWidth: auxLeft,
            auxRightWidth: auxRight
        )

        XCTAssertNotNil(rect)
        XCTAssertEqual(rect?.origin.x, 790)
        XCTAssertEqual(rect?.origin.y, 1131)
        XCTAssertEqual(rect?.size.width, 220)
        XCTAssertEqual(rect?.size.height, 38)
    }

    func testMacBookPro16PhysicalNotchCalculation() {
        let screenFrame = CGRect(x: 0, y: 0, width: 2056, height: 1329)
        let safeAreaTop: CGFloat = 38
        let auxLeft: CGFloat = 918
        let auxRight: CGFloat = 918

        let rect = NotchGeometry.calculatePhysicalNotchRect(
            screenFrame: screenFrame,
            safeAreaTop: safeAreaTop,
            auxLeftWidth: auxLeft,
            auxRightWidth: auxRight
        )

        XCTAssertNotNil(rect)
        XCTAssertEqual(rect?.origin.x, 918)
        XCTAssertEqual(rect?.origin.y, 1291)
        XCTAssertEqual(rect?.size.width, 220)
        XCTAssertEqual(rect?.size.height, 38)
    }

    func testMacBookAirPhysicalNotchCalculation() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1470, height: 956)
        let safeAreaTop: CGFloat = 32
        let auxLeft: CGFloat = 630
        let auxRight: CGFloat = 630

        let rect = NotchGeometry.calculatePhysicalNotchRect(
            screenFrame: screenFrame,
            safeAreaTop: safeAreaTop,
            auxLeftWidth: auxLeft,
            auxRightWidth: auxRight
        )

        XCTAssertNotNil(rect)
        XCTAssertEqual(rect?.size.width, 210)
        XCTAssertEqual(rect?.size.height, 32)
        XCTAssertEqual(rect?.origin.x, 630)
        XCTAssertEqual(rect?.origin.y, 924)
    }

    func testNonNotchDisplayReturnsNilForPhysicalNotch() {
        let screenFrame = CGRect(x: 0, y: 0, width: 3840, height: 2160)
        let rect = NotchGeometry.calculatePhysicalNotchRect(
            screenFrame: screenFrame,
            safeAreaTop: 0,
            auxLeftWidth: 0,
            auxRightWidth: 0
        )
        XCTAssertNil(rect)
    }

    func testVirtualIslandPillCentering() {
        let screenFrame = CGRect(x: 0, y: 0, width: 2560, height: 1440)
        let compactSize = CGSize(width: 180, height: 32)
        let topPadding: CGFloat = 12

        let rect = NotchGeometry.calculateVirtualIslandRect(
            screenFrame: screenFrame,
            compactSize: compactSize,
            topPadding: topPadding
        )

        XCTAssertEqual(rect.origin.x, 1190) // 2560/2 - 90
        XCTAssertEqual(rect.origin.y, 1396) // 1440 - 32 - 12
        XCTAssertEqual(rect.size.width, 180)
        XCTAssertEqual(rect.size.height, 32)
    }

    func testExpandedRectCalculations() {
        let anchorRect = CGRect(x: 790, y: 1131, width: 220, height: 38)
        let expandedSize = CGSize(width: 460, height: 180)

        let expanded = NotchGeometry.calculateExpandedRect(
            anchorRect: anchorRect,
            expandedSize: expandedSize,
            isPhysicalNotch: true
        )

        // MidX of anchor is 790 + 110 = 900
        // Expanded X = 900 - 230 = 670
        XCTAssertEqual(expanded.origin.x, 670)
        // Anchor maxY is 1131 + 38 = 1169
        // Expanded Y = 1169 - 180 = 989
        XCTAssertEqual(expanded.origin.y, 989)
        XCTAssertEqual(expanded.size.width, 460)
        XCTAssertEqual(expanded.size.height, 180)
    }

    func testDisplayModeOverrides() {
        let virtualProfile = NotchGeometry.detectProfile(mode: .alwaysVirtual)
        XCTAssertTrue(virtualProfile.isVirtualIsland)
        XCTAssertFalse(virtualProfile.hasPhysicalNotch)
        XCTAssertEqual(virtualProfile.compactSize, NotchGeometry.defaultVirtualCompactSize)

        let physicalProfile = NotchGeometry.detectProfile(mode: .alwaysPhysical)
        XCTAssertTrue(physicalProfile.hasPhysicalNotch)
        XCTAssertFalse(physicalProfile.isVirtualIsland)
    }

    @MainActor
    func testNotchCoordinatorLifecycleAndToggle() {
        let coordinator = NotchCoordinator(profile: .fallback)
        coordinator.setExpansionState(.compact)
        XCTAssertEqual(coordinator.expansionState, .compact)

        coordinator.toggleExpansion()
        XCTAssertEqual(coordinator.expansionState, .expanded)

        coordinator.toggleExpansion()
        XCTAssertEqual(coordinator.expansionState, .compact)

        coordinator.setExpansionState(.expanded)
        XCTAssertEqual(coordinator.expansionState, .expanded)

        coordinator.setExpansionState(.compact)
        XCTAssertEqual(coordinator.expansionState, .compact)
    }

    @MainActor
    func testAppStateNotchToggleDispatch() {
        let appState = AppState(debounceInterval: 0.0)
        NotchCoordinator.shared.setExpansionState(.compact)

        let res1 = appState.dispatch(.toggleNotchExpanded)
        XCTAssertTrue(res1.ok)
        XCTAssertEqual(appState.status(for: .dynamicNotch)?.runtimeState, .running)

        let res2 = appState.dispatch(.toggleNotchExpanded)
        XCTAssertTrue(res2.ok)
        XCTAssertEqual(appState.status(for: .dynamicNotch)?.runtimeState, .idle)
    }

    func testHeadlessCIPreflightSafety() {
        let profile = NotchGeometry.detectProfile()
        XCTAssertGreaterThan(profile.screenFrame.width, 0)
        XCTAssertGreaterThan(profile.screenFrame.height, 0)
        XCTAssertGreaterThan(profile.notchRect.width, 0)
        XCTAssertGreaterThan(profile.notchRect.height, 0)
    }

    @MainActor
    func testOutsideClickMonitoringLifecycleAndDismissal() {
        let coordinator = NotchCoordinator(profile: .fallback)
        coordinator.setExpansionState(.compact)
        XCTAssertFalse(coordinator.windowController.isMonitoringOutsideClicks)

        coordinator.setExpansionState(.expanded)
        XCTAssertTrue(coordinator.windowController.isMonitoringOutsideClicks)

        // Point outside the panel (e.g. at bottom-left corner of screen)
        let outsidePoint = NSPoint(x: 10, y: 10)
        let handled = coordinator.windowController.handleSimulatedClick(at: outsidePoint)
        XCTAssertTrue(handled)
        XCTAssertEqual(coordinator.expansionState, .compact)
        XCTAssertFalse(coordinator.windowController.isMonitoringOutsideClicks)
    }

    func testCustomNotchDimensionsDetection() {
        let customCompact = CGSize(width: 400, height: 40)
        let customExpanded = CGSize(width: 520, height: 220)

        let profile = NotchGeometry.detectProfile(
            mode: .alwaysVirtual,
            customCompactSize: customCompact,
            customExpandedSize: customExpanded
        )

        XCTAssertEqual(profile.compactSize.width, 400)
        XCTAssertEqual(profile.compactSize.height, 40)
        XCTAssertEqual(profile.notchRect.width, 400)
        XCTAssertEqual(profile.notchRect.height, 40)
        XCTAssertEqual(profile.expandedSize.width, 520)
        XCTAssertEqual(profile.expandedSize.height, 220)
    }

    @MainActor
    func testNotchCoordinatorCustomDimensionsLifecycle() {
        let coordinator = NotchCoordinator(profile: .fallback)
        coordinator.resetDimensionsToDefault()
        XCTAssertFalse(coordinator.hasCustomDimensions)

        coordinator.currentCompactWidth = 380
        coordinator.currentCompactHeight = 36
        coordinator.currentExpandedWidth = 480
        coordinator.currentExpandedHeight = 190

        XCTAssertTrue(coordinator.hasCustomDimensions)
        XCTAssertEqual(coordinator.currentCompactWidth, 380)
        XCTAssertEqual(coordinator.currentCompactHeight, 36)
        XCTAssertEqual(coordinator.activeProfile.compactSize.width, 380)
        XCTAssertEqual(coordinator.activeProfile.compactSize.height, 36)
        XCTAssertEqual(coordinator.activeProfile.expandedSize.width, 480)
        XCTAssertEqual(coordinator.activeProfile.expandedSize.height, 190)

        coordinator.resetDimensionsToDefault()
        XCTAssertFalse(coordinator.hasCustomDimensions)
    }

    @MainActor
    func testAppStateNotchDimensionsActionDispatch() {
        let appState = AppState(debounceInterval: 0.0)
        let res = appState.dispatch(.setNotchDimensions(
            compactWidth: 410,
            compactHeight: 38,
            expandedWidth: 510,
            expandedHeight: 210
        ))

        XCTAssertTrue(res.ok)
        XCTAssertEqual(NotchCoordinator.shared.currentCompactWidth, 410)
        XCTAssertEqual(NotchCoordinator.shared.currentCompactHeight, 38)
        XCTAssertEqual(NotchCoordinator.shared.currentExpandedWidth, 510)
        XCTAssertEqual(NotchCoordinator.shared.currentExpandedHeight, 210)

        let resetRes = appState.dispatch(.resetNotchDimensions)
        XCTAssertTrue(resetRes.ok)
        XCTAssertFalse(NotchCoordinator.shared.hasCustomDimensions)
    }

    @MainActor
    func testSeparatedPhysicalAndVirtualDimensions() {
        let coordinator = NotchCoordinator(profile: .fallback)
        coordinator.resetDimensionsToDefault()

        // Configure Physical dimensions
        coordinator.physicalCompactWidth = 240
        coordinator.physicalCompactHeight = 36
        coordinator.physicalExpandedWidth = 470
        coordinator.physicalExpandedHeight = 185

        XCTAssertTrue(coordinator.hasCustomPhysicalDimensions)
        XCTAssertFalse(coordinator.hasCustomVirtualDimensions)

        // Configure Virtual dimensions independently
        coordinator.virtualCompactWidth = 380
        coordinator.virtualCompactHeight = 30
        coordinator.virtualExpandedWidth = 440
        coordinator.virtualExpandedHeight = 150

        XCTAssertTrue(coordinator.hasCustomPhysicalDimensions)
        XCTAssertTrue(coordinator.hasCustomVirtualDimensions)

        // Verify values are strictly isolated
        XCTAssertEqual(coordinator.physicalCompactWidth, 240)
        XCTAssertEqual(coordinator.physicalCompactHeight, 36)
        XCTAssertEqual(coordinator.virtualCompactWidth, 380)
        XCTAssertEqual(coordinator.virtualCompactHeight, 30)

        // Reset only physical
        coordinator.resetPhysicalDimensionsToDefault()
        XCTAssertFalse(coordinator.hasCustomPhysicalDimensions)
        XCTAssertTrue(coordinator.hasCustomVirtualDimensions)
        XCTAssertEqual(coordinator.virtualCompactWidth, 380)

        // Reset virtual
        coordinator.resetVirtualDimensionsToDefault()
        XCTAssertFalse(coordinator.hasCustomVirtualDimensions)
        XCTAssertFalse(coordinator.hasCustomDimensions)
    }

    @MainActor
    func testNotificationRectAndEnlargedToastGeometry() {
        let profile = NotchScreenProfile.fallback
        let controller = NotchOverlayWindowController()

        let compactRect = controller.compactRect(for: profile)
        let notifRect = controller.notificationRect(for: profile)

        XCTAssertEqual(compactRect, profile.notchRect)
        // Notification rect must be taller and wider to house the bottom toast
        XCTAssertGreaterThan(notifRect.height, compactRect.height)
        XCTAssertGreaterThanOrEqual(notifRect.width, 320.0)

        // Coordinates must be centered horizontally
        XCTAssertEqual(notifRect.midX, profile.notchRect.midX, accuracy: 0.1)

        // Coordinator notification state management
        let coordinator = NotchCoordinator(profile: .fallback)
        XCTAssertFalse(coordinator.isNotificationActive)

        coordinator.handleNotificationStateChanged(true)
        XCTAssertTrue(coordinator.isNotificationActive)

        coordinator.handleNotificationStateChanged(false)
        XCTAssertFalse(coordinator.isNotificationActive)
    }

    func testDynamicNotchShapeWithEarsGeometry() {
        let testRect = CGRect(x: 0, y: 0, width: 340, height: 80)
        let shape = DynamicNotchShape(cornerRadius: 22, earRadius: 14, hasEars: true)
        let path = shape.path(in: testRect)

        let bounds = path.boundingRect
        XCTAssertEqual(bounds.minX, 0, accuracy: 0.1)
        XCTAssertEqual(bounds.minY, 0, accuracy: 0.1)
        XCTAssertEqual(bounds.maxX, 340, accuracy: 0.1)
        XCTAssertEqual(bounds.maxY, 80, accuracy: 0.1)
        XCTAssertFalse(path.isEmpty)
    }

    func testDynamicNotchShapeWithoutEars() {
        let testRect = CGRect(x: 10, y: 20, width: 200, height: 40)
        let shape = DynamicNotchShape(cornerRadius: 12, earRadius: 10, hasEars: false)
        let path = shape.path(in: testRect)

        let bounds = path.boundingRect
        XCTAssertEqual(bounds.minX, 10, accuracy: 0.1)
        XCTAssertEqual(bounds.minY, 20, accuracy: 0.1)
        XCTAssertEqual(bounds.maxX, 210, accuracy: 0.1)
        XCTAssertEqual(bounds.maxY, 60, accuracy: 0.1)
        XCTAssertFalse(path.isEmpty)
    }

    func testDynamicNotchShapeExtremeDimensions() {
        let narrowRect = CGRect(x: 0, y: 0, width: 20, height: 10)
        let shape = DynamicNotchShape(cornerRadius: 25, earRadius: 20, hasEars: true)
        let path = shape.path(in: narrowRect)

        XCTAssertFalse(path.isEmpty)
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.width, 20, accuracy: 0.1)
        XCTAssertEqual(bounds.height, 10, accuracy: 0.1)
    }
}
