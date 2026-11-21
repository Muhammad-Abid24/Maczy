import XCTest
@testable import MaczyKit

final class LiveActivityTests: XCTestCase {

    func testLiveActivityFormatting() {
        // Timer formatting
        let timer5m = LiveActivityItem(
            id: "t1",
            type: .timer(totalSeconds: 300, remainingSeconds: 299, isRunning: true),
            priority: 80
        )
        XCTAssertEqual(timer5m.formattedTimer, "04:59")
        XCTAssertEqual(timer5m.iconName, "timer")
        XCTAssertEqual(timer5m.title, "Timer")

        let timerZero = LiveActivityItem(
            id: "t2",
            type: .timer(totalSeconds: 60, remainingSeconds: 0, isRunning: false),
            priority: 80
        )
        XCTAssertEqual(timerZero.formattedTimer, "00:00")

        // Recording formatting
        let recording = LiveActivityItem(
            id: "r1",
            type: .screenRecording(elapsedSeconds: 125),
            priority: 90
        )
        XCTAssertEqual(recording.formattedRecording, "02:05")
        XCTAssertEqual(recording.iconName, "record.circle.fill")
        XCTAssertEqual(recording.title, "Recording")

        // Progress formatting
        let progress = LiveActivityItem(
            id: "p1",
            type: .taskProgress(progress: 0.75, status: "Downloading"),
            priority: 50
        )
        XCTAssertEqual(progress.message, "75%")
        XCTAssertEqual(progress.title, "Downloading")

        // Notification formatting
        let notif = LiveActivityItem(
            id: "n1",
            type: .notification(title: "Slack", message: "Elena: Review PR #14", appIcon: "message.fill"),
            priority: 100
        )
        XCTAssertEqual(notif.title, "Slack")
        XCTAssertEqual(notif.message, "Elena: Review PR #14")
        XCTAssertEqual(notif.iconName, "message.fill")
    }

    @MainActor
    func testPriorityResolution() {
        let coordinator = LiveActivityCoordinator()
        coordinator.clearAll()

        // 1. Progress (Priority 50)
        coordinator.setTaskProgress(id: "dl", status: "Downloading", progress: 0.5)
        XCTAssertEqual(coordinator.primaryActivity?.id, "dl")

        // 2. Timer (Priority 80)
        coordinator.startTimer(id: "timer", totalSeconds: 120)
        XCTAssertEqual(coordinator.primaryActivity?.id, "timer")

        // 3. Screen Recording (Priority 90)
        coordinator.startRecordingActivity(id: "rec")
        XCTAssertEqual(coordinator.primaryActivity?.id, "rec")

        // 4. Notification (Priority 100)
        coordinator.postNotification(id: "notif", title: "Test", message: "High Priority", durationSeconds: 10)
        XCTAssertEqual(coordinator.primaryActivity?.id, "notif")

        // Dismiss notification -> falls back to recording (90)
        coordinator.dismissActivity(id: "notif")
        XCTAssertEqual(coordinator.primaryActivity?.id, "rec")

        // Dismiss recording -> falls back to timer (80)
        coordinator.dismissActivity(id: "rec")
        XCTAssertEqual(coordinator.primaryActivity?.id, "timer")

        // Dismiss timer -> falls back to progress (50)
        coordinator.dismissActivity(id: "timer")
        XCTAssertEqual(coordinator.primaryActivity?.id, "dl")

        // Clear all
        coordinator.clearAll()
        XCTAssertNil(coordinator.primaryActivity)
        XCTAssertTrue(coordinator.activities.isEmpty)
    }

    @MainActor
    func testTimerLifecyclePauseResume() {
        let coordinator = LiveActivityCoordinator()
        coordinator.clearAll()

        coordinator.startTimer(id: "my_timer", totalSeconds: 60)
        guard let item = coordinator.activities.first(where: { $0.id == "my_timer" }) else {
            XCTFail("Timer not created")
            return
        }
        if case .timer(_, let remaining, let isRunning) = item.type {
            XCTAssertEqual(remaining, 60)
            XCTAssertTrue(isRunning)
        } else {
            XCTFail("Incorrect activity type")
        }

        // Pause
        coordinator.pauseTimer(id: "my_timer")
        let pausedItem = coordinator.activities.first { $0.id == "my_timer" }
        if case .timer(_, _, let isRunning) = pausedItem?.type {
            XCTAssertFalse(isRunning)
        } else {
            XCTFail("Timer not paused")
        }

        // Resume
        coordinator.resumeTimer(id: "my_timer")
        let resumedItem = coordinator.activities.first { $0.id == "my_timer" }
        if case .timer(_, _, let isRunning) = resumedItem?.type {
            XCTAssertTrue(isRunning)
        } else {
            XCTFail("Timer not resumed")
        }

        // Cancel
        coordinator.cancelTimer(id: "my_timer")
        XCTAssertNil(coordinator.activities.first { $0.id == "my_timer" })
    }

    @MainActor
    func testTickerCountdownAndCompletion() {
        let coordinator = LiveActivityCoordinator()
        coordinator.clearAll()

        coordinator.startTimer(id: "short_timer", totalSeconds: 2)

        // Tick 1
        coordinator.tick()
        let item1 = coordinator.activities.first { $0.id == "short_timer" }
        if case .timer(_, let remaining, _) = item1?.type {
            XCTAssertEqual(remaining, 1)
        }

        // Tick 2 (Timer finishes -> triggers notification)
        coordinator.tick()
        XCTAssertNil(coordinator.activities.first { $0.id == "short_timer" })
        XCTAssertTrue(coordinator.activities.contains { $0.id.hasPrefix("timer_done_") })
    }

    @MainActor
    func testNotificationAutoExpiration() {
        let coordinator = LiveActivityCoordinator()
        coordinator.clearAll()

        // Expired notification (-2.0s)
        coordinator.postNotification(
            id: "old_notif",
            title: "Old",
            message: "Expired",
            durationSeconds: -2.0
        )

        coordinator.tick()
        XCTAssertNil(coordinator.activities.first { $0.id == "old_notif" })
    }
}
