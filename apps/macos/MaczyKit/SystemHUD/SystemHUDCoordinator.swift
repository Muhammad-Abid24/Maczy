import Foundation
import Combine

/// Type of system hardware HUD currently presented in the Dynamic Notch.
public enum SystemHUDType: String, Sendable, Codable {
    case volume = "Volume"
    case brightness = "Brightness"
}

/// Snapshot event representing an active volume or brightness adjustment.
public struct SystemHUDEvent: Sendable, Equatable {
    public let type: SystemHUDType
    public let level: Double
    public let isMuted: Bool
    public let timestamp: Date

    public init(type: SystemHUDType, level: Double, isMuted: Bool = false, timestamp: Date = Date()) {
        self.type = type
        self.level = max(0.0, min(1.0, level))
        self.isMuted = isMuted
        self.timestamp = timestamp
    }

    /// Level formatted as an integer percentage (0 to 100).
    public var percentage: Int {
        if type == .volume && isMuted {
            return 0
        }
        return Int(round(level * 100.0))
    }

    /// Appropriate SF Symbol icon for current state and level.
    public var iconName: String {
        switch type {
        case .volume:
            if isMuted || level <= 0.001 {
                return "speaker.slash.fill"
            } else if level < 0.33 {
                return "speaker.wave.1.fill"
            } else if level < 0.66 {
                return "speaker.wave.2.fill"
            } else {
                return "speaker.wave.3.fill"
            }
        case .brightness:
            if level < 0.35 {
                return "sun.min.fill"
            } else {
                return "sun.max.fill"
            }
        }
    }
}

/// Main-actor coordinator managing system volume/brightness observation and Dynamic Notch HUD presentation.
@MainActor
public final class SystemHUDCoordinator: ObservableObject {
    public static let shared = SystemHUDCoordinator()

    @Published public private(set) var activeHUD: SystemHUDEvent?
    @Published public private(set) var currentVolume: Double = 0.5
    @Published public private(set) var isVolumeMuted: Bool = false
    @Published public private(set) var currentBrightness: Double = 0.75
    @Published public private(set) var isNativeOSDSuppressed: Bool = false

    public let audioController: SystemAudioControllerProtocol
    public let displayController: SystemDisplayControllerProtocol

    private var dismissTimer: Timer?
    private var isSuppressingEcho = false

    public init(
        audioController: SystemAudioControllerProtocol = NativeAudioHardwareController(),
        displayController: SystemDisplayControllerProtocol = NativeDisplayHardwareController(),
        autoStartObserving: Bool = true
    ) {
        self.audioController = audioController
        self.displayController = displayController

        let initialVol = Double(audioController.fetchVolume())
        let initialMute = audioController.isMuted()
        let initialBright = Double(displayController.fetchBrightness())

        self.currentVolume = initialVol
        self.isVolumeMuted = initialMute
        self.currentBrightness = initialBright

        if autoStartObserving {
            startHardwareObservation()
        }
    }

    deinit {
        dismissTimer?.invalidate()
        Self.applyNativeOSDSuppression(false)
    }

    /// Suppress or restore native macOS Volume/Brightness square bezel HUD overlay (OSDUIHelper).
    public func setNativeOSDSuppressed(_ suppressed: Bool) {
        self.isNativeOSDSuppressed = suppressed
        Self.applyNativeOSDSuppression(suppressed)
    }

    /// Nonisolated worker applying launchctl disable/enable command.
    public nonisolated static func applyNativeOSDSuppression(_ suppressed: Bool) {
        // Skip system service changes during automated test execution
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil &&
              ProcessInfo.processInfo.environment["XCTestBundlePath"] == nil &&
              NSClassFromString("XCTestCase") == nil else {
            return
        }

        let uid = getuid()
        let action = suppressed ? "disable" : "enable"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = [action, "gui/\(uid)/com.apple.OSDUIHelper"]
        try? proc.run()
        proc.waitUntilExit()

        if suppressed {
            let killProc = Process()
            killProc.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killProc.arguments = ["OSDUIHelper"]
            try? killProc.run()
            killProc.waitUntilExit()
        }
    }

