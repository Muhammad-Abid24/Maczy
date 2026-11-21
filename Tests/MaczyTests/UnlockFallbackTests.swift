import XCTest
@testable import MaczyKit

final class UnlockFallbackTests: XCTestCase {

    func testBiometricStatusOperationalFlags() {
        XCTAssertTrue(BiometricEnrollmentStatus.enrolled.isOperational)
        XCTAssertFalse(BiometricEnrollmentStatus.notEnrolled.isOperational)
        XCTAssertFalse(BiometricEnrollmentStatus.hardwareUnavailable.isOperational)
        XCTAssertFalse(BiometricEnrollmentStatus.passcodeNotSet.isOperational)
        XCTAssertFalse(BiometricEnrollmentStatus.lockedOut.isOperational)
        XCTAssertFalse(BiometricEnrollmentStatus.unknown.isOperational)
    }

    func testMockEvaluatorBehavior() {
        let mock = MockBiometricStatusEvaluator(
            statusToReturn: BiometricCapabilityStatus(
                isAvailable: false,
                enrollmentStatus: .hardwareUnavailable,
                details: "No Touch ID sensor found"
            ),
            canAuthWithPasscode: true
        )

        let status = mock.evaluateBiometricStatus()
        XCTAssertFalse(status.isAvailable)
        XCTAssertEqual(status.enrollmentStatus, .hardwareUnavailable)
        XCTAssertEqual(status.details, "No Touch ID sensor found")
        XCTAssertTrue(mock.evaluateDeviceOwnerAuth())
    }

    @MainActor
    func testFallbackManagerStatusAndEvaluatorSwap() {
        let mockEnrolled = MockBiometricStatusEvaluator(
            statusToReturn: BiometricCapabilityStatus(
                isAvailable: true,
                enrollmentStatus: .enrolled,
                details: "Touch ID Ready"
            ),
            canAuthWithPasscode: true
        )

        let manager = NativeUnlockFallbackManager(evaluator: mockEnrolled)
        XCTAssertTrue(manager.currentBiometricStatus.isAvailable)
        XCTAssertEqual(manager.currentBiometricStatus.enrollmentStatus, .enrolled)

        // Swap to unavailable
        let mockUnavailable = MockBiometricStatusEvaluator(
            statusToReturn: BiometricCapabilityStatus(
                isAvailable: false,
                enrollmentStatus: .notEnrolled,
                details: "No fingerprints enrolled"
            ),
            canAuthWithPasscode: true
        )

        manager.setEvaluator(mockUnavailable)
        XCTAssertFalse(manager.currentBiometricStatus.isAvailable)
        XCTAssertEqual(manager.currentBiometricStatus.enrollmentStatus, .notEnrolled)
    }

    func testSystemSettingsDeepLinkURLs() {
        let touchID = NativeUnlockFallbackManager.touchIDSettingsURL
        let password = NativeUnlockFallbackManager.passwordSettingsURL
        let watch = NativeUnlockFallbackManager.appleWatchSettingsURL

        XCTAssertEqual(touchID.scheme, "x-apple.systempreferences")
        XCTAssertEqual(password.scheme, "x-apple.systempreferences")
        XCTAssertEqual(watch.scheme, "x-apple.systempreferences")
    }

    func testSecurityBoundaryInvariant() {
        let statement = NativeUnlockFallbackManager.securityStatement
        XCTAssertTrue(statement.contains("Secure Enclave"))
        XCTAssertTrue(statement.contains("loginwindow"))
        XCTAssertTrue(statement.contains("Touch ID"))
        XCTAssertTrue(statement.contains("never collects, stores, or intercepts"))
    }

    @MainActor
    func testSmartUnlockFeasibilityGateFailsClosed() {
        let appState = AppState(debounceInterval: 0.0)

        // Must fail closed with CAPABILITY_UNSUPPORTED referring to MZ-023
        let result = appState.dispatch(.triggerSessionUnlock)
        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.errorCode, "CAPABILITY_UNSUPPORTED")
        XCTAssertTrue(result.message?.contains("MZ-023") == true)
    }
}
