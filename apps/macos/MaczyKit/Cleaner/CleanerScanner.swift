import Foundation

public protocol CleanerScannerProvider: Sendable {
    func scan(
        categories: Set<CleanCategory>,
        onProgress: (@Sendable (Double, CleanCategory) -> Void)?
    ) async throws -> CleanerScanManifest
}

public final class MockCleanerScannerProvider: CleanerScannerProvider, @unchecked Sendable {
    public var cannedItems: [CleanerManifestItem]
    public var shouldThrowError: Error?
    public var delayNanoseconds: UInt64 = 0

    public init(cannedItems: [CleanerManifestItem]? = nil) {
        if let items = cannedItems {
            self.cannedItems = items
        } else {
            self.cannedItems = [
                CleanerManifestItem(
                    path: "/Users/test/Library/Caches/com.apple.Safari",
                    name: "Safari Web Cache",
                    category: .browserCaches,
                    fileSizeBytes: 245_000_000,
                    isSafeToPurge: true
                ),
                CleanerManifestItem(
                    path: "/Users/test/Library/Developer/Xcode/DerivedData/Project-xyz",
                    name: "Project-xyz DerivedData",
                    category: .xcodeDerivedData,
                    fileSizeBytes: 1_850_000_000,
                    isSafeToPurge: true
                ),
                CleanerManifestItem(
                    path: "/Users/test/Library/Logs/DiagnosticReports",
                    name: "Diagnostic Reports",
                    category: .systemLogs,
                    fileSizeBytes: 65_000_000,
                    isSafeToPurge: true
                )
            ]
        }
    }

    public func scan(
        categories: Set<CleanCategory>,
        onProgress: (@Sendable (Double, CleanCategory) -> Void)?
    ) async throws -> CleanerScanManifest {
        if let error = shouldThrowError {
            throw error
        }

        let sortedCategories = Array(categories).sorted(by: { $0.rawValue < $1.rawValue })
        let total = Double(max(1, sortedCategories.count))

        for (index, cat) in sortedCategories.enumerated() {
            try Task.checkCancellation()
            if delayNanoseconds > 0 {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            }
            onProgress?((Double(index + 1) / total), cat)
        }

        let filtered = cannedItems.filter { categories.contains($0.category) }
        return CleanerScanManifest(items: filtered)
    }
}

public final class NativeCleanerScannerProvider: CleanerScannerProvider, @unchecked Sendable {
    public init() {}

    public func scan(
        categories: Set<CleanCategory>,
        onProgress: (@Sendable (Double, CleanCategory) -> Void)?
    ) async throws -> CleanerScanManifest {
        var collectedItems: [CleanerManifestItem] = []
        let fileManager = FileManager.default

        let sortedCategories = Array(categories).sorted(by: { $0.rawValue < $1.rawValue })
        let totalCategories = Double(max(1, sortedCategories.count))

        for (index, category) in sortedCategories.enumerated() {
            try Task.checkCancellation()

            onProgress?(Double(index) / totalCategories, category)

            for dir in category.candidateDirectories {
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: dir.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                    continue
                }

                // If candidate directory itself is unreadable or not writable, skip it safely
                guard fileManager.isReadableFile(atPath: dir.path) else {
                    continue
                }

                // Strictly verify exclusion before scanning
                let exclusion = CleanerExclusions.isProtected(path: dir.path)
                if exclusion.isProtected {
                    continue
                }

                // Enumerate shallow candidate bundles/directories
                if let contents = try? fileManager.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for fileURL in contents {
                        try Task.checkCancellation()

                        // Check if file is readable and writable by the user process
                        guard fileManager.isReadableFile(atPath: fileURL.path),
                              fileManager.isWritableFile(atPath: fileURL.path) else {
                            continue
                        }

                        let itemExclusion = CleanerExclusions.isProtected(path: fileURL.path)
                        if itemExclusion.isProtected {
                            continue
                        }

                        let size = computeSize(url: fileURL, fileManager: fileManager)
                        guard size > 0 else {
                            continue
                        }

                        let modDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()

                        let item = CleanerManifestItem(
                            path: fileURL.path,
                            name: fileURL.lastPathComponent,
                            category: category,
                            fileSizeBytes: size,
                            lastModified: modDate,
                            isSafeToPurge: true
                        )
                        collectedItems.append(item)
                    }
                }
            }

            onProgress?(Double(index + 1) / totalCategories, category)
        }

        return CleanerScanManifest(items: collectedItems)
    }

    private func computeSize(url: URL, fileManager: FileManager) -> Int64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            let attrs = try? fileManager.attributesOfItem(atPath: url.path)
            return (attrs?[.size] as? Int64) ?? 0
        }

        var totalSize: Int64 = 0
        if let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let itemURL as URL in enumerator {
                let (isProtected, _) = CleanerExclusions.isProtected(path: itemURL.path)
                if isProtected { continue }

                if let values = try? itemURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                   let isSubDir = values.isDirectory, !isSubDir,
                   let fileSize = values.fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        return totalSize
    }
}
