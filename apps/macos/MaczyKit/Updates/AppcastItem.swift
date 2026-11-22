import Foundation

public struct AppcastItem: Identifiable, Equatable, Sendable {
    public var id: String { "\(version)-\(buildNumber)" }
    public let title: String
    public let version: String
    public let buildNumber: String
    public let releaseNotesURL: URL?
    public let downloadURL: URL
    public let ed25519Signature: String
    public let minimumSystemVersion: String?
    public let publicationDate: Date?
    public let fileSize: Int64?

    public init(
        title: String,
        version: String,
        buildNumber: String,
        releaseNotesURL: URL? = nil,
        downloadURL: URL,
        ed25519Signature: String,
        minimumSystemVersion: String? = "14.0",
        publicationDate: Date? = nil,
        fileSize: Int64? = nil
    ) {
        self.title = title
        self.version = version
        self.buildNumber = buildNumber
        self.releaseNotesURL = releaseNotesURL
        self.downloadURL = downloadURL
        self.ed25519Signature = ed25519Signature
        self.minimumSystemVersion = minimumSystemVersion
        self.publicationDate = publicationDate
        self.fileSize = fileSize
    }

    /// Strict security invariant: unsigned updates are rejected in all build variants.
    public var hasValidSignatureMetadata: Bool {
        let trimmed = ed25519Signature.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count >= 32
    }

    public var formattedFileSize: String {
        guard let bytes = fileSize, bytes > 0 else { return "Unknown size" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
