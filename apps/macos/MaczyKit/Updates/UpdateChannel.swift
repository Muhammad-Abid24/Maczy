import Foundation

public enum UpdateChannel: String, CaseIterable, Identifiable, Sendable {
    case stable = "stable"
    case beta = "beta"
    case nightly = "nightly"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .stable: return "Stable"
        case .beta: return "Beta"
        case .nightly: return "Nightly"
        }
    }

    public var description: String {
        switch self {
        case .stable:
            return "Production-ready, thoroughly tested releases recommended for all users."
        case .beta:
            return "Early access to upcoming features and UI enhancements. May have minor bugs."
        case .nightly:
            return "Automated daily builds directly from GitHub main branch. For testers and developers."
        }
    }

    public var appcastURL: URL {
        switch self {
        case .stable:
            return URL(string: "https://raw.githubusercontent.com/Muhammad-Abid24/Maczy/main/appcast-stable.xml")!
        case .beta:
            return URL(string: "https://raw.githubusercontent.com/Muhammad-Abid24/Maczy/main/appcast-beta.xml")!
        case .nightly:
            return URL(string: "https://raw.githubusercontent.com/Muhammad-Abid24/Maczy/main/appcast-nightly.xml")!
        }
    }
}
