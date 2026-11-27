import Foundation
import AppKit
import Combine

/// Main-actor coordinator governing Dynamic Notch expansion, screen updates, and overlay window.
@MainActor
public final class NotchCoordinator: ObservableObject {
    public static let shared = NotchCoordinator()

    @Published public private(set) var activeProfile: NotchScreenProfile
    @Published public var displayMode: NotchDisplayMode = .auto {
        didSet {
            updateProfile()
        }
    }
    @Published public private(set) var expansionState: NotchExpansionState = .compact
    @Published public var isOverlayVisible: Bool = false {
        didSet {
            windowController.setOverlayVisible(isOverlayVisible)
        }
    }

    public let windowController: NotchOverlayWindowController
    @Published public private(set) var isNotificationActive: Bool = false
    private var isTemporarilyVisibleForHUD: Bool = false
    private var notificationCancellable: AnyCancellable?
    private var mediaCancellable: AnyCancellable?

    // MARK: - Physical Notch Custom Dimensions (Persisted via UserDefaults)
    @Published public var customPhysicalCompactWidth: CGFloat? {
        didSet {
            persist(customPhysicalCompactWidth, key: "maczy.notch.physical.compactWidth")
            updateProfile()
        }
    }
    @Published public var customPhysicalCompactHeight: CGFloat? {
        didSet {
            persist(customPhysicalCompactHeight, key: "maczy.notch.physical.compactHeight")
            updateProfile()
        }
    }
    @Published public var customPhysicalExpandedWidth: CGFloat? {
        didSet {
            persist(customPhysicalExpandedWidth, key: "maczy.notch.physical.expandedWidth")
            updateProfile()
        }
    }
    @Published public var customPhysicalExpandedHeight: CGFloat? {
        didSet {
            persist(customPhysicalExpandedHeight, key: "maczy.notch.physical.expandedHeight")
            updateProfile()
        }
    }

    // MARK: - Virtual Island Custom Dimensions (Persisted via UserDefaults)
    @Published public var customVirtualCompactWidth: CGFloat? {
        didSet {
            persist(customVirtualCompactWidth, key: "maczy.notch.virtual.compactWidth")
            updateProfile()
        }
    }
    @Published public var customVirtualCompactHeight: CGFloat? {
        didSet {
            persist(customVirtualCompactHeight, key: "maczy.notch.virtual.compactHeight")
            updateProfile()
        }
    }
    @Published public var customVirtualExpandedWidth: CGFloat? {
        didSet {
            persist(customVirtualExpandedWidth, key: "maczy.notch.virtual.expandedWidth")
            updateProfile()
        }
    }
    @Published public var customVirtualExpandedHeight: CGFloat? {
        didSet {
            persist(customVirtualExpandedHeight, key: "maczy.notch.virtual.expandedHeight")
            updateProfile()
        }
    }

    // MARK: - Dimension Accessors

    public var physicalCompactWidth: CGFloat {
        get { customPhysicalCompactWidth ?? 220.0 }
        set { customPhysicalCompactWidth = newValue }
    }
    public var physicalCompactHeight: CGFloat {
        get { customPhysicalCompactHeight ?? 34.0 }
        set { customPhysicalCompactHeight = newValue }
    }
    public var physicalExpandedWidth: CGFloat {
        get { customPhysicalExpandedWidth ?? NotchGeometry.defaultPhysicalExpandedSize.width }
        set { customPhysicalExpandedWidth = newValue }
    }
    public var physicalExpandedHeight: CGFloat {
        get { customPhysicalExpandedHeight ?? NotchGeometry.defaultPhysicalExpandedSize.height }
        set { customPhysicalExpandedHeight = newValue }
    }

    public var virtualCompactWidth: CGFloat {
        get { customVirtualCompactWidth ?? NotchGeometry.defaultVirtualCompactSize.width }
        set { customVirtualCompactWidth = newValue }
    }
    public var virtualCompactHeight: CGFloat {
        get { customVirtualCompactHeight ?? NotchGeometry.defaultVirtualCompactSize.height }
        set { customVirtualCompactHeight = newValue }
    }
    public var virtualExpandedWidth: CGFloat {
        get { customVirtualExpandedWidth ?? NotchGeometry.defaultVirtualExpandedSize.width }
        set { customVirtualExpandedWidth = newValue }
    }
    public var virtualExpandedHeight: CGFloat {
        get { customVirtualExpandedHeight ?? NotchGeometry.defaultVirtualExpandedSize.height }
        set { customVirtualExpandedHeight = newValue }
    }

