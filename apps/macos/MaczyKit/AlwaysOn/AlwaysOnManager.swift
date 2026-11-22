import Foundation
import Combine

@MainActor
public final class AlwaysOnManager: ObservableObject {
    @Published public private(set) var activeSession: AlwaysOnSession?
    @Published public private(set) var currentMode: AlwaysOnMode = .systemAndDisplay
    @Published public private(set) var remainingSeconds: Int?
    @Published public private(set) var formattedRemainingTime: String = "Idle"
    @Published public private(set) var lastReleaseReason: AlwaysOnReleaseReason?
    @Published public var safetyConfig: AlwaysOnSafetyConfig

    private let powerProvider: PowerAssertionProvider
    private let userDefaults: UserDefaults
    private var timer: Timer?
    private var thermalObserver: NSObjectProtocol?

    public init(
        powerProvider: PowerAssertionProvider = NativePowerAssertionProvider(),
        safetyConfig: AlwaysOnSafetyConfig = AlwaysOnSafetyConfig(),
        userDefaults: UserDefaults = .standard
    ) {
        self.powerProvider = powerProvider
        self.safetyConfig = safetyConfig
        self.userDefaults = userDefaults

        // Restore persisted mode preference
        if let saved = userDefaults.string(forKey: "maczy_always_on_mode"),
           let savedMode = AlwaysOnMode(rawValue: saved) {
            self.currentMode = savedMode
        }

        // Register thermal state change observer
        self.thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkThermalSafety(state: ProcessInfo.processInfo.thermalState)
            }
        }
    }

    deinit {
        if let observer = thermalObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        timer?.invalidate()
    }

    public var isActive: Bool {
        activeSession != nil
    }

    @discardableResult
    public func startSession(
        preset: AlwaysOnPreset,
        mode: AlwaysOnMode? = nil,
        startedAt: Date = Date(),
        reason: String = "Maczy Awake Session"
    ) -> Bool {
        let targetMode = mode ?? self.currentMode
        self.currentMode = targetMode

        // If an existing session is running, release it first
        if let existing = activeSession {
            _ = powerProvider.releaseAssertion(id: existing.assertionID)
            activeSession = nil
            timer?.invalidate()
            timer = nil
        }

        let result = powerProvider.createAssertion(
            type: targetMode.assertionType,
            name: "Maczy",
            details: "\(preset.displayName) (\(reason))"
        )

        guard result.success else {
            lastReleaseReason = nil
            formattedRemainingTime = "Error"
            return false
        }

        let session = AlwaysOnSession(
            preset: preset,
            mode: targetMode,
            startedAt: startedAt,
            assertionID: result.id
        )

        self.activeSession = session
        self.remainingSeconds = session.remainingSeconds(at: startedAt)
        self.formattedRemainingTime = session.formattedRemainingTime(at: startedAt)
        self.lastReleaseReason = nil

        startTimerIfNeeded()
        return true
    }

    public func stopSession(reason: AlwaysOnReleaseReason = .manualStop) {
        guard let session = activeSession else { return }

        _ = powerProvider.releaseAssertion(id: session.assertionID)
        self.activeSession = nil
        self.remainingSeconds = nil
        self.formattedRemainingTime = "Idle"
        self.lastReleaseReason = reason

        timer?.invalidate()
        timer = nil
    }

    public func setMode(_ mode: AlwaysOnMode) {
        userDefaults.set(mode.rawValue, forKey: "maczy_always_on_mode")
        guard mode != currentMode else { return }
        self.currentMode = mode

        // If a session is active, renew the power assertion with the new type
        if let currentSession = activeSession {
            let preset = currentSession.preset

            _ = powerProvider.releaseAssertion(id: currentSession.assertionID)

            let result = powerProvider.createAssertion(
                type: mode.assertionType,
                name: "Maczy",
                details: "\(preset.displayName) (Mode switched)"
            )

            if result.success {
                let updatedSession = AlwaysOnSession(
                    id: currentSession.id,
                    preset: currentSession.preset,
                    mode: mode,
                    startedAt: currentSession.startedAt,
                    assertionID: result.id
                )
                self.activeSession = updatedSession
            } else {
                stopSession(reason: .manualStop)
            }
        }
    }

    public func checkBatterySafety(percentage: Double, isCharging: Bool) {
        guard isActive else { return }
        if !isCharging && percentage <= safetyConfig.minBatteryPercentage {
            stopSession(reason: .lowBatteryAutoRelease(percentage: percentage))
        }
    }

    public func checkThermalSafety(state: ProcessInfo.ThermalState) {
        guard isActive else { return }
        if state.rawValue > safetyConfig.maxAllowedThermalState.rawValue {
            stopSession(reason: .thermalProtectionAutoRelease(state: state))
        }
    }

    public func tick(at date: Date = Date()) {
        guard let session = activeSession else { return }

        if let remaining = session.remainingSeconds(at: date) {
            self.remainingSeconds = remaining
            self.formattedRemainingTime = session.formattedRemainingTime(at: date)

            if remaining <= 0 {
                stopSession(reason: .timerExpired)
            }
        } else {
            self.remainingSeconds = nil
            self.formattedRemainingTime = "Indefinite"
        }
    }

    private func startTimerIfNeeded() {
        timer?.invalidate()
        timer = nil

        guard let session = activeSession, session.durationSeconds != nil else {
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }
}
