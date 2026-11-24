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
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?

    /// Optional callback invoked when a click occurs outside the notch frame.
    public var onOutsideClick: (@MainActor () -> Void)?

    public init() {}

    deinit {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    /// Whether outside-click monitoring is currently active.
    public var isMonitoringOutsideClicks: Bool {
        return globalClickMonitor != nil || localClickMonitor != nil
    }

    /// Create or show the floating non-activating panel.
    public func setOverlayVisible(_ visible: Bool) {
        if visible {
            ensurePanelCreated()
            panel?.orderFrontRegardless()
        } else {
            stopOutsideClickMonitoring()
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

        if state == .expanded {
            startOutsideClickMonitoring()
        } else {
            stopOutsideClickMonitoring()
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    /// Smoothly animate panel width in compact mode (e.g. during HUD toast presentation).
    public func animateToCompactWidth(_ width: CGFloat, profile: NotchScreenProfile) {
        ensurePanelCreated()
        guard let panel = panel else { return }
        let baseRect = targetRect(for: .compact, profile: profile)
        let newX = baseRect.midX - (width / 2.0)
        let targetFrame = CGRect(x: newX, y: baseRect.minY, width: width, height: baseRect.height)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    /// Handle simulated or event-based outside click testing. Returns true if outside and collapsed.
    @discardableResult
    public func handleSimulatedClick(at screenPoint: NSPoint) -> Bool {
        guard let panel = panel else { return false }
        if !panel.frame.contains(screenPoint) {
            if let onOutsideClick = onOutsideClick {
                onOutsideClick()
            } else {
                NotchCoordinator.shared.setExpansionState(.compact)
            }
            return true
        }
        return false
    }

    private func startOutsideClickMonitoring() {
        stopOutsideClickMonitoring()

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let panel = self.panel else { return }
                let clickLocation = NSEvent.mouseLocation
                if !panel.frame.contains(clickLocation) {
                    if let onOutsideClick = self.onOutsideClick {
                        onOutsideClick()
                    } else {
                        NotchCoordinator.shared.setExpansionState(.compact)
                    }
                }
            }
        }

        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.panel else { return event }
            let clickLocation = NSEvent.mouseLocation
            if !panel.frame.contains(clickLocation) {
                if let onOutsideClick = self.onOutsideClick {
                    onOutsideClick()
                } else {
                    NotchCoordinator.shared.setExpansionState(.compact)
                }
            }
            return event
        }
    }

    private func stopOutsideClickMonitoring() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
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
