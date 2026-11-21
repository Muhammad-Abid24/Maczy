import XCTest
import CoreGraphics
import AVFoundation
@testable import MaczyKit

@MainActor
final class ResolutionSettingsTests: XCTestCase {

    func testAllPresetsHaveDisplayNames() {
        for preset in RecordingResolutionPreset.allCases {
            XCTAssertFalse(preset.displayName.isEmpty, "Preset \(preset) must have display name")
        }
    }

    func testNativeResolutionPreservesSourceDimensions() {
        let (w, h) = ResolutionCalculator.calculateOutputDimensions(
            sourceWidth: 3024,
            sourceHeight: 1964,
            preset: .native
        )
        XCTAssertEqual(w, 3024)
        XCTAssertEqual(h, 1964)
    }

    func testHalfAndThreeQuarterScaleMultipliers() {
        // 50% scale
        let (halfW, halfH) = ResolutionCalculator.calculateOutputDimensions(
            sourceWidth: 3840,
            sourceHeight: 2160,
            preset: .halfScale
        )
        XCTAssertEqual(halfW, 1920)
        XCTAssertEqual(halfH, 1080)

        // 75% scale
        let (tqW, tqH) = ResolutionCalculator.calculateOutputDimensions(
            sourceWidth: 1920,
            sourceHeight: 1080,
            preset: .threeQuarterScale
        )
        XCTAssertEqual(tqW, 1440)
        XCTAssertEqual(tqH, 810)
    }

    func testStandard16By9Presets() {
        let source4KW = 3840
        let source4KH = 2160

        // 1440p
        let (qhdW, qhdH) = ResolutionCalculator.calculateOutputDimensions(
            sourceWidth: source4KW,
            sourceHeight: source4KH,
            preset: .qhd1440p
        )
        XCTAssertEqual(qhdW, 2560)
        XCTAssertEqual(qhdH, 1440)

        // 1080p
        let (fhdW, fhdH) = ResolutionCalculator.calculateOutputDimensions(
            sourceWidth: source4KW,
            sourceHeight: source4KH,
            preset: .fhd1080p
        )
        XCTAssertEqual(fhdW, 1920)
        XCTAssertEqual(fhdH, 1080)

        // 720p
        let (hdW, hdH) = ResolutionCalculator.calculateOutputDimensions(
            sourceWidth: source4KW,
            sourceHeight: source4KH,
            preset: .hd720p
        )
        XCTAssertEqual(hdW, 1280)
        XCTAssertEqual(hdH, 720)
    }

    func testMacBook16By10AspectFit() {
        // MacBook Pro 14" native Liquid Retina: 3024 × 1964 (aspect ratio 1.5397)
        let (w, h) = ResolutionCalculator.calculateOutputDimensions(
            sourceWidth: 3024,
            sourceHeight: 1964,
            preset: .fhd1080p,
            aspectMode: .fit
        )

        // Height fits within 1080, width scales proportionally: 1080 * (3024/1964) = 1662.8 -> 1662
        XCTAssertEqual(h, 1080)
        XCTAssertEqual(w % 2, 0, "Width must be even integer")
        XCTAssertEqual(h % 2, 0, "Height must be even integer")
        XCTAssertLessThanOrEqual(w, 1920)
    }

    func testOddDimensionsAlwaysAlignToEvenIntegers() {
        let oddInputs = [(1921, 1081), (723, 481), (1501, 999)]
        for (inW, inH) in oddInputs {
            let (outW, outH) = ResolutionCalculator.calculateOutputDimensions(
                sourceWidth: inW,
                sourceHeight: inH,
                preset: .native
            )
            XCTAssertEqual(outW % 2, 0, "Width \(outW) must be even for odd input \(inW)")
            XCTAssertEqual(outH % 2, 0, "Height \(outH) must be even for odd input \(inH)")
        }
    }

    func testBitrateEstimation() {
        let bitrateH264 = ResolutionCalculator.estimateBitrate(
            width: 1920,
            height: 1080,
            frameRate: 60,
            codec: .h264
        )
        let bitrateHEVC = ResolutionCalculator.estimateBitrate(
            width: 1920,
            height: 1080,
            frameRate: 60,
            codec: .hevc
        )

        XCTAssertGreaterThan(bitrateH264, 2_000_000)
        XCTAssertLessThanOrEqual(bitrateH264, 50_000_000)
        // HEVC is more compressed than H.264
        XCTAssertLessThan(bitrateHEVC, bitrateH264)
    }

    func testRecordingConfigurationIntegrationWithPreset() {
        let config = RecordingConfiguration(preset: .hd720p)
        let (w, h) = config.calculateDimensions(sourceWidth: 3840, sourceHeight: 2160)
        XCTAssertEqual(w, 1280)
        XCTAssertEqual(h, 720)

        let settings = config.buildVideoSettings(width: w, height: h)
        XCTAssertEqual(settings[AVVideoWidthKey] as? Int, 1280)
        XCTAssertEqual(settings[AVVideoHeightKey] as? Int, 720)
    }
}
