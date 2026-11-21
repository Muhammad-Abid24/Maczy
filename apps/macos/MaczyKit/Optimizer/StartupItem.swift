import Foundation
import AppKit

public struct StartupItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let bundleIdentifier: String?
    public let path: String
    public let isEnabled: Bool
    public let itemType: String

    public init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String?,
        path: String,
        isEnabled: Bool = true,
        itemType: String = "Login Item"
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.isEnabled = isEnabled
        self.itemType = itemType
    }
}

public protocol StartupItemProvider: Sendable {
    func fetchStartupItems() async -> [StartupItem]
    func openLoginItemsSettings() -> Bool
}

public final class MockStartupItemProvider: StartupItemProvider, @unchecked Sendable {
    public var cannedItems: [StartupItem]
    public var openedSettingsCount: Int = 0

    public init(cannedItems: [StartupItem]? = nil) {
        self.cannedItems = cannedItems ?? [
            StartupItem(
                name: "Maczy Helper",
                bundleIdentifier: "com.maczy.helper",
                path: "/Applications/Maczy.app/Contents/Library/LoginItems/MaczyHelper.app",
                isEnabled: true,
                itemType: "Background Task"
            ),
            StartupItem(
                name: "Docker Desktop",
                bundleIdentifier: "com.docker.docker",
                path: "/Applications/Docker.app",
                isEnabled: true,
                itemType: "Login Item"
            ),
            StartupItem(
                name: "Raycast",
                bundleIdentifier: "com.raycast.macos",
                path: "/Applications/Raycast.app",
                isEnabled: true,
                itemType: "Login Item"
            )
        ]
    }

    public func fetchStartupItems() async -> [StartupItem] {
        return cannedItems
    }

    public func openLoginItemsSettings() -> Bool {
        openedSettingsCount += 1
        return true
    }
}

public final class NativeStartupItemProvider: StartupItemProvider, @unchecked Sendable {
    public init() {}

    public func fetchStartupItems() async -> [StartupItem] {
        var items: [StartupItem] = []
        let fileManager = FileManager.default

        // Query user LaunchAgents
        let launchAgentsDir = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
        if let contents = try? fileManager.contentsOfDirectory(at: launchAgentsDir, includingPropertiesForKeys: nil) {
            for file in contents where file.pathExtension == "plist" {
                let name = file.deletingPathExtension().lastPathComponent
                items.append(StartupItem(
                    name: name,
                    bundleIdentifier: name,
                    path: file.path,
                    isEnabled: true,
                    itemType: "User LaunchAgent"
                ))
            }
        }

        return items
    }

    public func openLoginItemsSettings() -> Bool {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            return NSWorkspace.shared.open(url)
        }
        return false
    }
}
