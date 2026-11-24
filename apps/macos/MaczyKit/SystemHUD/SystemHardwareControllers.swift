import Foundation
import CoreAudio
import AudioToolbox
import CoreGraphics
import AppKit

// MARK: - Audio Hardware Controller Protocol & Implementation

/// Protocol defining system audio volume querying, control, and real-time observation.
public protocol SystemAudioControllerProtocol: AnyObject, Sendable {
    func fetchVolume() -> Float
    func isMuted() -> Bool
    func setVolume(_ volume: Float) -> Bool
    func startObserving(onChange: @escaping @Sendable (_ volume: Float, _ isMuted: Bool) -> Void)
    func stopObserving()
}

/// Production CoreAudio implementation observing and controlling default macOS output volume.
public final class NativeAudioHardwareController: SystemAudioControllerProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var defaultOutputDeviceID: AudioDeviceID = 0
    private var isObserving = false
    private var onChangeCallback: (@Sendable (Float, Bool) -> Void)?

    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?
    private var muteListenerBlock: AudioObjectPropertyListenerBlock?
    private var deviceListenerBlock: AudioObjectPropertyListenerBlock?

    public init() {
        updateDefaultOutputDevice()
    }

    deinit {
        stopObserving()
    }

    private func updateDefaultOutputDevice() {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
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
            &size,
            &deviceID
        )
        if status == noErr {
            self.defaultOutputDeviceID = deviceID
        }
    }

    public func fetchVolume() -> Float {
        lock.lock()
        defer { lock.unlock() }

        guard defaultOutputDeviceID != 0 else { return 0.5 }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var volume: Float32 = 0.0
        var size = UInt32(MemoryLayout<Float32>.size)
        var status = AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &address,
            0,
            nil,
            &size,
            &volume
        )
        if status == noErr {
            return max(0.0, min(1.0, volume))
        }

        // Fallback to scalar volume property
        var scalarAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var scalarVolume: Float32 = 0.0
        var scalarSize = UInt32(MemoryLayout<Float32>.size)
        status = AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &scalarAddress,
            0,
            nil,
            &scalarSize,
            &scalarVolume
        )
        if status == noErr {
            return max(0.0, min(1.0, scalarVolume))
        }
        return 0.5
    }

    public func isMuted() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard defaultOutputDeviceID != 0 else { return false }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectGetPropertyData(defaultOutputDeviceID, &address, 0, nil, &size, &muted) == noErr {
            return muted != 0
        }
        return false
    }

    public func setVolume(_ volume: Float) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard defaultOutputDeviceID != 0 else { return false }
        let clamped = max(0.0, min(1.0, volume))
        var val = Float32(clamped)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var status = AudioObjectSetPropertyData(
            defaultOutputDeviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &val
        )
        if status != noErr {
            var scalarAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            status = AudioObjectSetPropertyData(
                defaultOutputDeviceID,
                &scalarAddress,
                0,
                nil,
                UInt32(MemoryLayout<Float32>.size),
                &val
            )
        }

        // If adjusting above zero while muted, automatically unmute
        if clamped > 0 {
            var muteVal: UInt32 = 0
            var muteAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            _ = AudioObjectSetPropertyData(
                defaultOutputDeviceID,
                &muteAddress,
                0,
                nil,
                UInt32(MemoryLayout<UInt32>.size),
                &muteVal
            )
        }
        return status == noErr
    }

    public func startObserving(onChange: @escaping @Sendable (_ volume: Float, _ isMuted: Bool) -> Void) {
        lock.lock()
        defer { lock.unlock() }

        self.onChangeCallback = onChange
        guard !isObserving else { return }
        isObserving = true

        setupListeners()
    }

    private func setupListeners() {
        guard defaultOutputDeviceID != 0 else { return }

        // 1. Volume Listener Block
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let volBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self = self else { return }
            let v = self.fetchVolume()
            let m = self.isMuted()
            self.onChangeCallback?(v, m)
        }
        self.volumeListenerBlock = volBlock
        _ = AudioObjectAddPropertyListenerBlock(
            defaultOutputDeviceID,
            &volumeAddress,
            DispatchQueue.main,
            volBlock
        )

        // 2. Mute Listener Block
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let mBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self = self else { return }
            let v = self.fetchVolume()
            let m = self.isMuted()
            self.onChangeCallback?(v, m)
        }
        self.muteListenerBlock = mBlock
        _ = AudioObjectAddPropertyListenerBlock(
            defaultOutputDeviceID,
            &muteAddress,
            DispatchQueue.main,
            mBlock
        )

        // 3. Default Output Device Change Listener Block
        var deviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let devBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self = self else { return }
            self.handleDefaultDeviceChanged()
        }
        self.deviceListenerBlock = devBlock
        _ = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &deviceAddress,
            DispatchQueue.main,
            devBlock
        )
    }

    private func handleDefaultDeviceChanged() {
        tearDownDeviceListeners()
        updateDefaultOutputDevice()
        setupListeners()
        let v = fetchVolume()
        let m = isMuted()
        onChangeCallback?(v, m)
    }

    private func tearDownDeviceListeners() {
        if defaultOutputDeviceID != 0 {
            if let volBlock = volumeListenerBlock {
                var address = AudioObjectPropertyAddress(
                    mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: kAudioObjectPropertyElementMain
                )
                AudioObjectRemovePropertyListenerBlock(defaultOutputDeviceID, &address, DispatchQueue.main, volBlock)
                volumeListenerBlock = nil
            }
            if let mBlock = muteListenerBlock {
                var address = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyMute,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: kAudioObjectPropertyElementMain
                )
                AudioObjectRemovePropertyListenerBlock(defaultOutputDeviceID, &address, DispatchQueue.main, mBlock)
                muteListenerBlock = nil
            }
        }
    }

    public func stopObserving() {
        lock.lock()
        defer { lock.unlock() }

        guard isObserving else { return }
        isObserving = false
        tearDownDeviceListeners()

        if let devBlock = deviceListenerBlock {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, devBlock)
            deviceListenerBlock = nil
        }
        onChangeCallback = nil
    }
}

