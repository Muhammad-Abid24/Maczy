import Foundation
import AppKit

public protocol AppInventoryProvider: Sendable {
    func discoverInstalledApps() async throws -> [InstalledApp]
    func analyzeLeftovers(for app: InstalledApp) async throws -> [AppLeftoverItem]
    func moveItemsToTrash(urls: [URL]) throws -> [URL]
}

public final class MockAppInventoryProvider: AppInventoryProvider, @unchecked Sendable {
    public var cannedApps: [InstalledApp]
    public var cannedLeftovers: [String: [AppLeftoverItem]]
    public var trashedURLs: [URL] = []
    public var shouldFailTrash: Bool = false

    public init(
        cannedApps: [InstalledApp]? = nil,
        cannedLeftovers: [String: [AppLeftoverItem]]? = nil
    ) {
        if let apps = cannedApps {
            self.cannedApps = apps
        } else {
            self.cannedApps = [
                InstalledApp(
                    name: "Figma",
                    bundleIdentifier: "com.figma.Desktop",
                    version: "124.3.1",
                    publisher: "Figma, Inc.",
                    bundleURL: URL(fileURLWithPath: "/Applications/Figma.app"),
                    bundleSizeBytes: 185_000_000,
                    isSystemApp: false,
                    isRunning: false
                ),
                InstalledApp(
                    name: "Slack",
                    bundleIdentifier: "com.tinyspeck.slackmacgap",
                    version: "4.38.125",
                    publisher: "Slack Technologies, LLC",
                    bundleURL: URL(fileURLWithPath: "/Applications/Slack.app"),
                    bundleSizeBytes: 240_000_000,
                    isSystemApp: false,
                    isRunning: true
                ),
                InstalledApp(
                    name: "Safari",
                    bundleIdentifier: "com.apple.Safari",
                    version: "18.0",
                    publisher: "Apple Inc.",
                    bundleURL: URL(fileURLWithPath: "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app"),
                    bundleSizeBytes: 35_000_000,
                    isSystemApp: true,
                    isRunning: false
                )
            ]
        }

        if let leftovers = cannedLeftovers {
            self.cannedLeftovers = leftovers
        } else {
            self.cannedLeftovers = [
                "com.figma.Desktop": [
                    AppLeftoverItem(
                        path: "/Users/test/Library/Application Support/Figma",
                        name: "Figma Application Support",
                        locationType: .applicationSupport,
                        fileSizeBytes: 420_000_000,
                        safety: .reviewRequired
                    ),
                    AppLeftoverItem(
                        path: "/Users/test/Library/Caches/com.figma.Desktop",
                        name: "Figma Cache",
                        locationType: .caches,
                        fileSizeBytes: 650_000_000,
                        safety: .safe
                    ),
                    AppLeftoverItem(
                        path: "/Users/test/Library/Preferences/com.figma.Desktop.plist",
                        name: "Preferences",
                        locationType: .preferences,
                        fileSizeBytes: 15_000,
                        safety: .reviewRequired
                    )
                ]
            ]
        }
    }

    public func discoverInstalledApps() async throws -> [InstalledApp] {
        return cannedApps
    }

    public func analyzeLeftovers(for app: InstalledApp) async throws -> [AppLeftoverItem] {
        guard let bid = app.bundleIdentifier else { return [] }
        return cannedLeftovers[bid] ?? []
    }

    public func moveItemsToTrash(urls: [URL]) throws -> [URL] {
        if shouldFailTrash {
            throw NSError(domain: "MockUninstaller", code: 1, userInfo: [NSLocalizedDescriptionKey: "Simulated trash failure"])
        }
        trashedURLs.append(contentsOf: urls)
        return urls
    }
}

public final class NativeAppInventoryProvider: AppInventoryProvider, @unchecked Sendable {
    public init() {}

