import Foundation
import IOKit
import IOKit.ps

/// Protocol defining read-only extraction of battery telemetry.
public protocol BatteryTelemetryReaderProtocol: Sendable {
    func readTelemetry() -> BatterySnapshot
}

/// Native implementation querying macOS IOKit power sources and AppleSmartBattery registry.
public struct IOKitBatteryTelemetryReader: BatteryTelemetryReaderProtocol {
    public init() {}

    public func readTelemetry() -> BatterySnapshot {
        // 1. Query IOPS (IOPowerSources)
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return .desktopOrNotPresent
        }

        var primaryDescription: [String: Any]?
        for ps in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] {
                // Look for an internal battery first
                if (desc[kIOPSTypeKey as String] as? String) == (kIOPSInternalBatteryType as String) ||
                   (desc["Type"] as? String) == "InternalBattery" {
                    primaryDescription = desc
                    break
                }
                if primaryDescription == nil {
                    primaryDescription = desc
                }
            }
        }

        guard let desc = primaryDescription else {
            return .desktopOrNotPresent
        }

        let iopsData = Self.parsePowerSourcesDictionary(desc)
        guard iopsData.isPresent else {
            return .desktopOrNotPresent
        }

        // 2. Query AppleSmartBattery for deep hardware telemetry (Apple Silicon / Intel Mac)
        let smartData = queryAppleSmartBattery()

        // Compute effective health percent: prioritize Nominal/Design ratio, then AppleSmartBattery health, then IOPS
        let healthPercent: Int
        if let calcHealth = smartData.healthPercent {
            healthPercent = calcHealth
        } else {
            healthPercent = iopsData.maxCap
        }

        // Determine charging state
        let chargingState: ChargingState
        if iopsData.isCharging {
            chargingState = .charging
        } else if iopsData.isCharged {
            chargingState = .charged
        } else if iopsData.powerSource == .acPower {
            chargingState = .notCharging
        } else {
            chargingState = .discharging
        }

        return BatterySnapshot(
            isBatteryPresent: true,
            stateOfCharge: iopsData.soc,
            maxCapacityPercent: healthPercent,
            cycleCount: smartData.cycleCount,
            temperatureCelsius: smartData.temperatureCelsius,
            powerSource: iopsData.powerSource,
            chargingState: chargingState,
            timeToEmptyMinutes: iopsData.timeToEmpty,
            timeToFullMinutes: iopsData.timeToFull,
            voltageMilliVolts: smartData.voltageMv,
            amperageMilliAmps: smartData.amperageMa,
            designCapacityMah: smartData.designCapacity,
            nominalCapacityMah: smartData.nominalCapacity,
            healthCondition: iopsData.health,
            lastUpdated: Date()
        )
    }

    /// Pure parser for IOPowerSources dictionaries.
    public static func parsePowerSourcesDictionary(_ dict: [String: Any]) -> (
        soc: Int,
        maxCap: Int,
        isCharging: Bool,
        isCharged: Bool,
        isPresent: Bool,
        powerSource: PowerSourceType,
        timeToEmpty: Int?,
        timeToFull: Int?,
        health: BatteryHealthCondition
    ) {
        let isPresent = (dict[kIOPSIsPresentKey as String] as? Bool)
            ?? ((dict["Is Present"] as? Int) != 0)

        let currentCap = (dict[kIOPSCurrentCapacityKey as String] as? Int)
            ?? (dict["Current Capacity"] as? Int)
            ?? 100
        let maxCap = (dict[kIOPSMaxCapacityKey as String] as? Int)
            ?? (dict["Max Capacity"] as? Int)
            ?? 100

        let soc: Int
        if maxCap > 0 {
            soc = Int(round((Double(currentCap) / Double(maxCap)) * 100.0))
        } else {
            soc = currentCap
        }

        let isCharging = (dict[kIOPSIsChargingKey as String] as? Bool)
            ?? ((dict["Is Charging"] as? Int) == 1)
        let isCharged = (dict[kIOPSIsChargedKey as String] as? Bool)
            ?? ((dict["Is Charged"] as? Int) == 1)

        let powerSourceState = (dict[kIOPSPowerSourceStateKey as String] as? String)
            ?? (dict["Power Source State"] as? String)
            ?? ""
        let powerSource: PowerSourceType
        if powerSourceState == (kIOPSACPowerValue as String) || powerSourceState == "AC Power" {
            powerSource = .acPower
        } else if powerSourceState == (kIOPSBatteryPowerValue as String) || powerSourceState == "Battery Power" {
            powerSource = .battery
        } else {
            powerSource = .unknown
        }

        let timeToEmptyRaw = (dict[kIOPSTimeToEmptyKey as String] as? Int)
            ?? (dict["Time to Empty"] as? Int)
        let timeToEmpty: Int?
        if let raw = timeToEmptyRaw, raw > 0 {
            timeToEmpty = raw
        } else {
            timeToEmpty = nil
        }

        let timeToFullRaw = (dict[kIOPSTimeToFullChargeKey as String] as? Int)
            ?? (dict["Time to Full Charge"] as? Int)
        let timeToFull: Int?
        if let raw = timeToFullRaw, raw > 0 {
            timeToFull = raw
        } else {
            timeToFull = nil
        }

        let healthConditionStr = (dict["BatteryHealthCondition"] as? String)
            ?? (dict["BatteryHealth"] as? String)
            ?? ""
        let health: BatteryHealthCondition
        switch healthConditionStr.lowercased() {
        case "good", "normal":
            health = .normal
        case "check battery", "replace soon":
            health = .replaceSoon
        case "replace now":
            health = .replaceNow
        case "service battery":
            health = .serviceBattery
        default:
            health = .normal
        }

        return (
            soc: max(0, min(100, soc)),
            maxCap: max(0, min(100, maxCap)),
            isCharging: isCharging,
            isCharged: isCharged,
            isPresent: isPresent,
            powerSource: powerSource,
            timeToEmpty: timeToEmpty,
            timeToFull: timeToFull,
            health: health
        )
    }

    /// Pure parser for AppleSmartBattery registry dictionary.
    public static func parseAppleSmartBatteryDictionary(_ dict: [String: Any]) -> (
        cycleCount: Int,
        temperatureCelsius: Double?,
        voltageMv: Int?,
        amperageMa: Int?,
        nominalCapacity: Int?,
        designCapacity: Int?,
        healthPercent: Int?
    ) {
        let cycleCount = (dict["CycleCount"] as? Int) ?? 0
        let voltageMv = dict["Voltage"] as? Int
        let amperageMa = (dict["Amperage"] as? Int) ?? (dict["InstantAmperage"] as? Int)
        let nominalCap = dict["NominalChargeCapacity"] as? Int
        let designCap = dict["DesignCapacity"] as? Int

        var healthPercent: Int?
        if let nom = nominalCap, let des = designCap, des > 0 {
            healthPercent = max(0, min(100, Int(round((Double(nom) / Double(des)) * 100.0))))
        }

        var tempCelsius: Double?
        if let rawTemp = dict["Temperature"] as? Int {
            // AppleSmartBattery / SBS v1.1 register 0x08 is tenths of a Kelvin (0.1 K):
            // e.g. 2732 -> 0.05 °C, 2981 -> 24.95 °C, 3061 -> 32.95 °C.
            if rawTemp >= 2000 && rawTemp <= 6000 {
                let kelvin = Double(rawTemp) / 10.0
                tempCelsius = kelvin - 273.15
            } else if rawTemp >= -50 && rawTemp <= 150 {
                tempCelsius = Double(rawTemp)
            } else if rawTemp > 6000 && rawTemp <= 20000 {
                // Centi-Celsius (e.g. 6500 -> 65.0 °C)
                tempCelsius = Double(rawTemp) / 100.0
            }
        }

        return (
            cycleCount: max(0, cycleCount),
            temperatureCelsius: tempCelsius,
            voltageMv: voltageMv,
            amperageMa: amperageMa,
            nominalCapacity: nominalCap,
            designCapacity: designCap,
            healthPercent: healthPercent
        )
    }

    private func queryAppleSmartBattery() -> (
        cycleCount: Int,
        temperatureCelsius: Double?,
        voltageMv: Int?,
        amperageMa: Int?,
        nominalCapacity: Int?,
        designCapacity: Int?,
        healthPercent: Int?
    ) {
        var iterator: io_iterator_t = 0
        let matchDict = IOServiceMatching("AppleSmartBattery")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator)
        guard result == KERN_SUCCESS else {
            return (0, nil, nil, nil, nil, nil, nil)
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any] {
                return Self.parseAppleSmartBatteryDictionary(dict)
            }
        }

        return (0, nil, nil, nil, nil, nil, nil)
    }
}

/// Mock reader for testing and controlled simulations.
public struct MockBatteryTelemetryReader: BatteryTelemetryReaderProtocol {
    public var mockSnapshot: BatterySnapshot

    public init(mockSnapshot: BatterySnapshot = .desktopOrNotPresent) {
        self.mockSnapshot = mockSnapshot
    }

    public func readTelemetry() -> BatterySnapshot {
        mockSnapshot
    }
}
