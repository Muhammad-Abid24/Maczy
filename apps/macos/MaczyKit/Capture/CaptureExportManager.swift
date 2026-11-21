import Foundation
import CoreGraphics
import AppKit
import UniformTypeIdentifiers

/// Image export formats supported by Maczy.
public enum ImageExportFormat: String, Sendable, CaseIterable {
    case png = "png"
    case jpeg = "jpg"
    case heic = "heic"

    public var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .heic: return .heic
        }
    }
}

/// Manages screenshot disk persistence, clipboard export, and file formatting.
public final class CaptureExportManager: @unchecked Sendable {
    public static let shared = CaptureExportManager()

    private let fileManager = FileManager.default
    private let dateFormatter: DateFormatter

    public init() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        self.dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    }

    /// Default directory where Maczy stores captured screenshots: ~/Pictures/Screenshots
    public var defaultScreenshotsDirectory: URL {
        let picturesURL = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures")
        let dir = picturesURL.appendingPathComponent("Screenshots", isDirectory: true)

        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Formats standardized filename for a captured item.
    public func generateFilename(prefix: String = "Maczy_Screenshot", timestamp: Date = Date(), format: ImageExportFormat = .png) -> String {
        let dateString = dateFormatter.string(from: timestamp)
        return "\(prefix)_\(dateString).\(format.rawValue)"
    }

    /// Encodes a CGImage to binary data for a specified format.
    public func encodeImage(_ cgImage: CGImage, format: ImageExportFormat = .png, compressionQuality: Double = 0.9) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        switch format {
        case .png:
            return bitmapRep.representation(using: .png, properties: [:])
        case .jpeg:
            let quality = NSNumber(value: compressionQuality)
            return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality])
        case .heic:
            // Fallback to PNG representation if HEIC bitmap rep unavailable
            if #available(macOS 10.13, *) {
                let data = NSMutableData()
                if let destination = CGImageDestinationCreateWithData(data as CFMutableData, UTType.heic.identifier as CFString, 1, nil) {
                    let options: [CFString: Any] = [
                        kCGImageDestinationLossyCompressionQuality: compressionQuality
                    ]
                    CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                    if CGImageDestinationFinalize(destination) {
                        return data as Data
                    }
                }
            }
            return bitmapRep.representation(using: .png, properties: [:])
        }
    }

    /// Copies a CGImage to the macOS system clipboard.
    @discardableResult
    public func copyToPasteboard(_ cgImage: CGImage) -> Bool {
        guard let pngData = encodeImage(cgImage, format: .png) else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(pngData, forType: .png)

        let rep = NSBitmapImageRep(cgImage: cgImage)
        if let tiffData = rep.tiffRepresentation {
            pasteboard.setData(tiffData, forType: .tiff)
        }
        return true
    }

    /// Saves a captured image to disk in the configured directory.
    @discardableResult
    public func saveToDisk(
        _ cgImage: CGImage,
        destinationDirectory: URL? = nil,
        filename: String? = nil,
        format: ImageExportFormat = .png
    ) throws -> URL {
        guard let data = encodeImage(cgImage, format: format) else {
            throw CaptureError.captureFailed("Failed to encode image data for format \(format.rawValue)")
        }

        let directory = destinationDirectory ?? defaultScreenshotsDirectory
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let finalName = filename ?? generateFilename(format: format)
        let fileURL = directory.appendingPathComponent(finalName)

        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
