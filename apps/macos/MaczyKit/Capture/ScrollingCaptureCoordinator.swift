import Foundation
import AppKit
import CoreGraphics

/// Status of an ongoing scrolling capture session.
public struct ScrollingCaptureProgress: Sendable {
    public let sliceCount: Int
    public let estimatedTotalHeight: Int
    public let isEndReached: Bool
}

/// Coordinates the accumulation and stitching of sequential screenshot slices.
@MainActor
public final class ScrollingCaptureCoordinator: NSObject {
    public static let shared = ScrollingCaptureCoordinator()

    private var slices: [CGImage] = []
    private var isSessionActive: Bool = false
    private let stitchingEngine = ImageStitchingEngine.shared

    public private(set) var activeSliceCount: Int = 0

    public override init() {
        super.init()
    }

    /// Begins a new scrolling capture session, discarding any previous buffer.
    public func startSession() {
        slices.removeAll()
        isSessionActive = true
        activeSliceCount = 0
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

        // Estimate current stitched height
        let estimatedHeight = slices.reduce(0) { $0 + $1.height }
        return ScrollingCaptureProgress(
            sliceCount: activeSliceCount,
            estimatedTotalHeight: estimatedHeight,
            isEndReached: isEnd
        )
    }

    /// Finalizes the scrolling session, stitches all accumulated slices, and exports the result.
    public func finishSession() throws -> CapturedImageItem {
        guard !slices.isEmpty else {
            isSessionActive = false
            throw StitchingError.insufficientSlices
        }

        let result = try stitchingEngine.stitch(slices: slices)
        isSessionActive = false
        slices.removeAll()
        activeSliceCount = 0

        let item = CapturedImageItem(
            image: result.image,
            target: .scrolling
        )

        // Export to pasteboard and disk
        CaptureExportManager.shared.copyToPasteboard(item.image)
        let savedURL = try? CaptureExportManager.shared.saveToDisk(item.image, format: .png)

        // Show Preview HUD
        CapturePreviewHUD.shared.present(image: item.image, fileURL: savedURL)

        return item
    }

    /// Cancels the active scrolling capture session and frees accumulated images.
    public func cancelSession() {
        slices.removeAll()
        isSessionActive = false
        activeSliceCount = 0
    }
}
