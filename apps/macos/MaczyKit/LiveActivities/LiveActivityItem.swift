import Foundation

/// Specific type and payload of a live activity displayed in Dynamic Notch.
public enum LiveActivityType: Sendable, Equatable {
    case timer(totalSeconds: Int, remainingSeconds: Int, isRunning: Bool)
    case screenRecording(elapsedSeconds: Int)
    case taskProgress(progress: Double, status: String)
    case notification(title: String, message: String, appIcon: String, bundleIdentifier: String? = nil)
}

/// Dynamic live activity widget entity.
public struct LiveActivityItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let type: LiveActivityType
    public let priority: Int
    public let timestamp: Date
    public let expirationDate: Date?

    public init(
        id: String,
        type: LiveActivityType,
        priority: Int,
        timestamp: Date = Date(),
        expirationDate: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.priority = priority
        self.timestamp = timestamp
        self.expirationDate = expirationDate
    }

    /// Formatted timer countdown (e.g. "04:59").
    public var formattedTimer: String {
        switch type {
        case .timer(_, let remaining, _):
            let mins = max(0, remaining) / 60
            let secs = max(0, remaining) % 60
            return String(format: "%02d:%02d", mins, secs)
        default:
            return ""
        }
    }

    /// Formatted recording elapsed time (e.g. "00:32").
    public var formattedRecording: String {
        switch type {
        case .screenRecording(let elapsed):
            let mins = elapsed / 60
            let secs = elapsed % 60
            return String(format: "%02d:%02d", mins, secs)
        default:
            return ""
        }
    }

    /// Primary SF symbol icon for the activity.
    public var iconName: String {
        switch type {
        case .timer:
            return "timer"
        case .screenRecording:
            return "record.circle.fill"
        case .taskProgress:
            return "arrow.down.circle.fill"
        case .notification(_, _, let appIcon, _):
            return appIcon
        }
    }

    /// Application bundle identifier if this is an app notification.
    public var bundleIdentifier: String? {
        if case .notification(_, _, _, let bundleId) = type {
            return bundleId
        }
        return nil
    }

    /// Short title string for compact display.
    public var title: String {
        switch type {
        case .timer:
            return "Timer"
        case .screenRecording:
            return "Recording"
        case .taskProgress(_, let status):
            return status
        case .notification(let title, _, _, _):
            return title
        }
    }

    /// Short description or message string.
    public var message: String {
        switch type {
        case .timer(_, let remaining, _):
            return "\(remaining)s remaining"
        case .screenRecording(let elapsed):
            return "\(elapsed)s elapsed"
        case .taskProgress(let progress, _):
            return "\(Int(progress * 100))%"
        case .notification(_, let msg, _, _):
            return msg
        }
    }
}
