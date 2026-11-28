import Foundation
import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import os
import SQLite3
import Combine

/// Payload representing a captured macOS system notification.
public struct SystemNotificationPayload: Sendable, Equatable {
    public let recId: Int64
    public let bundleIdentifier: String
    public let title: String
    public let subtitle: String
    public let body: String
    public let date: Date

    public init(
        recId: Int64,
        bundleIdentifier: String,
        title: String,
        subtitle: String = "",
        body: String,
        date: Date = Date()
    ) {
        self.recId = recId
        self.bundleIdentifier = bundleIdentifier
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.date = date
    }

    /// Best display title, falling back to subtitle or application name.
    public var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        if !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return subtitle
        }
        let components = bundleIdentifier.split(separator: ".")
        if let last = components.last, !last.isEmpty {
            return String(last).capitalized
        }
        return "Notification"
    }

    /// Best display message body.
    public var displayMessage: String {
        if !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return body
        }
        return subtitle
    }

    /// Best SF Symbol icon for the application.
    public var fallbackIconName: String {
        let id = bundleIdentifier.lowercased()
        if id.contains("telegram") {
            return "paperplane.fill"
        } else if id.contains("whatsapp") {
            return "message.fill"
        } else if id.contains("mail") {
            return "envelope.fill"
        } else if id.contains("slack") {
            return "bubble.left.and.bubble.right.fill"
        } else if id.contains("calendar") {
            return "calendar"
        } else if id.contains("reminder") {
            return "checklist"
        } else if id.contains("message") || id.contains("chat") {
            return "message.fill"
        } else {
            return "bell.fill"
        }
    }
}

/// Protocol defining system notification monitoring and redirection to Dynamic Notch.
public protocol SystemNotificationObserverProtocol: AnyObject, Sendable {
    func startObserving()
    func stopObserving()
    var isObserving: Bool { get }
}

/// Real-time observer monitoring the macOS `usernoted` SQLite database and diverting
/// incoming system notifications to Maczy's Dynamic Notch while suppressing the native banner.
public final class SystemNotificationObserver: SystemNotificationObserverProtocol, @unchecked Sendable {
    public static let shared = SystemNotificationObserver()
    private static let logger = Logger(subsystem: "com.maczy.notifications", category: "SystemNotificationObserver")

    private let dbPath: String
    private let queue = DispatchQueue(label: "com.maczy.system-notifications", qos: .userInteractive)
    private let suppressionQueue = DispatchQueue(label: "com.maczy.system-notifications.suppress", qos: .userInteractive)
    private let lock = NSLock()

