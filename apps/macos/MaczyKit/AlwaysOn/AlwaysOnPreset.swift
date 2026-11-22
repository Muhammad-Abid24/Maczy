import Foundation
import IOKit.pwr_mgt

public enum AlwaysOnPreset: Equatable, Hashable, Sendable {
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case twoHours
    case custom(minutes: Int)
    case indefinite

    public init(minutes: Int?) {
        guard let minutes = minutes else {
            self = .indefinite
            return
        }
        switch minutes {
        case 15: self = .fifteenMinutes
        case 30: self = .thirtyMinutes
        case 60: self = .oneHour
        case 120: self = .twoHours
        default: self = .custom(minutes: max(1, minutes))
        }
    }

    public var durationMinutes: Int? {
        switch self {
        case .fifteenMinutes: return 15
        case .thirtyMinutes: return 30
        case .oneHour: return 60
        case .twoHours: return 120
        case .custom(let minutes): return minutes
        case .indefinite: return nil
        }
    }

    public var durationSeconds: Int? {
        durationMinutes.map { $0 * 60 }
    }

    public var displayName: String {
        switch self {
        case .fifteenMinutes: return "15 Minutes"
        case .thirtyMinutes: return "30 Minutes"
        case .oneHour: return "1 Hour"
        case .twoHours: return "2 Hours"
        case .custom(let minutes): return "\(minutes) Minutes"
        case .indefinite: return "Indefinite"
        }
    }

    public var shortLabel: String {
        switch self {
        case .fifteenMinutes: return "15m"
        case .thirtyMinutes: return "30m"
        case .oneHour: return "1h"
        case .twoHours: return "2h"
        case .custom(let minutes): return "\(minutes)m"
        case .indefinite: return "∞"
        }
    }
}

public enum AlwaysOnMode: String, CaseIterable, Equatable, Hashable, Sendable {
    case systemOnly = "system_only"
    case systemAndDisplay = "system_and_display"

    public var displayName: String {
        switch self {
        case .systemOnly:
            return "System Only"
        case .systemAndDisplay:
            return "System & Display"
        }
    }

    public var description: String {
        switch self {
        case .systemOnly:
            return "Keeps background tasks running; allows display to sleep."
        case .systemAndDisplay:
            return "Keeps display on and system fully awake."
        }
    }

    public var assertionType: String {
        switch self {
        case .systemOnly:
            return kIOPMAssertionTypePreventUserIdleSystemSleep
        case .systemAndDisplay:
            return kIOPMAssertionTypePreventUserIdleDisplaySleep
        }
    }
}
