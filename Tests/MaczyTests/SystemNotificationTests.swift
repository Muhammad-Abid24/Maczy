import XCTest
import SQLite3
@testable import MaczyKit

final class SystemNotificationTests: XCTestCase {

    func testSystemNotificationPayloadDisplayProperties() {
        // Standard notification with full fields
        let payload1 = SystemNotificationPayload(
            recId: 101,
            bundleIdentifier: "ru.keepcoder.telegram",
            title: "storebat",
            subtitle: "Group Alert",
            body: "CDK GOOGLE AI PRO 12M Added: 100"
        )
        XCTAssertEqual(payload1.displayTitle, "storebat")
        XCTAssertEqual(payload1.displayMessage, "CDK GOOGLE AI PRO 12M Added: 100")
        XCTAssertEqual(payload1.fallbackIconName, "paperplane.fill")

        // Notification without title, falling back to subtitle
        let payload2 = SystemNotificationPayload(
            recId: 102,
            bundleIdentifier: "net.whatsapp.whatsapp",
            title: "",
            subtitle: "Mas Indra",
            body: "Semangat pagi"
        )
        XCTAssertEqual(payload2.displayTitle, "Mas Indra")
        XCTAssertEqual(payload2.fallbackIconName, "message.fill")

        // Notification without title or subtitle, falling back to bundle name
        let payload3 = SystemNotificationPayload(
            recId: 103,
            bundleIdentifier: "com.apple.mail",
            title: "",
            subtitle: "",
            body: "New message arrived"
        )
        XCTAssertEqual(payload3.displayTitle, "Mail")
        XCTAssertEqual(payload3.fallbackIconName, "envelope.fill")

        // Slack notification fallback icon
        let payload4 = SystemNotificationPayload(
            recId: 104,
            bundleIdentifier: "com.tinyspeck.slackmacgap",
            title: "Engineering",
            body: "Deploy succeeded"
        )
        XCTAssertEqual(payload4.fallbackIconName, "bubble.left.and.bubble.right.fill")
    }

    func testPropertyListRecordParsing() {
        let dict: [String: Any] = [
            "req": [
                "titl": "Telegram Notification",
                "subt": "Chat 1",
                "body": "Hello world from Maczy"
            ]
        ]

        guard let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) else {
            XCTFail("Failed to serialize sample plist")
            return
        }

