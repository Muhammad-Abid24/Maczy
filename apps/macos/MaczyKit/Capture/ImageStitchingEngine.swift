import Foundation
import CoreGraphics
import AppKit

/// Errors that can occur during image stitching.
public enum StitchingError: Error, LocalizedError, Equatable {
    case insufficientSlices
    case dimensionMismatch(String)
    case canvasAllocationFailed
    case maxCanvasHeightExceeded(Int)

    public var errorDescription: String? {
        switch self {
        case .insufficientSlices:
            return "At least two image slices are required for scrolling capture stitching."
        case .dimensionMismatch(let reason):
            return "Image dimension mismatch: \(reason)"
        case .canvasAllocationFailed:
            return "Failed to allocate CoreGraphics bitmap context for stitched canvas."
        case .maxCanvasHeightExceeded(let height):
            return "Stitched canvas height (\(height)px) exceeds maximum allowed limit."
        }
    }
}

/// Result of stitching two or more sequential vertical screenshot slices.
public struct StitchingResult: Sendable {
    public let image: CGImage
    public let width: Int
    public let height: Int
    public let sliceCount: Int
    public let totalOverlapPixels: Int
}

/// High-performance CoreGraphics visual row correlation and stitching engine.
public final class ImageStitchingEngine: @unchecked Sendable {
    public static let shared = ImageStitchingEngine()

    /// Maximum canvas height in pixels to avoid memory exhaustion (CoreGraphics limit).
    public let maxCanvasHeight: Int

    public init(maxCanvasHeight: Int = 32768) {
        self.maxCanvasHeight = maxCanvasHeight
    }

    /// Finds the vertical overlap height between `topSlice` and `bottomSlice`.
    /// Returns the number of pixels at the bottom of `topSlice` that match the top of `bottomSlice`.
    public func findVerticalOverlap(
        topSlice: CGImage,
        bottomSlice: CGImage,
        minOverlap: Int = 10,
        maxOverlapRatio: Double = 0.85,
        differenceThreshold: Double = 25.0
    ) -> (overlap: Int, isIdentical: Bool) {
        let width = min(topSlice.width, bottomSlice.width)
        let topHeight = topSlice.height
        let bottomHeight = bottomSlice.height

        guard width > 0, topHeight > minOverlap, bottomHeight > minOverlap else {
            return (0, false)
        }

        // Check for identical images (e.g. scroll reached bottom of page)
        if topHeight == bottomHeight && areImagesIdentical(topSlice, bottomSlice, sampleStep: 4) {
            return (topHeight, true)
        }

        // Extract pixel rows for correlation
        guard let topData = extractPixelData(from: topSlice),
              let bottomData = extractPixelData(from: bottomSlice) else {
            return (0, false)
        }

        let maxOverlap = min(Int(Double(min(topHeight, bottomHeight)) * maxOverlapRatio), topHeight - 1)
        guard maxOverlap >= minOverlap else {
            return (0, false)
        }

        var bestOverlap = 0
        var minScore = Double.greatestFiniteMagnitude

        // Sample horizontal points to speed up row comparison (e.g. step of 4 or 8)
        let stepX = max(1, width / 64)
        let sampleRows = 16 // Number of rows to cross-verify

        for overlap in stride(from: maxOverlap, through: minOverlap, by: -1) {
            var totalDiff: Double = 0
            var sampleCount = 0

            let checkRows = min(sampleRows, overlap)
            for r in 0..<checkRows {
                let topRow = topHeight - overlap + r
                let bottomRow = r

                let topRowOffset = topRow * topSlice.width * 4
                let bottomRowOffset = bottomRow * bottomSlice.width * 4

                for x in stride(from: 0, to: width, by: stepX) {
                    let topPx = topRowOffset + x * 4
                    let bottomPx = bottomRowOffset + x * 4

                    guard topPx + 2 < topData.count, bottomPx + 2 < bottomData.count else { continue }

                    let diffR = abs(Double(topData[topPx]) - Double(bottomData[bottomPx]))
                    let diffG = abs(Double(topData[topPx + 1]) - Double(bottomData[bottomPx + 1]))
                    let diffB = abs(Double(topData[topPx + 2]) - Double(bottomData[bottomPx + 2]))

                    totalDiff += (diffR + diffG + diffB) / 3.0
                    sampleCount += 1
                }
            }

            guard sampleCount > 0 else { continue }
            let avgDiff = totalDiff / Double(sampleCount)

            if avgDiff < minScore {
                minScore = avgDiff
                bestOverlap = overlap
            }

            // Early exit on near-perfect match
            if avgDiff < 2.0 {
                break
            }
        }

        if minScore <= differenceThreshold {
            let isIdentical = (bestOverlap >= topHeight - 5)
            return (bestOverlap, isIdentical)
        }

        return (0, false)
    }

