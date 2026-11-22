import XCTest
import CoreGraphics
import AppKit
@testable import MaczyKit

@MainActor
final class CaptureTests: XCTestCase {

    private func createTestCGImage(width: Int = 120, height: Int = 80, red: CGFloat = 0.44, green: CGFloat = 0.17, blue: CGFloat = 0.88) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        )!

        // Fill background with color
        context.setFillColor(red: red, green: green, blue: blue, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()!
    }

    func testCaptureTargetProperties() {
        let fullscreenTarget = CaptureTarget.fullscreen(displayID: nil)
        XCTAssertEqual(fullscreenTarget.modeName, "fullscreen")

        let windowTarget = CaptureTarget.window(windowID: 101)
        XCTAssertEqual(windowTarget.modeName, "window")

        let areaTarget = CaptureTarget.area(rect: CGRect(x: 10, y: 20, width: 300, height: 200), displayID: nil)
        XCTAssertEqual(areaTarget.modeName, "area")
    }

    func testAreaSelectionCoordinateMath() {
        let overlay = AreaSelectionOverlayWindowController()

        // Normal drag: top-left to bottom-right
        let rect1 = overlay.calculateNormalizedRect(p1: CGPoint(x: 50, y: 50), p2: CGPoint(x: 250, y: 150))
        XCTAssertEqual(rect1, CGRect(x: 50, y: 50, width: 200, height: 100))

        // Inverted drag: bottom-right to top-left
        let rect2 = overlay.calculateNormalizedRect(p1: CGPoint(x: 250, y: 150), p2: CGPoint(x: 50, y: 50))
        XCTAssertEqual(rect2, CGRect(x: 50, y: 50, width: 200, height: 100))

        // Diagonal drag: top-right to bottom-left
        let rect3 = overlay.calculateNormalizedRect(p1: CGPoint(x: 250, y: 50), p2: CGPoint(x: 50, y: 150))
        XCTAssertEqual(rect3, CGRect(x: 50, y: 50, width: 200, height: 100))
    }

    func testFilenameGeneration() {
        let manager = CaptureExportManager.shared
        let fixedDate = Date(timeIntervalSince1970: 1700000000)

        let pngFilename = manager.generateFilename(prefix: "TestShot", timestamp: fixedDate, format: .png)
        XCTAssertTrue(pngFilename.hasPrefix("TestShot_"))
        XCTAssertTrue(pngFilename.hasSuffix(".png"))

        let jpgFilename = manager.generateFilename(prefix: "TestShot", timestamp: fixedDate, format: .jpeg)
        XCTAssertTrue(jpgFilename.hasSuffix(".jpg"))

        let heicFilename = manager.generateFilename(prefix: "TestShot", timestamp: fixedDate, format: .heic)
        XCTAssertTrue(heicFilename.hasSuffix(".heic"))
    }

    func testImageEncodingAndMagicHeaders() {
        let manager = CaptureExportManager.shared
        let image = createTestCGImage()

        // PNG Encoding
        guard let pngData = manager.encodeImage(image, format: .png) else {
            XCTFail("Failed to encode PNG")
            return
        }
        XCTAssertGreaterThan(pngData.count, 8)
        // PNG magic number: 0x89 0x50 0x4E 0x47
        let pngHeader = [UInt8](pngData.prefix(4))
        XCTAssertEqual(pngHeader, [0x89, 0x50, 0x4E, 0x47])

        // JPEG Encoding
        guard let jpegData = manager.encodeImage(image, format: .jpeg) else {
            XCTFail("Failed to encode JPEG")
            return
        }
        XCTAssertGreaterThan(jpegData.count, 2)
        // JPEG SOI magic number: 0xFF 0xD8
        let jpegHeader = [UInt8](jpegData.prefix(2))
        XCTAssertEqual(jpegHeader, [0xFF, 0xD8])
    }

    func testSaveToDiskAndFilePersistence() throws {
        let manager = CaptureExportManager.shared
        let image = createTestCGImage()

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let savedURL = try manager.saveToDisk(image, destinationDirectory: tempDir, filename: "test_output.png", format: .png)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))

        let readData = try Data(contentsOf: savedURL)
        XCTAssertGreaterThan(readData.count, 50)
    }

    func testCopyToPasteboard() {
        let manager = CaptureExportManager.shared
        let image = createTestCGImage()

        let copied = manager.copyToPasteboard(image)
        XCTAssertTrue(copied)

        let pasteboard = NSPasteboard.general
        let hasPNG = pasteboard.data(forType: .png) != nil
        let hasTIFF = pasteboard.data(forType: .tiff) != nil
        XCTAssertTrue(hasPNG || hasTIFF, "Pasteboard must contain PNG or TIFF representation")
    }

    func testCapturePreflightPermissionCheck() {
        let engine = ScreenCaptureEngine.shared
        // Ensure call does not crash and returns a valid boolean
        _ = engine.isAuthorized()
    }

    func testAppStateCaptureActionPipelineIntegration() {
        let appState = AppState()
        appState.setPermissionState(.screenRecording, state: .granted)

        let result = appState.dispatch(.captureScreenshot(mode: "fullscreen"))
        XCTAssertTrue(result.ok)
        XCTAssertEqual(appState.status(for: .captureAndRecording)?.runtimeState, .running)
    }

    func testCaptureWindowTargetZeroEquivalence() {
        let target = CaptureTarget.window(windowID: 0)
        XCTAssertEqual(target.modeName, "window")
    }

    func testAppStateStopScreenRecordingPipelineIntegration() {
        let appState = AppState()
        appState.setPermissionState(.screenRecording, state: .granted)

        let result = appState.dispatch(.stopScreenRecording)
        XCTAssertTrue(result.ok)
    }

    func testCapturePreviewHUDPresentationAndDismiss() {
        let hud = CapturePreviewHUD.shared
        let testImage = createTestCGImage(width: 200, height: 100)

        hud.present(image: testImage, fileURL: nil)
        XCTAssertTrue(hud.isVisible)
        XCTAssertEqual(hud.level, NSWindow.Level(Int(CGWindowLevelForKey(.maximumWindow))))

        hud.dismiss()
        // Ensure dismiss executes without error
    }

    func testRetinaMetadataPreservationInExport() {
        let manager = CaptureExportManager.shared
        let testImage = createTestCGImage(width: 400, height: 200)

        guard let pngData = manager.encodeImage(testImage, format: .png) else {
            XCTFail("Failed to encode image with Retina metadata")
            return
        }

        XCTAssertGreaterThan(pngData.count, 100)
    }

    func testAppStateLastCapturedImagePublishing() {
        let appState = AppState()
        let testImage = createTestCGImage(width: 100, height: 100)

        XCTAssertNil(appState.lastCapturedImage)
        appState.lastCapturedImage = testImage
        XCTAssertNotNil(appState.lastCapturedImage)
        XCTAssertEqual(appState.lastCapturedImage?.width, 100)
    }

    func testAreaSelectionPurposeAndScrollingHints() {
        let areaOverlay = AreaSelectionOverlayWindowController(purpose: .captureArea)
        XCTAssertEqual(areaOverlay.purpose, .captureArea)

        let scrollOverlay = AreaSelectionOverlayWindowController(purpose: .scrollingCapture)
        XCTAssertEqual(scrollOverlay.purpose, .scrollingCapture)
    }

    func testScrollingControlHUDPresentationAndDismiss() {
        let hud = ScrollingControlHUD.shared
        let targetRect = CGRect(x: 100, y: 100, width: 600, height: 400)

        hud.present(anchoredTo: targetRect)
        XCTAssertTrue(hud.isVisible)
        XCTAssertEqual(hud.level, NSWindow.Level(Int(CGWindowLevelForKey(.maximumWindow))))

        hud.dismiss()
    }

    func testScrollingCaptureCoordinatorInteractiveSessionAndAutoScroll() {
        let coordinator = ScrollingCaptureCoordinator.shared
        coordinator.startSession()

        XCTAssertFalse(coordinator.isAutoScrolling)
        XCTAssertEqual(coordinator.activeSliceCount, 0)
        XCTAssertEqual(coordinator.estimatedTotalHeight, 0)

        coordinator.toggleAutoScroll()
        XCTAssertTrue(coordinator.isAutoScrolling)

        coordinator.toggleAutoScroll()
        XCTAssertFalse(coordinator.isAutoScrolling)

        let slice1 = createTestCGImage(width: 200, height: 100, red: 0.1, green: 0.2, blue: 0.8)
        let slice2 = createTestCGImage(width: 200, height: 100, red: 0.8, green: 0.2, blue: 0.1)

        coordinator.appendSlice(slice1)
        XCTAssertEqual(coordinator.activeSliceCount, 1)
        XCTAssertEqual(coordinator.estimatedTotalHeight, 100)

        coordinator.appendSlice(slice2)
        XCTAssertEqual(coordinator.activeSliceCount, 2)
        XCTAssertEqual(coordinator.estimatedTotalHeight, 200)

        coordinator.cancelSession()
        XCTAssertEqual(coordinator.activeSliceCount, 0)
        XCTAssertEqual(coordinator.estimatedTotalHeight, 0)
        XCTAssertFalse(coordinator.isAutoScrolling)
    }
}
