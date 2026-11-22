import Foundation

public enum CleanCategory: String, CaseIterable, Identifiable, Sendable {
    case userCaches = "user_caches"
    case systemLogs = "system_logs"
    case xcodeDerivedData = "xcode_derived_data"
    case xcodeArchives = "xcode_archives"
    case packageManagerCaches = "package_manager_caches"
    case browserCaches = "browser_caches"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .userCaches:
            return "User Caches"
        case .systemLogs:
            return "System & App Logs"
        case .xcodeDerivedData:
            return "Xcode DerivedData"
        case .xcodeArchives:
            return "Xcode Archives"
        case .packageManagerCaches:
            return "Package Manager Caches"
        case .browserCaches:
            return "Browser Web Caches"
        }
    }

    public var icon: String {
        switch self {
        case .userCaches:
            return "archivebox"
        case .systemLogs:
            return "doc.text.magnifyingglass"
        case .xcodeDerivedData:
            return "hammer.fill"
        case .xcodeArchives:
            return "shippingbox.fill"
        case .packageManagerCaches:
            return "cube.box"
        case .browserCaches:
            return "safari"
        }
    }

    public var explanation: String {
        switch self {
        case .userCaches:
            return "Temporary application caches in ~/Library/Caches safely recreated on launch."
        case .systemLogs:
            return "Diagnostic reports and historical application logs in ~/Library/Logs."
        case .xcodeDerivedData:
            return "Intermediate build artifacts, module caches, and index files from Xcode."
        case .xcodeArchives:
            return "Old application archive packages in ~/Library/Developer/Xcode/Archives."
        case .packageManagerCaches:
            return "Homebrew, Cargo, and CocoaPods downloaded tarballs and build caches."
        case .browserCaches:
            return "Web content caches from Safari and Chrome."
        }
    }

    public var candidateDirectories: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .userCaches:
            return [home.appendingPathComponent("Library/Caches")]
        case .systemLogs:
            return [home.appendingPathComponent("Library/Logs")]
        case .xcodeDerivedData:
            return [home.appendingPathComponent("Library/Developer/Xcode/DerivedData")]
        case .xcodeArchives:
            return [home.appendingPathComponent("Library/Developer/Xcode/Archives")]
        case .packageManagerCaches:
            return [
                home.appendingPathComponent("Library/Caches/Homebrew"),
                home.appendingPathComponent(".cargo/registry/cache"),
                home.appendingPathComponent("Library/Caches/CocoaPods")
            ]
        case .browserCaches:
            return [
                home.appendingPathComponent("Library/Caches/com.apple.Safari"),
                home.appendingPathComponent("Library/Caches/Google/Chrome")
            ]
        }
    }
}
