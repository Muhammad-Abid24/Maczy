import Foundation

/// Classification of Bluetooth TWS and headphone devices.
public enum AudioDeviceType: String, CaseIterable, Sendable, Identifiable {
    case airPodsStandard = "AirPods"
    case airPodsPro = "AirPods Pro"
    case airPodsMax = "AirPods Max"
    case beats = "Beats"
    case genericTWS = "Bluetooth Audio"

    public var id: String { rawValue }

    /// SF Symbol icon representation for the device.
    public var iconName: String {
        switch self {
        case .airPodsStandard: return "airpod.right"
        case .airPodsPro: return "airpodpro.right"
        case .airPodsMax: return "airpodsmax"
        case .beats: return "headphones"
        case .genericTWS: return "headphones"
        }
    }

    /// Classifies a device type from its advertised Bluetooth friendly name.
    public static func classify(from deviceName: String) -> AudioDeviceType {
        let lower = deviceName.lowercased()
        if lower.contains("max") && (lower.contains("airpod") || lower.contains("airpods")) {
            return .airPodsMax
        }
        if lower.contains("pro") && (lower.contains("airpod") || lower.contains("airpods")) {
            return .airPodsPro
        }
        if lower.contains("airpod") || lower.contains("airpods") {
            return .airPodsStandard
        }
        if lower.contains("beats") || lower.contains("powerbeats") || lower.contains("solo") || lower.contains("studio") {
            return .beats
        }
        return .genericTWS
    }
}

/// Battery telemetry levels for paired TWS earbuds and charging case.
public struct AudioDeviceBattery: Sendable, Equatable {
    public let left: Int?
    public let right: Int?
    public let caseBattery: Int?
    public let single: Int?

    public init(left: Int? = nil, right: Int? = nil, caseBattery: Int? = nil, single: Int? = nil) {
        self.left = left
        self.right = right
        self.caseBattery = caseBattery
        self.single = single
    }

    /// User-facing short battery summary.
    public var summaryText: String {
        if let single = single {
            return "\(single)%"
        }
        var parts: [String] = []
        if let l = left { parts.append("L: \(l)%") }
        if let r = right { parts.append("R: \(r)%") }
        if let c = caseBattery { parts.append("Case: \(c)%") }
        return parts.isEmpty ? "Connected" : parts.joined(separator: " • ")
    }
}

/// Represents an active or newly connected audio device for animation and HUD rendering.
public struct AudioDeviceConnection: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let type: AudioDeviceType
    public let battery: AudioDeviceBattery?
    public let connectedAt: Date
    public let isSimulated: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        type: AudioDeviceType? = nil,
        battery: AudioDeviceBattery? = nil,
        connectedAt: Date = Date(),
        isSimulated: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type ?? AudioDeviceType.classify(from: name)
        self.battery = battery
        self.connectedAt = connectedAt
        self.isSimulated = isSimulated
    }
}
