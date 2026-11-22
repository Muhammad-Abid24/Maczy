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
    public let chargeLimitManager: ChargeLimitManager

    @Published public var permissions: [MaczyPermission: PermissionState] = [:]
    @Published public var lastCapturedImage: CGImage?
    @Published public var lastRecordedVideoURL: URL?
    @Published public var lastRecordedVideoThumbnail: CGImage?
    private var explicitlySetPermissions: Set<MaczyPermission> = []
    private var lastDispatchedActions: [String: Date] = [:]
    public var debounceInterval: TimeInterval
    private var cancellables = Set<AnyCancellable>()

    /// Whether code is currently executing inside an XCTest runner environment.
    public var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil ||
        NSClassFromString("XCTestCase") != nil
    }

    public init(
        capabilityRegistry: CapabilityRegistry = CapabilityRegistry(),
        eventBus: EventBus = .shared,
        debounceInterval: TimeInterval = 0.2,
        alwaysOnManager: AlwaysOnManager? = nil,
        updateManager: UpdateManager? = nil,
        cleanerManager: CleanerManager? = nil,
        uninstallManager: UninstallManager? = nil,
        optimizerManager: OptimizerManager? = nil,
        chargeLimitManager: ChargeLimitManager? = nil,
        autoRefreshPermissions: Bool = false
    ) {
        self.capabilityRegistry = capabilityRegistry
        self.eventBus = eventBus
        self.debounceInterval = debounceInterval
        self.alwaysOnManager = alwaysOnManager ?? AlwaysOnManager()
        self.updateManager = updateManager ?? UpdateManager()
        self.cleanerManager = cleanerManager ?? CleanerManager()
        self.uninstallManager = uninstallManager ?? UninstallManager()
        self.optimizerManager = optimizerManager ?? OptimizerManager()
        self.chargeLimitManager = chargeLimitManager ?? ChargeLimitManager()

        // Initialize default permissions in fail-closed state
        for perm in MaczyPermission.allCases {
            self.permissions[perm] = .notDetermined
        }

        if autoRefreshPermissions || !isRunningTests {
            refreshPermissions()
        }

        // Live refresh permissions when application becomes active (e.g. returning from System Settings)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPermissions()
            }
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
                self.chargeLimitManager.refreshReadback()
                if self.chargeLimitManager.isDischargingToCeiling {
                    if let eff = self.chargeLimitManager.effectiveLimit, newSnapshot.stateOfCharge <= eff {
                        _ = self.chargeLimitManager.stopDischargeToCeiling()
                    }
                }
                self.alwaysOnManager.checkBatterySafety(
                    percentage: Double(newSnapshot.stateOfCharge),
                    isCharging: newSnapshot.isACConnected || newSnapshot.isCharging
                )
            }
            .store(in: &cancellables)

        if !isRunningTests {
            BatteryMonitor.shared.startMonitoring()
        }

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
        explicitlySetPermissions.insert(permission)
        permissions[permission] = state
    }

    /// User confirmation that permission has been toggled in System Settings
    public func markPermissionGranted(_ permission: MaczyPermission) {
        setPermissionState(permission, state: .granted)
    }

    public func permissionState(_ permission: MaczyPermission) -> PermissionState {
        permissions[permission] ?? .notDetermined
    }

    /// Queries system TCC status via PermissionManager and updates published permission states.
    public func refreshPermissions() {
        for perm in MaczyPermission.allCases {
            guard !explicitlySetPermissions.contains(perm) else { continue }
            let status = PermissionManager.shared.checkStatus(for: perm)
            permissions[perm] = status
        }
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
            // In live app execution, live-check system TCC state to ensure real authorization
            if !isRunningTests && !explicitlySetPermissions.contains(reqPerm) {
                let liveStatus = PermissionManager.shared.checkStatus(for: reqPerm)
                permissions[reqPerm] = liveStatus
            }

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
                        self?.lastCapturedImage = item.image
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
                        self?.lastRecordedVideoURL = url
                        self?.lastRecordedVideoThumbnail = RecordingPreviewHUD.generateVideoThumbnail(for: url)
                        self?.transitionRuntime(moduleId: moduleId, to: .idle, message: "Saved: \(url.lastPathComponent)")
                    case .failure(let err):
                        self?.transitionRuntime(moduleId: moduleId, to: .idle, message: err.localizedDescription)
                    }
                }
            }
            result = CommandResult.success(message: "Recording stopped and saved")

        case .selectChargeLimit(let percentage):
            guard [80, 85, 90, 95, 100].contains(percentage) else {
                result = CommandResult.failure(
                    errorCode: "INVALID_PERCENTAGE",
                    message: "Charge limit must be 80, 85, 90, 95, or 100%"
                )
                break
            }

            let writeResult = chargeLimitManager.setChargeLimit(percentage)
            switch writeResult {
            case .success(let confirmedLimit):
                transitionRuntime(moduleId: moduleId, to: .running, message: "Charge ceiling set to \(confirmedLimit)% (readback verified)")
                result = CommandResult.success(message: "Charge ceiling set to \(confirmedLimit)%")
            case .failure(let error):
                let errorCode: String
                switch error {
                case .invalidPercentage: errorCode = "INVALID_PERCENTAGE"
                case .unsupportedHardware: errorCode = "UNSUPPORTED_HARDWARE"
                case .authorizationRequired: errorCode = "GATE_MZ_014"
                case .daemonUnavailable: errorCode = "DAEMON_UNAVAILABLE"
                case .writeFailed: errorCode = "WRITE_FAILED"
                }
                transitionRuntime(moduleId: moduleId, to: .idle, message: error.localizedDescription)
                result = CommandResult.failure(errorCode: errorCode, message: error.localizedDescription)
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

        case .executeCleanerPurge(let confirmed):
            let gateCheck = cleanerManager.requestCleanupExecution(isExplicitlyConfirmed: confirmed)
            if gateCheck.ok {
                transitionRuntime(moduleId: moduleId, to: .running, message: "Cleaning items to Trash...")
                Task { @MainActor [weak self] in
                    do {
                        let res = try await self?.cleanerManager.executeCleanup()
                        let msg = res?.message ?? "Cleanup completed"
                        self?.transitionRuntime(moduleId: moduleId, to: .idle, message: msg)
                    } catch {
                        self?.transitionRuntime(moduleId: moduleId, to: .idle, message: error.localizedDescription)
                    }
                }
                result = gateCheck
            } else {
                transitionRuntime(moduleId: moduleId, to: .idle, message: gateCheck.message ?? "Cleanup gated by MZ-029")
                result = gateCheck
            }
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