/// In-memory mock audio controller for deterministic testing.
public final class MockAudioHardwareController: SystemAudioControllerProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var volume: Float
    private var muted: Bool
    private var onChangeCallback: (@Sendable (Float, Bool) -> Void)?

    public init(initialVolume: Float = 0.5, initialMuted: Bool = false) {
        self.volume = initialVolume
        self.muted = initialMuted
    }

    public func fetchVolume() -> Float {
        lock.lock()
        defer { lock.unlock() }
        return volume
    }

    public func isMuted() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return muted
    }

    public func setVolume(_ newVolume: Float) -> Bool {
        lock.lock()
        let clamped = max(0.0, min(1.0, newVolume))
        self.volume = clamped
        if clamped > 0 { self.muted = false }
        let cb = onChangeCallback
        let m = self.muted
        lock.unlock()

        cb?(clamped, m)
        return true
    }

    public func startObserving(onChange: @escaping @Sendable (Float, Bool) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        self.onChangeCallback = onChange
    }

    public func stopObserving() {
        lock.lock()
        defer { lock.unlock() }
        self.onChangeCallback = nil
    }

    public func simulateExternalHardwareChange(volume: Float, isMuted: Bool) {
        lock.lock()
        self.volume = max(0.0, min(1.0, volume))
        self.muted = isMuted
        let cb = onChangeCallback
        lock.unlock()

        cb?(self.volume, isMuted)
    }
}

// MARK: - Display Brightness Hardware Controller Protocol & Implementation

/// Protocol defining system display brightness querying, control, and real-time observation.
public protocol SystemDisplayControllerProtocol: AnyObject, Sendable {
    func fetchBrightness() -> Float
    func setBrightness(_ brightness: Float) -> Bool
    func startObserving(onChange: @escaping @Sendable (_ brightness: Float) -> Void)
    func stopObserving()
}

/// Production DisplayServices implementation observing and controlling main display brightness.
public final class NativeDisplayHardwareController: SystemDisplayControllerProtocol, @unchecked Sendable {
    private typealias DisplayServicesGetBrightnessType = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias DisplayServicesSetBrightnessType = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let lock = NSLock()
    private var getBrightnessFunc: DisplayServicesGetBrightnessType?
    private var setBrightnessFunc: DisplayServicesSetBrightnessType?

