import XCTest
@testable import MaczyKit

final class TWSTests: XCTestCase {

    func testAudioDeviceClassification() {
        XCTAssertEqual(AudioDeviceType.classify(from: "Abid's AirPods Pro"), .airPodsPro)
        XCTAssertEqual(AudioDeviceType.classify(from: "AirPods Max - Space Gray"), .airPodsMax)
        XCTAssertEqual(AudioDeviceType.classify(from: "AirPods"), .airPodsStandard)
        XCTAssertEqual(AudioDeviceType.classify(from: "Beats Fit Pro"), .beats)
        XCTAssertEqual(AudioDeviceType.classify(from: "Powerbeats Pro"), .beats)
        XCTAssertEqual(AudioDeviceType.classify(from: "Sony WH-1000XM5"), .genericTWS)
        XCTAssertEqual(AudioDeviceType.classify(from: "Bose QC45"), .genericTWS)
    }

    func testAudioDeviceBatterySummary() {
        let tripple = AudioDeviceBattery(left: 85, right: 90, caseBattery: 100)
        XCTAssertEqual(tripple.summaryText, "L: 85% • R: 90% • Case: 100%")

        let dual = AudioDeviceBattery(left: 50, right: 45)
        XCTAssertEqual(dual.summaryText, "L: 50% • R: 45%")

        let single = AudioDeviceBattery(single: 78)
        XCTAssertEqual(single.summaryText, "78%")

        let empty = AudioDeviceBattery()
        XCTAssertEqual(empty.summaryText, "Connected")
    }

    func testMockBluetoothAudioObserver() {
        let mock = MockBluetoothAudioObserver()
        XCTAssertFalse(mock.isObserving)

        final class Box: @unchecked Sendable {
            var connection: AudioDeviceConnection?
        }
        let box = Box()
        mock.startObserving { conn in
            box.connection = conn
        }

        XCTAssertTrue(mock.isObserving)

        let device = AudioDeviceConnection(
            name: "Test AirPods Pro",
            type: .airPodsPro,
            battery: AudioDeviceBattery(left: 100, right: 100, caseBattery: 95)
        )
        mock.simulateConnection(device)

        XCTAssertNotNil(box.connection)
        XCTAssertEqual(box.connection?.name, "Test AirPods Pro")
        XCTAssertEqual(box.connection?.type, .airPodsPro)

        mock.stopObserving()
        XCTAssertFalse(mock.isObserving)
    }

    @MainActor
    func testTWSNotchCoordinatorPresentationAndDismiss() {
        let mock = MockBluetoothAudioObserver()
        let coordinator = TWSNotchCoordinator(observer: mock)

        XCTAssertNil(coordinator.activeConnectionToast)

        let device = AudioDeviceConnection(
            name: "AirPods Max",
            type: .airPodsMax,
            battery: AudioDeviceBattery(single: 90)
        )

        coordinator.presentConnection(device, autoDismissAfter: 0) // No auto dismiss
        XCTAssertNotNil(coordinator.activeConnectionToast)
        XCTAssertEqual(coordinator.activeConnectionToast?.name, "AirPods Max")
        XCTAssertEqual(coordinator.activeConnectionToast?.type, .airPodsMax)

        coordinator.dismiss()
        XCTAssertNil(coordinator.activeConnectionToast)
    }

    @MainActor
    func testTWSNotchCoordinatorAutoDismiss() {
        let mock = MockBluetoothAudioObserver()
        let coordinator = TWSNotchCoordinator(observer: mock)

        let device = AudioDeviceConnection(
            name: "AirPods",
            type: .airPodsStandard,
            battery: AudioDeviceBattery(left: 80, right: 80)
        )

        let exp = expectation(description: "Auto dismiss")
        coordinator.presentConnection(device, autoDismissAfter: 0.1)
        XCTAssertNotNil(coordinator.activeConnectionToast)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            XCTAssertNil(coordinator.activeConnectionToast)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }
}
