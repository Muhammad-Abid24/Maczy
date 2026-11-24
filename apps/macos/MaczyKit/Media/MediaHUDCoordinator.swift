import Foundation
import Combine

/// Main-actor coordinator managing active media playback telemetry, audio output detection, and controls.
@MainActor
public final class MediaHUDCoordinator: ObservableObject {
    public static let shared = MediaHUDCoordinator()

    @Published public private(set) var currentTrack: NowPlayingItem = .idle
    @Published public private(set) var isMediaActive: Bool = false
    @Published public private(set) var isAudioActive: Bool = false
    @Published public private(set) var isAudioPlaying: Bool = false

    /// Duration after audio pauses before the activity is dismissed and the notch returns to normal (default 5 minutes).
    public static let pausedAudioDismissalTimeout: TimeInterval = 300
    public var customDismissalTimeout: TimeInterval? = nil

    private let provider: MediaRemoteProviderProtocol
    private let audioDetector: AudioOutputDetectorProtocol
    private var pollTimer: Timer?
    private var pausedDismissalTask: Task<Void, Never>? = nil

    public init(
        provider: MediaRemoteProviderProtocol = NativeMediaRemoteProvider(),
        audioDetector: AudioOutputDetectorProtocol = NativeAudioOutputDetector(),
        autoStartMonitoring: Bool = true
    ) {
        self.provider = provider
        self.audioDetector = audioDetector
        if autoStartMonitoring {
            startMonitoring()
        }
    }

    /// Update track state from the underlying media provider and CoreAudio output status.
    public func refreshNowPlaying() async {
        let track = await provider.fetchNowPlaying()
        let audioRunning = audioDetector.isAudioOutputRunning()

        let isTrackPlaying: Bool = {
            if track != .idle && track.title != NowPlayingItem.idle.title {
                if track.duration != nil {
                    // Dedicated player with timeline (Music, Spotify, Mock)
                    return track.isPlaying
                } else {
                    // Browser streaming audio (YouTube, web)
                    return audioRunning
                }
            }
            return audioRunning
        }()

        if isTrackPlaying {
            // Cancel 5-minute pause timer as sound is actively playing
            pausedDismissalTask?.cancel()
            pausedDismissalTask = nil

            if track != .idle && track.title != NowPlayingItem.idle.title {
                self.currentTrack = track.withPlaying(true)
            } else {
                let (appName, icon) = audioDetector.activeAudioApplicationName()
                self.currentTrack = NowPlayingItem(
                    title: appName,
                    artist: "Audio Output",
                    album: nil,
                    isPlaying: true,
                    duration: nil,
                    elapsedTime: nil,
                    artworkIconName: icon
                )
            }
            self.isMediaActive = true
            self.isAudioActive = true
            self.isAudioPlaying = true
        } else {
            // Audio output is stopped or paused
            self.isAudioPlaying = false

            let existingTrack: NowPlayingItem? = {
                if track != .idle && track.title != NowPlayingItem.idle.title {
                    return track.withPlaying(false)
                } else if self.currentTrack != .idle && self.currentTrack.title != NowPlayingItem.idle.title {
                    return self.currentTrack.withPlaying(false)
                }
                return nil
            }()

            if let pausedTrack = existingTrack {
                self.currentTrack = pausedTrack
                self.isMediaActive = true
                self.isAudioActive = true

                // Start 5-minute pause timeout to restore notch silhouette if still paused
                if pausedDismissalTask == nil {
                    let timeout = customDismissalTimeout ?? Self.pausedAudioDismissalTimeout
                    pausedDismissalTask = Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                        guard let self = self, !Task.isCancelled else { return }
                        if !self.isAudioPlaying {
                            self.currentTrack = .idle
                            self.isMediaActive = false
                            self.isAudioActive = false
                            self.isAudioPlaying = false
                            self.pausedDismissalTask = nil
                        }
                    }
                }
            } else {
                pausedDismissalTask?.cancel()
                pausedDismissalTask = nil
                self.currentTrack = .idle
                self.isMediaActive = false
                self.isAudioActive = false
            }
        }
    }

    /// Toggle playback state.
    public func togglePlayPause() {
        Task {
            await provider.togglePlayPause()
            try? await Task.sleep(nanoseconds: 200_000_000)
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

    /// Begin monitoring for media and CoreAudio changes.
    public func startMonitoring(interval: TimeInterval = 2.5) {
        stopMonitoring()

        audioDetector.startMonitoring { [weak self] _ in
            Task { @MainActor in
                await self?.refreshNowPlaying()
            }
        }

        Task {
            await refreshNowPlaying()
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshNowPlaying()
            }
        }
    }

    /// Stop periodic media and audio monitoring.
    public func stopMonitoring() {
        audioDetector.stopMonitoring()
        pollTimer?.invalidate()
        pollTimer = nil
    }

    deinit {
        pollTimer?.invalidate()
    }
}
