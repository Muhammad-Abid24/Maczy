import Foundation
import CoreAudio
import AudioToolbox
import AppKit

/// Protocol defining system audio output activity detection.
public protocol AudioOutputDetectorProtocol: Sendable {
    func isAudioOutputRunning() -> Bool
    func activeAudioApplicationName() -> (name: String, iconName: String)
    func startMonitoring(onChange: @escaping @Sendable (Bool) -> Void)
    func stopMonitoring()
}

/// Native macOS CoreAudio implementation detecting active sound output across all apps (Apple Music, Spotify, browsers, YouTube, etc.).
public final class NativeAudioOutputDetector: AudioOutputDetectorProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var isMonitoring: Bool = false
    private var changeHandler: (@Sendable (Bool) -> Void)?
    private var defaultDeviceID: AudioDeviceID = 0
    private var deviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var hardwareListenerBlock: AudioObjectPropertyListenerBlock?
    private var debounceTimer: Timer?

    public init() {
        self.defaultDeviceID = fetchDefaultOutputDeviceID()
    }

    /// Queries CoreAudio whether the default audio output device is currently running somewhere.
    public func isAudioOutputRunning() -> Bool {
        let deviceID = fetchDefaultOutputDeviceID()
        guard deviceID != 0 else { return false }

        var isRunning: UInt32 = 0
        var propertySize = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &propertySize,
            &isRunning
        )

        return (status == noErr && isRunning != 0)
    }

    /// Identifies the running browser or media application likely outputting audio.
    public func activeAudioApplicationName() -> (name: String, iconName: String) {
        let runningApps = NSWorkspace.shared.runningApplications

        // Check active dedicated music players first
        if runningApps.contains(where: { $0.bundleIdentifier == "com.apple.Music" }) {
            return ("Apple Music", "music.note")
        }
        if runningApps.contains(where: { $0.bundleIdentifier == "com.spotify.client" }) {
            return ("Spotify", "music.note.list")
        }

        // Check active web browsers (likely playing YouTube, Soundcloud, video, etc.)
        let browsers: [(bundleId: String, name: String, icon: String)] = [
            ("com.apple.Safari", "Safari", "safari.fill"),
            ("com.google.Chrome", "Google Chrome", "globe"),
            ("company.thebrowser.Browser", "Arc", "globe"),
            ("com.brave.Browser", "Brave", "globe"),
            ("org.mozilla.firefox", "Firefox", "globe"),
            ("com.microsoft.edgemac", "Microsoft Edge", "globe")
        ]

        for b in browsers {
            if runningApps.contains(where: { $0.bundleIdentifier == b.bundleId }) {
                return (b.name, b.icon)
            }
        }

        // Check podcasts / TV
        if runningApps.contains(where: { $0.bundleIdentifier == "com.apple.podcasts" }) {
            return ("Podcasts", "waveform")
        }
        if runningApps.contains(where: { $0.bundleIdentifier == "com.apple.TV" }) {
            return ("Apple TV", "tv")
        }

        return ("Audio Output", "waveform")
    }

    /// Starts observing CoreAudio device running state and hardware changes.
    public func startMonitoring(onChange: @escaping @Sendable (Bool) -> Void) {
        lock.lock()
        defer { lock.unlock() }

        self.changeHandler = onChange
        self.isMonitoring = true
        registerListeners()

        // Immediate check on start
        let currentRunning = isAudioOutputRunning()
        DispatchQueue.main.async {
            onChange(currentRunning)
        }
    }

    /// Stops observing CoreAudio events.
    public func stopMonitoring() {
        lock.lock()
        defer { lock.unlock() }

        unregisterListeners()
        self.changeHandler = nil
        self.isMonitoring = false
        self.debounceTimer?.invalidate()
        self.debounceTimer = nil
    }

    private func registerListeners() {
        unregisterListeners()

        self.defaultDeviceID = fetchDefaultOutputDeviceID()
        guard defaultDeviceID != 0 else { return }

        // 1. Device running somewhere listener
        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let runningBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self = self else { return }
            self.handleDeviceRunningChanged()
        }
        self.deviceListenerBlock = runningBlock

        AudioObjectAddPropertyListenerBlock(
            defaultDeviceID,
            &runningAddress,
            DispatchQueue.main,
            runningBlock
        )

        // 2. Hardware default output device changed listener (e.g. plugging headphones/AirPods)
        var hardwareAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let hwBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self = self else { return }
            self.lock.lock()
            defer { self.lock.unlock() }
            if self.isMonitoring {
                self.registerListeners()
                self.handleDeviceRunningChanged()
            }
        }
        self.hardwareListenerBlock = hwBlock

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &hardwareAddress,
            DispatchQueue.main,
            hwBlock
        )
    }

    private func unregisterListeners() {
        if defaultDeviceID != 0, let block = deviceListenerBlock {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(defaultDeviceID, &address, DispatchQueue.main, block)
            deviceListenerBlock = nil
        }

        if let block = hardwareListenerBlock {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, block)
            hardwareListenerBlock = nil
        }
    }

    private func handleDeviceRunningChanged() {
        let isRunning = isAudioOutputRunning()
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let handler = self.changeHandler else { return }
            self.debounceTimer?.invalidate()
            self.debounceTimer = nil
            // Notify immediately with zero delay so spectrum stops the exact moment audio is paused/stopped
            handler(isRunning)
        }
    }

    private func fetchDefaultOutputDeviceID() -> AudioDeviceID {
        var deviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &deviceID
        )

        return (status == noErr) ? deviceID : 0
    }

    deinit {
        unregisterListeners()
        debounceTimer?.invalidate()
    }
}

/// Mock detector for unit testing audio output synchronization.
public final class MockAudioOutputDetector: AudioOutputDetectorProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var simulatedRunning: Bool
    private var simulatedAppName: String
    private var simulatedIcon: String
    private var changeHandler: (@Sendable (Bool) -> Void)?

    public init(initialRunning: Bool = false, appName: String = "Mock Player", iconName: String = "music.note") {
        self.simulatedRunning = initialRunning
        self.simulatedAppName = appName
        self.simulatedIcon = iconName
    }

    public func isAudioOutputRunning() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return simulatedRunning
    }

    public func activeAudioApplicationName() -> (name: String, iconName: String) {
        lock.lock()
        defer { lock.unlock() }
        return (simulatedAppName, simulatedIcon)
    }

    public func startMonitoring(onChange: @escaping @Sendable (Bool) -> Void) {
        lock.lock()
        self.changeHandler = onChange
        let running = simulatedRunning
        lock.unlock()
        DispatchQueue.main.async {
            onChange(running)
        }
    }

    public func stopMonitoring() {
        lock.lock()
        defer { lock.unlock() }
        self.changeHandler = nil
    }

    public func simulateAudioState(isRunning: Bool, appName: String? = nil, iconName: String? = nil) {
        lock.lock()
        self.simulatedRunning = isRunning
        if let appName = appName { self.simulatedAppName = appName }
        if let iconName = iconName { self.simulatedIcon = iconName }
        let handler = self.changeHandler
        lock.unlock()

        DispatchQueue.main.async {
            handler?(isRunning)
        }
    }
}
