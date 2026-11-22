import Foundation

/// Type of power source currently supplying energy to the system.
public enum PowerSourceType: String, Sendable, Codable {
    case battery = "Battery Power"
    case acPower = "AC Power"
    case unknown = "Unknown"
}

/// Dynamic charging and discharging state of the battery.
public enum ChargingState: String, Sendable, Codable {
    case discharging = "Discharging"
    case charging = "AC Connected (Charging)"
    case charged = "Fully Charged"
    case notCharging = "AC Connected (Not Charging)"
}

/// High-level battery health classification reported by macOS IOKit.
public enum BatteryHealthCondition: String, Sendable, Codable {
    case normal = "Normal"
    case replaceSoon = "Replace Soon"
    case replaceNow = "Replace Now"
    case serviceBattery = "Service Battery"
    case unknown = "Unknown"
}

/// Immutable telemetry snapshot representing battery hardware status.
public struct BatterySnapshot: Sendable, Equatable {
    public let isBatteryPresent: Bool
    public let stateOfCharge: Int
    public let maxCapacityPercent: Int
    public let cycleCount: Int
    public let temperatureCelsius: Double?
    public let powerSource: PowerSourceType
    public let chargingState: ChargingState
    public let timeToEmptyMinutes: Int?
    public let timeToFullMinutes: Int?
    public let voltageMilliVolts: Int?
    public let amperageMilliAmps: Int?
    public let designCapacityMah: Int?
    public let nominalCapacityMah: Int?
    public let healthCondition: BatteryHealthCondition
    public let lastUpdated: Date

    public init(
        isBatteryPresent: Bool = true,
        stateOfCharge: Int = 100,
        maxCapacityPercent: Int = 100,
        cycleCount: Int = 0,
        temperatureCelsius: Double? = nil,
        powerSource: PowerSourceType = .acPower,
        chargingState: ChargingState = .notCharging,
        timeToEmptyMinutes: Int? = nil,
        timeToFullMinutes: Int? = nil,
        voltageMilliVolts: Int? = nil,
        amperageMilliAmps: Int? = nil,
        designCapacityMah: Int? = nil,
        nominalCapacityMah: Int? = nil,
        healthCondition: BatteryHealthCondition = .normal,
        lastUpdated: Date = Date()
    ) {
        self.isBatteryPresent = isBatteryPresent
        self.stateOfCharge = max(0, min(100, stateOfCharge))
        self.maxCapacityPercent = max(0, min(100, maxCapacityPercent))
        self.cycleCount = max(0, cycleCount)
        self.temperatureCelsius = temperatureCelsius
        self.powerSource = powerSource
        self.chargingState = chargingState
        self.timeToEmptyMinutes = timeToEmptyMinutes
        self.timeToFullMinutes = timeToFullMinutes
        self.voltageMilliVolts = voltageMilliVolts
        self.amperageMilliAmps = amperageMilliAmps
        self.designCapacityMah = designCapacityMah
        self.nominalCapacityMah = nominalCapacityMah
        self.healthCondition = healthCondition
        self.lastUpdated = lastUpdated
    }

    /// Convenience snapshot for desktop Macs (Mac mini, Mac Studio, Mac Pro) or CI runners without battery.
    public static let desktopOrNotPresent = BatterySnapshot(
        isBatteryPresent: false,
        stateOfCharge: 100,
        maxCapacityPercent: 100,
        cycleCount: 0,
        temperatureCelsius: nil,
        powerSource: .acPower,
        chargingState: .notCharging,
        timeToEmptyMinutes: nil,
        timeToFullMinutes: nil,
        voltageMilliVolts: nil,
        amperageMilliAmps: nil,
        designCapacityMah: nil,
        nominalCapacityMah: nil,
        healthCondition: .normal,
        lastUpdated: Date()
    )

    public var isCharging: Bool {
        chargingState == .charging
    }

    public var isACConnected: Bool {
        powerSource == .acPower
    }

    /// Formatted temperature string (e.g. "32.5°C") or "—" if unavailable.
    public var formattedTemperature: String {
        guard let temp = temperatureCelsius else { return "—" }
        return String(format: "%.1f°C", temp)
    }

    /// Formatted remaining runtime estimate (e.g. "3h 45m remaining").
    public var formattedTimeToEmpty: String? {
        guard let minutes = timeToEmptyMinutes, minutes > 0 else { return nil }
        let hours = minutes / 60
        let remMinutes = minutes % 60
        if hours > 0 {
            return "\(hours)h \(remMinutes)m remaining"
        } else {
            return "\(remMinutes)m remaining"
        }
    }

    /// Formatted time until full charge (e.g. "45m until full").
    public var formattedTimeToFull: String? {
        guard let minutes = timeToFullMinutes, minutes > 0 else { return nil }
        let hours = minutes / 60
        let remMinutes = minutes % 60
        if hours > 0 {
            return "\(hours)h \(remMinutes)m until full"
        } else {
            return "\(remMinutes)m until full"
        }
    }

    /// SF Symbol icon name reflecting power source and current charge level.
    public var batteryIconName: String {
        guard isBatteryPresent else { return "powerplug.fill" }

        if isCharging {
            return "battery.100.bolt"
        }

        switch stateOfCharge {
        case 90...100: return "battery.100"
        case 70..<90: return "battery.75"
        case 40..<70: return "battery.50"
        case 15..<40: return "battery.25"
        default: return "battery.0"
        }
    }
}
