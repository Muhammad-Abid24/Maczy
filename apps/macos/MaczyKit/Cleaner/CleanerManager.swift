import Foundation
import Combine

/// Protocol defining safe deletion / moving files to macOS Trash for System Cleaner (MZ-029).
public protocol CleanupExecutionProvider: Sendable {
    func moveItemsToTrash(urls: [URL]) throws -> [URL]
}

/// Native macOS implementation moving items to macOS Trash with strict pre-deletion exclusion checks.
public final class NativeCleanupExecutionProvider: CleanupExecutionProvider, @unchecked Sendable {
    public init() {}

    public func moveItemsToTrash(urls: [URL]) throws -> [URL] {
        var trashed: [URL] = []
        let fileManager = FileManager.default

        for url in urls {
            guard fileManager.fileExists(atPath: url.path) else { continue }

            // Strict preflight protection check
            let exclusion = CleanerExclusions.isProtected(path: url.path)
            guard !exclusion.isProtected else {
                throw NSError(domain: "MaczyCleaner", code: 403, userInfo: [
                    NSLocalizedDescriptionKey: "Cannot remove protected path: \(url.path) (\(exclusion.reason ?? "Protected"))"
                ])
            }

            guard fileManager.isWritableFile(atPath: url.path) else {
                throw NSError(domain: "MaczyCleaner", code: 513, userInfo: [
                    NSLocalizedDescriptionKey: "Cannot remove path with insufficient access privileges: \(url.path)"
                ])
            }

            var resultingURL: NSURL?
            try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
            if let result = resultingURL as URL? {
                trashed.append(result)
            } else {
                trashed.append(url)
            }
        }
        return trashed
    }
}

/// Mock execution provider for isolated fixture testing without touching user files.
public final class MockCleanupExecutionProvider: CleanupExecutionProvider, @unchecked Sendable {
    public var trashedURLs: [URL] = []
    public var shouldFail: Bool = false

    public init() {}

    public func moveItemsToTrash(urls: [URL]) throws -> [URL] {
        if shouldFail {
            throw NSError(domain: "MockCleanup", code: 1, userInfo: [NSLocalizedDescriptionKey: "Simulated trash failure"])
        }
        for url in urls {
            let exclusion = CleanerExclusions.isProtected(path: url.path)
            if exclusion.isProtected {
                throw NSError(domain: "MockCleanup", code: 403, userInfo: [
                    NSLocalizedDescriptionKey: "Cannot remove protected path: \(url.path)"
                ])
            }
        }
        trashedURLs.append(contentsOf: urls)
        return urls
    }
}

/// Output result of a cleanup operation (MZ-029).
public struct CleanupResult: Sendable, Equatable {
    public let success: Bool
    public let trashedPaths: [String]
    public let failedPaths: [String]
    public let totalReclaimedBytes: Int64
    public let timestamp: Date
    public let message: String

    public var formattedReclaimedSize: String {
        ByteCountFormatter.string(fromByteCount: totalReclaimedBytes, countStyle: .file)
    }

    public init(
        success: Bool,
        trashedPaths: [String],
        failedPaths: [String] = [],
        totalReclaimedBytes: Int64,
        timestamp: Date = Date(),
        message: String
    ) {
        self.success = success
        self.trashedPaths = trashedPaths
        self.failedPaths = failedPaths
        self.totalReclaimedBytes = totalReclaimedBytes
        self.timestamp = timestamp
        self.message = message
    }
}

@MainActor
public final class CleanerManager: ObservableObject {
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var progress: Double = 0.0
    @Published public private(set) var currentCategory: CleanCategory? = nil
    @Published public private(set) var lastManifest: CleanerScanManifest? = nil
    @Published public var selectedCategories: Set<CleanCategory> = Set(CleanCategory.allCases)
    @Published public private(set) var scanError: String? = nil

    // MZ-029 Cleanup Execution State
    @Published public private(set) var isCleaning: Bool = false
    @Published public private(set) var lastCleanupResult: CleanupResult? = nil
    @Published public var isCleanupApproved: Bool = false

    private let scanner: CleanerScannerProvider
    private let executionProvider: CleanupExecutionProvider
    private var scanTask: Task<Void, Never>?

    public init(
        scanner: CleanerScannerProvider = NativeCleanerScannerProvider(),
        executionProvider: CleanupExecutionProvider = NativeCleanupExecutionProvider(),
        initiallyApproved: Bool = false
    ) {
        self.scanner = scanner
        self.executionProvider = executionProvider
        self.isCleanupApproved = initiallyApproved
    }

