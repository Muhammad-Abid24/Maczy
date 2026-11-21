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
    public let timestamp: Date

    public init(type: SystemHUDType, level: Double, timestamp: Date = Date()) {
        self.type = type
        self.level = max(0.0, min(1.0, level))
        self.timestamp = timestamp
    }

    /// Level formatted as an integer percentage (0 to 100).
    public var percentage: Int {
        Int(round(level * 100.0))
    }

    /// Appropriate SF Symbol icon for current state and level.
    public var iconName: String {
        switch type {
        case .volume:
            if level <= 0.001 {
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

/// Main-actor coordinator managing system volume/brightness observation and HUD presentation.
@MainActor
public final class SystemHUDCoordinator: ObservableObject {
    public static let shared = SystemHUDCoordinator()

    @Published public private(set) var activeHUD: SystemHUDEvent?
    @Published public private(set) var currentVolume: Double = 0.5
    @Published public private(set) var currentBrightness: Double = 0.75

    private var dismissTimer: Timer?

    public init() {}

    /// Trigger HUD presentation with given level, auto-dismissing after specified interval.
    public func showHUD(type: SystemHUDType, level: Double, autoDismissSeconds: TimeInterval = 2.0) {
        dismissTimer?.invalidate()
        let clamped = max(0.0, min(1.0, level))
        let event = SystemHUDEvent(type: type, level: clamped)
        self.activeHUD = event

        switch type {
        case .volume:
            self.currentVolume = clamped
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

    /// Set volume programmatically and trigger HUD.
    public func setVolume(_ level: Double) {
        showHUD(type: .volume, level: level)
    }

    /// Set brightness programmatically and trigger HUD.
    public func setBrightness(_ level: Double) {
        showHUD(type: .brightness, level: level)
    }

    deinit {
        dismissTimer?.invalidate()
    }
}
