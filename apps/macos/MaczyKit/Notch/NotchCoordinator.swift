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

    // MARK: - Custom Dimensions (Persisted via UserDefaults)
    @Published public var customCompactWidth: CGFloat? {
        didSet {
            if let w = customCompactWidth {
                UserDefaults.standard.set(Double(w), forKey: "maczy.notch.customCompactWidth")
            } else {
                UserDefaults.standard.removeObject(forKey: "maczy.notch.customCompactWidth")
            }
            updateProfile()
        }
    }

    @Published public var customCompactHeight: CGFloat? {
        didSet {
            if let h = customCompactHeight {
                UserDefaults.standard.set(Double(h), forKey: "maczy.notch.customCompactHeight")
            } else {
                UserDefaults.standard.removeObject(forKey: "maczy.notch.customCompactHeight")
            }
            updateProfile()
        }
    }

    @Published public var customExpandedWidth: CGFloat? {
        didSet {
            if let w = customExpandedWidth {
                UserDefaults.standard.set(Double(w), forKey: "maczy.notch.customExpandedWidth")
            } else {
                UserDefaults.standard.removeObject(forKey: "maczy.notch.customExpandedWidth")
            }
            updateProfile()
        }
    }

    @Published public var customExpandedHeight: CGFloat? {
        didSet {
            if let h = customExpandedHeight {
                UserDefaults.standard.set(Double(h), forKey: "maczy.notch.customExpandedHeight")
            } else {
                UserDefaults.standard.removeObject(forKey: "maczy.notch.customExpandedHeight")
            }
            updateProfile()
        }
    }

    public var currentCompactWidth: CGFloat {
        get { customCompactWidth ?? activeProfile.compactSize.width }
        set { customCompactWidth = newValue }
    }

    public var currentCompactHeight: CGFloat {
        get { customCompactHeight ?? activeProfile.compactSize.height }
        set { customCompactHeight = newValue }
    }

    public var currentExpandedWidth: CGFloat {
        get { customExpandedWidth ?? activeProfile.expandedSize.width }
        set { customExpandedWidth = newValue }
    }

    public var currentExpandedHeight: CGFloat {
        get { customExpandedHeight ?? activeProfile.expandedSize.height }
        set { customExpandedHeight = newValue }
    }

    public var hasCustomDimensions: Bool {
        return customCompactWidth != nil || customCompactHeight != nil || customExpandedWidth != nil || customExpandedHeight != nil
    }

    public func resetDimensionsToDefault() {
        customCompactWidth = nil
        customCompactHeight = nil
        customExpandedWidth = nil
        customExpandedHeight = nil
        UserDefaults.standard.removeObject(forKey: "maczy.notch.customCompactWidth")
        UserDefaults.standard.removeObject(forKey: "maczy.notch.customCompactHeight")
        UserDefaults.standard.removeObject(forKey: "maczy.notch.customExpandedWidth")
        UserDefaults.standard.removeObject(forKey: "maczy.notch.customExpandedHeight")
        updateProfile()
    }

    public init(profile: NotchScreenProfile? = nil) {
        var initCompactW: CGFloat? = nil
        var initCompactH: CGFloat? = nil
        var initExpandedW: CGFloat? = nil
        var initExpandedH: CGFloat? = nil

        if UserDefaults.standard.object(forKey: "maczy.notch.customCompactWidth") != nil {
            initCompactW = CGFloat(UserDefaults.standard.double(forKey: "maczy.notch.customCompactWidth"))
        }
        if UserDefaults.standard.object(forKey: "maczy.notch.customCompactHeight") != nil {
            initCompactH = CGFloat(UserDefaults.standard.double(forKey: "maczy.notch.customCompactHeight"))
        }
        if UserDefaults.standard.object(forKey: "maczy.notch.customExpandedWidth") != nil {
            initExpandedW = CGFloat(UserDefaults.standard.double(forKey: "maczy.notch.customExpandedWidth"))
        }
        if UserDefaults.standard.object(forKey: "maczy.notch.customExpandedHeight") != nil {
            initExpandedH = CGFloat(UserDefaults.standard.double(forKey: "maczy.notch.customExpandedHeight"))
        }

        self.customCompactWidth = initCompactW
        self.customCompactHeight = initCompactH
        self.customExpandedWidth = initExpandedW
        self.customExpandedHeight = initExpandedH

        var customCompact: CGSize? = nil
        if let w = initCompactW, let h = initCompactH {
            customCompact = CGSize(width: w, height: h)
        } else if let w = initCompactW {
            customCompact = CGSize(width: w, height: 32)
        } else if let h = initCompactH {
            customCompact = CGSize(width: 350, height: h)
        }

        var customExpanded: CGSize? = nil
        if let w = initExpandedW, let h = initExpandedH {
            customExpanded = CGSize(width: w, height: h)
        } else if let w = initExpandedW {
            customExpanded = CGSize(width: w, height: 160)
        } else if let h = initExpandedH {
            customExpanded = CGSize(width: 420, height: h)
        }

        let initialProfile = profile ?? NotchGeometry.detectProfile(
            customCompactSize: customCompact,
            customExpandedSize: customExpanded
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
    }

    /// Refresh screen profile based on current active display and displayMode preference.
    public func updateProfile() {
        var customCompact: CGSize? = nil
        if let w = customCompactWidth, let h = customCompactHeight {
            customCompact = CGSize(width: w, height: h)
        } else if let w = customCompactWidth {
            customCompact = CGSize(width: w, height: activeProfile.compactSize.height)
        } else if let h = customCompactHeight {
            customCompact = CGSize(width: activeProfile.compactSize.width, height: h)
        }

        var customExpanded: CGSize? = nil
        if let w = customExpandedWidth, let h = customExpandedHeight {
            customExpanded = CGSize(width: w, height: h)
        } else if let w = customExpandedWidth {
            customExpanded = CGSize(width: w, height: activeProfile.expandedSize.height)
        } else if let h = customExpandedHeight {
            customExpanded = CGSize(width: activeProfile.expandedSize.width, height: h)
        }

        let newProfile = NotchGeometry.detectProfile(
            mode: displayMode,
            customCompactSize: customCompact,
            customExpandedSize: customExpanded
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
        windowController.animateToState(state, profile: activeProfile)
    }

    /// Show or hide the physical/virtual notch overlay panel.
    public func toggleOverlay() {
        isOverlayVisible.toggle()
    }
}
