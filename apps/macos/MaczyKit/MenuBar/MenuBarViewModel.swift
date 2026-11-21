import Foundation
import SwiftUI

/// Actions and shortcuts exposed in the Maczy Menu Bar.
public struct MenuBarShortcut: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let keyEquivalent: String
    public let modifiers: String
    public let action: MaczyAction

    public init(id: String, title: String, keyEquivalent: String, modifiers: String, action: MaczyAction) {
        self.id = id
        self.title = title
        self.keyEquivalent = keyEquivalent
        self.modifiers = modifiers
        self.action = action
    }
}

/// Helper model managing Menu Bar interactions, shortcuts, and status summaries.
@MainActor
public final class MenuBarViewModel: ObservableObject {
    @Published public var lastActionResult: CommandResult?

    public static let standardShortcuts: [MenuBarShortcut] = [
        MenuBarShortcut(id: "cap_area", title: "Area Screenshot", keyEquivalent: "1", modifiers: "⌘⇧", action: .captureScreenshot(mode: "area")),
        MenuBarShortcut(id: "cap_window", title: "Window Screenshot", keyEquivalent: "2", modifiers: "⌘⇧", action: .captureScreenshot(mode: "window")),
        MenuBarShortcut(id: "cap_fullscreen", title: "Fullscreen Screenshot", keyEquivalent: "3", modifiers: "⌘⇧", action: .captureScreenshot(mode: "fullscreen")),
        MenuBarShortcut(id: "rec_toggle", title: "Record Screen", keyEquivalent: "R", modifiers: "⌘⇧", action: .startScreenRecording(target: "display", systemAudio: false, microphone: false)),
        MenuBarShortcut(id: "notch_toggle", title: "Toggle Notch", keyEquivalent: "N", modifiers: "⌘⇧", action: .toggleNotchExpanded),
        MenuBarShortcut(id: "clean_scan", title: "Safe Cleaner Scan", keyEquivalent: "C", modifiers: "⌘⇧", action: .startCleanerScan),
        MenuBarShortcut(id: "update_check", title: "Check for Updates", keyEquivalent: "U", modifiers: "⌘", action: .checkForUpdates)
    ]

    public init() {}

    public func executeAction(_ action: MaczyAction, on state: AppState) -> CommandResult {
        let result = state.dispatch(action)
        self.lastActionResult = result
        return result
    }
}