    public func discoverInstalledApps() async throws -> [InstalledApp] {
        var apps: [InstalledApp] = []
        let fileManager = FileManager.default

        let searchDirs: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        for dir in searchDirs {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }

            guard let contents = try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for appURL in contents where appURL.pathExtension == "app" {
                let isSystem = appURL.path.hasPrefix("/System") ||
                    appURL.path.hasPrefix("/System/Applications") ||
                    appURL.path.contains("System/Library")

                let bundle = Bundle(url: appURL)
                let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                    bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String ??
                    appURL.deletingPathExtension().lastPathComponent
                let bundleId = bundle?.bundleIdentifier
                let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
                let publisher = bundle?.object(forInfoDictionaryKey: "CFBundleGetInfoString") as? String

                var isRunning = false
                if let bid = bundleId {
                    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bid)
                    isRunning = !runningApps.isEmpty
                }

                let size = computeBundleSize(url: appURL, fileManager: fileManager)

                let app = InstalledApp(
                    name: name,
                    bundleIdentifier: bundleId,
                    version: version,
                    publisher: publisher,
                    bundleURL: appURL,
                    bundleSizeBytes: size,
                    lastUsedDate: nil,
                    isSystemApp: isSystem,
                    isRunning: isRunning
                )
                apps.append(app)
            }
        }

        return apps.sorted(by: { $0.bundleSizeBytes > $1.bundleSizeBytes })
    }

    public func analyzeLeftovers(for app: InstalledApp) async throws -> [AppLeftoverItem] {
        var leftovers: [AppLeftoverItem] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser

        guard let bundleId = app.bundleIdentifier, !bundleId.isEmpty else {
            return []
        }

        let appName = app.name

        // Target locations to inspect
        let locations: [(LeftoverLocationType, URL, String)] = [
            (.applicationSupport, home.appendingPathComponent("Library/Application Support").appendingPathComponent(bundleId), bundleId),
            (.applicationSupport, home.appendingPathComponent("Library/Application Support").appendingPathComponent(appName), appName),
            (.caches, home.appendingPathComponent("Library/Caches").appendingPathComponent(bundleId), bundleId),
            (.caches, home.appendingPathComponent("Library/Caches").appendingPathComponent(appName), appName),
            (.preferences, home.appendingPathComponent("Library/Preferences").appendingPathComponent("\(bundleId).plist"), "\(bundleId).plist"),
            (.logs, home.appendingPathComponent("Library/Logs").appendingPathComponent(bundleId), bundleId),
            (.logs, home.appendingPathComponent("Library/Logs").appendingPathComponent(appName), appName),
            (.savedState, home.appendingPathComponent("Library/Saved Application State").appendingPathComponent("\(bundleId).savedState"), "\(bundleId).savedState"),
            (.containers, home.appendingPathComponent("Library/Containers").appendingPathComponent(bundleId), bundleId)
        ]

        var seenPaths = Set<String>()

        for (locType, targetURL, itemName) in locations {
            guard fileManager.fileExists(atPath: targetURL.path), !seenPaths.contains(targetURL.path) else {
                continue
            }
            seenPaths.insert(targetURL.path)

            // Strict safety check via CleanerExclusions
            let exclusion = CleanerExclusions.isProtected(path: targetURL.path)
            let safety: LeftoverSafety
            if exclusion.isProtected {
                safety = .protected
            } else if locType == .caches || locType == .savedState || locType == .logs {
                safety = .safe
            } else {
                safety = .reviewRequired
            }

            let size = computeBundleSize(url: targetURL, fileManager: fileManager)

            let item = AppLeftoverItem(
                path: targetURL.path,
                name: itemName,
                locationType: locType,
                fileSizeBytes: size,
                safety: safety,
                isSelected: safety != .protected
            )
            leftovers.append(item)
        }

        return leftovers.sorted(by: { $0.fileSizeBytes > $1.fileSizeBytes })
    }

    public func moveItemsToTrash(urls: [URL]) throws -> [URL] {
        var trashed: [URL] = []
        let fileManager = FileManager.default

        for url in urls {
            // Preflight check
            guard fileManager.fileExists(atPath: url.path) else { continue }
            let exclusion = CleanerExclusions.isProtected(path: url.path)
            guard !exclusion.isProtected else {
                throw NSError(domain: "MaczyUninstaller", code: 403, userInfo: [
                    NSLocalizedDescriptionKey: "Cannot remove protected path: \(url.path) (\(exclusion.reason ?? "Protected"))"
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

    private func computeBundleSize(url: URL, fileManager: FileManager) -> Int64 {
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
            options: [.skipsHiddenFiles]
        ) {
            for case let itemURL as URL in enumerator {
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
