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

    private let provider: MediaRemoteProviderProtocol
    private let audioDetector: AudioOutputDetectorProtocol
    private var pollTimer: Timer?

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

        if track.isPlaying {
            self.currentTrack = track
            self.isMediaActive = true
            self.isAudioActive = true
            self.isAudioPlaying = true
        } else if audioRunning {
            // Audio output active from browser, system, YouTube, Spotify, etc.
            if track != .idle && track.title != NowPlayingItem.idle.title {
                self.currentTrack = track
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
        } else if track != .idle && track.title != NowPlayingItem.idle.title {
            // Paused media track
            self.currentTrack = track
            self.isMediaActive = true
            self.isAudioActive = false
            self.isAudioPlaying = false
        } else {
            // No media or audio
            self.currentTrack = .idle
            self.isMediaActive = false
            self.isAudioActive = false
            self.isAudioPlaying = false
        }
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
