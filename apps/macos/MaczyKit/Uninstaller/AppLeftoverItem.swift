import Foundation

public enum LeftoverLocationType: String, CaseIterable, Identifiable, Sendable {
    case applicationSupport = "Application Support"
    case caches = "Caches"
    case preferences = "Preferences"
    case logs = "Logs & Diagnostics"
    case savedState = "Saved State"
    case containers = "Sandboxed Containers"
    case other = "Other Associated Data"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .applicationSupport: return "folder.fill"
        case .caches: return "archivebox.fill"
        case .preferences: return "gearshape.fill"
        case .logs: return "doc.text.fill"
        case .savedState: return "clock.arrow.circlepath"
        case .containers: return "shippingbox.fill"
        case .other: return "doc.fill"
        }
    }
}

public enum LeftoverSafety: String, CaseIterable, Identifiable, Sendable {
    case safe = "Safe"
    case reviewRequired = "Review Required"
    case protected = "Protected"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .safe:
            return "Non-essential temporary caches or logs automatically purged without data loss."
        case .reviewRequired:
            return "Application configuration, presets, or local databases. Verify before removing."
        case .protected:
            return "Critical shared resources, personal documents, or system files strictly retained."
        }
    }
}

public struct AppLeftoverItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let path: String
    public let name: String
    public let locationType: LeftoverLocationType
    public let fileSizeBytes: Int64
    public let safety: LeftoverSafety
    public var isSelected: Bool

    public init(
        id: UUID = UUID(),
        path: String,
        name: String,
        locationType: LeftoverLocationType,
        fileSizeBytes: Int64,
        safety: LeftoverSafety = .safe,
        isSelected: Bool = true
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.locationType = locationType
        self.fileSizeBytes = fileSizeBytes
        self.safety = safety
        self.isSelected = isSelected
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }
}
