import Foundation
import AppKit
import ApplicationServices

/// Protocol defining media key interception and native HUD suppression.
public protocol MediaKeyInterceptorProtocol: AnyObject, Sendable {
    func start()
    func stop()
    var isRunning: Bool { get }
}

/// Global HID event tap interceptor that captures Volume and Brightness hardware keys,
/// updates hardware levels directly through Maczy, and swallows the native events to
/// completely suppress the default macOS onscreen display (HUD) bezel.
public final class MediaKeyInterceptor: MediaKeyInterceptorProtocol, @unchecked Sendable {
    public static let shared = MediaKeyInterceptor()

    // IOKit key constants (IOKit/hidsystem/ev_keymap.h)
    public static let NX_KEYTYPE_SOUND_UP: Int32 = 0
    public static let NX_KEYTYPE_SOUND_DOWN: Int32 = 1
    public static let NX_KEYTYPE_BRIGHTNESS_UP: Int32 = 2
    public static let NX_KEYTYPE_BRIGHTNESS_DOWN: Int32 = 3
    public static let NX_KEYTYPE_MUTE: Int32 = 7

    private let lock = NSLock()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var workerThread: Thread?
    private var threadRunLoop: CFRunLoop?

    private var _isRunning = false
    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isRunning
    }

    public var isEnabled: Bool = true
    private var lastUnmutedVolume: Double = 0.5

    public init() {}

    deinit {
        stop()
    }

    /// Start listening for media keys on a dedicated high-priority thread.
    public func start() {
        lock.lock()
        guard !_isRunning else {
            lock.unlock()
            return
        }
        _isRunning = true
        lock.unlock()

        // Skip event tap in test runner
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil &&
              ProcessInfo.processInfo.environment["XCTestBundlePath"] == nil &&
              NSClassFromString("XCTestCase") == nil else {
            return
        }

        let thread = Thread { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            self.threadRunLoop = CFRunLoopGetCurrent()
            self.lock.unlock()

            self.setupEventTap()
            CFRunLoopRun()
        }
        thread.name = "com.maczy.media-key-interceptor"
        thread.qualityOfService = .userInteractive
        self.workerThread = thread
        thread.start()
    }

    /// Stop the interceptor and tear down the event tap.
    public func stop() {
        lock.lock()
        guard _isRunning else {
            lock.unlock()
            return
        }
        _isRunning = false

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            self.eventTap = nil
        }

        if let source = runLoopSource, let rl = threadRunLoop {
            CFRunLoopRemoveSource(rl, source, .commonModes)
            self.runLoopSource = nil
        }

        if let rl = threadRunLoop {
            CFRunLoopStop(rl)
            self.threadRunLoop = nil
        }
        self.workerThread = nil
        lock.unlock()
    }

    private func setupEventTap() {
        // Event mask for system-defined events (NX_SYSDEFINED = 14)
        let eventMask: CGEventMask = (1 << 14)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else {
                return Unmanaged.passRetained(event)
            }
            let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()
            return interceptor.handleEvent(proxy: proxy, type: type, event: event)
        }

        // 1. Try cghidEventTap (earliest point in HID pipeline, before window server / mediaremoted)
        var tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        // 2. Fall back to cgSessionEventTap if cghidEventTap is unavailable
        if tap == nil {
            tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: callback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        }

        guard let validTap = tap else {
            return
        }

        self.eventTap = validTap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, validTap, 0)
        self.runLoopSource = source

        if let currentRL = threadRunLoop, let src = source {
            CFRunLoopAddSource(currentRL, src, .commonModes)
            CGEvent.tapEnable(tap: validTap, enable: true)
        }
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Auto-recover if event tap is disabled by macOS timeout
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return nil
        }

        guard isEnabled, type.rawValue == 14 else {
            return Unmanaged.passRetained(event)
        }

        guard let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passRetained(event)
        }

        let data1 = nsEvent.data1
        let keyCode = Int32((data1 & 0xFFFF0000) >> 16)
        let keyFlags = Int32(data1 & 0x0000FFFF)
        let keyState = (keyFlags & 0xFF00) >> 8
        let isDown = (keyState == 0x0A)

        guard isTargetMediaKey(keyCode) else {
            return Unmanaged.passRetained(event)
        }

        if isDown {
            let flags = nsEvent.modifierFlags
            processMediaAction(for: keyCode, modifierFlags: flags)
        }

        // Returning nil consumes/swallows the event completely.
        // The macOS system daemon never receives the key press, suppressing the native HUD!
        return nil
    }

    /// Whether this key code is one of the volume or brightness media keys.
    public func isTargetMediaKey(_ keyCode: Int32) -> Bool {
        switch keyCode {
        case Self.NX_KEYTYPE_SOUND_UP,
             Self.NX_KEYTYPE_SOUND_DOWN,
             Self.NX_KEYTYPE_MUTE,
             Self.NX_KEYTYPE_BRIGHTNESS_UP,
             Self.NX_KEYTYPE_BRIGHTNESS_DOWN:
            return true
        default:
            return false
        }
    }

    /// Process volume or brightness increment/decrement and route directly to SystemHUDCoordinator.
    public func processMediaAction(for keyCode: Int32, modifierFlags: NSEvent.ModifierFlags) {
        let isFineGrain = modifierFlags.contains(.shift) && modifierFlags.contains(.option)
        let step: Double = isFineGrain ? (1.0 / 64.0) : (1.0 / 16.0)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let hud = SystemHUDCoordinator.shared

            switch keyCode {
            case Self.NX_KEYTYPE_SOUND_UP:
                let current = hud.currentVolume
                let next = min(1.0, current + step)
                if hud.isVolumeMuted {
                    self.lastUnmutedVolume = max(step, next)
                }
                hud.setVolume(next)

            case Self.NX_KEYTYPE_SOUND_DOWN:
                let current = hud.currentVolume
                let next = max(0.0, current - step)
                hud.setVolume(next)

            case Self.NX_KEYTYPE_MUTE:
                if hud.isVolumeMuted || hud.currentVolume <= 0.001 {
                    let restore = self.lastUnmutedVolume > 0.05 ? self.lastUnmutedVolume : 0.25
                    hud.setVolume(restore)
                } else {
                    self.lastUnmutedVolume = hud.currentVolume
                    hud.setVolume(0.0)
                }

            case Self.NX_KEYTYPE_BRIGHTNESS_UP:
                let current = hud.currentBrightness
                let next = min(1.0, current + step)
                hud.setBrightness(next)

            case Self.NX_KEYTYPE_BRIGHTNESS_DOWN:
                let current = hud.currentBrightness
                let next = max(0.0, current - step)
                hud.setBrightness(next)

            default:
                break
            }
        }
    }
}
