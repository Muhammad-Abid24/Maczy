import Foundation
import AppKit
import AVFoundation
import CoreGraphics
import ApplicationServices
import ScreenCaptureKit
import CoreBluetooth
import UserNotifications

/// Helper class for requesting Bluetooth authorization via CBCentralManager.
final class BluetoothPermissionRequester: NSObject, CBCentralManagerDelegate, @unchecked Sendable {
    static var activeRequesters: [BluetoothPermissionRequester] = []
    private var central: CBCentralManager?
    private var continuation: CheckedContinuation<PermissionState, Never>?

    init(continuation: CheckedContinuation<PermissionState, Never>) {
        self.continuation = continuation
        super.init()
    }

    func start() {
        self.central = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: true])
        // Timeout safeguard for headless CI or delayed delegate execution
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self, let cont = self.continuation else { return }
            self.continuation = nil
            Self.activeRequesters.removeAll { $0 === self }
            let state: PermissionState
            switch CBCentralManager.authorization {
            case .allowedAlways:
                state = .granted
            case .denied:
                state = .denied
            case .restricted:
                state = .restricted
            case .notDetermined:
                state = .notDetermined
            @unknown default:
                state = .notDetermined
            }
            cont.resume(returning: state)
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state: PermissionState
        switch CBCentralManager.authorization {
        case .allowedAlways:
            state = .granted
        case .denied:
            state = .denied
        case .restricted:
            state = .restricted
        case .notDetermined:
            state = .notDetermined
        @unknown default:
            state = .notDetermined
        }
        continuation?.resume(returning: state)
        continuation = nil
        Self.activeRequesters.removeAll { $0 === self }
    }
}

/// Manages macOS TCC system permission checks, explicit requests, and settings deep linking.
public final class PermissionManager: @unchecked Sendable {
    public static let shared = PermissionManager()

    public init() {}

    /// Returns deep link URL for macOS System Settings privacy pane.
    public func settingsURL(for permission: MaczyPermission) -> URL? {
        let urlString: String
        switch permission {
        case .screenRecording:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case .camera:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .bluetooth:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth"
        case .notifications:
            urlString = "x-apple.systempreferences:com.apple.preference.notifications"
        case .fullDiskAccess:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        }
        return URL(string: urlString)
    }

    /// Validates whether running in a headless test or automated CI environment
    public var isHeadlessOrCI: Bool {
        if ProcessInfo.processInfo.environment["CI"] != nil ||
           ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil ||
           ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
           NSClassFromString("XCTestCase") != nil {
            return true
        }
        return false
    }

    /// Opens System Settings directly to the corresponding privacy pane.
    @MainActor
    public func openSettings(for permission: MaczyPermission) {
        guard !isHeadlessOrCI else { return }
        if let url = settingsURL(for: permission) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Cleanly relaunches the application to pick up new macOS TCC tokens after toggling permissions.
    @MainActor
    public func relaunchApp() {
        let appURL = Bundle.main.bundleURL
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", appURL.path]
        try? task.run()
        NSApplication.shared.terminate(nil)
    }

    /// Resets TCC ScreenCapture entry for com.maczy.app so macOS triggers a fresh authorization prompt.
    public func resetTCCScreenCapture() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        task.arguments = ["reset", "ScreenCapture", "com.maczy.app"]
        try? task.run()
    }

    /// Checks the current system permission authorization status.
    public func checkStatus(for permission: MaczyPermission) -> PermissionState {
        switch permission {
        case .screenRecording:
            // Check Screen Recording via CGPreflightScreenCaptureAccess
            if #available(macOS 10.15, *) {
                return CGPreflightScreenCaptureAccess() ? .granted : .notDetermined
            }
            return .granted

        case .camera:
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: return .granted
            case .denied: return .denied
            case .restricted: return .restricted
            case .notDetermined: return .notDetermined
            @unknown default: return .notDetermined
            }