    private var pollTimer: Timer?
    private var keyMonitor: Any?
    private var lastObservedBrightness: Float = 0.75
    private var onChangeCallback: (@Sendable (Float) -> Void)?
    private var isObserving = false

    public init() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY) {
            if let getSym = dlsym(handle, "DisplayServicesGetBrightness") {
                getBrightnessFunc = unsafeBitCast(getSym, to: DisplayServicesGetBrightnessType.self)
            }
            if let setSym = dlsym(handle, "DisplayServicesSetBrightness") {
                setBrightnessFunc = unsafeBitCast(setSym, to: DisplayServicesSetBrightnessType.self)
            }
        }
        self.lastObservedBrightness = fetchBrightness()
    }

    deinit {
        stopObserving()
    }

    public func fetchBrightness() -> Float {
        guard let getFunc = getBrightnessFunc else { return 0.75 }
        var brightness: Float = 0.0
        let status = getFunc(CGMainDisplayID(), &brightness)
        if status == 0 {
            return max(0.0, min(1.0, brightness))
        }
        return 0.75
    }

    public func setBrightness(_ brightness: Float) -> Bool {
        guard let setFunc = setBrightnessFunc else { return false }
        let clamped = max(0.0, min(1.0, brightness))
        let status = setFunc(CGMainDisplayID(), clamped)
        if status == 0 {
            lock.lock()
            lastObservedBrightness = clamped
            lock.unlock()
            return true
        }
        return false
    }

    public func startObserving(onChange: @escaping @Sendable (_ brightness: Float) -> Void) {
        lock.lock()
        self.onChangeCallback = onChange
        guard !isObserving else {
            lock.unlock()
            return
        }
        isObserving = true
        self.lastObservedBrightness = fetchBrightness()
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 1. High-frequency responsive timer (0.2s)
            self.pollTimer = Timer.scheduledTimer(withTimeInterval: 0.20, repeats: true) { [weak self] _ in
                self?.checkBrightnessChange()
            }

            // 2. Immediate global media key monitor for Brightness keys (NX_KEYTYPE_BRIGHTNESS_UP = 2, NX_KEYTYPE_BRIGHTNESS_DOWN = 3)
            self.keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
                guard let self = self else { return }
                if event.subtype.rawValue == 8 {
                    let keyCode = (event.data1 & 0xFFFF0000) >> 16
                    if keyCode == 2 || keyCode == 3 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                            self.checkBrightnessChange()
                        }
                    }
                }
            }
        }
    }

    private func checkBrightnessChange() {
        let current = fetchBrightness()
        lock.lock()
        let diff = abs(current - lastObservedBrightness)
        if diff >= 0.005 {
            lastObservedBrightness = current
            let cb = onChangeCallback
            lock.unlock()
            cb?(current)
        } else {
            lock.unlock()
        }
    }

    public func stopObserving() {
        lock.lock()
        isObserving = false
        onChangeCallback = nil
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.pollTimer?.invalidate()
            self?.pollTimer = nil
            if let monitor = self?.keyMonitor {
                NSEvent.removeMonitor(monitor)
                self?.keyMonitor = nil
            }
        }
    }
}

/// In-memory mock display controller for deterministic testing.
public final class MockDisplayHardwareController: SystemDisplayControllerProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var brightness: Float
    private var onChangeCallback: (@Sendable (Float) -> Void)?

    public init(initialBrightness: Float = 0.75) {
        self.brightness = initialBrightness
    }

    public func fetchBrightness() -> Float {
        lock.lock()
        defer { lock.unlock() }
        return brightness
    }

    public func setBrightness(_ newBrightness: Float) -> Bool {
        lock.lock()
        let clamped = max(0.0, min(1.0, newBrightness))
        self.brightness = clamped
        let cb = onChangeCallback
        lock.unlock()

        cb?(clamped)
        return true
    }

    public func startObserving(onChange: @escaping @Sendable (Float) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        self.onChangeCallback = onChange
    }

    public func stopObserving() {
        lock.lock()
        defer { lock.unlock() }
        self.onChangeCallback = nil
    }

    public func simulateExternalHardwareChange(brightness: Float) {
        lock.lock()
        self.brightness = max(0.0, min(1.0, brightness))
        let cb = onChangeCallback
        lock.unlock()

        cb?(self.brightness)
    }
}
