import Foundation
import CoreGraphics
import AppKit
import ScreenCaptureKit

/// Target definition for a screen capture operation.
public enum CaptureTarget: Sendable, Equatable {
    case fullscreen(displayID: CGDirectDisplayID?)
    case window(windowID: CGWindowID)
    case area(rect: CGRect, displayID: CGDirectDisplayID?)
    case scrolling

    public var modeName: String {
        switch self {
        case .fullscreen: return "fullscreen"
        case .window: return "window"
        case .area: return "area"
        case .scrolling: return "scrolling"
        }
    }
}

/// Result of a successful capture operation.
public struct CapturedImageItem: Sendable {
    public let image: CGImage
    public let size: CGSize
    public let timestamp: Date
    public let target: CaptureTarget

    public init(image: CGImage, target: CaptureTarget, timestamp: Date = Date()) {
        self.image = image
        self.size = CGSize(width: image.width, height: image.height)
        self.timestamp = timestamp
        self.target = target
    }

    public var nsImage: NSImage {
        NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}

/// Errors occurring during ScreenCaptureKit operations.
public enum CaptureError: Error, LocalizedError, Equatable {
    case permissionDenied
    case noDisplaysAvailable
    case noWindowsAvailable
    case targetNotFound
    case captureFailed(String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen Recording permission is required. Enable access in System Settings."
        case .noDisplaysAvailable:
            return "No active display found for screen capture."
        case .noWindowsAvailable:
            return "No shareable window found for window capture."
        case .targetNotFound:
            return "Specified window or display target could not be located."
        case .captureFailed(let reason):
            return "Screen capture failed: \(reason)"
        }
    }
}

/// Hardware-accelerated ScreenCaptureKit capture engine for Apple Silicon macOS 14+.
public final class ScreenCaptureEngine: @unchecked Sendable {
    public static let shared = ScreenCaptureEngine()

    public init() {}

    /// Checks if Screen Recording permission is currently granted.
    public func isAuthorized() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }

    /// Captures the specified target using ScreenCaptureKit.
    public func capture(target: CaptureTarget) async throws -> CapturedImageItem {
        guard isAuthorized() else {
            throw CaptureError.permissionDenied
        }

        // Fetch shareable content
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw CaptureError.captureFailed(error.localizedDescription)
        }

        switch target {
        case .fullscreen(let displayID):
            return try await captureDisplay(displayID: displayID, content: content)

        case .window(let windowID):
            return try await captureWindow(windowID: windowID, content: content)

        case .area(let rect, let displayID):
            return try await captureArea(rect: rect, displayID: displayID, content: content)

        case .scrolling:
            return try await captureWindow(windowID: 0, content: content)
        }
    }

    // MARK: - Private Capture Implementations

    private func captureDisplay(displayID: CGDirectDisplayID?, content: SCShareableContent) async throws -> CapturedImageItem {
        guard let display = findDisplay(displayID: displayID, in: content) else {
            let targetID = displayID ?? CGMainDisplayID()
            if let fallbackImage = CGDisplayCreateImage(targetID) {
                return CapturedImageItem(image: fallbackImage, target: .fullscreen(displayID: displayID))
            }
            throw CaptureError.noDisplaysAvailable
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.showsCursor = false
        config.capturesAudio = false

        do {
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return CapturedImageItem(image: image, target: .fullscreen(displayID: displayID))
        } catch {
            let targetID = displayID ?? CGMainDisplayID()
            if let fallbackImage = CGDisplayCreateImage(targetID) {
                return CapturedImageItem(image: fallbackImage, target: .fullscreen(displayID: displayID))
            }
            throw CaptureError.captureFailed(error.localizedDescription)
        }
    }

    private func captureWindow(windowID: CGWindowID, content: SCShareableContent) async throws -> CapturedImageItem {
        let window: SCWindow?
        if windowID == 0 {
            let myPID = ProcessInfo.processInfo.processIdentifier
            // Prefer the frontmost on-screen application window not belonging to Maczy
            window = content.windows.first(where: {
                $0.isOnScreen && $0.frame.width > 50 && $0.frame.height > 50 && $0.owningApplication?.processID != myPID
            }) ?? content.windows.first(where: { $0.isOnScreen && $0.frame.width > 50 })
        } else {
            window = content.windows.first(where: { $0.windowID == windowID })
        }

        guard let targetWindow = window else {
            throw CaptureError.targetNotFound
        }

        let filter = SCContentFilter(desktopIndependentWindow: targetWindow)
        let config = SCStreamConfiguration()
        config.width = max(1, Int(targetWindow.frame.width))
        config.height = max(1, Int(targetWindow.frame.height))
        config.showsCursor = false
        config.capturesAudio = false

        do {
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return CapturedImageItem(image: image, target: .window(windowID: targetWindow.windowID))
        } catch {
            throw CaptureError.captureFailed(error.localizedDescription)
        }
    }

    private func captureArea(rect: CGRect, displayID: CGDirectDisplayID?, content: SCShareableContent) async throws -> CapturedImageItem {
        guard let display = findDisplay(displayID: displayID, in: content) else {
            throw CaptureError.noDisplaysAvailable
        }

        // ScreenCaptureKit sourceRect coordinate origin is TOP-LEFT of display
        // While AppKit rect coordinate origin is BOTTOM-LEFT of display!
        var scSourceRect = rect
        let displayHeight = CGFloat(display.height)
        if rect.origin.y >= 0 && rect.maxY <= displayHeight {
            let flippedY = max(0, displayHeight - rect.maxY)
            scSourceRect = CGRect(x: rect.origin.x, y: flippedY, width: rect.width, height: rect.height)
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = scSourceRect
        config.width = max(1, Int(rect.width))
        config.height = max(1, Int(rect.height))
        config.showsCursor = false
        config.capturesAudio = false

        do {
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return CapturedImageItem(image: image, target: .area(rect: rect, displayID: displayID))
        } catch {
            throw CaptureError.captureFailed(error.localizedDescription)
        }
    }

    private func findDisplay(displayID: CGDirectDisplayID?, in content: SCShareableContent) -> SCDisplay? {
        if let id = displayID {
            return content.displays.first(where: { $0.displayID == id }) ?? content.displays.first
        }
        return content.displays.first
    }
}
