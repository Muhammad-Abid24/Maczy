# TASK.md — Current Antigravity Task

## Active selection: FIX-ALWAYS-ON-SYSTEM-ONLY-MODE (DONE) — Always On System Only Mode Activation & UI Sync
**Objective:** Fix the "System Only" mode in Always On module so that toggling it updates the UI immediately, persists across sessions, allows starting an awake session directly with the active mode, and correctly manages IOPM assertions on macOS.

### Completed this task
- [x] **Switched to Main & Pulled**: Checked out `main` and pulled latest upstream commits.
- [x] **Created New Branch**: Created branch `fix/always-on-system-only-mode` directly off updated `main`.
- [x] **Direct SwiftUI Observation in AlwaysOnDetailView**:
  - Bound `alwaysOnManager` as `@ObservedObject private var alwaysOnManager: AlwaysOnManager` to ensure SwiftUI automatically re-renders when `currentMode`, `isActive`, or other state changes.
  - Added primary "Start Always On" action button in the idle hero card showing the selected mode (`Mode ready: ...`).
- [x] **Mode Persistence & Management (`AlwaysOnManager.swift`)**:
  - Persisted user's selected mode (`AlwaysOnMode`) to `UserDefaults` under key `maczy_always_on_mode`.
  - Automatically loads and applies saved mode on `AlwaysOnManager` initialization.
  - Ensures mode changes correctly update `activeSession?.mode` and switch the underlying IOPM power assertion (`kIOPMAssertionTypePreventUserIdleSystemSleep` vs `kIOPMAssertionTypePreventUserIdleDisplaySleep`).
- [x] **MenuBar Quick Mode Toggles (`MenuBarView.swift`)**:
  - Added segmented mode switcher ("Display & System" vs "System Only") directly inside the Menu Bar popover.
- [x] **Unit Testing & Verification**:
  - Added `testSystemOnlyModePersistenceAndDirectStart()` in `AlwaysOnTests.swift` verifying persistence, dynamic assertion switching, and default initialization.
  - Validated with `./scripts/ci.sh`: all 20 Rust unit + perf tests and 219 Swift tests passed with 0 errors and 0 warnings, followed by Xcode build and ad-hoc codesign.
- [x] **Branch & Push**:
  - Committed and pushed strictly to branch `fix/always-on-system-only-mode`.
