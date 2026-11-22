import Foundation
import AppKit
import CoreGraphics

/// Status of an ongoing scrolling capture session.
public struct ScrollingCaptureProgress: Sendable {
    public let sliceCount: Int
    public let estimatedTotalHeight: Int
    public let isEndReached: Bool
}

/// Coordinates the accumulation, interactive control, and stitching of sequential screenshot slices.
@MainActor
public final class ScrollingCaptureCoordinator: NSObject, ObservableObject {
    public static let shared = ScrollingCaptureCoordinator()

    private var slices: [CGImage] = []
    private var isSessionActive: Bool = false
    private let stitchingEngine = ImageStitchingEngine.shared

    @Published public private(set) var activeSliceCount: Int = 0
    @Published public private(set) var estimatedTotalHeight: Int = 0
    @Published public private(set) var isAutoScrolling: Bool = false
    @Published public private(set) var isEndReached: Bool = false

    public private(set) var targetRect: CGRect = .zero
    public private(set) var targetDisplayID: CGDirectDisplayID = 0

    private var autoScrollTask: Task<Void, Never>?
    private var interactiveCompletion: ((Result<CapturedImageItem, CaptureError>) -> Void)?

    public override init() {
        super.init()
    }

    // MARK: - Core Session Lifecycle

    /// Begins a new scrolling capture session, discarding any previous buffer.
    public func startSession() {
        slices.removeAll()
        isSessionActive = true
        activeSliceCount = 0
        estimatedTotalHeight = 0
        isAutoScrolling = false
        isEndReached = false
    }

    /// Appends a new screenshot slice to the active session.
    @discardableResult
    public func appendSlice(_ slice: CGImage) -> ScrollingCaptureProgress {
        guard isSessionActive else {
            return ScrollingCaptureProgress(sliceCount: 0, estimatedTotalHeight: 0, isEndReached: true)
        }

        var isEnd = false
        if let lastSlice = slices.last {
            let (_, isIdentical) = stitchingEngine.findVerticalOverlap(topSlice: lastSlice, bottomSlice: slice)
            if isIdentical {
                isEnd = true
            }
        }

        if !isEnd {
            slices.append(slice)
            activeSliceCount = slices.count
        }

        // Estimate current stitched height (sum of slice heights)
        let estHeight = slices.reduce(0) { $0 + $1.height }
        self.estimatedTotalHeight = estHeight
        self.isEndReached = isEnd

        return ScrollingCaptureProgress(
            sliceCount: activeSliceCount,
            estimatedTotalHeight: estHeight,
            isEndReached: isEnd
        )
    }

    /// Finalizes the scrolling session, stitches all accumulated slices, and exports the result.
    public func finishSession(export: Bool = true) throws -> CapturedImageItem {
        guard !slices.isEmpty else {
            isSessionActive = false
            throw StitchingError.insufficientSlices
        }

        let result = try stitchingEngine.stitch(slices: slices)
        isSessionActive = false
        slices.removeAll()
        activeSliceCount = 0
        estimatedTotalHeight = 0
        isAutoScrolling = false
        isEndReached = false

        let item = CapturedImageItem(
            image: result.image,
            target: .scrolling
        )

        if export {
            // Export to pasteboard and disk
            CaptureExportManager.shared.copyToPasteboard(item.image)
            let savedURL = try? CaptureExportManager.shared.saveToDisk(item.image, format: .png)

            // Show Preview HUD
            CapturePreviewHUD.shared.present(image: item.image, fileURL: savedURL)
        }

        return item
    }

    /// Cancels the active scrolling capture session and frees accumulated images.
    public func cancelSession() {
        stopAutoScroll()
        slices.removeAll()
        isSessionActive = false
        activeSliceCount = 0
        estimatedTotalHeight = 0
        isAutoScrolling = false
        isEndReached = false
    }

    // MARK: - Interactive Session Flow

