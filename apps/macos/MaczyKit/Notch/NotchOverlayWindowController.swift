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
    private var hostingView: NotchHostingView<NotchContainerView>?
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

    /// Maximum canvas frame housing the Dynamic Notch, sized to fit the largest expanded state without resizing the NSPanel.
    public func canvasRect(for profile: NotchScreenProfile) -> CGRect {
        let maxWidth: CGFloat = max(profile.expandedSize.width, 520.0)
        let maxHeight: CGFloat = max(profile.expandedSize.height, 360.0)
        let x = profile.notchRect.midX - (maxWidth / 2.0)
        let y = profile.screenFrame.maxY - maxHeight - (profile.isVirtualIsland ? NotchGeometry.defaultVirtualTopPadding : 0)
        return CGRect(x: x, y: y, width: maxWidth, height: maxHeight)
    }

    /// Update panel frame for new screen profile.
    public func updateProfile(_ profile: NotchScreenProfile, expansionState: NotchExpansionState) {
        guard let panel = panel else { return }
        let targetFrame = canvasRect(for: profile)
        panel.setFrame(targetFrame, display: true, animate: false)
    }

    /// Ensure the floating panel is sized to the maximum transparent canvas frame.
    public func ensureCanvasSize(for profile: NotchScreenProfile) {
        guard let panel = panel else { return }
        let targetFrame = canvasRect(for: profile)
        if panel.frame != targetFrame {
            panel.setFrame(targetFrame, display: true, animate: false)
        }
    }

    /// Smoothly update state without triggering legacy 30 FPS NSWindow resize.
    /// Hardware GPU CoreAnimation inside SwiftUI renders the expansion at native display FPS (120Hz ProMotion).
    public func animateToState(_ state: NotchExpansionState, profile: NotchScreenProfile) {
        ensurePanelCreated()
        guard panel != nil else { return }

        if state == .expanded {
            startOutsideClickMonitoring()
        } else {
            stopOutsideClickMonitoring()
        }

        ensureCanvasSize(for: profile)
        // Refresh tracking rect to match the new state's visible notch area
        hostingView?.refreshTrackingAreas()
    }

    /// Target frame when a notification, volume, or brightness HUD is actively presenting.
    public func notificationRect(for profile: NotchScreenProfile) -> CGRect {
        let isAppNotification = LiveActivityCoordinator.shared.primaryActivity != nil
        let targetWidth: CGFloat
        let targetHeight: CGFloat

        if isAppNotification {
            targetWidth = profile.hasPhysicalNotch ? max(profile.notchRect.width + 200.0, 440.0) : 440.0
            targetHeight = profile.hasPhysicalNotch ? (profile.notchRect.height + 84.0) : 96.0
        } else {
            targetWidth = profile.hasPhysicalNotch ? max(profile.notchRect.width + 90.0, 350.0) : 350.0
            targetHeight = profile.hasPhysicalNotch ? (profile.notchRect.height + 46.0) : 64.0
        }

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

    /// Adapts canvas for audio playback compact size; SwiftUI GPU spring handles 120 FPS wing expansion.
    public func animateToAudioCompactSize(profile: NotchScreenProfile) {
        ensurePanelCreated()
        stopOutsideClickMonitoring()
        ensureCanvasSize(for: profile)
        hostingView?.refreshTrackingAreas()
    }

    /// Adapts canvas for enlarged notification banner size; SwiftUI GPU spring handles 120 FPS expansion.
    public func animateToNotificationSize(profile: NotchScreenProfile) {
        ensurePanelCreated()
        stopOutsideClickMonitoring()
        ensureCanvasSize(for: profile)
        hostingView?.refreshTrackingAreas()
    }

    /// Adapts canvas for normal compact size; SwiftUI GPU spring handles 120 FPS collapse.
    public func animateToCompactSize(profile: NotchScreenProfile, completion: (@MainActor () -> Void)? = nil) {
        ensurePanelCreated()
        stopOutsideClickMonitoring()
        ensureCanvasSize(for: profile)
        hostingView?.refreshTrackingAreas()
        completion?()
    }

    /// Adapts canvas for compact width changes.
    public func animateToCompactWidth(_ width: CGFloat, profile: NotchScreenProfile) {
        ensurePanelCreated()
        ensureCanvasSize(for: profile)
        hostingView?.refreshTrackingAreas()
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
                guard let self = self, self.panel != nil else { return }
                if !self.isMouseOverPanel() {
                    if let onOutsideClick = self.onOutsideClick {
                        onOutsideClick()
                    } else {
                        NotchCoordinator.shared.setExpansionState(.compact)
                    }
                }
            }
        }

        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.panel != nil else { return event }
            if !self.isMouseOverPanel() {
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

    /// Checks whether the mouse location is currently over the active visual notch shape.
    /// Compact state strictly checks the physical notch silhouette (profile.notchRect) so that
    /// hover only triggers when the cursor is actually over the hardware notch cutout, not the
    /// transparent canvas padding around it.
    public func isMouseOverPanel() -> Bool {
        guard let panel = panel, panel.isVisible else { return false }
        let mouseLocation = NSEvent.mouseLocation
        let profile = NotchCoordinator.shared.activeProfile
        let coordinator = NotchCoordinator.shared
        let isExpanded = (coordinator.expansionState == .expanded)

        let hoverRect: CGRect
        if isExpanded {
            let w = coordinator.activeExpandedWidth
            let h = coordinator.activeExpandedHeight
            let x = profile.notchRect.midX - (w / 2.0)
            let y = profile.screenFrame.maxY - h - (profile.isVirtualIsland ? NotchGeometry.defaultVirtualTopPadding : 0)
            hoverRect = CGRect(x: x, y: y, width: w, height: h)
        } else if coordinator.isNotificationActive {
            let w = coordinator.activeNotificationWidth
            let h = coordinator.activeNotificationHeight
            let x = profile.notchRect.midX - (w / 2.0)
            let y = profile.screenFrame.maxY - h - (profile.isVirtualIsland ? NotchGeometry.defaultVirtualTopPadding : 0)
            hoverRect = CGRect(x: x, y: y, width: w, height: h)
        } else if MediaHUDCoordinator.shared.isAudioActive {
            // Audio compact wings — wider than bare notch
            let w = coordinator.activeAudioCompactWidth
            let h = coordinator.activeCompactHeight
            let x = profile.notchRect.midX - (w / 2.0)
            let y = profile.screenFrame.maxY - h - (profile.isVirtualIsland ? NotchGeometry.defaultVirtualTopPadding : 0)
            hoverRect = CGRect(x: x, y: y, width: w, height: h)
        } else {
            // Compact idle: strictly the physical notch silhouette — no extra canvas padding
            hoverRect = profile.notchRect
        }

        return hoverRect.insetBy(dx: -4, dy: -4).contains(mouseLocation)
    }

    private func ensurePanelCreated() {
        guard panel == nil else { return }

        let initialProfile = NotchCoordinator.shared.activeProfile
        let frame = canvasRect(for: initialProfile)

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

/// Custom AppKit hosting view that handles hit-testing and hover detection directly on the active visual notch area.
/// Unused canvas space outside the active notch returns nil from hitTest, passing clicks straight through to windows behind.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    private var trackingArea: NSTrackingArea?

    /// Explicitly rebuild tracking areas now. Called by the window controller after each state transition
    /// (compact ↔ expanded ↔ audio ↔ notification) so the tracking rect stays in sync with the
    /// currently-visible notch shape rather than the full transparent canvas.
    func refreshTrackingAreas() {
        updateTrackingAreas()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let coordinator = NotchCoordinator.shared
        let isExpanded = (coordinator.expansionState == .expanded)

        let visualWidth: CGFloat
        let visualHeight: CGFloat

        if isExpanded {
            visualWidth = coordinator.activeExpandedWidth
            visualHeight = coordinator.activeExpandedHeight
        } else if coordinator.isNotificationActive {
            visualWidth = coordinator.activeNotificationWidth
            visualHeight = coordinator.activeNotificationHeight
        } else if MediaHUDCoordinator.shared.isAudioActive {
            visualWidth = coordinator.activeAudioCompactWidth
            visualHeight = coordinator.activeCompactHeight
        } else {
            visualWidth = coordinator.currentCompactWidth
            visualHeight = coordinator.activeCompactHeight
        }

        let winBounds = self.bounds
        let visualX = (winBounds.width - visualWidth) / 2.0
        let visualY: CGFloat = 0 // In NSHostingView, isFlipped == true, so the notch sits flush at y = 0
        let activeRect = CGRect(x: visualX, y: visualY, width: visualWidth, height: visualHeight)

        let interactiveRect = activeRect.insetBy(dx: -4, dy: -4)
        if interactiveRect.contains(point) {
            return super.hitTest(point)
        }

        // If expanded and user clicked outside the active card, collapse!
        if isExpanded && NSApp.currentEvent?.type == .leftMouseDown {
            Task { @MainActor in
                coordinator.setExpansionState(.compact)
            }
        }

        return nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        // Build a tight tracking rect that matches the currently-visible notch shape.
        // Using the full `bounds` (520×360 canvas) would fire mouseEntered for ANY cursor
        // entry into the transparent overlay area — causing hover-expand even when the
        // cursor is far from the physical notch cutout.
        let coordinator = NotchCoordinator.shared
        let isExpanded = (coordinator.expansionState == .expanded)
        let isNotification = coordinator.isNotificationActive

        let trackW: CGFloat
        let trackH: CGFloat

        if isExpanded {
            trackW = coordinator.activeExpandedWidth
            trackH = coordinator.activeExpandedHeight
        } else if isNotification {
            trackW = coordinator.activeNotificationWidth
            trackH = coordinator.activeNotificationHeight
        } else if MediaHUDCoordinator.shared.isAudioActive {
            // Audio compact with wings
            trackW = coordinator.activeAudioCompactWidth
            trackH = coordinator.activeCompactHeight
        } else {
            // Compact idle — physical notch silhouette only
            trackW = coordinator.currentCompactWidth
            trackH = coordinator.activeCompactHeight
        }

        // The view is flipped (y=0 at top). Notch sits flush at the top-centre.
        let viewBounds = self.bounds
        let trackX = (viewBounds.width - trackW) / 2.0
        let trackRect = CGRect(x: trackX, y: 0, width: trackW, height: trackH)

        let area = NSTrackingArea(
            rect: trackRect,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        Task { @MainActor in
            let coordinator = NotchCoordinator.shared
            if coordinator.isMouseOverNotchPanel() {
                coordinator.cancelScheduledCollapse()
                if coordinator.expansionState != .expanded {
                    coordinator.setExpansionState(.expanded)
                }
            }
        }
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        Task { @MainActor in
            let coordinator = NotchCoordinator.shared
            if coordinator.isMouseOverNotchPanel() {
                coordinator.cancelScheduledCollapse()
                if coordinator.expansionState != .expanded {
                    coordinator.setExpansionState(.expanded)
                }
            } else if coordinator.expansionState == .expanded {
                coordinator.scheduleCollapseIfMouseOutside(delay: 0.25)
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        Task { @MainActor in
            NotchCoordinator.shared.scheduleCollapseIfMouseOutside(delay: 0.15)
        }
    }
}
