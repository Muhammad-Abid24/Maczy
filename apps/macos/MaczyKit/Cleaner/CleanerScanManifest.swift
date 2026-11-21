import Foundation

public struct CleanerManifestItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let path: String
    public let name: String
    public let category: CleanCategory
    public let fileSizeBytes: Int64
    public let lastModified: Date
    public let isSafeToPurge: Bool
    public let exclusionReason: String?

    public init(
        id: UUID = UUID(),
        path: String,
        name: String,
        category: CleanCategory,
        fileSizeBytes: Int64,
        lastModified: Date = Date(),
        isSafeToPurge: Bool = true,
        exclusionReason: String? = nil
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.category = category
        self.fileSizeBytes = fileSizeBytes
        self.lastModified = lastModified
        self.isSafeToPurge = isSafeToPurge
        self.exclusionReason = exclusionReason
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }
}

public struct CleanerScanManifest: Equatable, Sendable {
    public let scanId: UUID
    public let timestamp: Date
    public let items: [CleanerManifestItem]
    public let totalScanSizeBytes: Int64
    public let reclaimableSizeBytes: Int64
    public let categoryBreakdown: [CleanCategory: Int64]
    public let categoryCounts: [CleanCategory: Int]

    public init(
        scanId: UUID = UUID(),
        timestamp: Date = Date(),
        items: [CleanerManifestItem]
    ) {
        self.scanId = scanId
        self.timestamp = timestamp
        self.items = items

        var total: Int64 = 0
        var reclaimable: Int64 = 0
        var breakdown: [CleanCategory: Int64] = [:]
        var counts: [CleanCategory: Int] = [:]

        for item in items {
            total += item.fileSizeBytes
            if item.isSafeToPurge {
                reclaimable += item.fileSizeBytes
                breakdown[item.category, default: 0] += item.fileSizeBytes
            }
            counts[item.category, default: 0] += 1
        }

        self.totalScanSizeBytes = total
        self.reclaimableSizeBytes = reclaimable
        self.categoryBreakdown = breakdown
        self.categoryCounts = counts
    }

    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalScanSizeBytes, countStyle: .file)
    }

    public var formattedReclaimableSize: String {
        ByteCountFormatter.string(fromByteCount: reclaimableSizeBytes, countStyle: .file)
    }
}
