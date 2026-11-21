import XCTest
@testable import MaczyKit

final class BatteryMonitoringTests: XCTestCase {

    func testParsePowerSourcesDictionaryCharging() {
        let dict: [String: Any] = [
            "Current Capacity": 82,
            "Max Capacity": 100,
            "Is Charging": 1,
            "Is Charged": 0,
            "Is Present": 1,
            "Power Source State": "AC Power",
            "Time to Full Charge": 45,
            "Time to Empty": 0,
            "BatteryHealth": "Good"
        ]

        let parsed = IOKitBatteryTelemetryReader.parsePowerSourcesDictionary(dict)
        XCTAssertTrue(parsed.isPresent)
        XCTAssertEqual(parsed.soc, 82)
        XCTAssertEqual(parsed.maxCap, 100)
        XCTAssertTrue(parsed.isCharging)
        XCTAssertFalse(parsed.isCharged)
        XCTAssertEqual(parsed.powerSource, .acPower)
        XCTAssertEqual(parsed.timeToFull, 45)
        XCTAssertNil(parsed.timeToEmpty)
        XCTAssertEqual(parsed.health, .normal)
    }

    func testParsePowerSourcesDictionaryDischarging() {
        let dict: [String: Any] = [
            "Current Capacity": 48,
            "Max Capacity": 100,
            "Is Charging": 0,
            "Is Charged": 0,
            "Is Present": true,
            "Power Source State": "Battery Power",
            "Time to Empty": 215,
            "BatteryHealthCondition": "Normal"
        ]

        let parsed = IOKitBatteryTelemetryReader.parsePowerSourcesDictionary(dict)
        XCTAssertTrue(parsed.isPresent)
        XCTAssertEqual(parsed.soc, 48)
        XCTAssertFalse(parsed.isCharging)
        XCTAssertFalse(parsed.isCharged)
        XCTAssertEqual(parsed.powerSource, .battery)
        XCTAssertEqual(parsed.timeToEmpty, 215)
        XCTAssertNil(parsed.timeToFull)
        XCTAssertEqual(parsed.health, .normal)
    }

    func testParsePowerSourcesDictionaryDesktopNotPresent() {
        let dict: [String: Any] = [
            "Is Present": false,
            "Power Source State": "AC Power"
        ]

        let parsed = IOKitBatteryTelemetryReader.parsePowerSourcesDictionary(dict)
        XCTAssertFalse(parsed.isPresent)
        XCTAssertEqual(parsed.powerSource, .acPower)
    }

    func testParseAppleSmartBatteryDictionary() {
        let dict: [String: Any] = [
            "CycleCount": 321,
            "Temperature": 3061,
            "Voltage": 12428,
            "Amperage": -1250,
            "NominalChargeCapacity": 5480,
            "DesignCapacity": 6249
        ]

        let parsed = IOKitBatteryTelemetryReader.parseAppleSmartBatteryDictionary(dict)
        XCTAssertEqual(parsed.cycleCount, 321)
        XCTAssertNotNil(parsed.temperatureCelsius)
        // 3061 tenths of Kelvin: 306.1 - 273.15 = 32.95 °C
        XCTAssertEqual(parsed.temperatureCelsius!, 32.95, accuracy: 0.1)
        XCTAssertEqual(parsed.voltageMv, 12428)
        XCTAssertEqual(parsed.amperageMa, -1250)
        XCTAssertEqual(parsed.nominalCapacity, 5480)
        XCTAssertEqual(parsed.designCapacity, 6249)
        // 5480 / 6249 * 100 = 87.69% -> rounded to 88%
        XCTAssertEqual(parsed.healthPercent, 88)
    }

    func testTemperatureConversionVariants() {
        // 1. Tenths of Kelvin (2000...6000)
        let dictKelvin: [String: Any] = ["Temperature": 2981] // 298.1 K = 24.95 °C
        let parsedKelvin = IOKitBatteryTelemetryReader.parseAppleSmartBatteryDictionary(dictKelvin)
        XCTAssertEqual(parsedKelvin.temperatureCelsius!, 24.95, accuracy: 0.1)

        // 2. Direct Celsius (-50...150)
        let dictCelsius: [String: Any] = ["Temperature": 35]
        let parsedCelsius = IOKitBatteryTelemetryReader.parseAppleSmartBatteryDictionary(dictCelsius)
        XCTAssertEqual(parsedCelsius.temperatureCelsius!, 35.0, accuracy: 0.1)

        // 3. Centi-Celsius (6001...20000)
        let dictCenti: [String: Any] = ["Temperature": 6500] // 65.0 °C
        let parsedCenti = IOKitBatteryTelemetryReader.parseAppleSmartBatteryDictionary(dictCenti)
        XCTAssertEqual(parsedCenti.temperatureCelsius!, 65.0, accuracy: 0.1)
    }

