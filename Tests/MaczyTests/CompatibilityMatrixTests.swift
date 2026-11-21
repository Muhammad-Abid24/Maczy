import XCTest
@testable import MaczyKit

final class CompatibilityMatrixTests: XCTestCase {

    func testOSVersionTiers() {
        // macOS 13 Ventura -> Unsupported
        let ventura = OperatingSystemVersion(majorVersion: 13, minorVersion: 6, patchVersion: 0)
        XCTAssertEqual(CompatibilityMatrix.evaluateOSVersion(ventura), .unsupported)
        XCTAssertFalse(CompatibilityMatrix.evaluateOSVersion(ventura).isExecutable)

        // macOS 14 Sonoma -> Tier 1 Supported
        let sonoma = OperatingSystemVersion(majorVersion: 14, minorVersion: 5, patchVersion: 0)
        XCTAssertEqual(CompatibilityMatrix.evaluateOSVersion(sonoma), .tier1Supported)
        XCTAssertTrue(CompatibilityMatrix.evaluateOSVersion(sonoma).isExecutable)

        // macOS 15 Sequoia -> Tier 1 Supported
        let sequoia = OperatingSystemVersion(majorVersion: 15, minorVersion: 1, patchVersion: 0)
        XCTAssertEqual(CompatibilityMatrix.evaluateOSVersion(sequoia), .tier1Supported)

        // macOS 16 -> Tier 2 Forward Projected
        let macOS16 = OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 0)
        XCTAssertEqual(CompatibilityMatrix.evaluateOSVersion(macOS16), .tier2ForwardProjected)

        // macOS 27 -> Tier 2 Forward Projected
        let macOS27 = OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)
        XCTAssertEqual(CompatibilityMatrix.evaluateOSVersion(macOS27), .tier2ForwardProjected)
        XCTAssertTrue(CompatibilityMatrix.evaluateOSVersion(macOS27).isExecutable)
    }

    func testHardwareArchitecture() {
        XCTAssertTrue(CompatibilityMatrix.isArchitectureSupported("arm64"))
        XCTAssertTrue(CompatibilityMatrix.isArchitectureSupported("ARM64"))
        XCTAssertTrue(CompatibilityMatrix.isArchitectureSupported("aarch64"))

        XCTAssertFalse(CompatibilityMatrix.isArchitectureSupported("x86_64"))
        XCTAssertFalse(CompatibilityMatrix.isArchitectureSupported("i386"))
    }

    func testSystemValidationCombinations() {
        // Valid Apple Silicon macOS 14
        let valid = CompatibilityMatrix.validateSystem(
            osVersion: OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0),
            architecture: "arm64"
        )
        XCTAssertTrue(valid.isSupported)
        XCTAssertEqual(valid.tier, .tier1Supported)

        // Invalid OS (macOS 12)
        let oldOS = CompatibilityMatrix.validateSystem(
            osVersion: OperatingSystemVersion(majorVersion: 12, minorVersion: 0, patchVersion: 0),
            architecture: "arm64"
        )
        XCTAssertFalse(oldOS.isSupported)
        XCTAssertEqual(oldOS.tier, .unsupported)

        // Invalid Architecture (x86_64)
        let intel = CompatibilityMatrix.validateSystem(
            osVersion: OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0),
            architecture: "x86_64"
        )
        XCTAssertFalse(intel.isSupported)
    }

    func testLicenseComplianceAndAbsenceOfCopyleft() {
        XCTAssertTrue(CompatibilityMatrix.verifyLicenseCompliance())

        for entry in CompatibilityMatrix.dependencyLicenses {
            XCTAssertFalse(entry.isCopyleft, "\(entry.name) must not be copyleft")
            XCTAssertTrue(
                entry.license.contains("MIT") || entry.license.contains("Apache"),
                "License \(entry.license) for \(entry.name) must be permissive"
            )
        }
    }

    func testAPIRiskRegisterCoverage() {
        XCTAssertEqual(CompatibilityMatrix.apiRiskRegister.count, 8)

        let unlockRisk = CompatibilityMatrix.apiRiskRegister.first { $0.id == "unlock" }
        XCTAssertEqual(unlockRisk?.riskLevel, .critical)
        XCTAssertTrue(unlockRisk?.mitigation.contains("MZ-023") == true)

        let snapRisk = CompatibilityMatrix.apiRiskRegister.first { $0.id == "snap" }
        XCTAssertEqual(snapRisk?.riskLevel, .medium)
    }
}
