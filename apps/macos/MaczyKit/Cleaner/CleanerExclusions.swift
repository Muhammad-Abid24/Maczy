import Foundation

public struct CleanerExclusions: Sendable {
    private static let excludedPathPrefixes: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/private",
        "/etc",
        "/var/db",
        "/Library/Keychains"
    ]

    private static let excludedDirectoryNames: Set<String> = [
        ".git",
        ".svn",
        ".hg",
        ".ssh",
        ".gnupg",
        ".aws",
        "Keychains",
        "1Password",
        "Bitwarden",
        "Keepass",
        "OpenVPN"
    ]

    private static let excludedFileExtensions: Set<String> = [
        "sqlite",
        "sqlite-wal",
        "sqlite-shm",
        "db",
        "keychain",
        "keychain-db",
        "pem",
        "key",
        "p12",
        "pfx"
    ]

    /// Evaluates whether a given path is strictly protected from scanning or purge.
    public static func isProtected(path: String) -> (isProtected: Bool, reason: String?) {
        let normalized = (path as NSString).standardizingPath

        // 1. Check system directory prefixes
        for prefix in excludedPathPrefixes {
            if normalized.hasPrefix(prefix) {
                return (true, "Protected system path: \(prefix)")
            }
        }

        let url = URL(fileURLWithPath: normalized)
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // 2. Protect user personal content roots
        let personalRoots = [
            (home as NSString).appendingPathComponent("Documents"),
            (home as NSString).appendingPathComponent("Desktop"),
            (home as NSString).appendingPathComponent("Downloads"),
            (home as NSString).appendingPathComponent("Pictures"),
            (home as NSString).appendingPathComponent("Movies"),
            (home as NSString).appendingPathComponent("Music")
        ]
        for root in personalRoots {
            if normalized == root || normalized.hasPrefix(root + "/") {
                return (true, "Protected user personal document directory")
            }
        }

        // 3. Check for security/credential sensitive directory components
        let components = url.pathComponents
        for component in components {
            if excludedDirectoryNames.contains(component) {
                return (true, "Protected credential or source repository directory: \(component)")
            }
        }

        // 4. Check for database or key file extensions
        let ext = url.pathExtension.lowercased()
        if excludedFileExtensions.contains(ext) {
            return (true, "Protected database or cryptographic key file (.\(ext))")
        }

        return (false, nil)
    }
}