    private var _isObserving = false
    public var isObserving: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isObserving
    }

    public var isSuppressionEnabled: Bool = true
    private var lastSeenRecId: Int64 = 0
    private var pollTimer: DispatchSourceTimer?
    private var fsSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var walSource: DispatchSourceFileSystemObject?
    private var walFileDescriptor: Int32 = -1
    private var lastBannerDismissTime: CFAbsoluteTime = 0
    private var suppressBannerUntil: CFAbsoluteTime = 0
    private var lastWalStamp: (sec: Int, nsec: Int, size: off_t) = (0, 0, -1)
    private var lastDbStamp: (sec: Int, nsec: Int, size: off_t) = (0, 0, -1)
    private var recentAXRecords: [(bundleId: String, title: String, body: String, allTexts: String, timestamp: CFAbsoluteTime)] = []
    private var nextSyntheticAXRecId: Int64 = -1
    private var axObserver: AXObserver?
    private var axObservedPID: pid_t = 0
    private var globalMouseDownMonitor: Any?
    private static var userOpenedNotificationCenterUntil: CFAbsoluteTime = 0

    public var onNotificationReceived: (@Sendable (SystemNotificationPayload) -> Void)?

    public init(databasePath: String? = nil, initialRecId: Int64? = nil) {
        if let customPath = databasePath {
            self.dbPath = customPath
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.dbPath = home.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db").path
        }
        if let recId = initialRecId {
            self.lastSeenRecId = recId
        }
    }

    deinit {
        stopObserving()
    }

    /// Parse a raw binary PropertyList BLOB from `usernoted.record.data`.
    public static func parseRecord(
        data: Data,
        recId: Int64,
        bundleIdentifier: String,
        deliveredDate: Double
    ) -> SystemNotificationPayload? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }

        let req = plist["req"] as? [String: Any] ?? plist
        let title = (req["titl"] as? String) ?? ""
        let subtitle = (req["subt"] as? String) ?? ""
        let body = (req["body"] as? String) ?? ""

        guard !title.isEmpty || !subtitle.isEmpty || !body.isEmpty else {
            return nil
        }

        let date = deliveredDate > 0 ? Date(timeIntervalSinceReferenceDate: deliveredDate) : Date()
        return SystemNotificationPayload(
            recId: recId,
            bundleIdentifier: bundleIdentifier,
            title: title,
            subtitle: subtitle,
            body: body,
            date: date
        )
    }

    /// Returns true if the AX window represents the user-opened Notification Center sidebar/widgets
    /// (which contains an `AXScrollArea` / `AXList`), rather than a transient floating banner toast.
    private static func isNotificationCenterSidebar(in element: AXUIElement, depth: Int = 0, nodeCount: inout Int) -> Bool {
        guard depth < 6, nodeCount < 60 else { return false }
        nodeCount += 1

        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""
        if role == (kAXScrollAreaRole as String) || role == (kAXListRole as String) {
            return true
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                if isNotificationCenterSidebar(in: child, depth: depth + 1, nodeCount: &nodeCount) {
                    return true
                }
            }
        }
        return false
    }

    /// Immediately move any on-screen NotificationCenter banner window off-screen (`(-10000, -10000)`).
    /// Ultra-fast (< 0.5ms) and safe to call synchronously right inside AXObserver callbacks.
    @discardableResult
    public static func moveBannerWindowsOffscreen() -> Bool {
        guard !isCursorInMenuBarTopRight() else { return false }
        guard AXIsProcessTrusted(),
              let ncApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first else {
            return false
        }

        let axApp = AXUIElementCreateApplication(ncApp.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement], !windows.isEmpty else {
            return false
        }

        var movedAny = false
        for window in windows {
            var currentPos = CGPoint.zero
            var hasPos = false
            var posRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
               let axVal = posRef,
               CFGetTypeID(axVal) == AXValueGetTypeID() {
                hasPos = AXValueGetValue(axVal as! AXValue, .cgPoint, &currentPos)
            }

            // Never hide the user-opened Notification Center sidebar; restore it to (0,0) if it was offscreen
            var sidebarNodes = 0
            if isNotificationCenterSidebar(in: window, nodeCount: &sidebarNodes) {
                if hasPos && (currentPos.x < -2000 || currentPos.y < -2000) {
                    var origin = CGPoint.zero
                    if let axOrigin = AXValueCreate(.cgPoint, &origin) {
                        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axOrigin)
                    }
                }
                continue
            }

            if hasPos && (currentPos.x < -2000 || currentPos.y < -2000) {
                continue
            }

            var containers: [AXUIElement] = []
            var count = 0
            findBannerContainers(in: window, nodeCount: &count, into: &containers)
            guard !containers.isEmpty else { continue }

            var posSettable: DarwinBoolean = false
            if AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &posSettable) == .success,
               posSettable.boolValue {
                var offscreen = CGPoint(x: -10000, y: -10000)
                if let axPoint = AXValueCreate(.cgPoint, &offscreen),
                   AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPoint) == .success {
                    movedAny = true
                }
            }
        }
        return movedAny
    }

    /// Dismiss native top-right macOS notification banner cleanly via Accessibility:
    /// 1) Immediately move the NotificationCenter banner window off-screen (`kAXPositionAttribute` -> (-10000, -10000))
    ///    so it disappears instantaneously without killing/restarting NotificationCenter (zero widget flicker/glitch).
    /// 2) Trigger the banner's `Name:Close` AX action so `usernoted` completes cleanly.
    /// Falls back to direct SIGKILL only if Accessibility is not granted or AX manipulation fails.
    @discardableResult
    public static func dismissBannerViaAX() -> Bool {
        guard AXIsProcessTrusted(),
              let ncApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first else {
            return false
        }

        let axApp = AXUIElementCreateApplication(ncApp.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement], !windows.isEmpty else {
            return false
        }

        var handledAny = moveBannerWindowsOffscreen()
        for window in windows {
            var sidebarNodes = 0
            if isNotificationCenterSidebar(in: window, nodeCount: &sidebarNodes) {
                continue
            }
            var containers: [AXUIElement] = []
            var count = 0
            findBannerContainers(in: window, nodeCount: &count, into: &containers)
            guard !containers.isEmpty else { continue }

            // Perform the banner's Close action (e.g. "Name:Close\nTarget:0x0\nSelector:(null)")
            for banner in containers {
                var actionsRef: CFArray?
                if AXUIElementCopyActionNames(banner, &actionsRef) == .success,
                   let actions = actionsRef as? [String],
                   let closeAction = actions.first(where: {
                       let low = $0.lowercased()
                       return low.contains("name:close") || low == "axcancel" || low.contains("clear") || low.contains("dismiss")
                   }) {
                    if AXUIElementPerformAction(banner, closeAction as CFString) == .success {
                        handledAny = true
                    }
                }
            }
        }
        return handledAny
    }

    /// Dismiss native top-right macOS notification banner cleanly via AX first, falling back to
    /// direct SIGKILL only when Accessibility is unavailable.
    public static func dismissNativeNotificationBanner() {
        if dismissBannerViaAX() {
            return
        }

        let bundleIds = [
            "com.apple.notificationcenterui",
            "com.apple.UserNotificationCenter"
        ]
        var killedViaPID = false
        for bid in bundleIds {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bid)
            for app in apps {
                let pid = app.processIdentifier
                if pid > 0 {
                    // Direct SIGKILL is instantaneous (no fork/exec delay)
                    if Darwin.kill(pid, SIGKILL) == 0 {
                        killedViaPID = true
                    } else {
                        _ = app.forceTerminate()
                    }
                }
            }
        }

        // Fallback killall only if NSRunningApplication didn't find/kill the process
        if !killedViaPID {
            for processName in ["NotificationCenter", "UserNotificationCenter"] {
                let task = Process()
                task.launchPath = "/usr/bin/killall"
                task.arguments = ["-9", processName]
                try? task.run()
            }
        }
    }

    /// Detects whether a native Notification Center banner toast window is currently visible
    /// at the top-right of the screen (excluding the full-height Notification Center sidebar).
    public static func isNativeBannerWindowVisible() -> Bool {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil &&
              ProcessInfo.processInfo.environment["XCTestBundlePath"] == nil &&
              NSClassFromString("XCTestCase") == nil else {
            return false
        }

        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        for info in windowList {
            guard let owner = info[kCGWindowOwnerName as String] as? String else { continue }
            guard owner == "Notification Center" || owner == "NotificationCenter" else { continue }
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let w = boundsDict["Width"] as? CGFloat,
                  let h = boundsDict["Height"] as? CGFloat else {
                continue
            }
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            let x = boundsDict["X"] as? CGFloat ?? 0
            let y = boundsDict["Y"] as? CGFloat ?? 0
            // Ignore windows already moved off-screen by dismissBannerViaAX()
            if x < -2000 || y < -2000 {
                continue
            }
            // macOS 26+ renders Notification Center banners on a layer-21 overlay window;
            // older macOS versions use a compact top-right toast window (30..320pt tall).
            if layer == 21 && w >= 200 && h >= 30 {
                return true
            }
            if w >= 200 && h >= 30 && h <= 320 && y <= 120 && x > 0 {
                return true
            }
        }
        return false
    }

    /// Returns true if the user recently clicked the top-right menu bar clock/Notification Center
    /// or is currently interacting with the top-right menu bar area (using points, not retina pixels).
    private static func isCursorInMenuBarTopRight() -> Bool {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil &&
              ProcessInfo.processInfo.environment["XCTestBundlePath"] == nil &&
              NSClassFromString("XCTestCase") == nil else {
            return false
        }
        let now = CFAbsoluteTimeGetCurrent()
        let mainWidth = CGDisplayBounds(CGMainDisplayID()).width
        guard let loc = CGEvent(source: nil)?.location else {
            return now < userOpenedNotificationCenterUntil
        }
        if now < userOpenedNotificationCenterUntil && loc.x >= (mainWidth - 450) {
            return true
        }
        return loc.y <= 44 && loc.x >= (mainWidth - 400)
    }

    // MARK: - Instant Accessibility (AXUIElement) Notification Extraction
    //
    // macOS `usernoted` does not flush new notifications to `db2/db` until ~5 seconds after
    // presentation. By reading the Notification Center banner's AXUIElement tree right as
    // its layer-21 window appears (before dismissing it), Maczy displays the notification in
    // the Dynamic Notch in < 40ms instead of waiting 5 seconds.

    private static let axActionNoiseLabels: Set<String> = [
        "close", "clear", "clear all", "options", "show more", "show less", "reply", "view", "actions"
    ]

    private static let knownAppBundleIds: [String: String] = [
        "telegram": "ru.keepcoder.telegram",
        "whatsapp": "net.whatsapp.whatsapp",
        "slack": "com.tinyspeck.slackmacgap",
        "mail": "com.apple.mail",
        "messages": "com.apple.MobileSMS",
        "calendar": "com.apple.iCal",
        "reminders": "com.apple.reminders",
        "script editor": "com.apple.scripteditor2",
        "discord": "com.hnc.Discord",
        "safari": "com.apple.Safari",
        "google chrome": "com.google.Chrome",
        "chrome": "com.google.Chrome",
        "brave browser": "com.brave.Browser",
        "brave": "com.brave.Browser",
        "arc": "company.thebrowser.Browser",
        "finder": "com.apple.finder",
        "notes": "com.apple.Notes",
        "facetime": "com.apple.FaceTime",
        "xcode": "com.apple.dt.Xcode",
        "terminal": "com.apple.Terminal",
        "visual studio code": "com.microsoft.VSCode",
        "system settings": "com.apple.systempreferences"
    ]

    private static let installedAppBundleMap: [String: String] = {
        var map: [String: String] = [:]
        let appDirs = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]
        for dir in appDirs {
            guard let items = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                let appURL = URL(fileURLWithPath: dir).appendingPathComponent(item)
                if let bundle = Bundle(url: appURL), let bid = bundle.bundleIdentifier {
                    let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                        ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                        ?? String(item.dropLast(4))
                    map[displayName.lowercased()] = bid
                    map[String(item.dropLast(4)).lowercased()] = bid
                }
            }
        }
        return map
    }()

    private static func resolveBundleIdentifier(fromCandidates candidates: [String]) -> String? {
        for raw in candidates {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let lower = trimmed.lowercased()

            if let known = knownAppBundleIds[lower],
               NSWorkspace.shared.urlForApplication(withBundleIdentifier: known) != nil {
                return known
            }
            for (k, bid) in knownAppBundleIds where lower.contains(k) {
                if NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) != nil {
                    return bid
                }
            }
            if let running = NSWorkspace.shared.runningApplications.first(where: {
                ($0.localizedName ?? "").caseInsensitiveCompare(trimmed) == .orderedSame
            }), let bid = running.bundleIdentifier,
               NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) != nil {
                return bid
            }
            if let installed = installedAppBundleMap[lower],
               NSWorkspace.shared.urlForApplication(withBundleIdentifier: installed) != nil {
                return installed
            }
        }
        return nil
    }

    private static func collectAXBannerData(
        from element: AXUIElement,
        depth: Int = 0,
        nodeCount: inout Int,
        texts: inout [String],
        appCandidates: inout [String]
    ) {
        guard depth < 10, nodeCount < 140 else { return }
        nodeCount += 1

        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""

        for attr in [kAXTitleAttribute as CFString, kAXDescriptionAttribute as CFString] {
            var ref: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, attr, &ref) == .success,
               let str = ref as? String {
                let clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty && !axActionNoiseLabels.contains(clean.lowercased()) {
                    // macOS often formats container AXDescription as "AppName, Title, Body"
                    if let firstSegment = clean.split(separator: ",").first {
                        appCandidates.append(String(firstSegment).trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    appCandidates.append(clean)
                }
            }
        }

        if role == (kAXStaticTextRole as String) {
            var valRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valRef)
            if let text = valRef as? String {
                let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty && !axActionNoiseLabels.contains(clean.lowercased()) {
                    texts.append(clean)
                }
            }
            return
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                collectAXBannerData(
                    from: child,
                    depth: depth + 1,
                    nodeCount: &nodeCount,
                    texts: &texts,
                    appCandidates: &appCandidates
                )
            }
        }
    }

    private static func findBannerContainers(
        in element: AXUIElement,
        depth: Int = 0,
        nodeCount: inout Int,
        into containers: inout [AXUIElement]
    ) {
        guard depth < 8, nodeCount < 100 else { return }
        nodeCount += 1

        var subroleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRef)
        let subrole = subroleRef as? String ?? ""

        if subrole == "AXNotificationCenterBanner" || subrole == "AXNotificationCenterAlert" {
            containers.append(element)
            return
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                findBannerContainers(in: child, depth: depth + 1, nodeCount: &nodeCount, into: &containers)
            }
        }
    }

    private func extractPayloadsFromAX() -> [SystemNotificationPayload] {
        guard AXIsProcessTrusted() else { return [] }
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui")
        guard let ncApp = apps.first else { return [] }

        let axApp = AXUIElementCreateApplication(ncApp.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement], !windows.isEmpty else {
            return []
        }

        var payloads: [SystemNotificationPayload] = []

        for window in windows {
            var sidebarNodes = 0
            if Self.isNotificationCenterSidebar(in: window, nodeCount: &sidebarNodes) {
                continue
            }
            var containers: [AXUIElement] = []
            var containerNodeCount = 0
            Self.findBannerContainers(in: window, nodeCount: &containerNodeCount, into: &containers)

            // Only extract from genuine Notification Center banner/alert containers.
            // Never fall back to scanning the whole window, as NotificationCenter also owns
            // desktop widgets (e.g. Clock widget "6.13") which are not notifications.
            guard !containers.isEmpty else { continue }
            for target in containers {
                var texts: [String] = []
                var appCandidates: [String] = []
                var textNodeCount = 0
                Self.collectAXBannerData(
                    from: target,
                    nodeCount: &textNodeCount,
                    texts: &texts,
                    appCandidates: &appCandidates
                )
                guard !texts.isEmpty else { continue }

                // Include first static text as an app candidate when 3+ lines are present
                if texts.count >= 3 {
                    appCandidates.insert(texts[0], at: 0)
                } else {
                    appCandidates.append(texts[0])
                }

                // Resolve a real macOS bundleIdentifier so NotchContainerView always renders the app icon
                let resolvedBundleId = Self.resolveBundleIdentifier(fromCandidates: appCandidates)
                guard let bundleId = resolvedBundleId else {
                    // Defer to SQLite record if AX didn't expose an identifiable app bundle
                    continue
                }

                let title: String
                let body: String

                if texts.count >= 3 && Self.resolveBundleIdentifier(fromCandidates: [texts[0]]) != nil {
                    title = texts[1]
                    body = texts.dropFirst(2).joined(separator: " ")
                } else if texts.count >= 2 {
                    title = texts[0]
                    body = texts.dropFirst(1).joined(separator: " ")
                } else {
                    title = texts[0]
                    body = ""
                }

                lock.lock()
                let recId = nextSyntheticAXRecId
                nextSyntheticAXRecId -= 1
                lock.unlock()

                payloads.append(SystemNotificationPayload(
                    recId: recId,
                    bundleIdentifier: bundleId,
                    title: title,
                    subtitle: "",
                    body: body,
                    date: Date()
                ))
            }
        }
        return payloads
    }

    private static func normalizedText(_ raw: String) -> String {
        raw.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func markAndCheckDuplicateAX(_ payload: SystemNotificationPayload, recordIfNew: Bool) -> Bool {
        let t = Self.normalizedText(payload.displayTitle)
        let m = Self.normalizedText(payload.displayMessage)
        let combined = Self.normalizedText("\(payload.displayTitle) \(payload.displayMessage)")
        let now = CFAbsoluteTimeGetCurrent()

        lock.lock()
        defer { lock.unlock() }
        recentAXRecords.removeAll { now - $0.timestamp > 20.0 }

        let stripEllipsis: (String) -> String = { s in
            s.trimmingCharacters(in: CharacterSet(charactersIn: "….")).trimmingCharacters(in: .whitespaces)
        }
        let mClean = stripEllipsis(m)
        let tClean = stripEllipsis(t)

        let isDup = recentAXRecords.contains { rec in
            let recBodyClean = stripEllipsis(rec.body)
            let recTitleClean = stripEllipsis(rec.title)

            if rec.title == t && rec.body == m {
                return true
            }
            if !mClean.isEmpty && mClean.count >= 4 {
                if rec.allTexts.contains(mClean) || (!recBodyClean.isEmpty && recBodyClean.count >= 4 && mClean.contains(recBodyClean)) {
                    return true
                }
            }
            if !tClean.isEmpty && tClean.count >= 4 && (recTitleClean == tClean || rec.allTexts.contains(tClean)) {
                if mClean.isEmpty || recBodyClean.isEmpty {
                    return true
                }
                let prefixLen = min(10, min(mClean.count, recBodyClean.count))
                if prefixLen >= 4 && mClean.prefix(prefixLen) == recBodyClean.prefix(prefixLen) {
                    return true
                }
            }
            return false
        }

        if isDup {
            return true
        }
        if recordIfNew {
            recentAXRecords.append((bundleId: payload.bundleIdentifier, title: t, body: m, allTexts: combined, timestamp: now))
        }
        return false
    }

    /// Start real-time monitoring of macOS notifications.
    public func startObserving() {
        startObserving(seedMaxId: true)
    }

    /// Start real-time monitoring of macOS notifications with optional initial rec_id seeding.
    public func startObserving(seedMaxId: Bool) {
        lock.lock()
        guard !_isObserving else {
            lock.unlock()
            return
        }
        _isObserving = true
        lock.unlock()

        queue.async { [weak self] in
            guard let self = self else { return }
            if seedMaxId {
                self.seedLastSeenRecId()
            }
            self.setupFileSystemWatcher()
            self.setupPollingTimer()
        }
        DispatchQueue.main.async { [weak self] in
            self?.setupAXObserver()
        }
    }

    /// Stop monitoring notifications.
    public func stopObserving() {
        lock.lock()
        guard _isObserving else {
            lock.unlock()
            return
        }
        _isObserving = false
        lock.unlock()

        queue.async { [weak self] in
            guard let self = self else { return }
            self.pollTimer?.cancel()
            self.pollTimer = nil

            if let fs = self.fsSource {
                fs.cancel()
                self.fsSource = nil
                self.fileDescriptor = -1
            } else if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }

            if let wal = self.walSource {
                wal.cancel()
                self.walSource = nil
                self.walFileDescriptor = -1
            } else if self.walFileDescriptor >= 0 {
                close(self.walFileDescriptor)
                self.walFileDescriptor = -1
            }
        }
        DispatchQueue.main.async { [weak self] in
            self?.teardownAXObserver()
        }
    }

    private func setupAXObserver() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil &&
              ProcessInfo.processInfo.environment["XCTestBundlePath"] == nil &&
              NSClassFromString("XCTestCase") == nil,
              AXIsProcessTrusted() else {
            return
        }
        guard let ncApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first else {
            return
        }
        let pid = ncApp.processIdentifier
        guard pid > 0, pid != axObservedPID else { return }

        teardownAXObserver()

        var observer: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon = refcon else { return }
            let obs = Unmanaged<SystemNotificationObserver>.fromOpaque(refcon).takeUnretainedValue()
            obs.handleAXWindowCreated()
        }

        guard AXObserverCreate(pid, callback, &observer) == .success, let observer = observer else {
            return
        }

        let axApp = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for notification in [
            kAXWindowCreatedNotification,
            kAXCreatedNotification,
            kAXWindowMovedNotification,
            kAXLayoutChangedNotification
        ] {
            AXObserverAddNotification(observer, axApp, notification as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)

        self.axObserver = observer
        self.axObservedPID = pid

        if globalMouseDownMonitor == nil {
            globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { _ in
                guard let loc = CGEvent(source: nil)?.location else { return }
                let mainWidth = CGDisplayBounds(CGMainDisplayID()).width
                if loc.y <= 44 && loc.x >= (mainWidth - 420) {
                    Self.userOpenedNotificationCenterUntil = CFAbsoluteTimeGetCurrent() + 3.0
                    // Restore NotificationCenter window immediately if it was previously parked offscreen
                    if let ncApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first {
                        let axApp = AXUIElementCreateApplication(ncApp.processIdentifier)
                        var windowsRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                           let windows = windowsRef as? [AXUIElement] {
                            for w in windows {
                                var origin = CGPoint.zero
                                if let axOrigin = AXValueCreate(.cgPoint, &origin) {
                                    AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, axOrigin)
                                }
                            }
                        }
                    }
                } else if loc.x < (mainWidth - 450) {
                    Self.userOpenedNotificationCenterUntil = 0
                }
            }
        }
    }

    private func teardownAXObserver() {
        if let monitor = globalMouseDownMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseDownMonitor = nil
        }
        if let observer = axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            axObserver = nil
            axObservedPID = 0
        }
    }

    private func handleAXWindowCreated() {
        guard isSuppressionEnabled, !Self.isCursorInMenuBarTopRight() else { return }
        // Move banner window off-screen SYNCHRONOUSLY at 0ms before doing any async work or AX text traversal
        let movedNow = Self.moveBannerWindowsOffscreen()
        suppressionQueue.async { [weak self] in
            guard let self = self else { return }
            let axPayloads = self.extractPayloadsFromAX()
            for payload in axPayloads {
                if !self.markAndCheckDuplicateAX(payload, recordIfNew: true) {
                    self.dispatchNotification(payload, suppressNative: false)
                }
            }
            if movedNow || !axPayloads.isEmpty || Self.isNativeBannerWindowVisible() {
                self.lastBannerDismissTime = CFAbsoluteTimeGetCurrent()
                Self.dismissNativeNotificationBanner()
            }
        }
    }

    private func seedLastSeenRecId() {
        var db: OpaquePointer?
        let rc = sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil)
        guard rc == SQLITE_OK, let db = db else {
            Self.logger.error("seedLastSeenRecId failed rc=\(rc, privacy: .public) path=\(self.dbPath, privacy: .public)")
            return
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let sql = "SELECT MAX(rec_id) FROM record"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                let maxId = sqlite3_column_int64(stmt, 0)
                self.lastSeenRecId = maxId
            }
            sqlite3_finalize(stmt)
        }
    }

    private func hasDatabaseFileChanged() -> Bool {
        var changed = false
        var walStat = stat()
        if stat(dbPath + "-wal", &walStat) == 0 {
            let stamp = (walStat.st_mtimespec.tv_sec, walStat.st_mtimespec.tv_nsec, walStat.st_size)
            if stamp != lastWalStamp {
                lastWalStamp = stamp
                changed = true
            }
        }
        var dbStat = stat()
        if stat(dbPath, &dbStat) == 0 {
            let stamp = (dbStat.st_mtimespec.tv_sec, dbStat.st_mtimespec.tv_nsec, dbStat.st_size)
            if stamp != lastDbStamp {
                lastDbStamp = stamp
                changed = true
            }
        }
        return changed
    }

    private func setupPollingTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.015, repeating: 0.015, leeway: .milliseconds(4))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            if self.isSuppressionEnabled {
                self.suppressionQueue.async { [weak self] in
                    guard let self = self else { return }
                    if let currentPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first?.processIdentifier,
                       currentPID != self.axObservedPID {
                        DispatchQueue.main.async { [weak self] in
                            self?.setupAXObserver()
                        }
                    }
                    let now = CFAbsoluteTimeGetCurrent()
                    if !Self.isCursorInMenuBarTopRight() &&
                       Self.isNativeBannerWindowVisible() {
                        // Move offscreen FIRST before reading AX texts so banner disappears immediately
                        Self.moveBannerWindowsOffscreen()
                        let axPayloads = self.extractPayloadsFromAX()
                        for payload in axPayloads {
                            if !self.markAndCheckDuplicateAX(payload, recordIfNew: true) {
                                self.dispatchNotification(payload, suppressNative: false)
                            }
                        }
                        if now - self.lastBannerDismissTime > 0.60 {
                            self.lastBannerDismissTime = now
                            Self.dismissNativeNotificationBanner()
                        }
                    }
                }
            }
            if self.hasDatabaseFileChanged() {
                self.checkForNewNotifications()
            }
        }
        timer.resume()
        self.pollTimer = timer
    }

    private func setupFileSystemWatcher() {
        let dirPath = (dbPath as NSString).deletingLastPathComponent
        let fd = open(dirPath, O_EVTONLY)
        if fd >= 0 {
            self.fileDescriptor = fd
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .extend, .attrib],
                queue: queue
            )
            source.setEventHandler { [weak self] in
                guard let self = self else { return }
                if self.walSource == nil {
                    self.attachWalWatcher()
                }
                self.checkForNewNotifications()
            }
            source.setCancelHandler {
                close(fd)
            }
            source.resume()
            self.fsSource = source
        }

        attachWalWatcher()
    }

    /// Watch the SQLite WAL file directly so inserts trigger immediately (< 1ms)
    /// instead of waiting for directory metadata changes or the fallback polling timer.
    private func attachWalWatcher() {
        if let existing = walSource {
            existing.cancel()
            self.walSource = nil
            self.walFileDescriptor = -1
        }

        let walPath = dbPath + "-wal"
        let fd = open(walPath, O_EVTONLY)
        guard fd >= 0 else { return }
        self.walFileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) {
                self.attachWalWatcher()
            }
            self.checkForNewNotifications()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        self.walSource = source
    }

    /// Query SQLite for any notification records inserted after `lastSeenRecId`.
    public func checkForNewNotifications() {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK, let db = db else {
            return
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let sql = "SELECT r.rec_id, a.identifier, r.data, r.delivered_date FROM record r JOIN app a ON r.app_id = a.app_id WHERE r.rec_id > ? ORDER BY r.rec_id ASC"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt = stmt else {
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, lastSeenRecId)

        var newNotifications: [SystemNotificationPayload] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            let recId = sqlite3_column_int64(stmt, 0)
            let appStr: String
            if let cStr = sqlite3_column_text(stmt, 1) {
                appStr = String(cString: cStr)
            } else {
                appStr = "com.apple.unknown"
            }

            let blobBytes = sqlite3_column_blob(stmt, 2)
            let blobSize = sqlite3_column_bytes(stmt, 2)
            let deliveredDate = sqlite3_column_double(stmt, 3)

            if recId > lastSeenRecId {
                lastSeenRecId = recId
            }

            if let blobBytes = blobBytes, blobSize > 0 {
                let data = Data(bytes: blobBytes, count: Int(blobSize))
                if let payload = Self.parseRecord(
                    data: data,
                    recId: recId,
                    bundleIdentifier: appStr,
                    deliveredDate: deliveredDate
                ) {
                    newNotifications.append(payload)
                }
            }
        }

        guard !newNotifications.isEmpty else { return }

        for payload in newNotifications {
            // Skip if already delivered instantaneously via AXUIElement within the last 15s
            if markAndCheckDuplicateAX(payload, recordIfNew: false) {
                continue
            }
            dispatchNotification(payload, suppressNative: true)
        }
    }

    private func dispatchNotification(_ payload: SystemNotificationPayload, suppressNative: Bool = true) {
        // 1. Route directly to Dynamic Notch Live Activities on MainActor with zero delay
        DispatchQueue.main.async {
            LiveActivityCoordinator.shared.postNotification(
                id: "sysnotif-\(payload.recId)",
                title: payload.displayTitle,
                message: payload.displayMessage,
                appIcon: payload.fallbackIconName,
                bundleIdentifier: payload.bundleIdentifier,
                durationSeconds: 4.5
            )
        }

        // 2. Notify callback if provided
        onNotificationReceived?(payload)

        // 3. Immediately suppress native macOS notification banner if still visible (single clean pass to avoid respawn glitch)
        if suppressNative && isSuppressionEnabled {
            suppressionQueue.async { [weak self] in
                let now = CFAbsoluteTimeGetCurrent()
                self?.suppressBannerUntil = now + 1.5
                if Self.isNativeBannerWindowVisible() {
                    self?.lastBannerDismissTime = now
                    Self.dismissNativeNotificationBanner()
                }
            }
        }
    }
}
