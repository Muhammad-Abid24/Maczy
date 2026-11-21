import Foundation
import AppKit
import AVFoundation
import CoreGraphics
import ApplicationServices

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

    /// Opens System Settings directly to the corresponding privacy pane.
    @MainActor
    public func openSettings(for permission: MaczyPermission) {
        if let url = settingsURL(for: permission) {
            NSWorkspace.shared.open(url)
        }
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

        case .bluetooth, .notifications, .fullDiskAccess:
            return .notDetermined
        }
    }

    /// Requests authorization explicitly for the given permission.
    public func requestAuthorization(for permission: MaczyPermission) async -> PermissionState {
        switch permission {
        case .screenRecording:
            if #available(macOS 10.15, *) {
                let granted = CGRequestScreenCaptureAccess()
                return granted ? .granted : .denied
            }
            return .granted

        case .camera:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .granted : .denied

        case .microphone:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            return granted ? .granted : .denied

        case .accessibility:
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            let granted = AXIsProcessTrustedWithOptions(options)
            return granted ? .granted : .notDetermined

        case .bluetooth, .notifications, .fullDiskAccess:
            return .notDetermined
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
