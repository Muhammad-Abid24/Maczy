import Foundation
import Combine

public enum UpdateStatus: Equatable, Sendable {
    case idle
    case checking
    case upToDate(version: String)
    case updateAvailable(item: AppcastItem)
    case error(message: String)

    public var statusText: String {
        switch self {
        case .idle:
            return "Idle"
        case .checking:
            return "Checking for updates..."
        case .upToDate(let ver):
            return "Up to date (v\(ver))"
        case .updateAvailable(let item):
            return "Update available: v\(item.version)"
        case .error(let msg):
            return "Error: \(msg)"
        }
    }
}

@MainActor
public final class UpdateManager: ObservableObject {
    @Published public var selectedChannel: UpdateChannel = .stable
    @Published public var automaticallyChecksForUpdates: Bool = true
    @Published public private(set) var status: UpdateStatus = .idle
    @Published public private(set) var currentVersion: String = "0.1.0"
    @Published public private(set) var currentBuild: String = "1"
    @Published public private(set) var lastCheckedDate: Date? = nil

    private let checkerProvider: UpdateCheckerProvider

    public init(
        checkerProvider: UpdateCheckerProvider = MockUpdateCheckerProvider(),
        currentVersion: String = "0.1.0",
        currentBuild: String = "1"
    ) {
        self.checkerProvider = checkerProvider
        self.currentVersion = currentVersion
        self.currentBuild = currentBuild
    }

    public func setChannel(_ channel: UpdateChannel) {
        guard channel != selectedChannel else { return }
        selectedChannel = channel
        status = .idle
    }

    public func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        automaticallyChecksForUpdates = enabled
    }

    @discardableResult
    public func checkForUpdates() async -> UpdateStatus {
        status = .checking
        do {
            let result = try await checkerProvider.checkForUpdates(
                channel: selectedChannel,
                currentVersion: currentVersion
            )
            lastCheckedDate = Date()
            switch result {
            case .upToDate(let ver):
                status = .upToDate(version: ver)
            case .updateAvailable(let item, _):
                // Enforce signature check
                guard item.hasValidSignatureMetadata else {
                    let err = UpdateError.unsignedUpdateItem(version: item.version)
                    status = .error(message: err.localizedDescription)
                    return status
                }
                status = .updateAvailable(item: item)
            }
        } catch {
            lastCheckedDate = Date()
            status = .error(message: error.localizedDescription)
        }
        return status
    }
}