    /// Begin observing real-time system hardware changes from CoreAudio and DisplayServices.
    public func startHardwareObservation() {
        setNativeOSDSuppressed(true)
        audioController.startObserving { [weak self] vol, muted in
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    self?.handleHardwareVolumeChanged(Double(vol), isMuted: muted)
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    MainActor.assumeIsolated {
                        self?.handleHardwareVolumeChanged(Double(vol), isMuted: muted)
                    }
                }
            }
        }

        displayController.startObserving { [weak self] brightness in
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    self?.handleHardwareBrightnessChanged(Double(brightness))
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    MainActor.assumeIsolated {
                        self?.handleHardwareBrightnessChanged(Double(brightness))
                    }
                }
            }
        }
    }

    /// Stop observing hardware changes.
    public func stopHardwareObservation() {
        setNativeOSDSuppressed(false)
        audioController.stopObserving()
        displayController.stopObserving()
    }

    /// Handle hardware volume changes coming from keyboard keys, Control Center, or external audio devices.
    public func handleHardwareVolumeChanged(_ level: Double, isMuted: Bool) {
        guard !isSuppressingEcho else { return }

        let clamped = max(0.0, min(1.0, level))
        let volumeChanged = abs(clamped - currentVolume) >= 0.005
        let muteChanged = (isMuted != self.isVolumeMuted)

        guard volumeChanged || muteChanged else { return }

        self.currentVolume = clamped
        self.isVolumeMuted = isMuted
        showHUD(type: .volume, level: clamped, isMuted: isMuted)
    }

    /// Handle hardware brightness changes coming from keyboard keys, Control Center, or ambient sensors.
    public func handleHardwareBrightnessChanged(_ level: Double) {
        guard !isSuppressingEcho else { return }

        let clamped = max(0.0, min(1.0, level))
        guard abs(clamped - currentBrightness) >= 0.005 else { return }

        self.currentBrightness = clamped
        showHUD(type: .brightness, level: clamped)
    }

    /// Trigger HUD presentation with given level, auto-dismissing after specified interval.
    public func showHUD(type: SystemHUDType, level: Double, isMuted: Bool = false, autoDismissSeconds: TimeInterval = 2.0) {
        dismissTimer?.invalidate()
        let clamped = max(0.0, min(1.0, level))
        let event = SystemHUDEvent(type: type, level: clamped, isMuted: isMuted)
        self.activeHUD = event

        switch type {
        case .volume:
            self.currentVolume = clamped
            self.isVolumeMuted = isMuted
        case .brightness:
            self.currentBrightness = clamped
        }

        if autoDismissSeconds > 0 {
            dismissTimer = Timer.scheduledTimer(withTimeInterval: autoDismissSeconds, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.dismissHUD()
                }
            }
        }
    }

    /// Manually dismiss any active HUD banner.
    public func dismissHUD() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        self.activeHUD = nil
    }

    /// Set volume programmatically, applying changes to macOS hardware and triggering the Dynamic Notch HUD.
    public func setVolume(_ level: Double) {
        let clamped = max(0.0, min(1.0, level))
        isSuppressingEcho = true
        _ = audioController.setVolume(Float(clamped))
        self.currentVolume = clamped
        self.isVolumeMuted = (clamped == 0.0)

        showHUD(type: .volume, level: clamped, isMuted: self.isVolumeMuted)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isSuppressingEcho = false
        }
    }

    /// Set brightness programmatically, applying changes to macOS display hardware and triggering the Dynamic Notch HUD.
    public func setBrightness(_ level: Double) {
        let clamped = max(0.0, min(1.0, level))
        isSuppressingEcho = true
        _ = displayController.setBrightness(Float(clamped))
        self.currentBrightness = clamped

        showHUD(type: .brightness, level: clamped)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isSuppressingEcho = false
        }
    }
}
