import XCTest
@testable import MaczyKit

@MainActor
final class PerformanceHarnessTests: XCTestCase {

    /// Measures cold initialization latency of AppState and the 7 modules.
    func testPerfAppStateInitializationLatency() {
        let iterations = 500
        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            let state = AppState()
            XCTAssertEqual(state.modules.count, 7)
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let perInitMs = (elapsed / Double(iterations)) * 1000.0

        print(String(format: "[PERF] AppState initialization x%d: total=%.4fs, avg=%.4fms", iterations, elapsed, perInitMs))
        // Target: < 10.0 ms per initialization
        XCTAssertLessThan(perInitMs, 10.0, "AppState initialization exceeded latency threshold")
    }

    /// Measures rapid UI state tab switching and property mutations.
    func testPerfTabSwitchingThroughput() {
        let appState = AppState()
        let iterations = 5_000
        let start = CFAbsoluteTimeGetCurrent()

        for i in 0..<iterations {
            appState.selectedTab = (i % 2 == 0) ? .overview : .permissions
            appState.isSidebarExpanded = (i % 2 == 0)
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let perOpUs = (elapsed / Double(iterations * 2)) * 1_000_000.0

        print(String(format: "[PERF] Tab & sidebar toggling x%d: total=%.4fs, avg=%.2fµs/op", iterations * 2, elapsed, perOpUs))
        // Target: < 50 µs per state mutation
        XCTAssertLessThan(perOpUs, 50.0, "State mutation exceeded latency threshold")
    }

    /// Measures system permission status preflight query latency (TCC IPC query overhead).
    func testPerfPermissionCheckQueryLatency() {
        let manager = PermissionManager.shared
        let iterations = 100
        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            for perm in MaczyPermission.allCases {
                _ = manager.checkStatus(for: perm)
            }
        }

        let totalChecks = iterations * MaczyPermission.allCases.count
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let perCheckMs = (elapsed / Double(totalChecks)) * 1000.0

        print(String(format: "[PERF] Permission queries x%d: total=%.4fs, avg=%.3fms/check", totalChecks, elapsed, perCheckMs))
        // Direct macOS TCC IPC round-trip must complete in under 50ms per query
        XCTAssertLessThan(perCheckMs, 50.0, "Permission query exceeded latency threshold")
    }

    /// Measures action pipeline evaluation and debounce throughput.
    func testPerfActionPipelineAndDebounceThroughput() {
        let appState = AppState(debounceInterval: 0.2)
        appState.setPermissionState(.screenRecording, state: .granted)

        let iterations = 5_000
        let start = CFAbsoluteTimeGetCurrent()

        var acceptedCount = 0
        var debouncedCount = 0

        for _ in 0..<iterations {
            let result = appState.dispatch(.captureScreenshot(mode: "area"))
            if result.ok {
                acceptedCount += 1
            } else if result.errorCode == "ACTION_DEBOUNCED" {
                debouncedCount += 1
            }
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let perEvalUs = (elapsed / Double(iterations)) * 1_000_000.0

        print(String(format: "[PERF] Action dispatch x%d: total=%.4fs, accepted=%d, debounced=%d, avg=%.2fµs",
                     iterations, elapsed, acceptedCount, debouncedCount, perEvalUs))
        XCTAssertEqual(acceptedCount, 1, "Only first rapid action should succeed within debounce window")
        XCTAssertEqual(debouncedCount, iterations - 1, "Subsequent rapid actions must be debounced")
        XCTAssertLessThan(perEvalUs, 50.0, "Pipeline evaluation exceeded latency threshold")
    }
}
