import Foundation
import Combine

/// Main-actor observable coordinator monitoring live battery hardware telemetry.
@MainActor
public final class BatteryMonitor: ObservableObject {
    public static let shared = BatteryMonitor()

    @Published public private(set) var currentSnapshot: BatterySnapshot

    private let reader: BatteryTelemetryReaderProtocol
    private var timer: Timer?

    public init(reader: BatteryTelemetryReaderProtocol = IOKitBatteryTelemetryReader()) {
        self.reader = reader
        self.currentSnapshot = reader.readTelemetry()
    }

    /// Refresh telemetry immediately and publish state update.
    public func refresh() {
        self.currentSnapshot = reader.readTelemetry()
    }

    /// Begin periodic polling for telemetry updates.
    public func startMonitoring(intervalSeconds: TimeInterval = 10.0) {
        stopMonitoring()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    /// Stop periodic monitoring.
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}
