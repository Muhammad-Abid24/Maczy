import Foundation

public struct AlwaysOnSession: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let preset: AlwaysOnPreset
    public let mode: AlwaysOnMode
    public let startedAt: Date
    public let durationSeconds: Int?
    public let assertionID: UInt32

    public init(
        id: UUID = UUID(),
        preset: AlwaysOnPreset,
        mode: AlwaysOnMode,
        startedAt: Date = Date(),
        assertionID: UInt32
    ) {
        self.id = id
        self.preset = preset
        self.mode = mode
        self.startedAt = startedAt
        self.durationSeconds = preset.durationSeconds
        self.assertionID = assertionID
    }

    public func remainingSeconds(at date: Date = Date()) -> Int? {
        guard let durationSeconds = durationSeconds else {
            return nil
        }
        let elapsed = Int(date.timeIntervalSince(startedAt))
        let remaining = durationSeconds - elapsed
        return max(0, remaining)
    }

    public func formattedRemainingTime(at date: Date = Date()) -> String {
        guard let remaining = remainingSeconds(at: date) else {
            return "Indefinite"
        }
        if remaining <= 0 {
            return "00:00"
        }
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
