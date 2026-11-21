import AppKit
import Foundation

/// Errors that may occur when invoking system screen lock.
public enum SystemLockError: Error, Equatable, Sendable {
    case symbolNotFound
    case processExecutionFailed(String)
    case unauthorized
    case unknown(String)
}

/// Abstract system lock provider protocol enabling dependency injection for testing.
public protocol SystemLockProvider: Sendable {
    func executeLock() -> Result<String, SystemLockError>
}

/// Production system lock provider invoking native macOS PrivateFramework `login.framework`
/// via dynamic loading (`SACLockScreenImmediate`), with fallback to `CGSession -suspend`.
public final class NativeSystemLockProvider: SystemLockProvider {
    public init() {}

    public func executeLock() -> Result<String, SystemLockError> {
        // Method 1: SACLockScreenImmediate via login.framework
        if let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY) {
            defer { dlclose(handle) }
            if let sym = dlsym(handle, "SACLockScreenImmediate") {
                typealias SACLockScreenImmediateFunc = @convention(c) () -> Void
                let lockFunc = unsafeBitCast(sym, to: SACLockScreenImmediateFunc.self)
                lockFunc()
                return .success("Screen locked via SACLockScreenImmediate")
            }
        }

        // Method 2: CGSession fallback
        let cgSessionPath = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
        if FileManager.default.isExecutableFile(atPath: cgSessionPath) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cgSessionPath)
            process.arguments = ["-suspend"]
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    return .success("Screen locked via CGSession -suspend")
                } else {
                    return .failure(.processExecutionFailed("CGSession returned exit code \(process.terminationStatus)"))
                }
            } catch {
                return .failure(.processExecutionFailed(error.localizedDescription))
            }
        }

        return .failure(.symbolNotFound)
    }
}

/// Mock system lock provider for unit tests and headless CI validation.
public final class MockSystemLockProvider: SystemLockProvider, @unchecked Sendable {
    public var shouldSucceed: Bool
    public var lockCount: Int = 0
    private let lock = NSLock()

    public init(shouldSucceed: Bool = true) {
        self.shouldSucceed = shouldSucceed
    }

    public func executeLock() -> Result<String, SystemLockError> {
        lock.lock()
        defer { lock.unlock() }
        lockCount += 1
        if shouldSucceed {
            return .success("Mock screen locked successfully")
        } else {
            return .failure(.processExecutionFailed("Mock lock failure simulated"))
        }
    }
}

/// Coordinates system lock operations conforming to MZ-020.
/// Uses genuine macOS Lock Screen APIs without modifying authorizationdb or bypassing authentication.
@MainActor
public final class SystemLockManager: ObservableObject {
    public static let shared = SystemLockManager()

    public private(set) var provider: SystemLockProvider
    @Published public private(set) var lastLockAttemptDate: Date?
    @Published public private(set) var lastResult: CommandResult?

    public init(provider: SystemLockProvider = NativeSystemLockProvider()) {
        self.provider = provider
    }

    public func setProvider(_ provider: SystemLockProvider) {
        self.provider = provider
    }

    /// Triggers immediate macOS screen lock.
    @discardableResult
    public func lockScreen() -> CommandResult {
        self.lastLockAttemptDate = Date()
        let outcome = provider.executeLock()

        let result: CommandResult
        switch outcome {
        case .success(let detail):
            result = CommandResult.success(
                message: "System locked: \(detail)",
                observedValue: "locked"
            )
        case .failure(let err):
            result = CommandResult.failure(
                errorCode: "LOCK_ERROR",
                message: "Failed to lock screen: \(err)"
            )
        }

        self.lastResult = result
        return result
    }
}