    public var isPhysicalActive: Bool {
        switch displayMode {
        case .alwaysPhysical:
            return true
        case .alwaysVirtual:
            return false
        case .auto:
            return activeProfile.hasPhysicalNotch
        }
    }

    // Active mode proxy getters/setters (maintains compatibility with existing callers/tests)
    public var currentCompactWidth: CGFloat {
        get { isPhysicalActive ? physicalCompactWidth : virtualCompactWidth }
        set {
            if isPhysicalActive {
                physicalCompactWidth = newValue
            } else {
                virtualCompactWidth = newValue
            }
        }
    }

    public var currentCompactHeight: CGFloat {
        get { isPhysicalActive ? physicalCompactHeight : virtualCompactHeight }
        set {
            if isPhysicalActive {
                physicalCompactHeight = newValue
            } else {
                virtualCompactHeight = newValue
            }
        }
    }

    public var currentExpandedWidth: CGFloat {
        get { isPhysicalActive ? physicalExpandedWidth : virtualExpandedWidth }
        set {
            if isPhysicalActive {
                physicalExpandedWidth = newValue
            } else {
                virtualExpandedWidth = newValue
            }
        }
    }

    public var currentExpandedHeight: CGFloat {
        get { isPhysicalActive ? physicalExpandedHeight : virtualExpandedHeight }
        set {
            if isPhysicalActive {
                physicalExpandedHeight = newValue
            } else {
                virtualExpandedHeight = newValue
            }
        }
    }

    public var hasCustomPhysicalDimensions: Bool {
        return customPhysicalCompactWidth != nil || customPhysicalCompactHeight != nil ||
               customPhysicalExpandedWidth != nil || customPhysicalExpandedHeight != nil
    }

    public var hasCustomVirtualDimensions: Bool {
        return customVirtualCompactWidth != nil || customVirtualCompactHeight != nil ||
               customVirtualExpandedWidth != nil || customVirtualExpandedHeight != nil
    }

    public var hasCustomDimensions: Bool {
        return hasCustomPhysicalDimensions || hasCustomVirtualDimensions
    }

    public func resetPhysicalDimensionsToDefault() {
        customPhysicalCompactWidth = nil
        customPhysicalCompactHeight = nil
        customPhysicalExpandedWidth = nil
        customPhysicalExpandedHeight = nil
        UserDefaults.standard.removeObject(forKey: "maczy.notch.physical.compactWidth")
        UserDefaults.standard.removeObject(forKey: "maczy.notch.physical.compactHeight")
        UserDefaults.standard.removeObject(forKey: "maczy.notch.physical.expandedWidth")
        UserDefaults.standard.removeObject(forKey: "maczy.notch.physical.expandedHeight")
        updateProfile()
    }

    public func resetVirtualDimensionsToDefault() {
        customVirtualCompactWidth = nil
        customVirtualCompactHeight = nil
        customVirtualExpandedWidth = nil
        customVirtualExpandedHeight = nil
        UserDefaults.standard.removeObject(forKey: "maczy.notch.virtual.compactWidth")
        UserDefaults.standard.removeObject(forKey: "maczy.notch.virtual.compactHeight")
        UserDefaults.standard.removeObject(forKey: "maczy.notch.virtual.expandedWidth")
        UserDefaults.standard.removeObject(forKey: "maczy.notch.virtual.expandedHeight")
        updateProfile()
    }

    public func resetDimensionsToDefault() {
        resetPhysicalDimensionsToDefault()
        resetVirtualDimensionsToDefault()
    }

