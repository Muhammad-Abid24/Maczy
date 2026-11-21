import Foundation
import Combine

/// Main-actor coordinator managing active media playback telemetry and controls.
@MainActor
public final class MediaHUDCoordinator: ObservableObject {
    public static let shared = MediaHUDCoordinator()

    @Published public private(set) var currentTrack: NowPlayingItem = .idle
    @Published public private(set) var isMediaActive: Bool = false

    private let provider: MediaRemoteProviderProtocol
    private var pollTimer: Timer?

    public init(provider: MediaRemoteProviderProtocol = NativeMediaRemoteProvider()) {
        self.provider = provider
    }

    /// Update track state from the underlying media provider.
    public func refreshNowPlaying() async {
        let track = await provider.fetchNowPlaying()
        self.currentTrack = track
        self.isMediaActive = track.isPlaying || (track != .idle)
    }

    /// Toggle playback state.
    public func togglePlayPause() {
        Task {
            await provider.togglePlayPause()
            await refreshNowPlaying()
        }
    }

    /// Play active track.
    public func play() {
        Task {
            await provider.play()
            await refreshNowPlaying()
        }
    }

    /// Pause active track.
    public func pause() {
        Task {
            await provider.pause()
            await refreshNowPlaying()
        }
    }

    /// Skip to next track.
    public func nextTrack() {
        Task {
            await provider.nextTrack()
            await refreshNowPlaying()
        }
    }

    /// Skip to previous track.
    public func previousTrack() {
        Task {
            await provider.previousTrack()
            await refreshNowPlaying()
        }
    }

    /// Begin polling for media changes.
    public func startMonitoring(interval: TimeInterval = 2.5) {
        stopMonitoring()
        Task {
            await refreshNowPlaying()
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshNowPlaying()
            }
        }
    }

    /// Stop periodic media polling.
    public func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    deinit {
        pollTimer?.invalidate()
    }
}
