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

    @MainActor
    func testSystemHUDHardwareSynchronization() {
        let audioMock = MockAudioHardwareController(initialVolume: 0.30, initialMuted: false)
        let displayMock = MockDisplayHardwareController(initialBrightness: 0.60)
        let coordinator = SystemHUDCoordinator(
            audioController: audioMock,
            displayController: displayMock,
            autoStartObserving: true
        )

        // Initial sync state
        XCTAssertEqual(coordinator.currentVolume, 0.30, accuracy: 0.001)
        XCTAssertEqual(coordinator.isVolumeMuted, false)
        XCTAssertEqual(coordinator.currentBrightness, 0.60, accuracy: 0.001)

        // 1. Simulate external hardware volume change (e.g. keyboard F12)
        audioMock.simulateExternalHardwareChange(volume: 0.85, isMuted: false)
        XCTAssertEqual(coordinator.currentVolume, 0.85, accuracy: 0.001)
        XCTAssertNotNil(coordinator.activeHUD)
        XCTAssertEqual(coordinator.activeHUD?.type, .volume)
        XCTAssertEqual(coordinator.activeHUD?.percentage, 85)
        XCTAssertEqual(coordinator.activeHUD?.iconName, "speaker.wave.3.fill")

        // 2. Simulate external mute change (e.g. keyboard mute key)
        audioMock.simulateExternalHardwareChange(volume: 0.85, isMuted: true)
        XCTAssertEqual(coordinator.isVolumeMuted, true)
        XCTAssertEqual(coordinator.activeHUD?.type, .volume)
        XCTAssertEqual(coordinator.activeHUD?.percentage, 0)
        XCTAssertEqual(coordinator.activeHUD?.iconName, "speaker.slash.fill")

        // 3. Simulate external brightness change (e.g. keyboard F1/F2)
        displayMock.simulateExternalHardwareChange(brightness: 0.20)
        XCTAssertEqual(coordinator.currentBrightness, 0.20, accuracy: 0.001)
        XCTAssertEqual(coordinator.activeHUD?.type, .brightness)
        XCTAssertEqual(coordinator.activeHUD?.percentage, 20)
        XCTAssertEqual(coordinator.activeHUD?.iconName, "sun.min.fill")

        displayMock.simulateExternalHardwareChange(brightness: 0.95)
        XCTAssertEqual(coordinator.currentBrightness, 0.95, accuracy: 0.001)
        XCTAssertEqual(coordinator.activeHUD?.type, .brightness)
        XCTAssertEqual(coordinator.activeHUD?.percentage, 95)
        XCTAssertEqual(coordinator.activeHUD?.iconName, "sun.max.fill")

        // 4. Test programmatic setVolume propagates to hardware
        coordinator.setVolume(0.50)
        XCTAssertEqual(audioMock.fetchVolume(), 0.50, accuracy: 0.001)
        XCTAssertFalse(audioMock.isMuted())
        XCTAssertEqual(coordinator.activeHUD?.percentage, 50)

        // 5. Test programmatic setBrightness propagates to hardware
        coordinator.setBrightness(0.70)
        XCTAssertEqual(displayMock.fetchBrightness(), 0.70, accuracy: 0.001)
        XCTAssertEqual(coordinator.activeHUD?.percentage, 70)
    }

    @MainActor
    func testNotchCoordinatorHUDAutoReveal() {
        let coordinator = NotchCoordinator.shared
        coordinator.isOverlayVisible = false
        XCTAssertFalse(coordinator.isOverlayVisible)

        // Trigger a HUD event
        SystemHUDCoordinator.shared.showHUD(type: .volume, level: 0.75, autoDismissSeconds: 0)
        XCTAssertNotNil(SystemHUDCoordinator.shared.activeHUD)

        // Dismiss HUD
        SystemHUDCoordinator.shared.dismissHUD()
        XCTAssertNil(SystemHUDCoordinator.shared.activeHUD)
        XCTAssertFalse(coordinator.isOverlayVisible)
    }

    func testAudioOutputDetectorActiveDetection() {
        let detector = MockAudioOutputDetector(initialRunning: false, appName: "Safari", iconName: "safari.fill")
        XCTAssertFalse(detector.isAudioOutputRunning())
        XCTAssertEqual(detector.activeAudioApplicationName().name, "Safari")

        detector.simulateAudioState(isRunning: true, appName: "Google Chrome", iconName: "globe")
        XCTAssertTrue(detector.isAudioOutputRunning())
        XCTAssertEqual(detector.activeAudioApplicationName().name, "Google Chrome")
    }

    @MainActor
    func testMediaHUDCoordinatorAudioActiveIntegration() async {
        let mediaMock = MockMediaRemoteProvider(initialItem: .idle)
        let audioMock = MockAudioOutputDetector(initialRunning: false, appName: "Safari", iconName: "safari.fill")
        let coordinator = MediaHUDCoordinator(provider: mediaMock, audioDetector: audioMock, autoStartMonitoring: false)

        await coordinator.refreshNowPlaying()
        XCTAssertFalse(coordinator.isAudioActive)
        XCTAssertFalse(coordinator.isAudioPlaying)

        // Simulate browser audio starts playing (e.g. YouTube in Safari)
        audioMock.simulateAudioState(isRunning: true, appName: "Safari", iconName: "safari.fill")
        await coordinator.refreshNowPlaying()

        XCTAssertTrue(coordinator.isAudioActive)
        XCTAssertTrue(coordinator.isAudioPlaying)
        XCTAssertEqual(coordinator.currentTrack.title, "Safari")
        XCTAssertEqual(coordinator.currentTrack.artist, "Audio Output")

        // Simulate audio stops
        audioMock.simulateAudioState(isRunning: false)
        await coordinator.refreshNowPlaying()

        XCTAssertFalse(coordinator.isAudioActive)
        XCTAssertFalse(coordinator.isAudioPlaying)
    }

    @MainActor
    func testAudioCompactRectGeometry() {
        let profile = NotchScreenProfile.fallback
        let controller = NotchOverlayWindowController()

        let compact = controller.compactRect(for: profile, isAudioActive: false)
        let audioCompact = controller.compactRect(for: profile, isAudioActive: true)

        XCTAssertGreaterThan(audioCompact.width, compact.width)
        XCTAssertEqual(audioCompact.height, compact.height)
        XCTAssertEqual(audioCompact.midX, compact.midX, accuracy: 0.1)
    }
}
