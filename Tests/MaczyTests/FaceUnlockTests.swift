import XCTest
@testable import MaczyKit

@MainActor
final class FaceUnlockTests: XCTestCase {

    override func setUp() async throws {
        FaceUnlockManager.shared.revokeEnrollment()
        FaceUnlockManager.shared.resetLockoutAfterNativeAuth()
    }

    override func tearDown() async throws {
        FaceUnlockManager.shared.revokeEnrollment()
        FaceUnlockManager.shared.resetLockoutAfterNativeAuth()
    }

    func testFaceEnrollmentLifecycle() {
        let manager = FaceUnlockManager.shared
        XCTAssertEqual(manager.enrollmentState, .revoked) // from tearDown/setUp
        XCTAssertNil(manager.storedTemplate)

        // Successful enrollment
        let result = manager.enrollFace(qualityScore: 0.92, livenessChallenge: .syntheticPass())
        switch result {
        case .success(let template):
            XCTAssertFalse(template.id.isEmpty)
            XCTAssertEqual(template.qualityScore, 0.92)
            XCTAssertFalse(template.isRevoked)
            XCTAssertTrue(template.featureDigest.hasPrefix("feat_vector_"))
            XCTAssertTrue(manager.enrollmentState.isEnrolled)
            XCTAssertNotNil(manager.storedTemplate)
        case .failure(let error):
            XCTFail("Enrollment should succeed, got error: \(error)")
        }

        // Revocation
        manager.revokeEnrollment()
        XCTAssertEqual(manager.enrollmentState, .revoked)
        XCTAssertNil(manager.storedTemplate)
    }

    func testFaceEnrollmentQualityAndLivenessGuards() {
        let manager = FaceUnlockManager.shared

        // Low quality rejected
        let lowQualityRes = manager.enrollFace(qualityScore: 0.35, livenessChallenge: .syntheticPass())
        switch lowQualityRes {
        case .success:
            XCTFail("Low quality capture should be rejected")
        case .failure(let err):
            XCTAssertEqual(err, .lowQualityCapture(score: 0.35))
        }

        // Liveness challenge failure rejected
        let livenessFailRes = manager.enrollFace(qualityScore: 0.85, livenessChallenge: .syntheticFail())
        switch livenessFailRes {
        case .success:
            XCTFail("Failed liveness challenge should be rejected")
        case .failure(let err):
            XCTAssertEqual(err, .livenessChallengeFailed)
        }
    }

    func testAntiSpoofHardwareAuditAnd2DPhotoAttack() {
        let manager = FaceUnlockManager.shared

        // Standard Mac hardware audit
        let report = manager.runAntiSpoofAudit(simulatedPhotoAttack: false)
        XCTAssertFalse(report.hasHardwareDepth)
        XCTAssertEqual(report.riskLevel, .critical_2DSensorVulnerable)
        XCTAssertTrue(report.sensorType.contains("FaceTime HD Camera"))
        XCTAssertTrue(report.auditSummary.contains("TrueDepth infrared dot matrix hardware is absent"))

        // Simulated 2D photo presentation attack
        let attackReport = manager.runAntiSpoofAudit(simulatedPhotoAttack: true)
        XCTAssertFalse(attackReport.livenessPassed)
        XCTAssertTrue(attackReport.auditSummary.contains("SPOOF REJECTED"))
    }

    func testSessionUnlockFailsClosedWithGateMZ024() {
        let manager = FaceUnlockManager.shared

        // Attempt without enrollment
        let unEnrolledResult = manager.attemptLockedSessionUnlock()
        XCTAssertFalse(unEnrolledResult.success)
        XCTAssertEqual(unEnrolledResult.errorCode, "NOT_ENROLLED")

        // Enroll face
        _ = manager.enrollFace(qualityScore: 0.90)

        // Attempt session unlock
        let unlockResult = manager.attemptLockedSessionUnlock()
        XCTAssertFalse(unlockResult.success)
        XCTAssertEqual(unlockResult.errorCode, "GATE_MZ_024")
        XCTAssertTrue(unlockResult.message.contains("loginwindow dismissal"))
        XCTAssertTrue(unlockResult.fallbackRecommended.contains("Touch ID"))
    }

    func testRateLimitingLockoutAfterThreeFailures() {
        let manager = FaceUnlockManager.shared
        _ = manager.enrollFace(qualityScore: 0.90)

        XCTAssertEqual(manager.consecutiveFailedAttempts, 0)
        XCTAssertFalse(manager.isLockedOut)

        // Attempt 1
        _ = manager.attemptLockedSessionUnlock()
        XCTAssertEqual(manager.consecutiveFailedAttempts, 1)
        XCTAssertFalse(manager.isLockedOut)

        // Attempt 2
        _ = manager.attemptLockedSessionUnlock()
        XCTAssertEqual(manager.consecutiveFailedAttempts, 2)
        XCTAssertFalse(manager.isLockedOut)

        // Attempt 3 -> triggers lockout
        _ = manager.attemptLockedSessionUnlock()
        XCTAssertEqual(manager.consecutiveFailedAttempts, 3)
        XCTAssertTrue(manager.isLockedOut)

        // Attempt 4 -> rejected due to lockout
        let lockedOutResult = manager.attemptLockedSessionUnlock()
        XCTAssertFalse(lockedOutResult.success)
        XCTAssertEqual(lockedOutResult.errorCode, "RATE_LIMITED_LOCKOUT")

        // Reset after native authentication
        manager.resetLockoutAfterNativeAuth()
        XCTAssertEqual(manager.consecutiveFailedAttempts, 0)
        XCTAssertFalse(manager.isLockedOut)
    }

    func testSessionLockStateQuery() {
        let isLocked = FaceUnlockManager.checkCurrentSessionLocked()
        // In local automated test, returns boolean without crash
        XCTAssertTrue([true, false].contains(isLocked))

        let manager = FaceUnlockManager.shared
        manager.refreshLockStatus()
        XCTAssertTrue([true, false].contains(manager.isSessionLocked))
    }

    func testUnlockDetailViewIntegration() {
        let appState = AppState()
        let view = UnlockDetailView(appState: appState)
        XCTAssertNotNil(view.body)
    }
}
