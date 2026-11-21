import Foundation
import AppKit

/// Protocol defining media playback observation and control.
public protocol MediaRemoteProviderProtocol: Sendable {
    func fetchNowPlaying() async -> NowPlayingItem
    func play() async
    func pause() async
    func togglePlayPause() async
    func nextTrack() async
    func previousTrack() async
}

/// Native macOS provider querying active players (Music, Spotify) asynchronously.
public struct NativeMediaRemoteProvider: MediaRemoteProviderProtocol {
    public init() {}

    public func fetchNowPlaying() async -> NowPlayingItem {
        // 1. Check if Apple Music is running
        if isAppRunning(bundleId: "com.apple.Music") {
            if let track = await queryMusicPlayer() {
                return track
            }
        }

        // 2. Check if Spotify is running
        if isAppRunning(bundleId: "com.spotify.client") {
            if let track = await querySpotifyPlayer() {
                return track
            }
        }

        return .idle
    }

    public func play() async {
        if isAppRunning(bundleId: "com.apple.Music") {
            _ = await runAppleScript("tell application \"Music\" to play")
        } else if isAppRunning(bundleId: "com.spotify.client") {
            _ = await runAppleScript("tell application \"Spotify\" to play")
        }
    }

    public func pause() async {
        if isAppRunning(bundleId: "com.apple.Music") {
            _ = await runAppleScript("tell application \"Music\" to pause")
        } else if isAppRunning(bundleId: "com.spotify.client") {
            _ = await runAppleScript("tell application \"Spotify\" to pause")
        }
    }

    public func togglePlayPause() async {
        if isAppRunning(bundleId: "com.apple.Music") {
            _ = await runAppleScript("tell application \"Music\" to playpause")
        } else if isAppRunning(bundleId: "com.spotify.client") {
            _ = await runAppleScript("tell application \"Spotify\" to playpause")
        }
    }

    public func nextTrack() async {
        if isAppRunning(bundleId: "com.apple.Music") {
            _ = await runAppleScript("tell application \"Music\" to next track")
        } else if isAppRunning(bundleId: "com.spotify.client") {
            _ = await runAppleScript("tell application \"Spotify\" to next track")
        }
    }

    public func previousTrack() async {
        if isAppRunning(bundleId: "com.apple.Music") {
            _ = await runAppleScript("tell application \"Music\" to previous track")
        } else if isAppRunning(bundleId: "com.spotify.client") {
            _ = await runAppleScript("tell application \"Spotify\" to previous track")
        }
    }

    private func isAppRunning(bundleId: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }

    private func queryMusicPlayer() async -> NowPlayingItem? {
        let script = """
        tell application "Music"
            if player state is playing or player state is paused then
                set trackName to name of current track
                set artistName to artist of current track
                set albumName to album of current track
                set isPlaying to (player state is playing)
                set trackDuration to duration of current track
                set trackPosition to player position
                return trackName & "|||" & artistName & "|||" & albumName & "|||" & isPlaying & "|||" & trackDuration & "|||" & trackPosition
            end if
        end tell
        """
        guard let output = await runAppleScript(script), !output.isEmpty else { return nil }
        return parsePlayerOutput(output, defaultIcon: "music.note")
    }

    private func querySpotifyPlayer() async -> NowPlayingItem? {
        let script = """
        tell application "Spotify"
            if player state is playing or player state is paused then
                set trackName to name of current track
                set artistName to artist of current track
                set albumName to album of current track
                set isPlaying to (player state is playing)
                set trackDuration to (duration of current track) / 1000
                set trackPosition to player position
                return trackName & "|||" & artistName & "|||" & albumName & "|||" & isPlaying & "|||" & trackDuration & "|||" & trackPosition
            end if
        end tell
        """
        guard let output = await runAppleScript(script), !output.isEmpty else { return nil }
        return parsePlayerOutput(output, defaultIcon: "music.note.list")
    }

    private func parsePlayerOutput(_ output: String, defaultIcon: String) -> NowPlayingItem? {
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }
        let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let album = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let isPlaying = parts[3].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
        let duration = Double(parts[4].trimmingCharacters(in: .whitespacesAndNewlines))
        let position = Double(parts[5].trimmingCharacters(in: .whitespacesAndNewlines))

        return NowPlayingItem(
            title: title.isEmpty ? "Unknown Track" : title,
            artist: artist.isEmpty ? "Unknown Artist" : artist,
            album: album.isEmpty ? nil : album,
            isPlaying: isPlaying,
            duration: duration,
            elapsedTime: position,
            artworkIconName: defaultIcon
        )
    }

    private func runAppleScript(_ source: String) async -> String? {
        await Task.detached {
            var error: NSDictionary?
            guard let script = NSAppleScript(source: source) else { return nil }
            let descriptor = script.executeAndReturnError(&error)
            if error == nil {
                return descriptor.stringValue
            }
            return nil
        }.value
    }
}

/// In-memory mock media provider for hermetic testing.
public actor MockMediaRemoteProvider: MediaRemoteProviderProtocol {
    private var item: NowPlayingItem

    public init(initialItem: NowPlayingItem = .idle) {
        self.item = initialItem
    }

    public func setTrack(_ newItem: NowPlayingItem) {
        item = newItem
    }

    public func fetchNowPlaying() async -> NowPlayingItem {
        return item
    }

    public func play() async {
        item = NowPlayingItem(
            title: item.title,
            artist: item.artist,
            album: item.album,
            isPlaying: true,
            duration: item.duration,
            elapsedTime: item.elapsedTime,
            artworkIconName: item.artworkIconName
        )
    }

    public func pause() async {
        item = NowPlayingItem(
            title: item.title,
            artist: item.artist,
            album: item.album,
            isPlaying: false,
            duration: item.duration,
            elapsedTime: item.elapsedTime,
            artworkIconName: item.artworkIconName
        )
    }

    public func togglePlayPause() async {
        let nextPlaying = !item.isPlaying
        item = NowPlayingItem(
            title: item.title,
            artist: item.artist,
            album: item.album,
            isPlaying: nextPlaying,
            duration: item.duration,
            elapsedTime: item.elapsedTime,
            artworkIconName: item.artworkIconName
        )
    }

    public func nextTrack() async {
        item = NowPlayingItem(
            title: "Next Track",
            artist: item.artist,
            album: item.album,
            isPlaying: true,
            duration: item.duration ?? 200,
            elapsedTime: 0,
            artworkIconName: item.artworkIconName
        )
    }

    public func previousTrack() async {
        item = NowPlayingItem(
            title: "Previous Track",
            artist: item.artist,
            album: item.album,
            isPlaying: true,
            duration: item.duration ?? 200,
            elapsedTime: 0,
            artworkIconName: item.artworkIconName
        )
    }
}