    func testBatterySnapshotFormattingHelpers() {
        let snapshot = BatterySnapshot(
            isBatteryPresent: true,
            stateOfCharge: 78,
            maxCapacityPercent: 92,
            cycleCount: 140,
            temperatureCelsius: 31.42,
            powerSource: .battery,
            chargingState: .discharging,
            timeToEmptyMinutes: 185,
            timeToFullMinutes: nil,
            voltageMilliVolts: 11800,
            amperageMilliAmps: -800,
            designCapacityMah: 5000,
            nominalCapacityMah: 4600,
            healthCondition: .normal
        )

        XCTAssertFalse(snapshot.isCharging)
        XCTAssertFalse(snapshot.isACConnected)
        XCTAssertEqual(snapshot.formattedTemperature, "31.4°C")
        XCTAssertEqual(snapshot.formattedTimeToEmpty, "3h 5m remaining")
        XCTAssertNil(snapshot.formattedTimeToFull)
        XCTAssertEqual(snapshot.batteryIconName, "battery.75")

        // Test Charging icon
        let chargingSnapshot = BatterySnapshot(
            isBatteryPresent: true,
            stateOfCharge: 80,
            chargingState: .charging
        )
        XCTAssertTrue(chargingSnapshot.isCharging)
        XCTAssertEqual(chargingSnapshot.batteryIconName, "battery.100.bolt")

        // Test time until full
        let fullSnapshot = BatterySnapshot(
            timeToFullMinutes: 42
        )
        XCTAssertEqual(fullSnapshot.formattedTimeToFull, "42m until full")

        // Test desktop Mac fallback
        let desktop = BatterySnapshot.desktopOrNotPresent
        XCTAssertFalse(desktop.isBatteryPresent)
        XCTAssertEqual(desktop.batteryIconName, "powerplug.fill")
        XCTAssertEqual(desktop.formattedTemperature, "—")
    }

    @MainActor
    func testMockTelemetryReaderAndMonitorRefresh() {
        let initial = BatterySnapshot(
            isBatteryPresent: true,
            stateOfCharge: 60,
            powerSource: .battery,
            chargingState: .discharging
        )
        let mockReader = MockBatteryTelemetryReader(mockSnapshot: initial)
        let monitor = BatteryMonitor(reader: mockReader)

        XCTAssertEqual(monitor.currentSnapshot.stateOfCharge, 60)
        XCTAssertEqual(monitor.currentSnapshot.chargingState, .discharging)

        // Simulate refresh with new snapshot
        let updated = BatterySnapshot(
            isBatteryPresent: true,
            stateOfCharge: 85,
            powerSource: .acPower,
            chargingState: .charging
        )
        var updatedMock = mockReader
        updatedMock.mockSnapshot = updated
        let monitor2 = BatteryMonitor(reader: updatedMock)
        monitor2.refresh()

        XCTAssertEqual(monitor2.currentSnapshot.stateOfCharge, 85)
        XCTAssertEqual(monitor2.currentSnapshot.chargingState, .charging)
    }

    @MainActor
    func testChargeLimitMZ014FailClosedGating() {
        let appState = AppState()

        // Valid percentage (80%) must be strictly gated by MZ-014 backend verification
        let res80 = appState.dispatch(.selectChargeLimit(percentage: 80))
        XCTAssertFalse(res80.ok)
        XCTAssertEqual(res80.errorCode, "GATE_MZ_014")

        let res100 = appState.dispatch(.selectChargeLimit(percentage: 100))
        XCTAssertFalse(res100.ok)
        XCTAssertEqual(res100.errorCode, "GATE_MZ_014")

        // Invalid percentage must fail
        let res73 = appState.dispatch(.selectChargeLimit(percentage: 73))
        XCTAssertFalse(res73.ok)
        XCTAssertEqual(res73.errorCode, "INVALID_PERCENTAGE")
    }

    @MainActor
    func testRefreshBatteryTelemetryAction() {
        let appState = AppState()
        let result = appState.dispatch(.refreshBatteryTelemetry)
        XCTAssertTrue(result.ok)
        XCTAssertNotNil(result.message)
    }

    func testNativeIOKitReaderSafePreflight() {
        let reader = IOKitBatteryTelemetryReader()
        let snapshot = reader.readTelemetry()

        // Verify bounds regardless of whether running on real MacBook or virtual CI runner
        XCTAssertGreaterThanOrEqual(snapshot.stateOfCharge, 0)
        XCTAssertLessThanOrEqual(snapshot.stateOfCharge, 100)
        XCTAssertGreaterThanOrEqual(snapshot.maxCapacityPercent, 0)
        XCTAssertLessThanOrEqual(snapshot.maxCapacityPercent, 100)
        XCTAssertGreaterThanOrEqual(snapshot.cycleCount, 0)

        if snapshot.isBatteryPresent {
            XCTAssertTrue(snapshot.powerSource == .battery || snapshot.powerSource == .acPower)
        } else {
            XCTAssertFalse(snapshot.isBatteryPresent)
            XCTAssertEqual(snapshot.powerSource, .acPower)
        }
    }
}
