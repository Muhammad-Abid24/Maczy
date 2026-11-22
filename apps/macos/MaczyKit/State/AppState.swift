import Foundation
import SwiftUI
import Combine

/// Observable application state driving Dashboard and Menu Bar surfaces.
/// Implements the strict ARCHITECTURE.md pipeline:
/// Action -> Capability Gate -> Permission Gate -> Command -> Result -> State Update
@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var selectedModule: MaczyModuleId = .captureAndRecording
    @Published public var selectedTab: DashboardTab = .overview
    @Published public var modules: [ModuleStatus] = []
    @Published public var isSidebarExpanded: Bool = false
    @Published public var batterySnapshot: BatterySnapshot = .desktopOrNotPresent

    public let capabilityRegistry: CapabilityRegistry
    public let eventBus: EventBus
    public let alwaysOnManager: AlwaysOnManager
    public let updateManager: UpdateManager
    public let cleanerManager: CleanerManager
    public let uninstallManager: UninstallManager
    public let optimizerManager: OptimizerManager

    private var permissions: [MaczyPermission: PermissionState] = [:]
    private var lastDispatchedActions: [String: Date] = [:]
    public var debounceInterval: TimeInterval
    private var cancellables = Set<AnyCancellable>()

    public init(
        capabilityRegistry: CapabilityRegistry = CapabilityRegistry(),
        eventBus: EventBus = .shared,
        debounceInterval: TimeInterval = 0.2,
        alwaysOnManager: AlwaysOnManager? = nil,
        updateManager: UpdateManager? = nil,
        cleanerManager: CleanerManager? = nil,
        uninstallManager: UninstallManager? = nil,
        optimizerManager: OptimizerManager? = nil
    ) {
        self.capabilityRegistry = capabilityRegistry
        self.eventBus = eventBus
        self.debounceInterval = debounceInterval
        self.alwaysOnManager = alwaysOnManager ?? AlwaysOnManager()
        self.updateManager = updateManager ?? UpdateManager()
        self.cleanerManager = cleanerManager ?? CleanerManager()
        self.uninstallManager = uninstallManager ?? UninstallManager()
        self.optimizerManager = optimizerManager ?? OptimizerManager()

        // Initialize default permissions in fail-closed state
        for perm in MaczyPermission.allCases {
            self.permissions[perm] = .notDetermined
        }

        // Initialize all 7 modules
        self.modules = MaczyModuleId.allCases.map { id in
            let cap = capabilityRegistry.capability(for: id) ?? ModuleCapability.defaultFor(moduleId: id)
            let isSupported = cap.isSupported
            let runtime: ModuleRuntimeState = isSupported ? .idle : .blocked
            let msg = isSupported ? "Ready for operation" : (cap.reason ?? "Capability blocked")

            return ModuleStatus(
                id: id,
                isImplemented: isSupported,
                runtimeState: runtime,
                statusMessage: msg,
                capability: cap
            )
        }

        // Subscribe to event bus for surface synchronization
        self.eventBus.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleAppEvent(event)
            }
            .store(in: &cancellables)

        // Bind live battery telemetry monitor
        self.batterySnapshot = BatteryMonitor.shared.currentSnapshot
        BatteryMonitor.shared.$currentSnapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newSnapshot in
                guard let self = self else { return }
                self.batterySnapshot = newSnapshot
                self.alwaysOnManager.checkBatterySafety(
                    percentage: Double(newSnapshot.stateOfCharge),
                    isCharging: newSnapshot.isACConnected || newSnapshot.isCharging
                )
            }
            .store(in: &cancellables)

        // Bind Always On session state to module runtime
        self.alwaysOnManager.$activeSession
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                guard let self = self else { return }
                if let session = session {
                    let msg = session.durationSeconds.map { "Awake (\($0 / 60)m)" } ?? "Awake (Indefinite)"
                    self.transitionRuntime(moduleId: .alwaysOn, to: .running, message: msg)
                } else {
                    let msg = self.alwaysOnManager.lastReleaseReason?.message ?? "Awake session idle"
                    self.transitionRuntime(moduleId: .alwaysOn, to: .idle, message: msg)
                }
            }
            .store(in: &cancellables)
    }

    public func status(for id: MaczyModuleId) -> ModuleStatus? {
        modules.first { $0.id == id }
    }

    public func setPermissionState(_ permission: MaczyPermission, state: PermissionState) {
        permissions[permission] = state
    }

    public func permissionState(_ permission: MaczyPermission) -> PermissionState {
        permissions[permission] ?? .notDetermined
    }

    /// Primary Action Pipeline:
    /// Action -> Capability Gate -> Permission Gate -> Command -> Result -> State Update
    @discardableResult
    public func dispatch(_ action: MaczyAction) -> CommandResult {
        let moduleId = action.targetModuleId

        // 0. Debounce / Idempotency Check
        let now = Date()
        let debounceKey = action.debounceKey
        if let lastTime = lastDispatchedActions[debounceKey], now.timeIntervalSince(lastTime) < debounceInterval {
            return CommandResult.failure(
                errorCode: "ACTION_DEBOUNCED",
                message: "Action ignored due to debounce threshold"
            )
        }
        lastDispatchedActions[debounceKey] = now

        // 1. Capability Gate
        guard let capability = capabilityRegistry.capability(for: moduleId), capability.isSupported else {
            let reason = capabilityRegistry.capability(for: moduleId)?.reason
                ?? "Module capability is not supported on this platform"
            eventBus.publish(.actionGated(
                moduleId: moduleId,
                gateType: "capability",
                reason: reason,
                errorCode: "CAPABILITY_UNSUPPORTED"
            ))
            return CommandResult.failure(
                errorCode: "CAPABILITY_UNSUPPORTED",
                message: reason
            )
        }

        // 2. Permission Gate
        for reqPerm in capability.requiredPermissions {
            let state = permissionState(reqPerm)
            guard state.isGranted else {
                let msg = "Operation requires \(reqPerm.displayName) permission (\(state.rawValue))"
                eventBus.publish(.actionGated(
                    moduleId: moduleId,
                    gateType: "permission",
                    reason: msg,
                    errorCode: "PERMISSION_REQUIRED"
                ))
                return CommandResult.failure(
                    errorCode: "PERMISSION_REQUIRED",
                    message: msg
                )
            }
        }

        // 3. Command Execution & State Transition
        let result: CommandResult
        switch action {
        case .captureScreenshot(let mode):
            transitionRuntime(moduleId: moduleId, to: .running, message: "Capturing screenshot (\(mode))...")
            CaptureCoordinator.shared.triggerCapture(mode: mode) { [weak self] captureResult in
                Task { @MainActor in
                    switch captureResult {
                    case .success(let item):
                        self?.transitionRuntime(moduleId: moduleId, to: .idle, message: "Captured \(Int(item.size.width))×\(Int(item.size.height))")
                    case .failure(let error):
                        self?.transitionRuntime(moduleId: moduleId, to: .idle, message: error.localizedDescription)
                    }
                }
            }
            result = CommandResult.success(message: "Screenshot captured in \(mode) mode")

        case .startScreenRecording(let target, let sysAudio, let mic):
            let msg = "Recording \(target) (audio: sys=\(sysAudio), mic=\(mic))"
            transitionRuntime(moduleId: moduleId, to: .running, message: msg)
            RecordingCoordinator.shared.startRecording(target: target, systemAudio: sysAudio, microphone: mic) { [weak self] res in
                Task { @MainActor in
                    switch res {
                    case .success(let url):
                        self?.transitionRuntime(moduleId: moduleId, to: .running, message: "Recording to \(url.lastPathComponent)")
                    case .failure(let err):
                        self?.transitionRuntime(moduleId: moduleId, to: .idle, message: err.localizedDescription)
                    }
                }
            }
            result = CommandResult.success(message: msg)

        case .stopScreenRecording:
            transitionRuntime(moduleId: moduleId, to: .idle, message: "Finalizing MP4...")
            RecordingCoordinator.shared.stopRecording { [weak self] res in
                Task { @MainActor in
                    switch res {
                    case .success(let url):
                        self?.transitionRuntime(moduleId: moduleId, to: .idle, message: "Saved: \(url.lastPathComponent)")
                    case .failure(let err):
                        self?.transitionRuntime(moduleId: moduleId, to: .idle, message: err.localizedDescription)
                    }
                }
            }
            result = CommandResult.success(message: "Recording stopped and saved")

        case .selectChargeLimit(let percentage):
            if [80, 85, 90, 95, 100].contains(percentage) {
                // Charge write controls are strictly gated by MZ-014 backend verification
                result = CommandResult.failure(
                    errorCode: "GATE_MZ_014",
                    message: "Setting charge limit requires MZ-014 backend verification. Write controls gated."
                )
            } else {
                result = CommandResult.failure(
                    errorCode: "INVALID_PERCENTAGE",
                    message: "Charge limit must be 80, 85, 90, 95, or 100%"
                )
            }

        case .refreshBatteryTelemetry:
            BatteryMonitor.shared.refresh()
            let soc = BatteryMonitor.shared.currentSnapshot.stateOfCharge
            let msg = BatteryMonitor.shared.currentSnapshot.isBatteryPresent
                ? "Battery telemetry updated: \(soc)%"
                : "Desktop Mac: AC Power active"
            transitionRuntime(moduleId: moduleId, to: .idle, message: msg)
            result = CommandResult.success(message: msg)

        case .toggleNotchExpanded:
            NotchCoordinator.shared.toggleExpansion()
            let isExpanded = NotchCoordinator.shared.expansionState == .expanded
            let next: ModuleRuntimeState = isExpanded ? .running : .idle
            let msg = isExpanded ? "Dynamic Notch expanded" : "Dynamic Notch collapsed"
            transitionRuntime(moduleId: moduleId, to: next, message: msg)
            result = CommandResult.success(message: msg)

        case let .setNotchDimensions(compactWidth, compactHeight, expandedWidth, expandedHeight):
            if let w = compactWidth { NotchCoordinator.shared.currentCompactWidth = CGFloat(w) }
            if let h = compactHeight { NotchCoordinator.shared.currentCompactHeight = CGFloat(h) }
            if let w = expandedWidth { NotchCoordinator.shared.currentExpandedWidth = CGFloat(w) }
            if let h = expandedHeight { NotchCoordinator.shared.currentExpandedHeight = CGFloat(h) }
            let msg = "Dynamic Notch dimensions updated"
            transitionRuntime(moduleId: moduleId, to: .running, message: msg)
            result = CommandResult.success(message: msg)

        case .resetNotchDimensions:
            NotchCoordinator.shared.resetDimensionsToDefault()
            let msg = "Dynamic Notch dimensions reset to defaults"
            transitionRuntime(moduleId: moduleId, to: .idle, message: msg)
            result = CommandResult.success(message: msg)

        case .snapActiveWindow(let preset):
            let snapResult = WindowSnapManager.shared.snapActiveWindow(to: preset)
            if snapResult.ok {
                transitionRuntime(moduleId: moduleId, to: .idle, message: "Window snapped to \(preset.rawValue)")
            }
            result = snapResult

        case .undoWindowSnap:
            let undoResult = WindowSnapManager.shared.undoLastSnap()
            if undoResult.ok {
                transitionRuntime(moduleId: moduleId, to: .idle, message: "Window snap undone")
            }
            result = undoResult

        case .lockScreen:
            let lockResult = SystemLockManager.shared.lockScreen()
            if lockResult.ok {
                transitionRuntime(moduleId: moduleId, to: .idle, message: "System locked")
            }
            result = lockResult

        case .requestFaceUnlockEnrollment, .triggerSessionUnlock:
            // Strictly blocked by capability gate; unreachable if capability gate holds
            result = CommandResult.failure(
                errorCode: "GATE_MZ_023",
                message: "Smart Unlock is gated by MZ-023 feasibility review"
            )

        case .checkForUpdates:
            transitionRuntime(moduleId: moduleId, to: .running, message: "Checking for updates...")
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let newStatus = await self.updateManager.checkForUpdates()
                self.transitionRuntime(
                    moduleId: moduleId,
                    to: .idle,
                    message: newStatus.statusText
                )
            }
            result = CommandResult.success(message: "Update check initiated")

        case .startAwakeSession(let duration):
            let preset = AlwaysOnPreset(minutes: duration)
            let started = alwaysOnManager.startSession(preset: preset)
            if started {
                let msg = duration.map { "Awake session active for \($0) minutes" } ?? "Awake session active indefinitely"
                transitionRuntime(moduleId: moduleId, to: .running, message: msg)
                result = CommandResult.success(message: msg)
            } else {
                result = CommandResult.failure(errorCode: "IOPM_ASSERTION_FAILED", message: "Failed to create power assertion")
            }

        case .stopAwakeSession:
            alwaysOnManager.stopSession(reason: .manualStop)
            transitionRuntime(moduleId: moduleId, to: .idle, message: "Awake session ended")
            result = CommandResult.success(message: "Awake session stopped")

        case .startCleanerScan:
            cleanerManager.startScan()
            transitionRuntime(moduleId: moduleId, to: .running, message: "Safe scan in progress...")
            result = CommandResult.success(message: "Safe read-only scan started")

        case .cancelCleanerScan:
            cleanerManager.cancelScan()
            transitionRuntime(moduleId: moduleId, to: .idle, message: "Scan cancelled")
            result = CommandResult.success(message: "Scan cancelled")
        }

        // 4. Publish Event
        eventBus.publish(.commandExecuted(moduleId: moduleId, result: result))
        return result
    }

    private func transitionRuntime(
        moduleId: MaczyModuleId,
        to newRuntime: ModuleRuntimeState,
        message: String
    ) {
        if let idx = modules.firstIndex(where: { $0.id == moduleId }) {
            let previous = modules[idx].runtimeState
            modules[idx].runtimeState = newRuntime
            modules[idx].statusMessage = message

            eventBus.publish(.moduleRuntimeChanged(
                moduleId: moduleId,
                previous: previous,
                current: newRuntime
            ))
        }
    }

    private func handleAppEvent(_ event: AppEvent) {
        // Handle cross-surface updates and logging
    }
}
