import Foundation
import CoreGraphics
import CoreMedia
import AVFoundation
import ScreenCaptureKit

/// Status representing the active recording state.
public struct RecordingState: Sendable, Equatable {
    public let isRecording: Bool
    public let durationSeconds: TimeInterval
    public let framesWritten: Int
    public let targetMode: String

    public static let idle = RecordingState(isRecording: false, durationSeconds: 0, framesWritten: 0, targetMode: "none")
}

/// Errors occurring during screen recording lifecycle.
public enum RecordingError: Error, LocalizedError, Equatable {
    case permissionDenied
    case microphonePermissionDenied
    case alreadyRecording
    case notRecording
    case writerInitializationFailed(String)
    case streamInitializationFailed(String)
    case outputDirectoryUnavailable

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen Recording permission is required. Enable access in System Settings."
        case .microphonePermissionDenied:
            return "Microphone permission is required for voice recording. Enable access in System Settings."
        case .alreadyRecording:
            return "A recording session is already in progress."
        case .notRecording:
            return "No active recording session to stop."
        case .writerInitializationFailed(let reason):
            return "Failed to initialize AVAssetWriter: \(reason)"
        case .streamInitializationFailed(let reason):
            return "Failed to start ScreenCaptureKit stream: \(reason)"
        case .outputDirectoryUnavailable:
            return "Failed to create or access the recordings output directory."
        }
    }
}

/// Hardware-accelerated screen video recorder using ScreenCaptureKit and AVAssetWriter.
public final class ScreenRecordingEngine: NSObject, SCStreamOutput, @unchecked Sendable {
    public static let shared = ScreenRecordingEngine()

    private var activeStream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var currentConfig: RecordingConfiguration?
    private var isRecordingInternal: Bool = false
    private var sessionStartTime: CMTime = .invalid
    private var frameCount: Int = 0
    private var recordingStartDate: Date?

    private let lock = NSLock()

    public override init() {
        super.init()
    }

