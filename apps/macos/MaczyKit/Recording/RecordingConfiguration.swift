import Foundation
import CoreGraphics
import AVFoundation

/// Target modes for ScreenCaptureKit video recording.
public enum RecordingTarget: Sendable, Equatable {
    case display(displayID: CGDirectDisplayID?)
    case window(windowID: CGWindowID)
    case region(rect: CGRect, displayID: CGDirectDisplayID?)

    public var modeName: String {
        switch self {
        case .display: return "display"
        case .window: return "window"
        case .region: return "region"
        }
    }
}

/// Video compression codecs supported on Apple Silicon.
public enum RecordingVideoCodec: String, Sendable, CaseIterable {
    case h264 = "avc1"
    case hevc = "hvc1"

    public var avCodecType: AVVideoCodecType {
        switch self {
        case .h264: return .h264
        case .hevc: return .hevc
        }
    }
}

/// Complete configuration for a screen recording session.
public struct RecordingConfiguration: Sendable {
    public let target: RecordingTarget
    public let codec: RecordingVideoCodec
    public let frameRate: Int
    public let systemAudio: Bool
    public let microphone: Bool
    public let outputDirectory: URL
    public let filename: String

    public init(
        target: RecordingTarget = .display(displayID: nil),
        codec: RecordingVideoCodec = .h264,
        frameRate: Int = 60,
        systemAudio: Bool = false,
        microphone: Bool = false,
        outputDirectory: URL? = nil,
        filename: String? = nil
    ) {
        self.target = target
        self.codec = codec
        self.frameRate = frameRate
        self.systemAudio = systemAudio
        self.microphone = microphone

        let defaultDir: URL
        if let dir = outputDirectory {
            defaultDir = dir
        } else {
            let moviesURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Movies")
            defaultDir = moviesURL.appendingPathComponent("Maczy_Recordings", isDirectory: true)
        }
        self.outputDirectory = defaultDir

        if let name = filename {
            self.filename = name
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            let dateStr = formatter.string(from: Date())
            self.filename = "Maczy_Recording_\(dateStr).mp4"
        }
    }

    public var outputURL: URL {
        outputDirectory.appendingPathComponent(filename)
    }

    public func buildVideoSettings(width: Int, height: Int) -> [String: Any] {
        return [
            AVVideoCodecKey: codec.avCodecType,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: width * height * 4,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: frameRate
            ]
        ]
    }
}
