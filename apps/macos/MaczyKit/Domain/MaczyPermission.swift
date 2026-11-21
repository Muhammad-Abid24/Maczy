import Foundation

/// Standard macOS system permissions governed by TCC and OS security.
public enum MaczyPermission: String, CaseIterable, Sendable {
    case screenRecording = "screen_recording"
    case camera = "camera"
    case microphone = "microphone"
    case accessibility = "accessibility"
    case bluetooth = "bluetooth"
    case notifications = "notifications"
    case fullDiskAccess = "full_disk_access"

    public var displayName: String {
        switch self {
        case .screenRecording: return "Screen Recording"
        case .camera: return "Camera"
        case .microphone: return "Microphone"
        case .accessibility: return "Accessibility"
        case .bluetooth: return "Bluetooth"
        case .notifications: return "Notifications"
        case .fullDiskAccess: return "Full Disk Access"
        }
    }
}

/// Authorization status for an OS-managed permission.
public enum PermissionState: String, Sendable {
    case notDetermined = "not_determined"
    case granted = "granted"
    case denied = "denied"
    case restricted = "restricted"

    public var isGranted: Bool {
        self == .granted
    }
}