    public var isRecording: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isRecordingInternal
    }

    private func checkAndClaimRecording() throws {
        lock.lock()
        defer { lock.unlock() }
        if isRecordingInternal {
            throw RecordingError.alreadyRecording
        }
        isRecordingInternal = true
    }

    private func cancelSessionClaim() {
        lock.lock()
        defer { lock.unlock() }
        isRecordingInternal = false
    }

    private func storeSession(
        stream: SCStream,
        writer: AVAssetWriter,
        videoInput: AVAssetWriterInput,
        audioInput: AVAssetWriterInput?,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        configuration: RecordingConfiguration
    ) {
        lock.lock()
        defer { lock.unlock() }
        self.activeStream = stream
        self.assetWriter = writer
        self.videoInput = videoInput
        self.audioInput = audioInput
        self.pixelBufferAdaptor = adaptor
        self.currentConfig = configuration
        self.sessionStartTime = .invalid
        self.frameCount = 0
        self.recordingStartDate = Date()
    }

    private func resetSession() -> (SCStream, AVAssetWriter, AVAssetWriterInput, AVAssetWriterInput?, RecordingConfiguration)? {
        lock.lock()
        defer { lock.unlock() }
        guard isRecordingInternal,
              let stream = activeStream,
              let writer = assetWriter,
              let videoInput = videoInput,
              let config = currentConfig else {
            return nil
        }
        let audioIn = self.audioInput
        self.isRecordingInternal = false
        self.activeStream = nil
        self.assetWriter = nil
        self.videoInput = nil
        self.audioInput = nil
        self.pixelBufferAdaptor = nil
        self.currentConfig = nil
        return (stream, writer, videoInput, audioIn, config)
    }

    /// Preflight check for Screen Recording TCC authorization.
    public func isAuthorized() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }

    /// Starts a new hardware-accelerated screen recording session.
    public func startRecording(configuration: RecordingConfiguration) async throws -> URL {
        guard isAuthorized() else {
            throw RecordingError.permissionDenied
        }

        if configuration.microphone {
            guard AudioRecordingManager.shared.isMicrophoneAuthorized() else {
                throw RecordingError.microphonePermissionDenied
            }
        }

        try checkAndClaimRecording()

        // 1. Ensure output directory exists
        let outputDir = configuration.outputDirectory
        do {
            if !FileManager.default.fileExists(atPath: outputDir.path) {
                try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            }
        } catch {
            throw RecordingError.outputDirectoryUnavailable
        }

        let outputURL = configuration.outputURL

        // Remove existing file at path if needed
        try? FileManager.default.removeItem(at: outputURL)

        // 2. Fetch shareable content & configure SCContentFilter
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw RecordingError.streamInitializationFailed(error.localizedDescription)
        }

        let filter: SCContentFilter
        var captureWidth: Int = 1920
        var captureHeight: Int = 1080

        switch configuration.target {
        case .display(let displayID):
            let display = findDisplay(displayID: displayID, in: content)
            guard let validDisplay = display else {
                throw RecordingError.streamInitializationFailed("No display found")
            }
            filter = SCContentFilter(display: validDisplay, excludingWindows: [])
            captureWidth = validDisplay.width
            captureHeight = validDisplay.height

        case .window(let windowID):
            let window: SCWindow?
            if windowID == 0 {
                let myPID = ProcessInfo.processInfo.processIdentifier
                window = content.windows.first(where: {
                    $0.isOnScreen && $0.frame.width > 50 && $0.frame.height > 50 && $0.owningApplication?.processID != myPID
                }) ?? content.windows.first(where: { $0.isOnScreen && $0.frame.width > 50 })
            } else {
                window = content.windows.first(where: { $0.windowID == windowID })
            }

            guard let validWindow = window else {
                throw RecordingError.streamInitializationFailed("Window target not found")
            }
            filter = SCContentFilter(desktopIndependentWindow: validWindow)
            captureWidth = max(2, Int(validWindow.frame.width))
            captureHeight = max(2, Int(validWindow.frame.height))

        case .region(let rect, let displayID):
            let display = findDisplay(displayID: displayID, in: content)
            guard let validDisplay = display else {
                throw RecordingError.streamInitializationFailed("No display found for region")
            }
            filter = SCContentFilter(display: validDisplay, excludingWindows: [])
            captureWidth = max(2, Int(rect.width))
            captureHeight = max(2, Int(rect.height))
        }

        // Apply resolution preset and even dimensions required by H.264 / HEVC encoders
        let outputDims = configuration.calculateDimensions(sourceWidth: captureWidth, sourceHeight: captureHeight)
        captureWidth = outputDims.width
        captureHeight = outputDims.height

        // 3. Initialize AVAssetWriter
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        } catch {
            throw RecordingError.writerInitializationFailed(error.localizedDescription)
        }

        let videoSettings = configuration.buildVideoSettings(width: captureWidth, height: captureHeight)
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: captureWidth,
            kCVPixelBufferHeightKey as String: captureHeight
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        guard writer.canAdd(videoInput) else {
            throw RecordingError.writerInitializationFailed("Cannot add video input to asset writer")
        }
        writer.add(videoInput)

        var audioInput: AVAssetWriterInput?
        if configuration.hasAudio {
            let audioSettings = AudioRecordingManager.shared.buildAACAudioSettings()
            let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            aInput.expectsMediaDataInRealTime = true
            guard writer.canAdd(aInput) else {
                throw RecordingError.writerInitializationFailed("Cannot add audio input to asset writer")
            }
            writer.add(aInput)
            audioInput = aInput
        }

        guard writer.startWriting() else {
            throw RecordingError.writerInitializationFailed(writer.error?.localizedDescription ?? "startWriting failed")
        }

        // 4. Configure SCStream
        let streamConfig = SCStreamConfiguration()
        streamConfig.width = captureWidth
        streamConfig.height = captureHeight
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(configuration.frameRate))
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfig.showsCursor = true

        if configuration.systemAudio {
            streamConfig.capturesAudio = true
        }

        if #available(macOS 15.0, *) {
            if configuration.microphone {
                streamConfig.captureMicrophone = true
            }
        }

        if case .region(let rect, _) = configuration.target {
            streamConfig.sourceRect = rect
        }

        let stream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
        do {
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.maczy.recording.videoQueue", qos: .userInitiated))
            if configuration.systemAudio {
                try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "com.maczy.recording.audioQueue", qos: .userInitiated))
            }
            if #available(macOS 15.0, *) {
                if configuration.microphone {
                    try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: DispatchQueue(label: "com.maczy.recording.micQueue", qos: .userInitiated))
                }
            }
            try await stream.startCapture()
        } catch {
            writer.cancelWriting()
            cancelSessionClaim()
            throw RecordingError.streamInitializationFailed(error.localizedDescription)
        }

        storeSession(
            stream: stream,
            writer: writer,
            videoInput: videoInput,
            audioInput: audioInput,
            adaptor: adaptor,
            configuration: configuration
        )

        return outputURL
    }

    /// Stops the active recording session, finalizes the MP4 asset, and returns the file URL.
    public func stopRecording() async throws -> URL {
        guard let (stream, writer, videoInput, audioInput, config) = resetSession() else {
            throw RecordingError.notRecording
        }

        // 1. Stop capture stream
        try await stream.stopCapture()

        // 2. Finalize video & audio writers
        videoInput.markAsFinished()
        audioInput?.markAsFinished()
        let finalURL = config.outputURL

        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }

        return finalURL
    }

    // MARK: - SCStreamOutput

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }

        switch type {
        case .screen:
            lock.lock()
            guard isRecordingInternal,
                  let writer = assetWriter,
                  let input = videoInput,
                  let adaptor = pixelBufferAdaptor else {
                lock.unlock()
                return
            }

            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            // Initialize session start time with the first frame timestamp
            if sessionStartTime == .invalid {
                sessionStartTime = timestamp
                writer.startSession(atSourceTime: timestamp)
            }

            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                lock.unlock()
                return
            }

            if input.isReadyForMoreMediaData {
                adaptor.append(imageBuffer, withPresentationTime: timestamp)
                frameCount += 1
            }
            lock.unlock()

        case .audio, .microphone:
            lock.lock()
            guard isRecordingInternal,
                  let writer = assetWriter,
                  let audioIn = audioInput else {
                lock.unlock()
                return
            }

            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            if sessionStartTime == .invalid {
                sessionStartTime = timestamp
                writer.startSession(atSourceTime: timestamp)
            }

            if audioIn.isReadyForMoreMediaData {
                audioIn.append(sampleBuffer)
            }
            lock.unlock()

        @unknown default:
            break
        }
    }

    private func findDisplay(displayID: CGDirectDisplayID?, in content: SCShareableContent) -> SCDisplay? {
        if let id = displayID {
            return content.displays.first(where: { $0.displayID == id }) ?? content.displays.first
        }
        return content.displays.first
    }
}
