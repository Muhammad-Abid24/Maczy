import Foundation

public enum DeveloperArtifactCategory: String, CaseIterable, Identifiable, Sendable {
    case xcodeDerivedData = "Xcode DerivedData"
    case simulatorCaches = "CoreSimulator Caches"
    case swiftPackageManager = "Swift Package Manager"
    case cargoCaches = "Cargo Build Caches"
    case nodeCaches = "Node Package Caches"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .xcodeDerivedData: return "hammer.fill"
        case .simulatorCaches: return "iphone"
        case .swiftPackageManager: return "swift"
        case .cargoCaches: return "gearshape.2.fill"
        case .nodeCaches: return "hexagon.fill"
        }
    }
}

public struct DeveloperArtifactItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let path: String
    public let category: DeveloperArtifactCategory
    public let fileSizeBytes: Int64
    public let isSafeToClear: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        category: DeveloperArtifactCategory,
        fileSizeBytes: Int64,
        isSafeToClear: Bool = true
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.category = category
        self.fileSizeBytes = fileSizeBytes
        self.isSafeToClear = isSafeToClear
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }
}

public protocol DeveloperArtifactScannerProvider: Sendable {
    func scanArtifacts() async throws -> [DeveloperArtifactItem]
}

public final class MockDeveloperArtifactScannerProvider: DeveloperArtifactScannerProvider, @unchecked Sendable {
    public var cannedItems: [DeveloperArtifactItem]

    public init(cannedItems: [DeveloperArtifactItem]? = nil) {
        self.cannedItems = cannedItems ?? [
            DeveloperArtifactItem(
                name: "Xcode DerivedData (Build cache)",
                path: "/Users/test/Library/Developer/Xcode/DerivedData",
                category: .xcodeDerivedData,
                fileSizeBytes: 2_450_000_000
            ),
            DeveloperArtifactItem(
                name: "Simulator Device Caches",
                path: "/Users/test/Library/Developer/CoreSimulator/Caches",
                category: .simulatorCaches,
                fileSizeBytes: 850_000_000
            ),
            DeveloperArtifactItem(
                name: "Swift Package Manager Source Caches",
                path: "/Users/test/Library/Caches/org.swift.swiftpm",
                category: .swiftPackageManager,
                fileSizeBytes: 320_000_000
            ),
            DeveloperArtifactItem(
                name: "Cargo Registry Download Cache",
                path: "/Users/test/.cargo/registry/cache",
                category: .cargoCaches,
                fileSizeBytes: 540_000_000
            ),
            DeveloperArtifactItem(
                name: "npm Global Cache",
                path: "/Users/test/.npm/_cacache",
                category: .nodeCaches,
                fileSizeBytes: 410_000_000
            )
        ]
    }

    public func scanArtifacts() async throws -> [DeveloperArtifactItem] {
        return cannedItems
    }
}

public final class NativeDeveloperArtifactScannerProvider: DeveloperArtifactScannerProvider, @unchecked Sendable {
    public init() {}

    public func scanArtifacts() async throws -> [DeveloperArtifactItem] {
        var items: [DeveloperArtifactItem] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser

        let targets: [(DeveloperArtifactCategory, URL, String)] = [
            (.xcodeDerivedData, home.appendingPathComponent("Library/Developer/Xcode/DerivedData"), "Xcode DerivedData"),
            (.simulatorCaches, home.appendingPathComponent("Library/Developer/CoreSimulator/Caches"), "CoreSimulator Caches"),
            (.swiftPackageManager, home.appendingPathComponent("Library/Caches/org.swift.swiftpm"), "SPM Repositories & Modules"),
            (.cargoCaches, home.appendingPathComponent(".cargo/registry/cache"), "Cargo Registry Cache"),
            (.nodeCaches, home.appendingPathComponent(".npm/_cacache"), "npm Content Cache")
        ]

        for (category, url, displayName) in targets {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }

            let exclusion = CleanerExclusions.isProtected(path: url.path)
            guard !exclusion.isProtected else { continue }

            let size = computeSize(url: url, fileManager: fileManager)
            if size > 0 {
                items.append(DeveloperArtifactItem(
                    name: displayName,
                    path: url.path,
                    category: category,
                    fileSizeBytes: size,
                    isSafeToClear: true
                ))
            }
        }

        return items
    }

    private func computeSize(url: URL, fileManager: FileManager) -> Int64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue {
            let attrs = try? fileManager.attributesOfItem(atPath: url.path)
            return (attrs?[.size] as? Int64) ?? 0
        }

        var total: Int64 = 0
        if let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let itemURL as URL in enumerator {
                if let vals = try? itemURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                   let isSub = vals.isDirectory, !isSub,
                   let size = vals.fileSize {
                    total += Int64(size)
                }
            }
        }
        return total
    }
}
