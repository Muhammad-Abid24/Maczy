# TASK.md — Current Antigravity Task

## Active selection: MZ-014 (DONE) — Battery Charge Limit Selection (80/85/90/95/100) + Verified Backend Readback & Safe Unsupported State
**Objective:** Implement Battery Guardian configurable charge limit ceilings (80%, 85%, 90%, 95%, 100%), hardware write controls & readback, safe unsupported state handling, and verified backend unit tests.

### Completed this task
- [x] **Switched to Main & Pulled**: Checked out `main` and pulled latest upstream commits (`ffb36c6`).
- [x] **Created New Feature Branch**: Created branch `feat/mz-014-charge-limit-controls` directly off updated `main`.
- [x] **Backend & Manager Architecture (`ChargeLimitBackend.swift`)**:
  - Defined `ChargeLimitBackendProtocol` with `isSupported`, `hardwareModel`, `readCurrentLimit()`, and `writeLimit(percentage)`.
  - Implemented `NativeSMCChargeLimitBackend`: queries sysctl `hw.model`, detects desktop vs portable Macs, checks authorization / privilege level, verifies ceiling write, and persists preference in `UserDefaults`.
  - Implemented `MockChargeLimitBackend`: provides verified test harness for setting valid limits (80, 85, 90, 95, 100), readback confirmation, invalid percentage rejection, and safe unsupported state simulation.
  - Implemented `ChargeLimitManager` (`@MainActor ObservableObject`): manages active readback ceiling, supported state, status messages, and live notifications.
- [x] **State & Action Pipeline (`AppState.swift`, `maczy-core`)**:
  - Integrated `ChargeLimitManager` into `AppState`.
  - Handled `.selectChargeLimit(percentage)`: validates percentages [80, 85, 90, 95, 100], updates runtime status to running upon readback verification, and fails closed safely with `GATE_MZ_014` when unprivileged.
  - Enhanced Rust core `AppState` with `enable_charge_limit_backend()` and `get_charge_limit()` for verified backend execution and readback.
- [x] **UI & Readback Surfaces (`BatteryDetailView.swift`, `MenuBarView.swift`)**:
  - Bound `chargeLimitManager` into `BatteryDetailView` with live readback pill (`Active Ceiling: XX% (Readback Verified)`).
  - Added safe unsupported state banner for desktop Macs or environments without hardware battery support.
  - Added active ceiling readback indicator in MenuBar popover Battery Guardian section.
- [x] **Testing & CI Verification**:
  - Added unit tests in `BatteryMonitoringTests.swift`:
    - `testChargeLimitSelection80To100WithVerifiedBackend`: verified 80/85/90/95/100 limit writes and readback.
    - `testChargeLimitRejectsInvalidPercentages`: verified rejection of 0, 50, 73, 99, 105.
    - `testChargeLimitSafeUnsupportedState`: verified safe fallback on desktop/unsupported hardware.
    - `testChargeLimitAppStateIntegrationWithVerifiedBackend`: verified `AppState` dispatch pipeline and module runtime state.
    - `testNativeSMCBackendSafetyChecks`: verified unprivileged fail-closed behavior.
  - Added Rust tests in `crates/maczy-core/src/lib.rs` verifying backend gating, limit selection, and readback.
  - Ran `./scripts/ci.sh`: zero warnings, zero errors.
- [x] **Branch & Push**:
  - Committed and pushed strictly to branch `feat/mz-014-charge-limit-controls`.
