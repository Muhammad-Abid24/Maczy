import XCTest
@testable import MaczyKit

final class MediaHUDTests: XCTestCase {

    func testNowPlayingItemProgressAndFormatting() {
        let track = NowPlayingItem(
            title: "Midnight City",
            artist: "M83",
            album: "Hurry Up, We're Dreaming",
            isPlaying: true,
            duration: 244,
            elapsedTime: 61,
            artworkIconName: "music.note"
        )

        XCTAssertEqual(track.progress, 0.25, accuracy: 0.001)
        XCTAssertEqual(track.formattedElapsed, "1:01")
        XCTAssertEqual(track.formattedDuration, "4:04")
        XCTAssertTrue(track.isPlaying)

        // Test clamped progress when elapsed exceeds duration
        let overTrack = NowPlayingItem(
            title: "Outro",
            artist: "M83",
            duration: 100,
            elapsedTime: 120
        )
        XCTAssertEqual(overTrack.progress, 1.0)

        // Test idle track
        let idle = NowPlayingItem.idle
        XCTAssertEqual(idle.progress, 0.0)
        XCTAssertEqual(idle.formattedElapsed, "0:00")
        XCTAssertEqual(idle.formattedDuration, "--:--")
        XCTAssertFalse(idle.isPlaying)
    }

    func testMockMediaRemoteProviderControls() async {
        let initial = NowPlayingItem(
            title: "Starboy",
            artist: "The Weeknd",
            isPlaying: false,
            duration: 230,
            elapsedTime: 45
        )
        let provider = MockMediaRemoteProvider(initialItem: initial)

        let initialFetched = await provider.fetchNowPlaying()
        XCTAssertFalse(initialFetched.isPlaying)
        XCTAssertEqual(initialFetched.title, "Starboy")

        // Play
        await provider.play()
        let playing = await provider.fetchNowPlaying()
        XCTAssertTrue(playing.isPlaying)

        // Pause
        await provider.pause()
        let paused = await provider.fetchNowPlaying()
        XCTAssertFalse(paused.isPlaying)

        // Toggle Play/Pause
        await provider.togglePlayPause()
        let toggled = await provider.fetchNowPlaying()
        XCTAssertTrue(toggled.isPlaying)

        // Next Track
        await provider.nextTrack()
        let next = await provider.fetchNowPlaying()
        XCTAssertEqual(next.title, "Next Track")
        XCTAssertTrue(next.isPlaying)

        // Previous Track
        await provider.previousTrack()
        let prev = await provider.fetchNowPlaying()
        XCTAssertEqual(prev.title, "Previous Track")
    }

    @MainActor
    func testMediaHUDCoordinatorPlaybackLifecycle() async {
        let initial = NowPlayingItem(
            title: "Blinding Lights",
            artist: "The Weeknd",
            isPlaying: true,
            duration: 200,
            elapsedTime: 50
        )
        let mock = MockMediaRemoteProvider(initialItem: initial)
        let coordinator = MediaHUDCoordinator(provider: mock)

        await coordinator.refreshNowPlaying()
        XCTAssertTrue(coordinator.isMediaActive)
        XCTAssertEqual(coordinator.currentTrack.title, "Blinding Lights")

        coordinator.pause()
        // Wait briefly for Task to execute
        try? await Task.sleep(nanoseconds: 50_000_000)
        await coordinator.refreshNowPlaying()
        XCTAssertFalse(coordinator.currentTrack.isPlaying)
    }

    func testSystemHUDEventLevelClampingAndPercentage() {
        // Normal level
        let ev1 = SystemHUDEvent(type: .volume, level: 0.684)
        XCTAssertEqual(ev1.percentage, 68)
        XCTAssertEqual(ev1.iconName, "speaker.wave.3.fill")

        // Mute / Zero level
        let evZero = SystemHUDEvent(type: .volume, level: 0.0)
        XCTAssertEqual(evZero.percentage, 0)
        XCTAssertEqual(evZero.iconName, "speaker.slash.fill")

        // Clamped negative level
        let evNeg = SystemHUDEvent(type: .volume, level: -0.4)
        XCTAssertEqual(evNeg.level, 0.0)
        XCTAssertEqual(evNeg.percentage, 0)

        // Clamped over 1.0 level
        let evOver = SystemHUDEvent(type: .volume, level: 1.8)
        XCTAssertEqual(evOver.level, 1.0)
        XCTAssertEqual(evOver.percentage, 100)

        // Brightness low
        let evBrightLow = SystemHUDEvent(type: .brightness, level: 0.25)
        XCTAssertEqual(evBrightLow.iconName, "sun.min.fill")

        // Brightness high
        let evBrightHigh = SystemHUDEvent(type: .brightness, level: 0.85)
        XCTAssertEqual(evBrightHigh.iconName, "sun.max.fill")
    }

    @MainActor
    func testSystemHUDCoordinatorShowAndDismiss() {
        let coordinator = SystemHUDCoordinator()
        XCTAssertNil(coordinator.activeHUD)

        coordinator.showHUD(type: .volume, level: 0.65, autoDismissSeconds: 0)
        XCTAssertNotNil(coordinator.activeHUD)
        XCTAssertEqual(coordinator.activeHUD?.type, .volume)
        XCTAssertEqual(coordinator.activeHUD?.level, 0.65)
        XCTAssertEqual(coordinator.currentVolume, 0.65)

        coordinator.dismissHUD()
        XCTAssertNil(coordinator.activeHUD)
    }

    @MainActor
    func testSystemHUDCoordinatorSetVolumeAndBrightness() {
        let coordinator = SystemHUDCoordinator()

        coordinator.setVolume(0.42)
        XCTAssertEqual(coordinator.currentVolume, 0.42)
        XCTAssertEqual(coordinator.activeHUD?.type, .volume)
        XCTAssertEqual(coordinator.activeHUD?.percentage, 42)

        coordinator.setBrightness(0.91)
        XCTAssertEqual(coordinator.currentBrightness, 0.91)
        XCTAssertEqual(coordinator.activeHUD?.type, .brightness)
        XCTAssertEqual(coordinator.activeHUD?.percentage, 91)
    }

    func testNativeMediaRemoteProviderPreflightSafety() async {
        let provider = NativeMediaRemoteProvider()
        let item = await provider.fetchNowPlaying()
        // Must return either valid track or .idle without throwing
        XCTAssertFalse(item.title.isEmpty)
        XCTAssertFalse(item.artist.isEmpty)
    }
}
