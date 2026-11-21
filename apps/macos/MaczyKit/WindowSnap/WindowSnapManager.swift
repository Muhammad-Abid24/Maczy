import AppKit
import ApplicationServices
import Foundation

/// Window restore state representing previous window position and size for undo operations.
public struct WindowRestoreState: Sendable, Equatable {
    public let windowId: String
    public let previousFrame: CGRect
    public let timestamp: Date

    public init(windowId: String, previousFrame: CGRect, timestamp: Date = Date()) {
        self.windowId = windowId
        self.previousFrame = previousFrame
        self.timestamp = timestamp
    }
}

/// Native Window Snapping Manager operating via macOS Accessibility APIs (AXUIElement).
/// Conforms to MZ-019 requirements: snap presets, undo stack, and protection against modifying system windows.
@MainActor
public final class WindowSnapManager: ObservableObject {
    public static let shared = WindowSnapManager()

    /// Maximum number of undo states kept in memory.
    public static let maxUndoCapacity = 50

    /// Protected macOS bundle identifiers that must never be resized or moved.
    nonisolated public static let protectedBundleIdentifiers: Set<String> = [
        "com.apple.dock",
        "com.apple.WindowServer",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.Spotlight",
        "com.apple.screencaptureui",
        "com.apple.SystemUIServer",
        Bundle.main.bundleIdentifier ?? "com.maczy.app"
    ]

    /// Protected AX subroles that indicate dialogs, sheets, or non-resizable system elements.
    nonisolated public static let protectedSubroles: Set<String> = [
        kAXSystemDialogSubrole as String,
        kAXDialogSubrole as String,
        kAXUnknownSubrole as String,
        kAXFloatingWindowSubrole as String
    ]

    @Published public private(set) var undoStack: [WindowRestoreState] = []
    @Published public private(set) var lastSnappedPreset: WindowSnapPreset?

    public init() {}

    public var canUndo: Bool {
        !undoStack.isEmpty
    }

    /// Evaluates whether a given window is protected from snapping operations.
    nonisolated public static func isProtected(
        bundleIdentifier: String?,
        subrole: String?,
        isPositionSettable: Bool,
        isSizeSettable: Bool
    ) -> Bool {
        if let bid = bundleIdentifier, protectedBundleIdentifiers.contains(bid) {
            return true
        }
        if let subrole = subrole, protectedSubroles.contains(subrole) {
            return true
        }
        if !isPositionSettable || !isSizeSettable {
            return true
        }
        return false
    }

    /// Pushes a restore state to the undo history stack with bounded capacity.
    public func pushUndoState(_ state: WindowRestoreState) {
        undoStack.append(state)
        if undoStack.count > Self.maxUndoCapacity {
            undoStack.removeFirst(undoStack.count - Self.maxUndoCapacity)
        }
    }

    /// Clears all undo history.
    public func clearUndoHistory() {
        undoStack.removeAll()
    }

    /// Snaps the currently active (focused) frontmost window to a specified preset.
    @discardableResult
    public func snapActiveWindow(to preset: WindowSnapPreset, margin: CGFloat = 0) -> CommandResult {
        // 1. Accessibility Authorization Gate
        guard AXIsProcessTrusted() else {
            return CommandResult.failure(
                errorCode: "ACCESSIBILITY_UNAUTHORIZED",
                message: "Accessibility permissions required to control and snap application windows."
            )
        }

        // 2. Identify Frontmost Application
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return CommandResult.failure(
                errorCode: "NO_ACTIVE_APP",
                message: "Could not identify active frontmost application."
            )
        }

        let bundleId = frontApp.bundleIdentifier ?? ""
        if Self.protectedBundleIdentifiers.contains(bundleId) {
            return CommandResult.failure(
                errorCode: "PROTECTED_APP",
                message: "Cannot snap system application: \(bundleId)"
            )
        }

