import Foundation

public struct SemanticVersion: Comparable, Equatable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: String?
    public let rawString: String

    public init?(_ versionString: String) {
        let trimmed = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        guard !trimmed.isEmpty else { return nil }

        self.rawString = trimmed
        let parts = trimmed.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
        let mainParts = parts[0].split(separator: ".")

        guard mainParts.count >= 1, let maj = Int(mainParts[0]) else { return nil }
        self.major = maj
        self.minor = mainParts.count >= 2 ? (Int(mainParts[1]) ?? 0) : 0
        self.patch = mainParts.count >= 3 ? (Int(mainParts[2]) ?? 0) : 0

        if parts.count > 1 {
            self.prerelease = String(parts[1])
        } else {
            self.prerelease = nil
        }
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        if lhs.patch != rhs.patch {
            return lhs.patch < rhs.patch
        }
        // If versions are equal, a release version is greater than a prerelease version
        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil):
            return false
        case (.some, nil):
            // lhs is prerelease, rhs is final release -> lhs < rhs
            return true
        case (nil, .some):
            // lhs is final release, rhs is prerelease -> lhs > rhs
            return false
        case let (pre1?, pre2?):
            return pre1 < pre2
        }
    }
}
