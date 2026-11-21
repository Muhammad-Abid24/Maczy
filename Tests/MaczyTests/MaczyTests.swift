import XCTest
@testable import MaczyKit

final class MaczyTests: XCTestCase {
    func testModuleCountIsExactlySeven() {
        XCTAssertEqual(MaczyModuleId.allCases.count, 7, "Maczy must have exactly 7 defined modules per PRD")
    }

    func testAllSevenModulesHaveDisplayNamesAndIcons() {
        for module in MaczyModuleId.allCases {
            XCTAssertFalse(module.displayName.isEmpty, "Module \(module.rawValue) must have a non-empty display name")
            XCTAssertFalse(module.iconName.isEmpty, "Module \(module.rawValue) must have an icon")
            XCTAssertFalse(module.summary.isEmpty, "Module \(module.rawValue) must have a summary")
        }
    }

    func testCoreBridgeModuleStatusReporting() {
        let bridge = MaczyCoreBridge.shared
        XCTAssertEqual(bridge.moduleCount, 7)
        XCTAssertEqual(bridge.targetArch, "arm64")
        XCTAssertEqual(bridge.minDeployment, "14.0")

        let statuses = bridge.fetchAllModuleStatuses()
        XCTAssertEqual(statuses.count, 7)

        for status in statuses {
            // MZ-001 scaffold: modules must truthfully report unimplemented
            XCTAssertFalse(status.isImplemented, "Scaffold module \(status.name) must report not implemented")
            XCTAssertEqual(status.runtimeState, .notImplemented)
            XCTAssertFalse(status.statusMessage.isEmpty)
        }
    }

    func testSmartUnlockSecurityMessageExplicit() {
        let bridge = MaczyCoreBridge.shared
        let statuses = bridge.fetchAllModuleStatuses()
        let smartUnlock = statuses.first { $0.id == .smartUnlock }

        XCTAssertNotNil(smartUnlock)
        XCTAssertTrue(smartUnlock!.statusMessage.contains("MZ-023"))
        XCTAssertTrue(smartUnlock!.statusMessage.contains("macOS Lock Screen"))
    }
}
