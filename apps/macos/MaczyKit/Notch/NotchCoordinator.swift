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

    public init(profile: NotchScreenProfile? = nil) {
        let initialProfile = profile ?? NotchGeometry.detectProfile()
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
        let newProfile = NotchGeometry.detectProfile(mode: displayMode)
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
