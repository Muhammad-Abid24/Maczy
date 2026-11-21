import Foundation
import CoreGraphics
import CoreMedia
import AVFoundation

/// The 4-state audio matrix for screen recording sessions.
public enum RecordingAudioMode: String, Sendable, CaseIterable {
    case none = "none"                       // OFF / OFF
    case systemOnly = "system_only"         // ON / OFF
    case micOnly = "mic_only"               // OFF / ON
    case systemAndMic = "system_and_mic"    // ON / ON

    public var displayName: String {
        switch self {
        case .none: return "Muted (Video Only)"
        case .systemOnly: return "System Audio Only"
        case .micOnly: return "Microphone Only"
        case .systemAndMic: return "System Audio + Microphone"
        }
    }

    public var hasSystemAudio: Bool {
        self == .systemOnly || self == .systemAndMic
    }

    public var hasMicrophone: Bool {
        self == .micOnly || self == .systemAndMic
    }

    public var hasAudio: Bool {
        self != .none
    }

    public static func from(systemAudio: Bool, microphone: Bool) -> RecordingAudioMode {
        switch (systemAudio, microphone) {
        case (false, false): return .none
        case (true, false): return .systemOnly
        case (false, true): return .micOnly
        case (true, true): return .systemAndMic
        }
    }
}

/// Helper managing audio recording permission checks, AAC audio format settings, and audio stream routing.
public final class AudioRecordingManager: @unchecked Sendable {
    public static let shared = AudioRecordingManager()

    public init() {}

    /// Checks if microphone capture is authorized by macOS TCC.
    public func isMicrophoneAuthorized() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    /// Requests explicit microphone authorization.
    public func requestMicrophoneAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    /// Builds standard Apple Silicon AAC stereo audio settings for AVAssetWriter.
    public func buildAACAudioSettings(
        sampleRate: Double = 48000.0,
        channels: Int = 2,
        bitRate: Int = 128000
    ) -> [String: Any] {
        var channelLayout = AudioChannelLayout()
        memset(&channelLayout, 0, MemoryLayout<AudioChannelLayout>.size)
        channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo

        let channelLayoutData = Data(bytes: &channelLayout, count: MemoryLayout<AudioChannelLayout>.size)

        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVEncoderBitRateKey: bitRate,
            AVChannelLayoutKey: channelLayoutData
        ]
    }
}
