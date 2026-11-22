import Foundation

/// Coordinates AirPods and TWS connection animations and HUD banners inside the Dynamic Notch.
@MainActor
public final class TWSNotchCoordinator: ObservableObject {
    public static let shared = TWSNotchCoordinator()

    @Published public private(set) var activeConnectionToast: AudioDeviceConnection?
    private var dismissTimer: Timer?
    public private(set) var observer: BluetoothAudioObserver

    public init(observer: BluetoothAudioObserver = NativeBluetoothAudioObserver()) {
        self.observer = observer
    }

    public func setObserver(_ observer: BluetoothAudioObserver) {
        self.observer.stopObserving()
        self.observer = observer
    }

    /// Begins listening for system Bluetooth audio device connections.
    public func startObserving() {
        observer.startObserving { [weak self] connection in
            Task { @MainActor [weak self] in
                self?.presentConnection(connection)
            }
        }
    }

    public func stopObserving() {
        observer.stopObserving()
        dismiss()
    }

    /// Presents a connection toast with spring animation and auto-dismissal.
    public func presentConnection(_ connection: AudioDeviceConnection, autoDismissAfter: TimeInterval = 4.0) {
        dismissTimer?.invalidate()
        self.activeConnectionToast = connection

        if autoDismissAfter > 0 {
            dismissTimer = Timer.scheduledTimer(withTimeInterval: autoDismissAfter, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.dismiss()
                }
            }
        }
    }

    /// Dismisses the currently displayed connection toast.
    public func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        self.activeConnectionToast = nil
    }
}
