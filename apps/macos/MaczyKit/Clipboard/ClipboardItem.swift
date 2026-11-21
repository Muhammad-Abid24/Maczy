import Foundation
import CoreGraphics

/// Classified content category stored in clipboard history.
public enum ClipboardContentType: String, Sendable, Codable {
    case text = "Text"
    case image = "Image"
    case fileURLs = "Files"
}

/// Immutable record of an ingested clipboard item.
public struct ClipboardItem: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let type: ClipboardContentType
    public let text: String?
    public let imageDimensions: CGSize?
    public let byteSize: Int
    public let filePaths: [String]?
    public let timestamp: Date
    public let sourceApp: String?

    public init(
        id: UUID = UUID(),
        type: ClipboardContentType,
        text: String? = nil,
        imageDimensions: CGSize? = nil,
        byteSize: Int = 0,
        filePaths: [String]? = nil,
        timestamp: Date = Date(),
        sourceApp: String? = nil
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.imageDimensions = imageDimensions
        self.byteSize = byteSize
        self.filePaths = filePaths
        self.timestamp = timestamp
        self.sourceApp = sourceApp
    }

    /// Truncated preview text suitable for compact UI presentation.
    public var previewText: String {
        switch type {
        case .text:
            guard let t = text, !t.isEmpty else { return "Empty text" }
            let singleLine = t.replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if singleLine.count > 64 {
                return String(singleLine.prefix(64)) + "…"
            }
            return singleLine

        case .image:
            if let dim = imageDimensions {
                return "Image (\(Int(dim.width))×\(Int(dim.height)) pt)"
            }
            return "Image (\(byteSize / 1024) KB)"

        case .fileURLs:
            guard let files = filePaths, !files.isEmpty else { return "0 files" }
            if files.count == 1 {
                return URL(fileURLWithPath: files[0]).lastPathComponent
            } else {
                return "\(files.count) files (\(URL(fileURLWithPath: files[0]).lastPathComponent)…)"
            }
        }
    }

    /// Associated SF Symbol icon name.
    public var iconName: String {
        switch type {
        case .text: return "doc.text"
        case .image: return "photo"
        case .fileURLs: return "folder"
        }
    }

    /// Relative timestamp description.
    public var relativeTime: String {
        let elapsed = abs(Date().timeIntervalSince(timestamp))
        if elapsed < 60 {
            return "Just now"
        } else if elapsed < 3600 {
            return "\(Int(elapsed / 60))m ago"
        } else if elapsed < 86400 {
            return "\(Int(elapsed / 3600))h ago"
        } else {
            return "\(Int(elapsed / 86400))d ago"
        }
    }
}