    /// Starts an interactive scrolling capture session anchored to a user-selected rectangle.
    public func startInteractiveSession(
        rect: CGRect,
        displayID: CGDirectDisplayID,
        completion: ((Result<CapturedImageItem, CaptureError>) -> Void)? = nil
    ) async {
        self.targetRect = rect
        self.targetDisplayID = displayID
        self.interactiveCompletion = completion

        startSession()

        // Capture initial slice immediately
        do {
            let initialSlice = try await ScreenCaptureEngine.shared.capture(target: .area(rect: rect, displayID: displayID))
            appendSlice(initialSlice.image)
        } catch let error as CaptureError {
            interactiveCompletion?(.failure(error))
            interactiveCompletion = nil
            return
        } catch {
            interactiveCompletion?(.failure(.captureFailed(error.localizedDescription)))
            interactiveCompletion = nil
            return
        }

        // Present floating interactive control HUD
        ScrollingControlHUD.shared.present(anchoredTo: rect)
    }

    /// Captures the current content within `targetRect` and appends it as a new slice.
    @discardableResult
    public func captureCurrentSlice() async -> ScrollingCaptureProgress {
        guard isSessionActive, targetRect.width > 0, targetRect.height > 0 else {
            return ScrollingCaptureProgress(sliceCount: activeSliceCount, estimatedTotalHeight: estimatedTotalHeight, isEndReached: true)
        }

        do {
            let slice = try await ScreenCaptureEngine.shared.capture(target: .area(rect: targetRect, displayID: targetDisplayID))
            return appendSlice(slice.image)
        } catch {
            return ScrollingCaptureProgress(sliceCount: activeSliceCount, estimatedTotalHeight: estimatedTotalHeight, isEndReached: false)
        }
    }

    /// Toggles the automatic scrolling loop.
    public func toggleAutoScroll() {
        if isAutoScrolling {
            stopAutoScroll()
        } else {
            startAutoScroll()
        }
    }

    /// Starts automated scrolling and continuous slice capture.
    public func startAutoScroll(stepDelta: Int32 = -6, intervalSeconds: Double = 0.45) {
        guard isSessionActive else { return }
        isAutoScrolling = true
        autoScrollTask?.cancel()

        autoScrollTask = Task { [weak self] in
            while true {
                guard let self = self, self.isAutoScrolling, self.isSessionActive else { break }

                // 1. Simulate mouse wheel scroll down at center of target rect
                let center = CGPoint(x: self.targetRect.midX, y: self.targetRect.midY)
                Self.simulateScrollWheel(at: center, deltaY: stepDelta)

                // 2. Wait for content to render smoothly
                try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))

                guard self.isAutoScrolling && self.isSessionActive else { break }

                // 3. Capture slice
                let progress = await self.captureCurrentSlice()

                if progress.isEndReached {
                    self.stopAutoScroll()
                    break
                }
            }
        }
    }

    /// Stops the automated scrolling loop.
    public func stopAutoScroll() {
        isAutoScrolling = false
        autoScrollTask?.cancel()
        autoScrollTask = nil
    }

    /// Finishes the interactive session, stitches accumulated slices, and exports.
    public func finishInteractiveSession() {
        stopAutoScroll()
        ScrollingControlHUD.shared.dismiss()

        do {
            let item = try finishSession(export: false)
            interactiveCompletion?(.success(item))
        } catch let error as StitchingError {
            interactiveCompletion?(.failure(.captureFailed(error.localizedDescription)))
        } catch {
            interactiveCompletion?(.failure(.captureFailed(error.localizedDescription)))
        }
        interactiveCompletion = nil
    }

    /// Cancels the interactive session and dismisses the HUD.
    public func cancelInteractiveSession() {
        stopAutoScroll()
        ScrollingControlHUD.shared.dismiss()
        cancelSession()

        interactiveCompletion?(.failure(.captureFailed("User canceled scrolling capture")))
        interactiveCompletion = nil
    }

    // MARK: - Event Simulation Utility

    /// Synthesizes mouse scroll wheel events at the specified screen point.
    public static func simulateScrollWheel(at screenPoint: CGPoint, deltaY: Int32) {
        guard let primaryScreen = NSScreen.screens.first else { return }
        let primaryHeight = primaryScreen.frame.height
        let quartzPoint = CGPoint(x: screenPoint.x, y: primaryHeight - screenPoint.y)

        // Move cursor slightly to the target area so macOS routes mouse wheel to that window
        if let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: quartzPoint, mouseButton: .left) {
            moveEvent.post(tap: .cghidEventTap)
        }

        // deltaY < 0 scrolls downward (e.g. -6 lines)
        if let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: deltaY,
            wheel2: 0,
            wheel3: 0
        ) {
            scrollEvent.location = quartzPoint
            scrollEvent.post(tap: .cghidEventTap)
        }
    }
}
