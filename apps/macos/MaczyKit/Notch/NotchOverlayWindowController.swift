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
            context.duration = 0.30
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    /// Target frame when a notification, volume, or brightness HUD is actively presenting.
    public func notificationRect(for profile: NotchScreenProfile) -> CGRect {
        let targetWidth: CGFloat = profile.hasPhysicalNotch ? max(profile.notchRect.width + 90.0, 350.0) : 350.0
        let targetHeight: CGFloat = profile.hasPhysicalNotch ? (profile.notchRect.height + 46.0) : 64.0
        let x = profile.notchRect.midX - (targetWidth / 2.0)
        let y = profile.screenFrame.maxY - targetHeight - (profile.isVirtualIsland ? NotchGeometry.defaultVirtualTopPadding : 0)
        return CGRect(x: x, y: y, width: targetWidth, height: targetHeight)
    }

    /// Target frame for regular compact state.
    public func compactRect(for profile: NotchScreenProfile, isAudioActive: Bool = false) -> CGRect {
        if isAudioActive {
            return audioCompactRect(for: profile)
        }
        return profile.notchRect
    }

    /// Target frame for active audio playback compact state with extended wings.
    public func audioCompactRect(for profile: NotchScreenProfile) -> CGRect {
        let targetWidth: CGFloat = profile.hasPhysicalNotch ? max(profile.notchRect.width + 124.0, 344.0) : 280.0
        let targetHeight: CGFloat = profile.notchRect.height
        let x = profile.notchRect.midX - (targetWidth / 2.0)
        let y = profile.screenFrame.maxY - targetHeight - (profile.isVirtualIsland ? NotchGeometry.defaultVirtualTopPadding : 0)
        return CGRect(x: x, y: y, width: targetWidth, height: targetHeight)
    }

    /// Smoothly animate panel into audio playback compact size (wings on both sides).
    public func animateToAudioCompactSize(profile: NotchScreenProfile) {
        ensurePanelCreated()
        guard let panel = panel else { return }
        stopOutsideClickMonitoring()
        let targetFrame = audioCompactRect(for: profile)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.30
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    /// Smoothly animate panel into enlarged notification banner size.
    public func animateToNotificationSize(profile: NotchScreenProfile) {
        ensurePanelCreated()
        guard let panel = panel else { return }
        stopOutsideClickMonitoring()
        let targetFrame = notificationRect(for: profile)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.30
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    /// Smoothly animate panel back to normal compact size.
    public func animateToCompactSize(profile: NotchScreenProfile, completion: (@MainActor () -> Void)? = nil) {
        ensurePanelCreated()
        guard let panel = panel else {
            completion?()
            return
        }
        stopOutsideClickMonitoring()
        let targetFrame = compactRect(for: profile)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(targetFrame, display: true)
        }, completionHandler: {
            Task { @MainActor in
                completion?()
            }
        })
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

    /// Calculates the expanded frame dynamically sizing to accommodate active cards with full rounded bounds.
    @MainActor
    public func expandedRect(for profile: NotchScreenProfile, isMediaActive: Bool? = nil) -> CGRect {
        let activeMedia = isMediaActive ?? MediaHUDCoordinator.shared.isMediaActive
        var targetHeight: CGFloat = max(profile.expandedSize.height, 195.0)
        if activeMedia {
            targetHeight += 82.0
        }
        if TWSNotchCoordinator.shared.activeConnectionToast != nil {
            targetHeight += 70.0
        }
        let activeLiveCards = LiveActivityCoordinator.shared.activities.filter {
            if case .screenRecording = $0.type { return false }
            return true
        }
        if !activeLiveCards.isEmpty {
            targetHeight += CGFloat(activeLiveCards.count) * 44.0
        }

        let targetWidth: CGFloat = max(profile.expandedSize.width, 480.0)
        let x = profile.notchRect.midX - (targetWidth / 2.0)
        let y = profile.screenFrame.maxY - targetHeight - (profile.isVirtualIsland ? NotchGeometry.defaultVirtualTopPadding : 0)
        return CGRect(x: x, y: y, width: targetWidth, height: targetHeight)
    }

    private func targetRect(for state: NotchExpansionState, profile: NotchScreenProfile) -> CGRect {
        switch state {
        case .compact:
            let isAudio = MediaHUDCoordinator.shared.isAudioActive
            return compactRect(for: profile, isAudioActive: isAudio)
        case .expanded:
            return expandedRect(for: profile)
        }
    }

    /// Checks whether the mouse location is currently over the panel frame.
    public func isMouseOverPanel() -> Bool {
        guard let panel = panel, panel.isVisible else { return false }
        let mouseLocation = NSEvent.mouseLocation
        let extended = panel.frame.insetBy(dx: -4, dy: -4)
        return extended.contains(mouseLocation)
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
        newPanel.acceptsMouseMovedEvents = true

        let container = NotchContainerView(coordinator: NotchCoordinator.shared)
        let hosting = NotchHostingView(rootView: container)
        newPanel.contentView = hosting

        self.hostingView = hosting
        self.panel = newPanel
    }
}

/// Custom AppKit hosting view that installs an NSTrackingArea to provide robust, glitch-free hover detection.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        Task { @MainActor in
            NotchCoordinator.shared.cancelScheduledCollapse()
            if NotchCoordinator.shared.expansionState != .expanded {
                NotchCoordinator.shared.setExpansionState(.expanded)
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        Task { @MainActor in
            NotchCoordinator.shared.scheduleCollapseIfMouseOutside()
        }
    }
}
