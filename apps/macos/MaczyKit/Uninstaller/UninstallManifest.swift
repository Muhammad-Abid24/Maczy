import Foundation

public struct UninstallManifest: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let app: InstalledApp
    public let leftoverItems: [AppLeftoverItem]

    public init(
        id: UUID = UUID(),
        app: InstalledApp,
        leftoverItems: [AppLeftoverItem]
    ) {
        self.id = id
        self.app = app
        self.leftoverItems = leftoverItems
    }

    public var selectedLeftovers: [AppLeftoverItem] {
        leftoverItems.filter { $0.isSelected && $0.safety != .protected }
    }

    public var totalRemovalSizeBytes: Int64 {
        let leftoversSize = selectedLeftovers.reduce(0) { $0 + $1.fileSizeBytes }
        return app.bundleSizeBytes + leftoversSize
    }

    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalRemovalSizeBytes, countStyle: .file)
    }

    public var canRemoveDirectlyToTrash: Bool {
        !app.isSystemApp && !app.isRunning
    }

    public var blockingReason: String? {
        if app.isSystemApp {
            return "System applications cannot be uninstalled to maintain macOS integrity."
        }
        if app.isRunning {
            return "Application is currently running. Please quit \(app.name) before uninstalling."
        }
        return nil
    }
}

public struct UninstallResult: Equatable, Sendable {
    public let success: Bool
    public let trashedPaths: [String]
    public let failedPaths: [String]
    public let totalFreedBytes: Int64
    public let message: String

    public init(
        success: Bool,
        trashedPaths: [String],
        failedPaths: [String] = [],
        totalFreedBytes: Int64 = 0,
        message: String
    ) {
        self.success = success
        self.trashedPaths = trashedPaths
        self.failedPaths = failedPaths
        self.totalFreedBytes = totalFreedBytes
        self.message = message
    }

    public var formattedFreedBytes: String {
        ByteCountFormatter.string(fromByteCount: totalFreedBytes, countStyle: .file)
    }
}
