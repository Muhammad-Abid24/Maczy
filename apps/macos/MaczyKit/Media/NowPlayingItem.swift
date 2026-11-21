import Foundation

/// Immutable model representing the active media track and playback progress.
public struct NowPlayingItem: Sendable, Equatable {
    public let title: String
    public let artist: String
    public let album: String?
    public let isPlaying: Bool
    public let duration: TimeInterval?
    public let elapsedTime: TimeInterval?
    public let artworkIconName: String

    public init(
        title: String,
        artist: String,
        album: String? = nil,
        isPlaying: Bool = false,
        duration: TimeInterval? = nil,
        elapsedTime: TimeInterval? = nil,
        artworkIconName: String = "music.note"
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.artworkIconName = artworkIconName
    }

    /// Empty idle track when no media is currently playing.
    public static let idle = NowPlayingItem(
        title: "No Media Playing",
        artist: "Ready",
        album: nil,
        isPlaying: false,
        duration: nil,
        elapsedTime: nil,
        artworkIconName: "music.note"
    )

    /// Playback progress normalized between 0.0 and 1.0.
    public var progress: Double {
        guard let dur = duration, dur > 0, let elapsed = elapsedTime else { return 0.0 }
        return max(0.0, min(1.0, elapsed / dur))
    }

    /// Formatted elapsed time string (e.g. "1:24").
    public var formattedElapsed: String {
        guard let elapsed = elapsedTime, elapsed >= 0 else { return "0:00" }
        let totalSeconds = Int(elapsed)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Formatted total duration string (e.g. "3:45").
    public var formattedDuration: String {
        guard let dur = duration, dur > 0 else { return "--:--" }
        let totalSeconds = Int(dur)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
