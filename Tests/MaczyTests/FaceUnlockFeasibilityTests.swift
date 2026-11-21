import XCTest
@testable import MaczyKit

final class FaceUnlockFeasibilityTests: XCTestCase {

    func testAllScenariosEvaluatedInFeasibilityReport() {
        XCTAssertEqual(LockScreenScenario.allCases.count, 6)
        XCTAssertEqual(FaceUnlockFeasibilityReport.scenarioResults.count, 6)

        // Ensure every scenario has a finding
        for scenario in LockScreenScenario.allCases {
            let finding = FaceUnlockFeasibilityReport.finding(for: scenario)
            XCTAssertNotNil(finding, "Missing finding for \(scenario.rawValue)")
            XCTAssertFalse(finding?.verdict.isExecutable ?? true)
            XCTAssertFalse(finding?.obstacle.isEmpty ?? true)
        }
    }

    func testTechnicalPathwaysAssessments() {
        XCTAssertEqual(TechnicalPathway.allCases.count, 4)
        for pathway in TechnicalPathway.allCases {
            XCTAssertFalse(pathway.assessment.isEmpty)
        }
    }

    func testOverallVerdictIsBlocked() {
        XCTAssertEqual(FaceUnlockFeasibilityReport.overallVerdict, .blocked)
        XCTAssertFalse(FaceUnlockFeasibilityReport.isMZ024ImplementationAuthorized)
    }

    @MainActor
    func testCapabilityGateBlocksEnrollmentAction() {
        let appState = AppState(debounceInterval: 0.0)

        let enrollResult = appState.dispatch(.requestFaceUnlockEnrollment)
        XCTAssertFalse(enrollResult.ok)
        XCTAssertEqual(enrollResult.errorCode, "CAPABILITY_UNSUPPORTED")
        XCTAssertTrue(enrollResult.message?.contains("MZ-023") == true)
    }

    @MainActor
    func testCapabilityGateBlocksSessionUnlockAction() {
        let appState = AppState(debounceInterval: 0.0)

        let unlockResult = appState.dispatch(.triggerSessionUnlock)
        XCTAssertFalse(unlockResult.ok)
        XCTAssertEqual(unlockResult.errorCode, "CAPABILITY_UNSUPPORTED")
        XCTAssertTrue(unlockResult.message?.contains("MZ-023") == true)
    }
}
