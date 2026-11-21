import Foundation
import AppKit

public struct InstalledApp: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let bundleIdentifier: String?
    public let version: String
    public let publisher: String?
    public let bundleURL: URL
    public let bundleSizeBytes: Int64
    public let lastUsedDate: Date?
    public let isSystemApp: Bool
    public let isRunning: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String?,
        version: String = "1.0",
        publisher: String? = nil,
        bundleURL: URL,
        bundleSizeBytes: Int64 = 0,
        lastUsedDate: Date? = nil,
        isSystemApp: Bool = false,
        isRunning: Bool = false
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.publisher = publisher
        self.bundleURL = bundleURL
        self.bundleSizeBytes = bundleSizeBytes
        self.lastUsedDate = lastUsedDate
        self.isSystemApp = isSystemApp
        self.isRunning = isRunning
    }

    public var formattedBundleSize: String {
        ByteCountFormatter.string(fromByteCount: bundleSizeBytes, countStyle: .file)
    }

    public var locationPath: String {
        bundleURL.path
    }
}

public enum AppSortOption: String, CaseIterable, Identifiable, Sendable {
    case size = "Size"
    case name = "Name"
    case lastUsed = "Last Used"

    public var id: String { rawValue }
}
