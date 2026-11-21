import Foundation
import CoreGraphics
import AppKit

/// Coordinates user recording triggers, interactive region selection, and state updates.
@MainActor
public final class RecordingCoordinator: NSObject, AreaSelectionOverlayDelegate {
    public static let shared = RecordingCoordinator()

    private var activeRegionOverlay: AreaSelectionOverlayWindowController?
    private var pendingRegionAudioOptions: (systemAudio: Bool, mic: Bool)?
    private var currentRecordedURL: URL?

    public private(set) var activeOutputURL: URL?

    public override init() {
        super.init()
    }

    /// Triggers start of screen recording for the given target specification.
    public func startRecording(
        target: String,
        systemAudio: Bool = false,
        microphone: Bool = false,
        completion: ((Result<URL, Error>) -> Void)? = nil
    ) {
        let normalizedTarget = target.lowercased()

        if normalizedTarget == "region" || normalizedTarget == "area" {
            // Interactive region selection first
            self.pendingRegionAudioOptions = (systemAudio, microphone)
            let overlay = AreaSelectionOverlayWindowController(screen: NSScreen.main ?? NSScreen.screens[0])
            overlay.delegate = self
            self.activeRegionOverlay = overlay
            overlay.present()
        } else if normalizedTarget == "window" {
            let config = RecordingConfiguration(
                target: .window(windowID: 0),
                systemAudio: systemAudio,
                microphone: microphone
            )
            executeStart(config: config, completion: completion)
        } else {
            // Fullscreen display
            let config = RecordingConfiguration(
                target: .display(displayID: nil),
                systemAudio: systemAudio,
                microphone: microphone
            )
            executeStart(config: config, completion: completion)
        }
    }

    /// Stops the active recording session.
    public func stopRecording(completion: ((Result<URL, Error>) -> Void)? = nil) {
        Task {
            do {
                let savedURL = try await ScreenRecordingEngine.shared.stopRecording()
                self.activeOutputURL = nil
                self.currentRecordedURL = savedURL
                completion?(.success(savedURL))
            } catch {
                self.activeOutputURL = nil
                completion?(.failure(error))
            }
        }
    }

    private func executeStart(config: RecordingConfiguration, completion: ((Result<URL, Error>) -> Void)?) {
        Task {
            do {
                let outputURL = try await ScreenRecordingEngine.shared.startRecording(configuration: config)
                self.activeOutputURL = outputURL
                completion?(.success(outputURL))
            } catch {
                completion?(.failure(error))
            }
        }
    }

    // MARK: - AreaSelectionOverlayDelegate

    public func areaSelectionDidSelectRect(_ rect: CGRect, on displayID: CGDirectDisplayID) {
        self.activeRegionOverlay = nil
        let audioOpts = self.pendingRegionAudioOptions ?? (false, false)
        self.pendingRegionAudioOptions = nil

        let config = RecordingConfiguration(
            target: .region(rect: rect, displayID: displayID),
            systemAudio: audioOpts.systemAudio,
            microphone: audioOpts.mic
        )
        executeStart(config: config, completion: nil)
    }

    public func areaSelectionDidCancel() {
        self.activeRegionOverlay = nil
        self.pendingRegionAudioOptions = nil
    }
}