    /// Stitches sequential vertical slices into a single unified composite `CGImage`.
    public func stitch(slices: [CGImage]) throws -> StitchingResult {
        guard !slices.isEmpty else {
            throw StitchingError.insufficientSlices
        }

        if slices.count == 1 {
            let single = slices[0]
            return StitchingResult(
                image: single,
                width: single.width,
                height: single.height,
                sliceCount: 1,
                totalOverlapPixels: 0
            )
        }

        let canvasWidth = slices[0].width
        for (idx, slice) in slices.enumerated() {
            guard slice.width == canvasWidth else {
                throw StitchingError.dimensionMismatch("Slice \(idx) width (\(slice.width)) != \(canvasWidth)")
            }
        }

        // 1. Calculate offsets and overlaps between consecutive slices
        var overlaps: [Int] = []
        var totalCanvasHeight = slices[0].height
        var totalOverlap = 0

        for i in 0..<(slices.count - 1) {
            let (overlap, isIdentical) = findVerticalOverlap(topSlice: slices[i], bottomSlice: slices[i + 1])

            // If identical, we don't add additional height
            if isIdentical {
                overlaps.append(slices[i + 1].height)
                continue
            }

            let effectiveOverlap = max(0, overlap)
            overlaps.append(effectiveOverlap)
            totalOverlap += effectiveOverlap

            let addedHeight = slices[i + 1].height - effectiveOverlap
            totalCanvasHeight += max(0, addedHeight)

            if totalCanvasHeight > maxCanvasHeight {
                totalCanvasHeight = maxCanvasHeight
                break
            }
        }

        // 2. Allocate composite bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: canvasWidth,
            height: totalCanvasHeight,
            bitsPerComponent: 8,
            bytesPerRow: canvasWidth * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw StitchingError.canvasAllocationFailed
        }

        // 3. Draw strips onto the composite canvas
        // Note: CoreGraphics origin (0,0) is at bottom-left.
        // Slice 0 starts at the top: y = totalCanvasHeight - slice0.height.
        var currentYFromTop = 0

        for (idx, slice) in slices.enumerated() {
            let sliceHeight = slice.height

            if idx == 0 {
                let destY = totalCanvasHeight - sliceHeight
                context.draw(slice, in: CGRect(x: 0, y: destY, width: canvasWidth, height: sliceHeight))
                currentYFromTop = sliceHeight
            } else {
                let overlap = idx - 1 < overlaps.count ? overlaps[idx - 1] : 0
                // Skip if duplicate / identical slice
                if overlap >= sliceHeight { continue }

                // The new strip is sliceHeight - overlap
                let stripHeight = sliceHeight - overlap
                currentYFromTop += stripHeight

                // Clamp to canvas height
                if currentYFromTop > totalCanvasHeight {
                    break
                }

                let destY = totalCanvasHeight - currentYFromTop
                // Clip and draw the non-overlapping portion of this slice
                context.saveGState()
                context.clip(to: CGRect(x: 0, y: destY, width: canvasWidth, height: stripHeight))
                // Draw entire slice aligned such that the bottom portion appears in the clip
                context.draw(slice, in: CGRect(x: 0, y: destY, width: canvasWidth, height: sliceHeight))
                context.restoreGState()
            }
        }

        guard let compositeImage = context.makeImage() else {
            throw StitchingError.canvasAllocationFailed
        }

        return StitchingResult(
            image: compositeImage,
            width: canvasWidth,
            height: totalCanvasHeight,
            sliceCount: slices.count,
            totalOverlapPixels: totalOverlap
        )
    }

    // MARK: - Private Helpers

    private func extractPixelData(from image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return data
    }

    private func areImagesIdentical(_ img1: CGImage, _ img2: CGImage, sampleStep: Int = 8) -> Bool {
        guard img1.width == img2.width && img1.height == img2.height else { return false }
        guard let data1 = extractPixelData(from: img1),
              let data2 = extractPixelData(from: img2) else { return false }

        let count = data1.count
        guard count == data2.count else { return false }

        var diffAccumulator: Double = 0
        var samples = 0

        for i in stride(from: 0, to: count - 3, by: sampleStep * 4) {
            let r = abs(Int(data1[i]) - Int(data2[i]))
            let g = abs(Int(data1[i + 1]) - Int(data2[i + 1]))
            let b = abs(Int(data1[i + 2]) - Int(data2[i + 2]))
            diffAccumulator += Double(r + g + b) / 3.0
            samples += 1
        }

        guard samples > 0 else { return true }
        return (diffAccumulator / Double(samples)) < 1.0
    }
}
