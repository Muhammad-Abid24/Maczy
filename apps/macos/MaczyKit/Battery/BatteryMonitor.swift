import Foundation
import Combine
import IOKit
import IOKit.ps

/// Main-actor observable coordinator monitoring live battery hardware telemetry.
@MainActor
public final class BatteryMonitor: ObservableObject {
    public static let shared = BatteryMonitor()

    @Published public private(set) var currentSnapshot: BatterySnapshot

    private let reader: BatteryTelemetryReaderProtocol
    private var timer: Timer?
    private var runLoopSource: CFRunLoopSource?

    public static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil ||
        NSClassFromString("XCTestCase") != nil
    }

    public init(reader: BatteryTelemetryReaderProtocol = IOKitBatteryTelemetryReader(), autoStart: Bool = true) {
        self.reader = reader
        self.currentSnapshot = reader.readTelemetry()
        if autoStart && !Self.isRunningTests {
            startMonitoring()
        }
    }

    /// Refresh telemetry immediately and publish state update.
    public func refresh() {
        self.currentSnapshot = reader.readTelemetry()
    }

    /// Begin real-time event-driven monitoring via IOKit power notifications and periodic fallback timer.
    public func startMonitoring(intervalSeconds: TimeInterval = 2.0) {
        stopMonitoring()
        refresh()

        // 1. Register IOKit Power Sources RunLoop Source for instant push notifications
        // on charger plug/unplug, charging state toggle, and percentage increments.
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx = ctx else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue()
            Task { @MainActor in
                monitor.refresh()
            }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            self.runLoopSource = source
        }

        // 2. Scheduled timer fallback for continuous voltage, amperage, and temperature telemetry
        timer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    /// Stop periodic monitoring and release run loop source.
    public func stopMonitoring() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
        timer?.invalidate()
        timer = nil
    }

    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        timer?.invalidate()
    }
}