        // 3. Inspect Focused Window via AXUIElement
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        var focusedWindowValue: AnyObject?
        let copyStatus = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowValue)

        guard copyStatus == .success, let windowElement = focusedWindowValue as! AXUIElement? else {
            return CommandResult.failure(
                errorCode: "NO_FOCUSED_WINDOW",
                message: "No focused window found for \(frontApp.localizedName ?? "app")."
            )
        }

        // 4. Validate Window Permissions & Role
        var subroleValue: AnyObject?
        AXUIElementCopyAttributeValue(windowElement, kAXSubroleAttribute as CFString, &subroleValue)
        let subrole = subroleValue as? String

        var isPosSettable: DarwinBoolean = false
        var isSizeSettable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(windowElement, kAXPositionAttribute as CFString, &isPosSettable)
        AXUIElementIsAttributeSettable(windowElement, kAXSizeAttribute as CFString, &isSizeSettable)

        if Self.isProtected(
            bundleIdentifier: bundleId,
            subrole: subrole,
            isPositionSettable: isPosSettable.boolValue,
            isSizeSettable: isSizeSettable.boolValue
        ) {
            return CommandResult.failure(
                errorCode: "WINDOW_PROTECTED",
                message: "Window is protected or non-resizable."
            )
        }

        // 5. Read Current Window Frame (AX coordinates)
        guard let currentAXRect = readAXRect(from: windowElement) else {
            return CommandResult.failure(
                errorCode: "FRAME_READ_FAILED",
                message: "Failed to read existing window coordinates."
            )
        }

        // 6. Resolve Screen
        let primaryScreen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main ?? NSScreen.screens[0]
        let currentAppKitRect = WindowGeometryEngine.axToAppKit(
            rect: currentAXRect,
            primaryScreenHeight: primaryScreen.frame.height
        )

        let targetScreen = NSScreen.screens.first(where: { $0.frame.intersects(currentAppKitRect) }) ?? primaryScreen

        // 7. Calculate Target Rect
        let targetAppKitRect = WindowGeometryEngine.calculateTargetRect(
            for: preset,
            in: targetScreen.visibleFrame,
            margin: margin
        )

        let targetAXRect = WindowGeometryEngine.appKitToAX(
            rect: targetAppKitRect,
            primaryScreenHeight: primaryScreen.frame.height
        )

        // 8. Save Undo State
        let windowId = "\(frontApp.processIdentifier):\(windowTitle(for: windowElement))"
        pushUndoState(WindowRestoreState(windowId: windowId, previousFrame: currentAXRect))

        // 9. Apply New Position & Size
        applyAXRect(targetAXRect, to: windowElement)
        self.lastSnappedPreset = preset

        return CommandResult.success(
            message: "Snapped \(frontApp.localizedName ?? "window") to \(preset.rawValue)",
            observedValue: preset.rawValue
        )
    }

    /// Undoes the last window snap operation, restoring the previous frame.
    @discardableResult
    public func undoLastSnap() -> CommandResult {
        guard let state = undoStack.popLast() else {
            return CommandResult.failure(
                errorCode: "UNDO_STACK_EMPTY",
                message: "No window snap actions to undo."
            )
        }

        guard AXIsProcessTrusted() else {
            return CommandResult.failure(
                errorCode: "ACCESSIBILITY_UNAUTHORIZED",
                message: "Accessibility permissions required to restore window coordinates."
            )
        }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return CommandResult.failure(
                errorCode: "NO_ACTIVE_APP",
                message: "No active frontmost application to restore."
            )
        }

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        var focusedWindowValue: AnyObject?
        let copyStatus = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowValue)

        guard copyStatus == .success, let windowElement = focusedWindowValue as! AXUIElement? else {
            return CommandResult.failure(
                errorCode: "NO_FOCUSED_WINDOW",
                message: "No focused window to restore."
            )
        }

        applyAXRect(state.previousFrame, to: windowElement)
        self.lastSnappedPreset = nil

        return CommandResult.success(
            message: "Restored window to previous frame.",
            observedValue: "\(state.previousFrame)"
        )
    }

    // MARK: - Private Helpers

    private func readAXRect(from element: AXUIElement) -> CGRect? {
        var posValue: AnyObject?
        var sizeValue: AnyObject?

        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero

        guard let posVal = posValue as! AXValue?,
              let sizeVal = sizeValue as! AXValue?,
              AXValueGetValue(posVal, .cgPoint, &point),
              AXValueGetValue(sizeVal, .cgSize, &size) else {
            return nil
        }

        return CGRect(origin: point, size: size)
    }

    private func applyAXRect(_ rect: CGRect, to element: AXUIElement) {
        var point = rect.origin
        var size = rect.size

        if let posVal = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, posVal)
        }
        if let sizeVal = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeVal)
        }
    }

    private func windowTitle(for element: AXUIElement) -> String {
        var titleVal: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleVal) == .success,
           let title = titleVal as? String {
            return title
        }
        return "Untitled"
    }
}