        case .microphone:
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized: return .granted
            case .denied: return .denied
            case .restricted: return .restricted
            case .notDetermined: return .notDetermined
            @unknown default: return .notDetermined
            }

        case .accessibility:
            return AXIsProcessTrusted() ? .granted : .notDetermined

        case .bluetooth:
            switch CBCentralManager.authorization {
            case .allowedAlways: return .granted
            case .denied: return .denied
            case .restricted: return .restricted
            case .notDetermined: return .notDetermined
            @unknown default: return .notDetermined
            }

        case .notifications:
            return checkNotificationStatus()

        case .fullDiskAccess:
            return checkFullDiskAccess()
        }
    }

    /// Validates whether UNUserNotificationCenter can be safely used without throwing NSInternalInconsistencyException
    private var isNotificationCenterAvailable: Bool {
        if NSClassFromString("XCTestCase") != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return false
        }
        guard let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty else {
            return false
        }
        return Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }

    /// Checks UserNotifications authorization status synchronously.
    private func checkNotificationStatus() -> PermissionState {
        guard isNotificationCenterAvailable else {
            return .notDetermined
        }
        let sema = DispatchSemaphore(value: 0)
        var result: PermissionState = .notDetermined
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                result = .granted
            case .denied:
                result = .denied
            case .notDetermined:
                result = .notDetermined
            case .ephemeral:
                result = .granted
            @unknown default:
                result = .notDetermined
            }
            sema.signal()
        }
        _ = sema.wait(timeout: .now() + 0.3)
        return result
    }

    /// Tests readable access to system-protected user directories requiring Full Disk Access.
    public func checkFullDiskAccess() -> PermissionState {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let testPaths = [
            home.appendingPathComponent("Library/Safari").path,
            home.appendingPathComponent("Library/Suggestions").path,
            home.appendingPathComponent("Library/Mail").path
        ]

        for path in testPaths {
            if FileManager.default.fileExists(atPath: path) {
                if FileManager.default.isReadableFile(atPath: path) {
                    return .granted
                }
            }
        }
        return .notDetermined
    }

    /// Requests authorization explicitly for the given permission.
    public func requestAuthorization(for permission: MaczyPermission) async -> PermissionState {
        if isHeadlessOrCI {
            return checkStatus(for: permission)
        }
        switch permission {
        case .screenRecording:
            if #available(macOS 10.15, *) {
                if CGPreflightScreenCaptureAccess() {
                    return .granted
                }

                // 1. Trigger system prompt dialog
                _ = CGRequestScreenCaptureAccess()

                // 2. Query ScreenCaptureKit to force macOS 14+ TCC to register bundle in System Settings
                if #available(macOS 14.0, *) {
                    _ = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                }

                // 3. Re-check if access is now granted
                if CGPreflightScreenCaptureAccess() {
                    return .granted
                }

                await MainActor.run {
                    openSettings(for: .screenRecording)
                }
                return .notDetermined
            }
            return .granted

        case .camera:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                await MainActor.run {
                    openSettings(for: .camera)
                }
                return .denied
            }
            return .granted

        case .microphone:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted {
                await MainActor.run {
                    openSettings(for: .microphone)
                }
                return .denied
            }
            return .granted

        case .accessibility:
            if AXIsProcessTrusted() {
                return .granted
            }
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            let granted = AXIsProcessTrustedWithOptions(options)
            if !granted {
                await MainActor.run {
                    openSettings(for: .accessibility)
                }
            }
            return granted ? .granted : .notDetermined

        case .bluetooth:
            let current = checkStatus(for: .bluetooth)
            if current == .granted {
                return .granted
            }
            if current == .denied || current == .restricted {
                await MainActor.run {
                    openSettings(for: .bluetooth)
                }
                return current
            }
            let state = await withCheckedContinuation { continuation in
                let requester = BluetoothPermissionRequester(continuation: continuation)
                BluetoothPermissionRequester.activeRequesters.append(requester)
                requester.start()
            }
            if state != .granted {
                await MainActor.run {
                    openSettings(for: .bluetooth)
                }
            }
            return state

        case .notifications:
            guard isNotificationCenterAvailable else {
                return .notDetermined
            }
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                if !granted {
                    await MainActor.run {
                        openSettings(for: .notifications)
                    }
                    return .denied
                }
                return .granted
            } catch {
                await MainActor.run {
                    openSettings(for: .notifications)
                }
                return .denied
            }

        case .fullDiskAccess:
            let current = checkFullDiskAccess()
            if current == .granted {
                return .granted
            }
            await MainActor.run {
                openSettings(for: .fullDiskAccess)
            }
            return current
        }
    }

    /// Associated primary module for a given permission.
    public func associatedModule(for permission: MaczyPermission) -> MaczyModuleId {
        switch permission {
        case .screenRecording: return .captureAndRecording
        case .microphone: return .captureAndRecording
        case .camera: return .smartUnlock
        case .accessibility: return .dynamicNotch
        case .bluetooth: return .dynamicNotch
        case .notifications: return .dynamicNotch
        case .fullDiskAccess: return .systemCleaner
        }
    }

    /// Plain-English explanation of why the permission is needed.
    public func rationale(for permission: MaczyPermission) -> String {
        switch permission {
        case .screenRecording:
            return "Required to capture area screenshots, window captures, and display recordings locally."
        case .microphone:
            return "Optional for including voice audio during screen recordings. Default is OFF."
        case .camera:
            return "Opt-in only for local facial recognition research. Zero images are stored or transmitted."
        case .accessibility:
            return "Allows window snapping presets and scrolling capture automation."
        case .bluetooth:
            return "Used for observing AirPods/TWS connection status in the Dynamic Notch."
        case .notifications:
            return "Displays completion alerts for recordings, cleaner scans, and update notices."
        case .fullDiskAccess:
            return "Optional for system-wide cache scanning. Never used for unprompted file modification."
        }
    }
}
