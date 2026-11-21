import XCTest
@testable import MaczyKit

final class WindowSnapTests: XCTestCase {

    // MARK: - Geometry Engine Preset Tests

    func testLeftHalfCalculation() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1512, height: 940)
        let rect = WindowGeometryEngine.calculateTargetRect(for: .leftHalf, in: visibleFrame)

        XCTAssertEqual(rect.origin.x, 0)
        XCTAssertEqual(rect.origin.y, 0)
        XCTAssertEqual(rect.width, 756)
        XCTAssertEqual(rect.height, 940)
    }

    func testRightHalfCalculation() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1512, height: 940)
        let rect = WindowGeometryEngine.calculateTargetRect(for: .rightHalf, in: visibleFrame)

        XCTAssertEqual(rect.origin.x, 756)
        XCTAssertEqual(rect.origin.y, 0)
        XCTAssertEqual(rect.width, 756)
        XCTAssertEqual(rect.height, 940)
    }

    func testTopHalfAndBottomHalfCalculation() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1512, height: 940)
        let topRect = WindowGeometryEngine.calculateTargetRect(for: .topHalf, in: visibleFrame)
        let bottomRect = WindowGeometryEngine.calculateTargetRect(for: .bottomHalf, in: visibleFrame)

        XCTAssertEqual(topRect.origin.x, 0)
        XCTAssertEqual(topRect.origin.y, 470)
        XCTAssertEqual(topRect.width, 1512)
        XCTAssertEqual(topRect.height, 470)

        XCTAssertEqual(bottomRect.origin.x, 0)
        XCTAssertEqual(bottomRect.origin.y, 0)
        XCTAssertEqual(bottomRect.width, 1512)
        XCTAssertEqual(bottomRect.height, 470)
    }

    func testMaximizeCalculation() {
        let visibleFrame = CGRect(x: 0, y: 25, width: 1920, height: 1055)
        let rect = WindowGeometryEngine.calculateTargetRect(for: .maximize, in: visibleFrame)

        XCTAssertEqual(rect.origin.x, 0)
        XCTAssertEqual(rect.origin.y, 25)
        XCTAssertEqual(rect.width, 1920)
        XCTAssertEqual(rect.height, 1055)
    }

    func testCenterPresetCalculation() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let rect = WindowGeometryEngine.calculateTargetRect(for: .center, in: visibleFrame)

        XCTAssertEqual(rect.width, 700)
        XCTAssertEqual(rect.height, 800)
        XCTAssertEqual(rect.origin.x, 150)
        XCTAssertEqual(rect.origin.y, 100)
    }

    func testThirdsAndTwoThirdsCalculations() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1800, height: 1000)

        let leftThird = WindowGeometryEngine.calculateTargetRect(for: .leftThird, in: visibleFrame)
        XCTAssertEqual(leftThird.origin.x, 0)
        XCTAssertEqual(leftThird.width, 600)
        XCTAssertEqual(leftThird.height, 1000)

        let centerThird = WindowGeometryEngine.calculateTargetRect(for: .centerThird, in: visibleFrame)
        XCTAssertEqual(centerThird.origin.x, 600)
        XCTAssertEqual(centerThird.width, 600)

        let rightThird = WindowGeometryEngine.calculateTargetRect(for: .rightThird, in: visibleFrame)
        XCTAssertEqual(rightThird.origin.x, 1200)
        XCTAssertEqual(rightThird.width, 600)

        let leftTwoThirds = WindowGeometryEngine.calculateTargetRect(for: .leftTwoThirds, in: visibleFrame)
        XCTAssertEqual(leftTwoThirds.origin.x, 0)
        XCTAssertEqual(leftTwoThirds.width, 1200)

        let rightTwoThirds = WindowGeometryEngine.calculateTargetRect(for: .rightTwoThirds, in: visibleFrame)
        XCTAssertEqual(rightTwoThirds.origin.x, 600)
        XCTAssertEqual(rightTwoThirds.width, 1200)
    }

    func testQuartersCalculations() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)

        let tl = WindowGeometryEngine.calculateTargetRect(for: .topLeftQuarter, in: visibleFrame)
        let tr = WindowGeometryEngine.calculateTargetRect(for: .topRightQuarter, in: visibleFrame)
        let bl = WindowGeometryEngine.calculateTargetRect(for: .bottomLeftQuarter, in: visibleFrame)
        let br = WindowGeometryEngine.calculateTargetRect(for: .bottomRightQuarter, in: visibleFrame)

        XCTAssertEqual(tl, CGRect(x: 0, y: 400, width: 500, height: 400))
        XCTAssertEqual(tr, CGRect(x: 500, y: 400, width: 500, height: 400))
        XCTAssertEqual(bl, CGRect(x: 0, y: 0, width: 500, height: 400))
        XCTAssertEqual(br, CGRect(x: 500, y: 0, width: 500, height: 400))
    }

    func testWindowGapMarginCalculation() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let margin: CGFloat = 10

        let left = WindowGeometryEngine.calculateTargetRect(for: .leftHalf, in: visibleFrame, margin: margin)
        // vw = 1000. halfW = (1000 - 30) / 2 = 485
        // x = 0 + 10 = 10, y = 10, w = 485, h = 800 - 20 = 780
        XCTAssertEqual(left.origin.x, 10)
        XCTAssertEqual(left.origin.y, 10)
        XCTAssertEqual(left.width, 485)
        XCTAssertEqual(left.height, 780)

        let right = WindowGeometryEngine.calculateTargetRect(for: .rightHalf, in: visibleFrame, margin: margin)
        // x = 0 + 485 + 20 = 505
        XCTAssertEqual(right.origin.x, 505)
        XCTAssertEqual(right.origin.y, 10)
        XCTAssertEqual(right.width, 485)
        XCTAssertEqual(right.height, 780)
    }

    // MARK: - Coordinate Conversion Tests

    func testCoordinateConversionsRoundTrip() {
        let primaryHeight: CGFloat = 1080
        let originalAppKit = CGRect(x: 100, y: 200, width: 800, height: 600)

        let ax = WindowGeometryEngine.appKitToAX(rect: originalAppKit, primaryScreenHeight: primaryHeight)
        // ax.y = 1080 - 200 - 600 = 280
        XCTAssertEqual(ax.origin.x, 100)
        XCTAssertEqual(ax.origin.y, 280)
        XCTAssertEqual(ax.width, 800)
        XCTAssertEqual(ax.height, 600)

        let roundTripAppKit = WindowGeometryEngine.axToAppKit(rect: ax, primaryScreenHeight: primaryHeight)
        XCTAssertEqual(roundTripAppKit, originalAppKit)
    }

    // MARK: - Notch Drop Zone Tests

    func testNotchDropZoneCalculation() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let zone = WindowGeometryEngine.notchSnapZone(screenFrame: screen, zoneWidth: 260, zoneHeight: 48)

        XCTAssertEqual(zone.origin.x, (1512 - 260) / 2)
        XCTAssertEqual(zone.origin.y, 982 - 48)
        XCTAssertEqual(zone.width, 260)
        XCTAssertEqual(zone.height, 48)
    }

    // MARK: - Protection and Gating Tests

    func testProtectedWindowFiltering() {
        // Dock must be protected
        XCTAssertTrue(WindowSnapManager.isProtected(
            bundleIdentifier: "com.apple.dock",
            subrole: nil,
            isPositionSettable: true,
            isSizeSettable: true
        ))

        // WindowServer must be protected
        XCTAssertTrue(WindowSnapManager.isProtected(
            bundleIdentifier: "com.apple.WindowServer",
            subrole: nil,
            isPositionSettable: true,
            isSizeSettable: true
        ))

        // System dialog subrole must be protected
        XCTAssertTrue(WindowSnapManager.isProtected(
            bundleIdentifier: "com.apple.finder",
            subrole: "AXSystemDialog",
            isPositionSettable: true,
            isSizeSettable: true
        ))

        // Non-resizable window must be protected
        XCTAssertTrue(WindowSnapManager.isProtected(
            bundleIdentifier: "com.example.app",
            subrole: "AXStandardWindow",
            isPositionSettable: true,
            isSizeSettable: false
        ))

        // Standard user window with settable geometry is NOT protected
        XCTAssertFalse(WindowSnapManager.isProtected(
            bundleIdentifier: "com.apple.Safari",
            subrole: "AXStandardWindow",
            isPositionSettable: true,
            isSizeSettable: true
        ))
    }

    // MARK: - Undo Stack Tests

    @MainActor
    func testUndoStackBoundedCapacity() {
        let manager = WindowSnapManager()
        manager.clearUndoHistory()
        XCTAssertFalse(manager.canUndo)

        // Push 60 states
        for i in 1...60 {
            manager.pushUndoState(WindowRestoreState(
                windowId: "win_\(i)",
                previousFrame: CGRect(x: i, y: i, width: 100, height: 100)
            ))
        }

        XCTAssertEqual(manager.undoStack.count, WindowSnapManager.maxUndoCapacity)
        XCTAssertTrue(manager.canUndo)
        // First item should be win_11 (first 10 evicted)
        XCTAssertEqual(manager.undoStack.first?.windowId, "win_11")
        XCTAssertEqual(manager.undoStack.last?.windowId, "win_60")
    }

    // MARK: - AppState Integration Tests

    @MainActor
    func testAppStateWindowSnapActionDispatch() {
        let appState = AppState(debounceInterval: 0.0)

        // Dispatching snap when not trusted returns ACCESSIBILITY_UNAUTHORIZED or safe error
        let result = appState.dispatch(.snapActiveWindow(preset: .leftHalf))
        if !result.ok {
            XCTAssertNotNil(result.errorCode)
        }

        // Dispatching undo when stack is empty returns appropriate failure
        let undoResult = appState.dispatch(.undoWindowSnap)
        if !undoResult.ok {
            XCTAssertNotNil(undoResult.errorCode)
        }
    }
}
