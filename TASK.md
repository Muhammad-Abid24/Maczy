# TASK.md — Current Antigravity Task

## Active selection: MZ-014 (DONE) — Battery Charge Limit Selection (80/85/90/95/100) + Verified Backend Readback & Safe Unsupported State
**Objective:** Implement Battery Guardian configurable charge limit ceilings (80%, 85%, 90%, 95%, 100%), hardware write controls & readback, safe unsupported state handling, and verified backend unit tests.

### Completed this task
- [x] **Switched to Main & Pulled**: Checked out `main` and pulled latest upstream commits (`ffb36c6`).
- [x] **Created New Feature Branch**: Created branch `feat/mz-014-charge-limit-controls` directly off updated `main`.
- [x] **Real-Time Telemetry & Zero Refresh Button (`BatteryMonitor.swift`, `BatteryDetailView.swift`)**:
  - Implemented event-driven IOKit Power Sources RunLoop Source registration (`IOPSNotificationCreateRunLoopSource` on `CFRunLoopGetMain()`) for zero-latency notifications on charger plug/unplug, charging state toggle, and battery percentage changes.
  - Added periodic 2.0-second fallback timer in `BatteryMonitor` for continuous cell temperature, voltage, and amperage telemetry.
  - Started monitoring automatically upon app initialization (`autoStart && !isRunningTests`).
  - **Completely removed manual Refresh button** from Battery Guardian header; replaced with live pulsing "Live Real-Time" telemetry indicator badge.
  - Refined charging state status strings: dynamically displays `AC Connected (Charging)` vs `AC Connected (Not Charging)` vs `Discharging` in real-time.
- [x] **Batt Daemon Integration & Ceiling Enforcement (`ChargeLimitBackend.swift`)**:
  - Connected to `/var/run/batt.sock` with HTTP `PUT /limit` protocol and accepted `201 Created` / `200 OK`.
  - Added `writeAdapter(enabled: Bool)` to `BattDaemonClient` via `PUT /adapter`.
  - Added `readAdapterStatus` and `writeAdapter` to `ChargeLimitBackendProtocol` and `NativeSMCChargeLimitBackend`.
  - Persisted user approval for hardware write tests in `UserDefaults` so authorization persists across sessions.
- [x] **Ceiling Overshoot & Discharge Control Handling (`BatteryDetailView.swift`, `ChargeLimitManager.swift`)**:
  - Added overshoot banner when current battery percentage exceeds the active charge limit (e.g. 90% > 85%).
  - Clarified SMC power bypass behavior: explains that charging is stopped (0 mA draw) and hardware will hold at current SoC without further charging.
  - Added "Discharge to Ceiling (85%) on Battery" action calling `startDischargeToCeiling()` (temporarily disabling power adapter).
  - Added auto-termination in `AppState`: once battery discharges to effective limit, the power adapter is automatically re-enabled (`stopDischargeToCeiling()`) and locks at ceiling.
- [x] **Testing & CI Verification**:
  - Added tests in `BatteryMonitoringTests.swift`:
    - `testAdapterControlAndDischargeToCeiling`: verifies adapter toggle, discharge state, and fail-closed authorization check.
    - `testRealtimeMonitoringLifecycle`: verifies start/stop monitoring lifecycle and runloop source safety.
    - `testChargingStateRealtimeDisplayStrings`: verifies display strings for AC Connected (Charging), AC Connected (Not Charging), and Discharging.
  - Executed `./scripts/ci.sh`: Rust fmt, clippy (0 warnings), 21 Rust tests, 228 Swift tests pass, Xcode arm64 build, and ad-hoc codesign passed in 36s.
  - Executed `./scripts/dev.sh`: Rebuilt, codesigned, and re-launched `/Users/muhammadabid/Applications/Maczy.app`.
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
