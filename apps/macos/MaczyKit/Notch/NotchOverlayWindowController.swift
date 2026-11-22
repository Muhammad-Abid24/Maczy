import AppKit
import SwiftUI

/// Specialized NSPanel subclass for the Dynamic Notch overlay.
/// Prevents AppKit's default constrainFrameRect from pushing the notch panel down below the menu bar.
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool {
        return false
    }

    override var canBecomeMain: Bool {
        return false
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        // Return unconstrained frame so the overlay sits flush at the physical screen top / notch cutout
        return frameRect
    }
}

/// Window controller hosting the Dynamic Notch overlay panel at the top of the display.
@MainActor
public final class NotchOverlayWindowController {
    private var panel: NotchPanel?
    private var hostingView: NSHostingView<NotchContainerView>?

    public init() {}

    /// Create or show the floating non-activating panel.
    public func setOverlayVisible(_ visible: Bool) {
        if visible {
            ensurePanelCreated()
            panel?.orderFrontRegardless()
        } else {
            panel?.orderOut(nil)
        }
    }

    /// Update panel frame for new screen profile.
    public func updateProfile(_ profile: NotchScreenProfile, expansionState: NotchExpansionState) {
        guard let panel = panel else { return }
        let targetFrame = targetRect(for: expansionState, profile: profile)
        panel.setFrame(targetFrame, display: true, animate: false)
    }

    /// Smoothly animate panel frame during compact <-> expanded state transitions.
    public func animateToState(_ state: NotchExpansionState, profile: NotchScreenProfile) {
        ensurePanelCreated()
        guard let panel = panel else { return }
        let targetFrame = targetRect(for: state, profile: profile)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    private func targetRect(for state: NotchExpansionState, profile: NotchScreenProfile) -> CGRect {
        switch state {
        case .compact:
            return profile.notchRect
        case .expanded:
            return NotchGeometry.calculateExpandedRect(
                anchorRect: profile.notchRect,
                expandedSize: profile.expandedSize,
                isPhysicalNotch: profile.hasPhysicalNotch
            )
        }
    }

    private func ensurePanelCreated() {
        guard panel == nil else { return }

        let initialProfile = NotchCoordinator.shared.activeProfile
        let frame = initialProfile.notchRect

        let newPanel = NotchPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false
        newPanel.level = .statusBar
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        newPanel.ignoresMouseEvents = false

        let container = NotchContainerView(coordinator: NotchCoordinator.shared)
        let hosting = NSHostingView(rootView: container)
        newPanel.contentView = hosting

        self.hostingView = hosting
        self.panel = newPanel
    }
}
