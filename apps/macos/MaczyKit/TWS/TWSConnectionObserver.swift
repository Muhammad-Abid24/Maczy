import Foundation
import IOKit

/// Observer protocol for Bluetooth audio device connection events.
public protocol BluetoothAudioObserver: Sendable {
    func startObserving(onConnect: @escaping @Sendable (AudioDeviceConnection) -> Void)
    func stopObserving()
}

/// Production Bluetooth audio observer reading native connection notifications and IORegistry battery telemetry.
public final class NativeBluetoothAudioObserver: BluetoothAudioObserver, @unchecked Sendable {
    private var callback: (@Sendable (AudioDeviceConnection) -> Void)?
    private var observerToken: NSObjectProtocol?
    private let lock = NSLock()

    public init() {}

    public func startObserving(onConnect: @escaping @Sendable (AudioDeviceConnection) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        self.callback = onConnect

        // Listen for system Bluetooth connection events
        observerToken = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("IOBluetoothDeviceWasConnectedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleDeviceConnected(notification: notification)
        }
    }

    public func stopObserving() {
        lock.lock()
        defer { lock.unlock() }
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
            observerToken = nil
        }
        callback = nil
    }

    private func handleDeviceConnected(notification: Notification) {
        // Extract device name or inspect audio peripherals
        var deviceName = "Bluetooth Audio"
        if let userInfo = notification.userInfo,
           let name = userInfo["name"] as? String {
            deviceName = name
        }

        let type = AudioDeviceType.classify(from: deviceName)
        let battery = readIORegistryBattery(for: deviceName)
        let connection = AudioDeviceConnection(
            name: deviceName,
            type: type,
            battery: battery,
            connectedAt: Date(),
            isSimulated: false
        )

        callback?(connection)
    }

    /// Attempts to read battery levels for connected AirPods/Bluetooth headsets from IORegistry.
    public func readIORegistryBattery(for deviceName: String) -> AudioDeviceBattery? {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AppleDeviceManagementHIDEventService")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var entry: io_object_t = IOIteratorNext(iterator)
        while entry != 0 {
            defer {
                IOObjectRelease(entry)
                entry = IOIteratorNext(iterator)
            }

            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any] {

                let product = dict["Product"] as? String ?? ""
                if product.localizedCaseInsensitiveContains(deviceName) || deviceName.localizedCaseInsensitiveContains(product) {
                    let left = dict["BatteryPercentLeft"] as? Int
                    let right = dict["BatteryPercentRight"] as? Int
                    let casePct = dict["BatteryPercentCase"] as? Int
                    let single = dict["BatteryPercentSingle"] as? Int ?? dict["BatteryPercent"] as? Int

                    if left != nil || right != nil || casePct != nil || single != nil {
                        return AudioDeviceBattery(left: left, right: right, caseBattery: casePct, single: single)
                    }
                }
            }
        }
        return nil
    }
}

/// Mock observer enabling deterministic unit tests and synthetic event triggering.
public final class MockBluetoothAudioObserver: BluetoothAudioObserver, @unchecked Sendable {
    private var callback: (@Sendable (AudioDeviceConnection) -> Void)?
    private let lock = NSLock()
    public private(set) var isObserving: Bool = false

    public init() {}

    public func startObserving(onConnect: @escaping @Sendable (AudioDeviceConnection) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        self.callback = onConnect
        self.isObserving = true
    }

    public func stopObserving() {
        lock.lock()
        defer { lock.unlock() }
        self.callback = nil
        self.isObserving = false
    }

    /// Simulates a device connection event for tests or UI demonstration.
    public func simulateConnection(_ device: AudioDeviceConnection) {
        lock.lock()
        let cb = self.callback
        lock.unlock()
        cb?(device)
    }
}
