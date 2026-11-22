# TASK.md — Current Antigravity Task

## Active selection: FIX-TRUTHFUL-TCC-PERMISSION-CAPTURE (DONE) — Enforce Truthful System TCC Authorization & Preflight Capture Guarding
**Objective:** Resolve discrepancy where the dashboard reported "Permission Granted" while macOS still required Screen Recording authorization, guard against capture attempts when unauthorized, and clearly guide the user through the macOS TCC relaunch requirement.

### Completed this task
- [x] **Switched to Main & Pulled**: Base commit `6c00198` on `main`.
- [x] **Created New Feature/Fix Branch**: Created branch `fix/truthful-tcc-permission-capture` directly off updated `main`.
- [x] **Truthful Live TCC Permission Synchronization (`AppState.swift`)**:
  - Removed stale `UserDefaults` caching in `AppState.init` that persisted false-positive `.granted` badges across app launches.
  - Ensured `refreshPermissions()` strictly reflects `PermissionManager.shared.checkStatus(for:)` without falling back to stale in-memory granted flags.
  - Live TCC gate in `dispatch(.captureScreenshot)` queries actual system status while respecting test mock overrides.
- [x] **Pre-flight Authorization Guard (`CaptureCoordinator.swift`)**:
  - Added pre-flight check at the beginning of `triggerCapture(mode:)`:
    ```swift
    guard ScreenCaptureEngine.shared.isAuthorized() else {
        _ = CGRequestScreenCaptureAccess()
        PermissionManager.shared.openSettings(for: .screenRecording)
        self.handleCaptureFailure(.permissionDenied)
        return
    }
    ```
    Prevents area selection overlays from activating when Screen Recording is not permitted, triggering the system prompt and deep-linking directly to System Settings.
- [x] **Clear Guidance & UI Actions (`CaptureDetailView.swift`, `PermissionCenterView.swift`)**:
  - Removed misleading manual "Confirm Allowed" override buttons.
  - Banner clearly explains that after toggling Maczy ON in System Settings, a relaunch is required so macOS injects the Mach authorization token into the process.
  - Added direct "Relaunch App" button calling `PermissionManager.shared.relaunchApp()`.
- [x] **Validation**:
  - Ran `./scripts/ci.sh`: all 20 Rust unit + perf tests and 211 Swift unit tests passed with 0 errors and 0 warnings, followed by successful Xcode arm64 build and ad-hoc code sign verification.
- [x] **Branch & Push**:
  - Committed and pushed strictly to `fix/truthful-tcc-permission-capture`.