    public func toggleCategory(_ category: CleanCategory) {
        if selectedCategories.contains(category) {
            if selectedCategories.count > 1 {
                selectedCategories.remove(category)
            }
        } else {
            selectedCategories.insert(category)
        }
    }

    /// Background cooperative scan to keep the MainActor UI thread 100% fluid and responsive.
    public func startScan() {
        guard !isScanning else { return }
        isScanning = true
        progress = 0.0
        scanError = nil
        currentCategory = nil

        let categoriesToScan = selectedCategories
        let activeScanner = self.scanner

        scanTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let progressHandler: @Sendable (Double, CleanCategory) -> Void = { [weak self] pct, cat in
                    Task { @MainActor [weak self] in
                        self?.progress = pct
                        self?.currentCategory = cat
                    }
                }

                // Offload filesystem enumeration and I/O to background cooperative pool
                let manifest = try await Task.detached(priority: .userInitiated) {
                    try await activeScanner.scan(categories: categoriesToScan, onProgress: progressHandler)
                }.value

                await MainActor.run { [weak self] in
                    self?.lastManifest = manifest
                    self?.progress = 1.0
                    self?.isScanning = false
                    self?.currentCategory = nil
                }
            } catch is CancellationError {
                await MainActor.run { [weak self] in
                    self?.isScanning = false
                    self?.currentCategory = nil
                    self?.scanError = "Scan cancelled"
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.isScanning = false
                    self?.currentCategory = nil
                    self?.scanError = error.localizedDescription
                }
            }
        }
    }

    public func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        currentCategory = nil
        scanError = "Scan cancelled by user"
    }

    /// Strict Security Invariant (MZ-029 Gate):
    /// Cleanup execution (mutating or deleting files) requires explicit user confirmation.
    /// Fails closed unless isExplicitlyConfirmed or isCleanupApproved is true.
    public func requestCleanupExecution(isExplicitlyConfirmed: Bool = false) -> CommandResult {
        guard isExplicitlyConfirmed || isCleanupApproved else {
            return CommandResult.failure(
                errorCode: "GATE_MZ_029",
                message: "Cleanup deletion execution is strictly blocked by MZ-029 security review. Maczy operates in fail-closed safety mode."
            )
        }
        return CommandResult.success(message: "Cleanup execution confirmed and authorized")
    }

    /// Executes safe cleanup by moving verified purgeable cache items to macOS Trash (MZ-029).
    @discardableResult
    public func executeCleanup() async throws -> CleanupResult {
        guard let manifest = lastManifest, !manifest.items.isEmpty else {
            throw NSError(domain: "MaczyCleaner", code: 400, userInfo: [NSLocalizedDescriptionKey: "No items available to clean."])
        }

        isCleaning = true
        var trashedPaths: [String] = []
        var failedPaths: [String] = []
        var freedBytes: Int64 = 0

        // Filter items that are verified safe to purge
        let purgeableItems = manifest.items.filter { $0.isSafeToPurge }

        for item in purgeableItems {
            let url = URL(fileURLWithPath: item.path)
            let exclusion = CleanerExclusions.isProtected(path: item.path)
            if exclusion.isProtected {
                failedPaths.append(item.path)
                continue
            }

            do {
                _ = try executionProvider.moveItemsToTrash(urls: [url])
                trashedPaths.append(item.path)
                freedBytes += item.fileSizeBytes
            } catch {
                failedPaths.append(item.path)
            }
        }

        let isSuccess = failedPaths.isEmpty
        let result = CleanupResult(
            success: isSuccess,
            trashedPaths: trashedPaths,
            failedPaths: failedPaths,
            totalReclaimedBytes: freedBytes,
            timestamp: Date(),
            message: failedPaths.isEmpty ?
                "Successfully moved \(trashedPaths.count) items (\(ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file))) to Trash." :
                "Moved \(trashedPaths.count) items to Trash; \(failedPaths.count) items could not be removed."
        )

        self.lastCleanupResult = result
        self.isCleaning = false

        // Update manifest to reflect remaining items
        let remaining = manifest.items.filter { !trashedPaths.contains($0.path) }
        self.lastManifest = remaining.isEmpty ? nil : CleanerScanManifest(items: remaining)

        return result
    }
}
