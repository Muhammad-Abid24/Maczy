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
}
