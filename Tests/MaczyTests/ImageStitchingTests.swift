import XCTest
import CoreGraphics
import AppKit
@testable import MaczyKit

final class ImageStitchingTests: XCTestCase {

    /// Helper to create a test image with distinct colored horizontal bands for deterministic overlap testing.
    private func createTestBandImage(width: Int = 100, height: Int = 100, startHue: CGFloat = 0.0) -> CGImage {
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

        // Draw horizontal gradient bands
        for y in 0..<height {
            let hue = (startHue + CGFloat(y) / CGFloat(height)).truncatingRemainder(dividingBy: 1.0)
            let color = NSColor(hue: hue, saturation: 0.9, brightness: 0.9, alpha: 1.0)
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: 0, y: y, width: width, height: 1))
        }

        return context.makeImage()!
    }

    /// Helper to crop a sub-rectangle from a source CGImage.
    private func cropImage(_ image: CGImage, rect: CGRect) -> CGImage {
        return image.cropping(to: rect)!
    }

    func testSingleSliceStitching() throws {
        let engine = ImageStitchingEngine.shared
        let slice = createTestBandImage(width: 120, height: 80)

        let result = try engine.stitch(slices: [slice])
        XCTAssertEqual(result.width, 120)
        XCTAssertEqual(result.height, 80)
        XCTAssertEqual(result.sliceCount, 1)
        XCTAssertEqual(result.totalOverlapPixels, 0)
    }

    func testEmptySlicesThrowsError() {
        let engine = ImageStitchingEngine.shared
        XCTAssertThrowsError(try engine.stitch(slices: [])) { error in
            XCTAssertEqual(error as? StitchingError, .insufficientSlices)
        }
    }

    func testDimensionMismatchThrowsError() {
        let engine = ImageStitchingEngine.shared
        let slice1 = createTestBandImage(width: 100, height: 60)
        let slice2 = createTestBandImage(width: 120, height: 60)

        XCTAssertThrowsError(try engine.stitch(slices: [slice1, slice2])) { error in
            guard case .dimensionMismatch = (error as? StitchingError) else {
                XCTFail("Expected dimensionMismatch error, got: \(error)")
                return
            }
        }
    }

    func testSyntheticOverlappingSlicesStitching() throws {
        let engine = ImageStitchingEngine.shared

        // Create a single tall master image (width 120, height 300)
        let masterImage = createTestBandImage(width: 120, height: 300)

        // Slice 1: rows 0 to 180 (height 180)
        // CoreGraphics cropping coordinates: (x, y, width, height)
        let slice1 = cropImage(masterImage, rect: CGRect(x: 0, y: 0, width: 120, height: 180))

        // Slice 2: rows 120 to 300 (height 180). Overlap with Slice 1 is 60px (rows 120 to 180)
        let slice2 = cropImage(masterImage, rect: CGRect(x: 0, y: 120, width: 120, height: 180))

        let (overlap, isIdentical) = engine.findVerticalOverlap(topSlice: slice1, bottomSlice: slice2)
        XCTAssertFalse(isIdentical)
        // Overlap should be detected close to 60px
        XCTAssertGreaterThanOrEqual(overlap, 55)
        XCTAssertLessThanOrEqual(overlap, 65)

        let result = try engine.stitch(slices: [slice1, slice2])
        XCTAssertEqual(result.width, 120)
        // Expected total height is roughly 180 + (180 - 60) = 300
        XCTAssertGreaterThanOrEqual(result.height, 290)
        XCTAssertLessThanOrEqual(result.height, 310)
        XCTAssertEqual(result.sliceCount, 2)
    }

    func testIdenticalConsecutiveSlicesDetectedAsEndReached() {
        let engine = ImageStitchingEngine.shared
        let slice = createTestBandImage(width: 100, height: 80)

        let (overlap, isIdentical) = engine.findVerticalOverlap(topSlice: slice, bottomSlice: slice)
        XCTAssertTrue(isIdentical, "Consecutive identical slices must be flagged as end of scrolling")
        XCTAssertEqual(overlap, 80)
    }

    func testMaxCanvasHeightBounding() throws {
        let engine = ImageStitchingEngine(maxCanvasHeight: 250)
        let slice1 = createTestBandImage(width: 100, height: 150)
        let slice2 = createTestBandImage(width: 100, height: 150)

        let result = try engine.stitch(slices: [slice1, slice2])
        XCTAssertLessThanOrEqual(result.height, 250, "Stitched height must be clamped to maxCanvasHeight")
    }

    @MainActor
    func testScrollingCaptureCoordinatorLifecycle() throws {
        let coordinator = ScrollingCaptureCoordinator.shared
        coordinator.startSession()

        let slice1 = createTestBandImage(width: 80, height: 60, startHue: 0.1)
        let slice2 = createTestBandImage(width: 80, height: 60, startHue: 0.3)

        let progress1 = coordinator.appendSlice(slice1)
        XCTAssertEqual(progress1.sliceCount, 1)
        XCTAssertFalse(progress1.isEndReached)

        let progress2 = coordinator.appendSlice(slice2)
        XCTAssertEqual(progress2.sliceCount, 2)

        let item = try coordinator.finishSession()
        XCTAssertEqual(item.target.modeName, "scrolling")
        XCTAssertEqual(item.size.width, 80)
        XCTAssertGreaterThan(item.size.height, 60)
        XCTAssertEqual(coordinator.activeSliceCount, 0)
    }

    @MainActor
    func testScrollingCaptureCoordinatorCancel() {
        let coordinator = ScrollingCaptureCoordinator.shared
        coordinator.startSession()

        let slice = createTestBandImage(width: 80, height: 60)
        coordinator.appendSlice(slice)
        XCTAssertEqual(coordinator.activeSliceCount, 1)

        coordinator.cancelSession()
        XCTAssertEqual(coordinator.activeSliceCount, 0)
    }
}
