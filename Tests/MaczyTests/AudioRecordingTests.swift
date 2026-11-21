import XCTest
import AVFoundation
@testable import MaczyKit

final class AudioRecordingTests: XCTestCase {

    func testRecordingAudioModeMatrix() {
        // Test all combinations
        let modeNone = RecordingAudioMode.from(systemAudio: false, microphone: false)
        XCTAssertEqual(modeNone, .none)
        XCTAssertFalse(modeNone.hasSystemAudio)
        XCTAssertFalse(modeNone.hasMicrophone)
        XCTAssertFalse(modeNone.hasAudio)
        XCTAssertEqual(modeNone.rawValue, "none")
        XCTAssertEqual(modeNone.displayName, "Muted (Video Only)")

        let modeSys = RecordingAudioMode.from(systemAudio: true, microphone: false)
        XCTAssertEqual(modeSys, .systemOnly)
        XCTAssertTrue(modeSys.hasSystemAudio)
        XCTAssertFalse(modeSys.hasMicrophone)
        XCTAssertTrue(modeSys.hasAudio)
        XCTAssertEqual(modeSys.rawValue, "system_only")
        XCTAssertEqual(modeSys.displayName, "System Audio Only")

        let modeMic = RecordingAudioMode.from(systemAudio: false, microphone: true)
        XCTAssertEqual(modeMic, .micOnly)
        XCTAssertFalse(modeMic.hasSystemAudio)
        XCTAssertTrue(modeMic.hasMicrophone)
        XCTAssertTrue(modeMic.hasAudio)
        XCTAssertEqual(modeMic.rawValue, "mic_only")
        XCTAssertEqual(modeMic.displayName, "Microphone Only")

        let modeBoth = RecordingAudioMode.from(systemAudio: true, microphone: true)
        XCTAssertEqual(modeBoth, .systemAndMic)
        XCTAssertTrue(modeBoth.hasSystemAudio)
        XCTAssertTrue(modeBoth.hasMicrophone)
        XCTAssertTrue(modeBoth.hasAudio)
        XCTAssertEqual(modeBoth.rawValue, "system_and_mic")
        XCTAssertEqual(modeBoth.displayName, "System Audio + Microphone")
    }

    func testRecordingConfigurationAudioIntegration() {
        let configDefault = RecordingConfiguration()
        XCTAssertFalse(configDefault.systemAudio)
        XCTAssertFalse(configDefault.microphone)
        XCTAssertEqual(configDefault.audioMode, .none)
        XCTAssertFalse(configDefault.hasAudio)

        let configSys = RecordingConfiguration(systemAudio: true, microphone: false)
        XCTAssertTrue(configSys.systemAudio)
        XCTAssertFalse(configSys.microphone)
        XCTAssertEqual(configSys.audioMode, .systemOnly)
        XCTAssertTrue(configSys.hasAudio)

        let configMic = RecordingConfiguration(systemAudio: false, microphone: true)
        XCTAssertFalse(configMic.systemAudio)
        XCTAssertTrue(configMic.microphone)
        XCTAssertEqual(configMic.audioMode, .micOnly)
        XCTAssertTrue(configMic.hasAudio)

        let configBoth = RecordingConfiguration(systemAudio: true, microphone: true)
        XCTAssertTrue(configBoth.systemAudio)
        XCTAssertTrue(configBoth.microphone)
        XCTAssertEqual(configBoth.audioMode, .systemAndMic)
        XCTAssertTrue(configBoth.hasAudio)
    }

    func testAACAudioSettingsGeneration() {
        let manager = AudioRecordingManager.shared
        let defaultSettings = manager.buildAACAudioSettings()

        XCTAssertEqual(defaultSettings[AVFormatIDKey] as? AudioFormatID, kAudioFormatMPEG4AAC)
        XCTAssertEqual(defaultSettings[AVSampleRateKey] as? Double, 48000.0)
        XCTAssertEqual(defaultSettings[AVNumberOfChannelsKey] as? Int, 2)
        XCTAssertEqual(defaultSettings[AVEncoderBitRateKey] as? Int, 128000)
        XCTAssertNotNil(defaultSettings[AVChannelLayoutKey] as? Data)

        // Custom audio parameters
        let customSettings = manager.buildAACAudioSettings(sampleRate: 44100.0, channels: 1, bitRate: 96000)
        XCTAssertEqual(customSettings[AVFormatIDKey] as? AudioFormatID, kAudioFormatMPEG4AAC)
        XCTAssertEqual(customSettings[AVSampleRateKey] as? Double, 44100.0)
        XCTAssertEqual(customSettings[AVNumberOfChannelsKey] as? Int, 1)
        XCTAssertEqual(customSettings[AVEncoderBitRateKey] as? Int, 96000)
    }

    func testMicrophoneAuthorizationCheck() {
        let manager = AudioRecordingManager.shared
        let authorized = manager.isMicrophoneAuthorized()
        let expected = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        XCTAssertEqual(authorized, expected)
    }

    func testMicrophonePermissionDeniedError() {
        let error = RecordingError.microphonePermissionDenied
        XCTAssertEqual(error, .microphonePermissionDenied)
        XCTAssertNotEqual(error, .permissionDenied)
        XCTAssertTrue(error.errorDescription?.contains("Microphone permission is required") == true)
    }

    func testMaczyActionAudioParameters() {
        let actionNone = MaczyAction.startScreenRecording(target: "display", systemAudio: false, microphone: false)
        XCTAssertEqual(actionNone.targetModuleId, .captureAndRecording)
        XCTAssertEqual(actionNone.debounceKey, "record_start")

        let actionAudio = MaczyAction.startScreenRecording(target: "region", systemAudio: true, microphone: false)
        XCTAssertEqual(actionAudio.targetModuleId, .captureAndRecording)
        XCTAssertEqual(actionAudio.debounceKey, "record_start")

        let actionBoth = MaczyAction.startScreenRecording(target: "window", systemAudio: true, microphone: true)
        XCTAssertEqual(actionBoth.targetModuleId, .captureAndRecording)
        XCTAssertEqual(actionBoth.debounceKey, "record_start")
    }

    @MainActor
    func testAppStateAudioRecordingBlockedWithoutPermission() {
        let appState = AppState()
        appState.setPermissionState(.screenRecording, state: .denied)

        let res = appState.dispatch(.startScreenRecording(target: "display", systemAudio: true, microphone: true))
        XCTAssertFalse(res.ok)
        XCTAssertEqual(res.errorCode, "PERMISSION_REQUIRED")
        XCTAssertEqual(appState.status(for: .captureAndRecording)?.runtimeState, .idle)
    }
}