    private func persist(_ val: CGFloat?, key: String) {
        if let v = val {
            UserDefaults.standard.set(Double(v), forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    public init(profile: NotchScreenProfile? = nil) {
        var physCompactW: CGFloat? = nil
        var physCompactH: CGFloat? = nil
        var physExpandedW: CGFloat? = nil
        var physExpandedH: CGFloat? = nil

        var virtCompactW: CGFloat? = nil
        var virtCompactH: CGFloat? = nil
        var virtExpandedW: CGFloat? = nil
        var virtExpandedH: CGFloat? = nil

        if UserDefaults.standard.object(forKey: "maczy.notch.physical.compactWidth") != nil {
            physCompactW = CGFloat(UserDefaults.standard.double(forKey: "maczy.notch.physical.compactWidth"))
        }
        if UserDefaults.standard.object(forKey: "maczy.notch.physical.compactHeight") != nil {
            physCompactH = CGFloat(UserDefaults.standard.double(forKey: "maczy.notch.physical.compactHeight"))
        }
        if UserDefaults.standard.object(forKey: "maczy.notch.physical.expandedWidth") != nil {
            physExpandedW = CGFloat(UserDefaults.standard.double(forKey: "maczy.notch.physical.expandedWidth"))
        }
        if UserDefaults.standard.object(forKey: "maczy.notch.physical.expandedHeight") != nil {
            physExpandedH = CGFloat(UserDefaults.standard.double(forKey: "maczy.notch.physical.expandedHeight"))
        }

        if UserDefaults.standard.object(forKey: "maczy.notch.virtual.compactWidth") != nil {
            virtCompactW = CGFloat(UserDefaults.standard.double(forKey: "maczy.notch.virtual.compactWidth"))
        }
        if UserDefaults.standard.object(forKey: "maczy.notch.virtual.compactHeight") != nil {
            virtCompactH = CGFloat(UserDefaults.standard.double(forKey: "maczy.notch.virtual.compactHeight"))
        }
        if UserDefaults.standard.object(forKey: "maczy.notch.virtual.expandedWidth") != nil {
            virtExpandedW = CGFloat(UserDefaults.standard.double(forKey: "maczy.notch.virtual.expandedWidth"))
        }
        if UserDefaults.standard.object(forKey: "maczy.notch.virtual.expandedHeight") != nil {
            virtExpandedH = CGFloat(UserDefaults.standard.double(forKey: "maczy.notch.virtual.expandedHeight"))
        }

        self.customPhysicalCompactWidth = physCompactW
        self.customPhysicalCompactHeight = physCompactH
        self.customPhysicalExpandedWidth = physExpandedW
        self.customPhysicalExpandedHeight = physExpandedH

        self.customVirtualCompactWidth = virtCompactW
        self.customVirtualCompactHeight = virtCompactH
        self.customVirtualExpandedWidth = virtExpandedW
        self.customVirtualExpandedHeight = virtExpandedH

        var physCompact: CGSize? = nil
        if let w = physCompactW, let h = physCompactH {
            physCompact = CGSize(width: w, height: h)
        } else if let w = physCompactW {
            physCompact = CGSize(width: w, height: 34)
        } else if let h = physCompactH {
            physCompact = CGSize(width: 220, height: h)
        }

        var physExpanded: CGSize? = nil
        if let w = physExpandedW, let h = physExpandedH {
            physExpanded = CGSize(width: w, height: h)
        } else if let w = physExpandedW {
            physExpanded = CGSize(width: w, height: NotchGeometry.defaultPhysicalExpandedSize.height)
        } else if let h = physExpandedH {
            physExpanded = CGSize(width: NotchGeometry.defaultPhysicalExpandedSize.width, height: h)
        }

        var virtCompact: CGSize? = nil
        if let w = virtCompactW, let h = virtCompactH {
            virtCompact = CGSize(width: w, height: h)
        } else if let w = virtCompactW {
            virtCompact = CGSize(width: w, height: NotchGeometry.defaultVirtualCompactSize.height)
        } else if let h = virtCompactH {
            virtCompact = CGSize(width: NotchGeometry.defaultVirtualCompactSize.width, height: h)
        }

        var virtExpanded: CGSize? = nil
        if let w = virtExpandedW, let h = virtExpandedH {
            virtExpanded = CGSize(width: w, height: h)
        } else if let w = virtExpandedW {
            virtExpanded = CGSize(width: w, height: NotchGeometry.defaultVirtualExpandedSize.height)
        } else if let h = virtExpandedH {
            virtExpanded = CGSize(width: NotchGeometry.defaultVirtualExpandedSize.width, height: h)
        }

        let initialProfile = profile ?? NotchGeometry.detectProfile(
            physicalCompactSize: physCompact,
            physicalExpandedSize: physExpanded,
            virtualCompactSize: virtCompact,
            virtualExpandedSize: virtExpanded
        )
        self.activeProfile = initialProfile
        let controller = NotchOverlayWindowController()
        self.windowController = controller
        controller.onOutsideClick = { [weak self] in
            self?.setExpansionState(.compact)
        }

        // Observe screen changes (e.g. plugging/unplugging external display)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateProfile()
            }
        }

        // Automatically present and expand overlay window when any notification or system HUD event occurs
        self.notificationCancellable = Publishers.CombineLatest3(
            SystemHUDCoordinator.shared.$activeHUD,
            LiveActivityCoordinator.shared.$primaryActivity,
            TWSNotchCoordinator.shared.$activeConnectionToast
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] hud, activity, tws in
            let hasNotification = (hud != nil || activity != nil || tws != nil)
            self?.handleNotificationStateChanged(hasNotification)
        }

        // Automatically adapt notch width when media or audio output is active
        self.mediaCancellable = MediaHUDCoordinator.shared.$isAudioActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAudioActive in
                self?.handleAudioActivityStateChanged(isAudioActive)
            }