        let payload = SystemNotificationObserver.parseRecord(
            data: data,
            recId: 999,
            bundleIdentifier: "ru.keepcoder.telegram",
            deliveredDate: 817246000.0
        )

        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.recId, 999)
        XCTAssertEqual(payload?.bundleIdentifier, "ru.keepcoder.telegram")
        XCTAssertEqual(payload?.title, "Telegram Notification")
        XCTAssertEqual(payload?.subtitle, "Chat 1")
        XCTAssertEqual(payload?.body, "Hello world from Maczy")
    }

    func testSystemNotificationObserverWithTemporaryDatabase() {
        final class Box<T>: @unchecked Sendable {
            var value: T?
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbPath = tempDir.appendingPathComponent("notifications.db").path

        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil), SQLITE_OK)
        guard let db = db else {
            XCTFail("Could not create temp sqlite db")
            return
        }

        let createTables = """
        PRAGMA journal_mode=WAL;
        CREATE TABLE app (app_id INTEGER PRIMARY KEY, identifier VARCHAR);
        CREATE TABLE record (rec_id INTEGER PRIMARY KEY, app_id INTEGER, data BLOB, delivered_date REAL);
        INSERT INTO app (app_id, identifier) VALUES (1, 'ru.keepcoder.telegram');
        """
        XCTAssertEqual(sqlite3_exec(db, createTables, nil, nil, nil), SQLITE_OK)

        // Insert notification record into db first
        let sampleDict: [String: Any] = [
            "req": [
                "titl": "storebat",
                "body": "📦 CDK GOOGLE AI PRO"
            ]
        ]
        let blobData = try! PropertyListSerialization.data(fromPropertyList: sampleDict, format: .binary, options: 0)

        var stmt: OpaquePointer?
        let insertSQL = "INSERT INTO record (rec_id, app_id, data, delivered_date) VALUES (1, 1, ?, 817246000.0)"
        XCTAssertEqual(sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil), SQLITE_OK)
        _ = blobData.withUnsafeBytes { rawBuffer in
            sqlite3_bind_blob(stmt, 1, rawBuffer.baseAddress, Int32(rawBuffer.count), nil)
        }
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_DONE)
        sqlite3_finalize(stmt)
        sqlite3_close(db)

        // Create observer pointing to temp database with initialRecId: 0
        let observer = SystemNotificationObserver(databasePath: dbPath, initialRecId: 0)
        observer.isSuppressionEnabled = false

        let box = Box<SystemNotificationPayload>()
        let exp = expectation(description: "Captured notification from SQLite")
        observer.onNotificationReceived = { payload in
            box.value = payload
            exp.fulfill()
        }

        // Trigger check
        observer.checkForNewNotifications()

        wait(for: [exp], timeout: 2.0)
        XCTAssertNotNil(box.value)
        XCTAssertEqual(box.value?.title, "storebat")
        XCTAssertEqual(box.value?.body, "📦 CDK GOOGLE AI PRO")
        XCTAssertEqual(box.value?.bundleIdentifier, "ru.keepcoder.telegram")
    }

    @MainActor
    func testLiveActivityWithBundleIdentifier() {
        let coordinator = LiveActivityCoordinator()
        coordinator.clearAll()

        coordinator.postNotification(
            id: "test-telegram",
            title: "storebat",
            message: "Incoming message",
            appIcon: "paperplane.fill",
            bundleIdentifier: "ru.keepcoder.telegram",
            durationSeconds: 5
        )

        XCTAssertEqual(coordinator.primaryActivity?.id, "test-telegram")
        XCTAssertEqual(coordinator.primaryActivity?.title, "storebat")
        XCTAssertEqual(coordinator.primaryActivity?.message, "Incoming message")
        XCTAssertEqual(coordinator.primaryActivity?.bundleIdentifier, "ru.keepcoder.telegram")

        coordinator.clearAll()
    }

    @MainActor
    func testSystemHUDNativeOSDSuppressionState() {
        let audio = MockAudioHardwareController()
        let display = MockDisplayHardwareController()
        let coordinator = SystemHUDCoordinator(
            audioController: audio,
            displayController: display,
            autoStartObserving: false
        )

        XCTAssertFalse(coordinator.isNativeOSDSuppressed)

        coordinator.setNativeOSDSuppressed(true)
        XCTAssertTrue(coordinator.isNativeOSDSuppressed)

        coordinator.setNativeOSDSuppressed(false)
        XCTAssertFalse(coordinator.isNativeOSDSuppressed)

        coordinator.startHardwareObservation()
        XCTAssertTrue(coordinator.isNativeOSDSuppressed)

        coordinator.stopHardwareObservation()
        XCTAssertFalse(coordinator.isNativeOSDSuppressed)
    }

    func testMediaKeyInterceptorTargetKeysAndActions() {
        let interceptor = MediaKeyInterceptor()

        XCTAssertTrue(interceptor.isTargetMediaKey(MediaKeyInterceptor.NX_KEYTYPE_SOUND_UP))
        XCTAssertTrue(interceptor.isTargetMediaKey(MediaKeyInterceptor.NX_KEYTYPE_SOUND_DOWN))
        XCTAssertTrue(interceptor.isTargetMediaKey(MediaKeyInterceptor.NX_KEYTYPE_MUTE))
        XCTAssertTrue(interceptor.isTargetMediaKey(MediaKeyInterceptor.NX_KEYTYPE_BRIGHTNESS_UP))
        XCTAssertTrue(interceptor.isTargetMediaKey(MediaKeyInterceptor.NX_KEYTYPE_BRIGHTNESS_DOWN))
        XCTAssertFalse(interceptor.isTargetMediaKey(999))

        // Test start/stop lifecycle (guarded against real event tap creation during unit testing)
        interceptor.start()
        XCTAssertTrue(interceptor.isRunning)
        interceptor.stop()
        XCTAssertFalse(interceptor.isRunning)
    }

    func testNativeBannerWindowCheckSafeInTests() {
        XCTAssertFalse(SystemNotificationObserver.isNativeBannerWindowVisible())
    }
}
