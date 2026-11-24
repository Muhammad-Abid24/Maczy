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

/// Native macOS provider querying active players (Music, Spotify, browsers) asynchronously.
public struct NativeMediaRemoteProvider: MediaRemoteProviderProtocol {
    private typealias MRGetNowPlayingInfoFunc = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void

    public init() {}

    public func fetchNowPlaying() async -> NowPlayingItem {
        // 1. Direct MediaRemote query (fastest, supports YouTube in browsers, Music, Spotify)
        if let remoteTrack = await queryMediaRemote() {
            return remoteTrack
        }

        // 2. Check if Apple Music is running
        if isAppRunning(bundleId: "com.apple.Music") {
            if let track = await queryMusicPlayer() {
                return track
            }
        }

        // 3. Check if Spotify is running
        if isAppRunning(bundleId: "com.spotify.client") {
            if let track = await querySpotifyPlayer() {
                return track
            }
        }

        // 4. Check web browsers (Brave, Chrome, Safari, Edge, Arc)
        if let browserTrack = await queryBrowserMedia() {
            return browserTrack
        }

        return .idle
    }

    private func queryMediaRemote() async -> NowPlayingItem? {
        await withCheckedContinuation { continuation in
            guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY),
                  let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else {
                continuation.resume(returning: nil)
                return
            }
            let getInfo = unsafeBitCast(sym, to: MRGetNowPlayingInfoFunc.self)
            getInfo(DispatchQueue.global(qos: .userInteractive)) { info in
                guard !info.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
                guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "Media"
                let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String
                let duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double
                let elapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double
                let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? (info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Int).map(Double.init) ?? 0.0
                let isPlaying = (rate > 0.01)

                var icon = "play.rectangle.fill"
                let titleLower = title.lowercased()
                let artistLower = artist.lowercased()
                if titleLower.contains("youtube") || artistLower.contains("youtube") || titleLower.contains("video") || duration == nil {
                    icon = "play.rectangle.fill"
                } else if let dur = duration, dur > 0 {
                    icon = "music.note"
                }

                let item = NowPlayingItem(
                    title: title,
                    artist: artist,
                    album: album,
                    isPlaying: isPlaying,
                    duration: duration,
                    elapsedTime: elapsed,
                    artworkIconName: icon
                )
                continuation.resume(returning: item)
            }
        }
    }

    public func play() async {
        if isAppRunning(bundleId: "com.apple.Music") {
            _ = await runAppleScript("tell application \"Music\" to play")
        } else if isAppRunning(bundleId: "com.spotify.client") {
            _ = await runAppleScript("tell application \"Spotify\" to play")
        } else {
            Self.sendSystemMediaKey(key: 16) // NX_KEYTYPE_PLAY
        }
    }

    public func pause() async {
        if isAppRunning(bundleId: "com.apple.Music") {
            _ = await runAppleScript("tell application \"Music\" to pause")
        } else if isAppRunning(bundleId: "com.spotify.client") {
            _ = await runAppleScript("tell application \"Spotify\" to pause")
        } else {
            Self.sendSystemMediaKey(key: 16) // NX_KEYTYPE_PLAY
        }
    }

    public func togglePlayPause() async {
        if isAppRunning(bundleId: "com.apple.Music") {
            _ = await runAppleScript("tell application \"Music\" to playpause")
        } else if isAppRunning(bundleId: "com.spotify.client") {
            _ = await runAppleScript("tell application \"Spotify\" to playpause")
        } else {
            Self.sendSystemMediaKey(key: 16) // NX_KEYTYPE_PLAY
        }
    }

    public func nextTrack() async {
        if isAppRunning(bundleId: "com.apple.Music") {
            _ = await runAppleScript("tell application \"Music\" to next track")
        } else if isAppRunning(bundleId: "com.spotify.client") {
            _ = await runAppleScript("tell application \"Spotify\" to next track")
        } else {
            Self.sendSystemMediaKey(key: 19) // NX_KEYTYPE_FAST
        }
    }

    public func previousTrack() async {
        if isAppRunning(bundleId: "com.apple.Music") {
            _ = await runAppleScript("tell application \"Music\" to previous track")
        } else if isAppRunning(bundleId: "com.spotify.client") {
            _ = await runAppleScript("tell application \"Spotify\" to previous track")
        } else {
            Self.sendSystemMediaKey(key: 20) // NX_KEYTYPE_REWIND
        }
    }

    /// Dispatches hardware system media keys universally recognized by macOS across all apps and browsers.
    public static func sendSystemMediaKey(key: Int32) {
        func doKey(down: Bool) {
            let flags: NSEvent.ModifierFlags = down ? [.init(rawValue: 0xa00)] : [.init(rawValue: 0xb00)]
            let data1 = Int((key << 16) | (down ? 0xa00 : 0xb00))
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
        doKey(down: true)
        doKey(down: false)
    }

    private func isAppRunning(bundleId: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }

    private func queryBrowserMedia() async -> NowPlayingItem? {
        let browsers: [(bundleId: String, name: String)] = [
            ("com.brave.Browser", "Brave"),
            ("com.google.Chrome", "Google Chrome"),
            ("com.apple.Safari", "Safari"),
            ("com.microsoft.edgemac", "Microsoft Edge"),
            ("company.thebrowser.Browser", "Arc")
        ]

        for b in browsers {
            if isAppRunning(bundleId: b.bundleId) {
                if let item = await querySingleBrowser(bundleId: b.bundleId, browserName: b.name) {
                    return item
                }
            }
        }
        return nil
    }

    private func querySingleBrowser(bundleId: String, browserName: String) async -> NowPlayingItem? {
        let script: String
        if bundleId == "com.apple.Safari" {
            script = """
            tell application "Safari"
                repeat with w in windows
                    set t to current tab of w
                    set u to (URL of t) as text
                    if u contains "youtube.com/watch" or u contains "music.youtube" or u contains "soundcloud" or u contains "spotify" then
                        return (name of t) & "|||" & u
                    end if
                end repeat
                repeat with w in windows
                    repeat with t in tabs of w
                        set u to (URL of t) as text
                        if u contains "youtube.com/watch" or u contains "music.youtube" then
                            return (name of t) & "|||" & u
                        end if
                    end repeat
                end repeat
                if (count of windows) > 0 then
                    set t to current tab of window 1
                    return (name of t) & "|||" & ((URL of t) as text)
                end if
                return ""
            end tell
            """
        } else {
            script = """
            tell application id "\(bundleId)"
                repeat with w in windows
                    set t to active tab of w
                    set u to (URL of t) as text
                    if u contains "youtube.com/watch" or u contains "music.youtube" or u contains "soundcloud" or u contains "spotify" then
                        return (title of t) & "|||" & u
                    end if
                end repeat
                repeat with w in windows
                    repeat with t in tabs of w
                        set u to (URL of t) as text
                        if u contains "youtube.com/watch" or u contains "music.youtube" then
                            return (title of t) & "|||" & u
                        end if
                    end repeat
                end repeat
                if (count of windows) > 0 then
                    set t to active tab of window 1
                    return (title of t) & "|||" & ((URL of t) as text)
                end if
                return ""
            end tell
            """
        }

        guard let output = await runAppleScript(script), !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard !parts.isEmpty else { return nil }
        let rawTitle = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawTitle.isEmpty else { return nil }

        let parsed = parseBrowserMediaTitle(rawTitle, browserName: browserName)
        return NowPlayingItem(
            title: parsed.title,
            artist: parsed.artist,
            album: nil,
            isPlaying: true,
            duration: nil,
            elapsedTime: nil,
            artworkIconName: parsed.icon
        )
    }

    private func parseBrowserMediaTitle(_ rawTitle: String, browserName: String) -> (title: String, artist: String, icon: String) {
        var title = rawTitle
        // Strip leading notification badge like "(1) " or "(99+) "
        if let badgeRange = title.range(of: "^\\([0-9+]+\\)\\s*", options: .regularExpression) {
            title.removeSubrange(badgeRange)
        }

        var artist = "\(browserName) Audio"
        var icon = "play.rectangle.fill"

        if title.hasSuffix(" - YouTube") {
            title = String(title.dropLast(" - YouTube".count))
            artist = "YouTube • \(browserName)"
            icon = "play.rectangle.fill"
        } else if title.hasSuffix(" - YouTube Music") {
            title = String(title.dropLast(" - YouTube Music".count))
            artist = "YouTube Music"
            icon = "music.note"
        } else if title.contains("SoundCloud") {
            artist = "SoundCloud • \(browserName)"
            icon = "waveform"
        } else if title.contains("Spotify") {
            artist = "Spotify Web"
            icon = "music.note.list"
        }

        if title.contains(" - ") {
            let parts = title.components(separatedBy: " - ")
            if parts.count == 2 {
                artist = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                title = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleanTitle.isEmpty ? "Media Stream" : cleanTitle, artist, icon)
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
