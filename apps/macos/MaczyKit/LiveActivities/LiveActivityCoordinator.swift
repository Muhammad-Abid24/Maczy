import Foundation
import Combine

/// Main-actor coordinator managing Live Activities and notifications in the Dynamic Notch.
@MainActor
public final class LiveActivityCoordinator: ObservableObject {
    public static let shared = LiveActivityCoordinator()

    @Published public private(set) var activities: [LiveActivityItem] = []
    @Published public private(set) var primaryActivity: LiveActivityItem?

    private var tickerTimer: Timer?

    public init() {
        startTicker()
    }

    /// Post a temporary notification toast banner (auto-dismisses after duration).
    public func postNotification(
        id: String = UUID().uuidString,
        title: String,
        message: String,
        appIcon: String = "bell.fill",
        bundleIdentifier: String? = nil,
        durationSeconds: TimeInterval = 4.0
    ) {
        let expiration = Date().addingTimeInterval(durationSeconds)
        let item = LiveActivityItem(
            id: id,
            type: .notification(title: title, message: message, appIcon: appIcon, bundleIdentifier: bundleIdentifier),
            priority: 100,
            expirationDate: expiration
        )
        upsertActivity(item)
    }

    /// Start a countdown timer live activity.
    public func startTimer(id: String = "timer", totalSeconds: Int) {
        let item = LiveActivityItem(
            id: id,
            type: .timer(totalSeconds: totalSeconds, remainingSeconds: totalSeconds, isRunning: true),
            priority: 80
        )
        upsertActivity(item)
    }

    /// Pause an active countdown timer.
    public func pauseTimer(id: String = "timer") {
        guard let idx = activities.firstIndex(where: { $0.id == id }) else { return }
        if case .timer(let total, let remaining, _) = activities[idx].type {
            let updated = LiveActivityItem(
                id: id,
                type: .timer(totalSeconds: total, remainingSeconds: remaining, isRunning: false),
                priority: 80
            )
            activities[idx] = updated
            recomputePrimary()
        }
    }

    /// Resume a paused countdown timer.
    public func resumeTimer(id: String = "timer") {
        guard let idx = activities.firstIndex(where: { $0.id == id }) else { return }
        if case .timer(let total, let remaining, _) = activities[idx].type {
            let updated = LiveActivityItem(
                id: id,
                type: .timer(totalSeconds: total, remainingSeconds: remaining, isRunning: true),
                priority: 80
            )
            activities[idx] = updated
            recomputePrimary()
        }
    }

    /// Cancel and remove a countdown timer.
    public func cancelTimer(id: String = "timer") {
        dismissActivity(id: id)
    }

    /// Start a screen recording elapsed time live activity.
    public func startRecordingActivity(id: String = "recording") {
        let item = LiveActivityItem(
            id: id,
            type: .screenRecording(elapsedSeconds: 0),
            priority: 90
        )
        upsertActivity(item)
    }

    /// Stop screen recording live activity.
    public func stopRecordingActivity(id: String = "recording") {
        dismissActivity(id: id)
    }

    /// Start or update a download/task progress live activity.
    public func setTaskProgress(id: String, status: String, progress: Double) {
        let clamped = max(0.0, min(1.0, progress))
        let item = LiveActivityItem(
            id: id,
            type: .taskProgress(progress: clamped, status: status),
            priority: 50
        )
        upsertActivity(item)
    }

    /// Dismiss a specific live activity.
    public func dismissActivity(id: String) {
        activities.removeAll { $0.id == id }
        recomputePrimary()
    }

    /// Clear all live activities.
    public func clearAll() {
        activities.removeAll()
        primaryActivity = nil
    }

    private func upsertActivity(_ item: LiveActivityItem) {
        if let idx = activities.firstIndex(where: { $0.id == item.id }) {
            activities[idx] = item
        } else {
            activities.append(item)
        }
        recomputePrimary()
    }

    private func recomputePrimary() {
        // Highest priority wins; if tied, most recently created wins
        self.primaryActivity = activities.max { a, b in
            if a.priority != b.priority {
                return a.priority < b.priority
            }
            return a.timestamp < b.timestamp
        }
    }

    private func startTicker() {
        tickerTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    /// Periodic 1-second update step.
    public func tick() {
        let now = Date()
        var updated: [LiveActivityItem] = []
        var completedNotifications: [LiveActivityItem] = []

        for item in activities {
            // Check expiration
            if let exp = item.expirationDate, now >= exp {
                continue // Drop expired notification
            }

            switch item.type {
            case .timer(let total, let remaining, let isRunning):
                if isRunning {
                    let nextRemaining = remaining - 1
                    if nextRemaining <= 0 {
                        // Timer completed! Fire notification
                        let exp = now.addingTimeInterval(5.0)
                        let doneNotif = LiveActivityItem(
                            id: "timer_done_\(item.id)",
                            type: .notification(
                                title: "Timer Completed",
                                message: "Your timer has finished.",
                                appIcon: "bell.badge.fill"
                            ),
                            priority: 100,
                            timestamp: now,
                            expirationDate: exp
                        )
                        completedNotifications.append(doneNotif)
                        continue
                    } else {
                        updated.append(LiveActivityItem(
                            id: item.id,
                            type: .timer(totalSeconds: total, remainingSeconds: nextRemaining, isRunning: true),
                            priority: item.priority,
                            timestamp: item.timestamp
                        ))
                    }
                } else {
                    updated.append(item)
                }

            case .screenRecording(let elapsed):
                updated.append(LiveActivityItem(
                    id: item.id,
                    type: .screenRecording(elapsedSeconds: elapsed + 1),
                    priority: item.priority,
                    timestamp: item.timestamp
                ))

            case .taskProgress, .notification:
                updated.append(item)
            }
        }

        updated.append(contentsOf: completedNotifications)
        self.activities = updated
        recomputePrimary()
    }

    deinit {
        tickerTimer?.invalidate()
    }
}
