import XCTest
import CoreGraphics
import AVFoundation
@testable import MaczyKit

@MainActor
final class RecordingTests: XCTestCase {

    func testRecordingTargetProperties() {
        let displayTarget = RecordingTarget.display(displayID: nil)
        XCTAssertEqual(displayTarget.modeName, "display")

        let windowTarget = RecordingTarget.window(windowID: 99)
        XCTAssertEqual(windowTarget.modeName, "window")

        let regionTarget = RecordingTarget.region(rect: CGRect(x: 0, y: 0, width: 800, height: 600), displayID: nil)
        XCTAssertEqual(regionTarget.modeName, "region")
    }

    func testRecordingConfigurationDefaults() {
        let config = RecordingConfiguration()
        XCTAssertEqual(config.codec, .h264)
        XCTAssertEqual(config.frameRate, 60)
        XCTAssertFalse(config.systemAudio)
        XCTAssertFalse(config.microphone)
        XCTAssertTrue(config.filename.hasPrefix("Maczy_Recording_"))
        XCTAssertTrue(config.filename.hasSuffix(".mp4"))
        XCTAssertTrue(config.outputDirectory.path.contains("Maczy_Recordings"))
        XCTAssertTrue(config.outputURL.path.hasSuffix(".mp4"))
    }

    func testRecordingVideoSettingsGeneration() {
        let config = RecordingConfiguration(codec: .h264, frameRate: 60)
        let settings = config.buildVideoSettings(width: 1920, height: 1080)

        XCTAssertEqual(settings[AVVideoCodecKey] as? AVVideoCodecType, .h264)
        XCTAssertEqual(settings[AVVideoWidthKey] as? Int, 1920)
        XCTAssertEqual(settings[AVVideoHeightKey] as? Int, 1080)

        guard let compression = settings[AVVideoCompressionPropertiesKey] as? [String: Any] else {
            XCTFail("Missing compression properties dictionary")
            return
        }
        XCTAssertNotNil(compression[AVVideoAverageBitRateKey])
        XCTAssertEqual(compression[AVVideoExpectedSourceFrameRateKey] as? Int, 60)
    }

    func testHEVCCodecSelection() {
        let config = RecordingConfiguration(codec: .hevc)
        let settings = config.buildVideoSettings(width: 2560, height: 1440)
        XCTAssertEqual(settings[AVVideoCodecKey] as? AVVideoCodecType, .hevc)
    }

    func testPreflightPermissionQuery() {
        let engine = ScreenRecordingEngine.shared
        _ = engine.isAuthorized()
    }

    func testStopRecordingWhenNotRecordingThrowsError() async {
        let engine = ScreenRecordingEngine.shared
        XCTAssertFalse(engine.isRecording)

        do {
            _ = try await engine.stopRecording()
            XCTFail("Stopping a non-existent recording should throw notRecording error")
        } catch let error as RecordingError {
            XCTAssertEqual(error, .notRecording)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testAppStateRecordingPipelineTransitions() {
        let appState = AppState()
        appState.setPermissionState(.screenRecording, state: .granted)

        // Start recording
        let startResult = appState.dispatch(.startScreenRecording(target: "display", systemAudio: false, microphone: false))
        XCTAssertTrue(startResult.ok)
        XCTAssertEqual(appState.status(for: .captureAndRecording)?.runtimeState, .running)

        // Stop recording
        let stopResult = appState.dispatch(.stopScreenRecording)
        XCTAssertTrue(stopResult.ok)
        XCTAssertEqual(appState.status(for: .captureAndRecording)?.runtimeState, .idle)
    }
}
