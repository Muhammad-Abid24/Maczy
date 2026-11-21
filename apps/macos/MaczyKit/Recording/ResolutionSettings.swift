import Foundation
import CoreGraphics

/// Available resolution and scaling presets for screen recording.
public enum RecordingResolutionPreset: Sendable, Equatable, Hashable, CaseIterable {
    case native
    case uhd4K
    case qhd1440p
    case fhd1080p
    case hd720p
    case halfScale
    case threeQuarterScale

    public static var allCases: [RecordingResolutionPreset] {
        [.native, .uhd4K, .qhd1440p, .fhd1080p, .hd720p, .threeQuarterScale, .halfScale]
    }

    public var displayName: String {
        switch self {
        case .native: return "Native (100%)"
        case .uhd4K: return "4K UHD (2160p)"
        case .qhd1440p: return "1440p QHD"
        case .fhd1080p: return "1080p FHD"
        case .hd720p: return "720p HD"
        case .threeQuarterScale: return "75% Scale"
        case .halfScale: return "50% Scale"
        }
    }

    public var maximumDimensions: (width: Int, height: Int)? {
        switch self {
        case .native: return nil
        case .uhd4K: return (3840, 2160)
        case .qhd1440p: return (2560, 1440)
        case .fhd1080p: return (1920, 1080)
        case .hd720p: return (1280, 720)
        case .threeQuarterScale, .halfScale: return nil
        }
    }

    public var scaleMultiplier: Double? {
        switch self {
        case .native: return 1.0
        case .threeQuarterScale: return 0.75
        case .halfScale: return 0.50
        default: return nil
        }
    }
}

/// Scaling policy when source aspect ratio differs from target bounding box.
public enum AspectRatioMode: String, Sendable, CaseIterable {
    case fit
    case fill
    case stretch
}

/// Utility for calculating encoder-compliant, aspect-ratio-accurate output resolutions.
public enum ResolutionCalculator {

    /// Calculates even-dimension width and height constrained by the selected preset and aspect ratio mode.
    public static func calculateOutputDimensions(
        sourceWidth: Int,
        sourceHeight: Int,
        preset: RecordingResolutionPreset,
        aspectMode: AspectRatioMode = .fit
    ) -> (width: Int, height: Int) {
        guard sourceWidth > 0, sourceHeight > 0 else {
            return (1920, 1080)
        }

        var targetWidth: Double
        var targetHeight: Double

        if let multiplier = preset.scaleMultiplier {
            targetWidth = Double(sourceWidth) * multiplier
            targetHeight = Double(sourceHeight) * multiplier
        } else if let maxDims = preset.maximumDimensions {
            let maxW = Double(maxDims.width)
            let maxH = Double(maxDims.height)

            switch aspectMode {
            case .fit:
                let scaleW = maxW / Double(sourceWidth)
                let scaleH = maxH / Double(sourceHeight)
                let scale = min(scaleW, scaleH, 1.0) // Do not upscale beyond source unless custom
                targetWidth = Double(sourceWidth) * scale
                targetHeight = Double(sourceHeight) * scale

            case .stretch:
                targetWidth = maxW
                targetHeight = maxH

            case .fill:
                let scaleW = maxW / Double(sourceWidth)
                let scaleH = maxH / Double(sourceHeight)
                let scale = max(scaleW, scaleH)
                targetWidth = Double(sourceWidth) * scale
                targetHeight = Double(sourceHeight) * scale
            }
        } else {
            // Native source
            targetWidth = Double(sourceWidth)
            targetHeight = Double(sourceHeight)
        }

        // Align to even integers for H.264 / HEVC video encoders
        let finalWidth = max(2, (Int(round(targetWidth)) / 2) * 2)
        let finalHeight = max(2, (Int(round(targetHeight)) / 2) * 2)

        return (finalWidth, finalHeight)
    }

    /// Estimates target bitrate in bits per second based on resolution and framerate.
    public static func estimateBitrate(width: Int, height: Int, frameRate: Int, codec: RecordingVideoCodec) -> Int {
        let pixelCount = width * height
        let baseRate = Double(pixelCount * frameRate)

        // HEVC is ~40% more efficient than H.264 for equivalent visual quality
        let codecFactor = (codec == .hevc) ? 0.07 : 0.11
        let estimatedBitsPerSecond = Int(baseRate * codecFactor)

        // Clamp between 2 Mbps (720p low) and 50 Mbps (4K 60fps)
        return min(max(estimatedBitsPerSecond, 2_000_000), 50_000_000)
    }
}
