import Foundation
import AVFoundation
import AppKit

/// Monitors live microphone audio levels for visual voice preview meters.
@MainActor
public final class MicrophoneLevelMonitor: ObservableObject {
    public static let shared = MicrophoneLevelMonitor()

    @Published public private(set) var audioLevel: Float = 0.0
    @Published public private(set) var isMonitoring: Bool = false
    @Published public private(set) var deviceName: String = "Built-in Microphone"

    /// Mock audio level for unit tests and headless environments.
    public var mockAudioLevel: Float? {
        didSet {
            if let mock = mockAudioLevel {
                self.audioLevel = mock
            } else {
                self.audioLevel = 0.0
            }
        }
    }

    private var audioEngine: AVAudioEngine?
    private var isEngineRunning: Bool = false

    public init() {}

    /// Starts monitoring live microphone input levels.
    public func startMonitoring() {
        guard !isMonitoring else { return }
        self.isMonitoring = true

        if let mock = mockAudioLevel {
            self.audioLevel = mock
            return
        }

        Task {
            // Check & request authorization if necessary
            if !AudioRecordingManager.shared.isMicrophoneAuthorized() {
                let granted = await AudioRecordingManager.shared.requestMicrophoneAccess()
                guard granted else { return }
            }

            self.setupAudioEngine()
        }
    }

    /// Stops monitoring microphone input.
    public func stopMonitoring() {
        guard isMonitoring else { return }
        self.isMonitoring = false

        if isEngineRunning, let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }

        self.audioEngine = nil
        self.isEngineRunning = false
        if mockAudioLevel == nil {
            self.audioLevel = 0.0
        }
    }

    private func setupAudioEngine() {
        guard isMonitoring else { return }

        do {
            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let bus = 0
            let format = inputNode.outputFormat(forBus: bus)

            // Safe guard against virtual/headless environments without active input channels
            guard format.channelCount > 0 else {
                return
            }

            inputNode.removeTap(onBus: bus)
            inputNode.installTap(onBus: bus, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                guard let channelData = buffer.floatChannelData?[0] else { return }
                let frameLength = Int(buffer.frameLength)
                guard frameLength > 0 else { return }

                var sum: Float = 0
                for i in 0..<frameLength {
                    sum += abs(channelData[i])
                }
                let avg = sum / Float(frameLength)
                // Normalize dynamically to 0.0 ... 1.0 with boosted response
                let normalized = min(1.0, max(0.0, avg * 10.0))

                Task { @MainActor [weak self] in
                    guard let self = self, self.isMonitoring else { return }
                    if self.mockAudioLevel == nil {
                        self.audioLevel = normalized
                    }
                }
            }

            try engine.start()
            self.audioEngine = engine
            self.isEngineRunning = true
        } catch {
            // Fails gracefully in headless test environments without hardware microphones
            self.isEngineRunning = false
        }
    }
}