        // Start system notification monitoring outside unit test runner
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil &&
           ProcessInfo.processInfo.environment["XCTestBundlePath"] == nil &&
           NSClassFromString("XCTestCase") == nil {
            SystemNotificationObserver.shared.startObserving()
        }
    }

    public func handleAudioActivityStateChanged(_ isAudioActive: Bool) {
        guard !isNotificationActive else { return }

        if isAudioActive {
            if !isOverlayVisible {
                isTemporarilyVisibleForHUD = true
                windowController.setOverlayVisible(true)
            }
            if expansionState == .compact {
                windowController.animateToAudioCompactSize(profile: activeProfile)
            } else if expansionState == .expanded {
                windowController.animateToState(.expanded, profile: activeProfile)
            }
        } else {
            if expansionState == .compact {
                windowController.animateToCompactSize(profile: activeProfile) { [weak self] in
                    guard let self = self else { return }
                    if self.isTemporarilyVisibleForHUD {
                        self.isTemporarilyVisibleForHUD = false
                        if !self.isOverlayVisible {
                            self.windowController.setOverlayVisible(false)
                        }
                    }
                }
            } else if expansionState == .expanded {
                windowController.animateToState(.expanded, profile: activeProfile)
            }
        }
    }

    public func handleNotificationStateChanged(_ hasNotification: Bool) {
        guard hasNotification != self.isNotificationActive else { return }
        self.isNotificationActive = hasNotification

        if hasNotification {
            if !isOverlayVisible {
                isTemporarilyVisibleForHUD = true
                windowController.setOverlayVisible(true)
            }
            if expansionState == .compact {
                windowController.animateToNotificationSize(profile: activeProfile)
            }
        } else {
            if expansionState == .compact {
                if MediaHUDCoordinator.shared.isAudioActive {
                    windowController.animateToAudioCompactSize(profile: activeProfile)
                } else {
                    windowController.animateToCompactSize(profile: activeProfile) { [weak self] in
                        guard let self = self else { return }
                        if self.isTemporarilyVisibleForHUD {
                            self.isTemporarilyVisibleForHUD = false
                            if !self.isOverlayVisible {
                                self.windowController.setOverlayVisible(false)
                            }
                        }
                    }
                }
            } else {
                if isTemporarilyVisibleForHUD {
                    isTemporarilyVisibleForHUD = false
                    if !isOverlayVisible {
                        windowController.setOverlayVisible(false)
                    }
                }
            }
        }
    }

    /// Refresh screen profile based on current active display and displayMode preference.
    public func updateProfile() {
        var physCompact: CGSize? = nil
        if let w = customPhysicalCompactWidth, let h = customPhysicalCompactHeight {
            physCompact = CGSize(width: w, height: h)
        } else if let w = customPhysicalCompactWidth {
            physCompact = CGSize(width: w, height: 34)
        } else if let h = customPhysicalCompactHeight {
            physCompact = CGSize(width: 220, height: h)
        }

        var physExpanded: CGSize? = nil
        if let w = customPhysicalExpandedWidth, let h = customPhysicalExpandedHeight {
            physExpanded = CGSize(width: w, height: h)
        } else if let w = customPhysicalExpandedWidth {
            physExpanded = CGSize(width: w, height: NotchGeometry.defaultPhysicalExpandedSize.height)
        } else if let h = customPhysicalExpandedHeight {
            physExpanded = CGSize(width: NotchGeometry.defaultPhysicalExpandedSize.width, height: h)
        }

        var virtCompact: CGSize? = nil
        if let w = customVirtualCompactWidth, let h = customVirtualCompactHeight {
            virtCompact = CGSize(width: w, height: h)
        } else if let w = customVirtualCompactWidth {
            virtCompact = CGSize(width: w, height: NotchGeometry.defaultVirtualCompactSize.height)
        } else if let h = customVirtualCompactHeight {
            virtCompact = CGSize(width: NotchGeometry.defaultVirtualCompactSize.width, height: h)
        }

        var virtExpanded: CGSize? = nil
        if let w = customVirtualExpandedWidth, let h = customVirtualExpandedHeight {
            virtExpanded = CGSize(width: w, height: h)
        } else if let w = customVirtualExpandedWidth {
            virtExpanded = CGSize(width: w, height: NotchGeometry.defaultVirtualExpandedSize.height)
        } else if let h = customVirtualExpandedHeight {
            virtExpanded = CGSize(width: NotchGeometry.defaultVirtualExpandedSize.width, height: h)
        }

        let newProfile = NotchGeometry.detectProfile(
            mode: displayMode,
            physicalCompactSize: physCompact,
            physicalExpandedSize: physExpanded,
            virtualCompactSize: virtCompact,
            virtualExpandedSize: virtExpanded
        )
        self.activeProfile = newProfile
        windowController.updateProfile(newProfile, expansionState: expansionState)
    }

    /// Toggle between compact silhouette and expanded interactive card.
    public func toggleExpansion() {
        let next: NotchExpansionState = (expansionState == .compact) ? .expanded : .compact
        setExpansionState(next)
    }

    /// Set explicit expansion state with animated window adjustment.
    public func setExpansionState(_ state: NotchExpansionState) {
        self.expansionState = state
        if state == .compact && isNotificationActive {
            windowController.animateToNotificationSize(profile: activeProfile)
        } else if state == .compact && MediaHUDCoordinator.shared.isAudioActive {
            windowController.animateToAudioCompactSize(profile: activeProfile)
        } else {
            windowController.animateToState(state, profile: activeProfile)
        }
    }

    /// Show or hide the physical/virtual notch overlay panel.
    public func toggleOverlay() {
        isOverlayVisible.toggle()
    }

    // MARK: - Hover Lifecycle & Smooth Debounced Collapse
    private var scheduledCollapseTask: Task<Void, Never>? = nil

    /// Cancels any scheduled collapse timeout when the cursor re-enters the notch.
    public func cancelScheduledCollapse() {
        scheduledCollapseTask?.cancel()
        scheduledCollapseTask = nil
    }

    /// Schedules a collapse after a graceful debounce, only collapsing if the cursor is truly outside the notch panel.
    public func scheduleCollapseIfMouseOutside(delay: TimeInterval = 0.25) {
        cancelScheduledCollapse()
        scheduledCollapseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self = self, !Task.isCancelled else { return }
            if !self.isMouseOverNotchPanel() {
                self.setExpansionState(.compact)
            }
        }
    }

    /// Returns whether the cursor is currently physically over the overlay panel.
    public func isMouseOverNotchPanel() -> Bool {
        return windowController.isMouseOverPanel()
    }

    // MARK: - Dynamic Canvas Dimensions for 120 FPS GPU Render Pipeline
    public var activeAudioCompactWidth: CGFloat {
        windowController.audioCompactRect(for: activeProfile).width
    }
    public var activeCompactHeight: CGFloat {
        activeProfile.notchRect.height
    }
    public var activeNotificationWidth: CGFloat {
        windowController.notificationRect(for: activeProfile).width
    }
    public var activeNotificationHeight: CGFloat {
        windowController.notificationRect(for: activeProfile).height
    }
    public var activeExpandedWidth: CGFloat {
        windowController.expandedRect(for: activeProfile).width
    }
    public var activeExpandedHeight: CGFloat {
        windowController.expandedRect(for: activeProfile).height
    }
}
