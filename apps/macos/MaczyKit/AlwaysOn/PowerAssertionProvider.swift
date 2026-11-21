import Foundation
import IOKit.pwr_mgt

public protocol PowerAssertionProvider: Sendable {
    func createAssertion(type: String, name: String, details: String) -> (id: UInt32, success: Bool)
    func releaseAssertion(id: UInt32) -> Bool
}

public final class NativePowerAssertionProvider: PowerAssertionProvider, @unchecked Sendable {
    public init() {}

    public func createAssertion(type: String, name: String, details: String) -> (id: UInt32, success: Bool) {
        var assertionID: IOPMAssertionID = 0
        let assertionName = "\(name): \(details)" as CFString
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            assertionName,
            &assertionID
        )
        return (UInt32(assertionID), result == kIOReturnSuccess)
    }

    public func releaseAssertion(id: UInt32) -> Bool {
        let result = IOPMAssertionRelease(IOPMAssertionID(id))
        return result == kIOReturnSuccess
    }
}

public final class MockPowerAssertionProvider: PowerAssertionProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var nextID: UInt32 = 100
    private var activeAssertions: Set<UInt32> = []

    public var shouldFail: Bool = false
    public var lastCreatedType: String?
    public var lastCreatedName: String?
    public var createdCount: Int = 0
    public var releasedCount: Int = 0

    public init() {}

    public func createAssertion(type: String, name: String, details: String) -> (id: UInt32, success: Bool) {
        lock.lock()
        defer { lock.unlock() }

        if shouldFail {
            return (0, false)
        }

        let newID = nextID
        nextID += 1
        activeAssertions.insert(newID)
        lastCreatedType = type
        lastCreatedName = "\(name): \(details)"
        createdCount += 1
        return (newID, true)
    }

    public func releaseAssertion(id: UInt32) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if activeAssertions.contains(id) {
            activeAssertions.remove(id)
            releasedCount += 1
            return true
        }
        return false
    }

    public var activeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return activeAssertions.count
    }

    public func isAssertionActive(id: UInt32) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeAssertions.contains(id)
    }
}
