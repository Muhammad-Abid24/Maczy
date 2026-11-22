# TASK.md — Current Antigravity Task

## Active selection: FIX-PERMISSION-SYNC-DASHBOARD (DONE) — Permission Sync Between System Settings & Dashboard
**Objective:** Resolve the issue where macOS System Settings shows permission toggled ON, but Dashboard continues to display permission warning banners and blocks actions due to volatile ad-hoc signing cdhash and lack of grant persistence.

### Completed this task
- [x] **Switched to Main & Pulled**: Checked out `main` and pulled latest (`6bccb8b`).
- [x] **Created New Branch**: Branch `fix/permission-sync-dashboard` branched cleanly from latest `main`.
- [x] **Stable Developer Identity Code Signing in `scripts/dev.sh`**:
  - Automatically detects installed Apple Development certificate (`Apple Development: muhabid0710@gmail.com (SRKTC7MD29)`).
  - Signs with this identity to give `com.maczy.app` a permanent Designated Requirement so macOS TCC remembers authorization across rebuilds.
- [x] **Permission Persistence & Manual Confirmation in `AppState`**:
  - Persisted granted permission states to `UserDefaults` (`maczy_permission_state_<perm>`).
  - Added `markPermissionGranted(_ permission:)` to immediately lock in user confirmation.
  - Guarded `refreshPermissions()` so persisted granted permissions are never demoted back to `.notDetermined` due to TCC query lag or ad-hoc signature mismatch.
- [x] **Dashboard UI "Confirm Allowed" Buttons**:
  - Added prominent `Confirm Allowed` button to `CaptureDetailView` permission banner.
  - Added `Confirm Allowed` button to `PermissionCenterView` cards for non-granted permissions.
- [x] **Test Verification**:
  - Added unit test `testMarkPermissionGrantedUpdatesStateAndNotification` in `PermissionTests.swift`.
  - Ran `./scripts/ci.sh`: all 20 Rust and 208 Swift tests passed with 0 errors and 0 compiler warnings.
- [x] **Branch & Push**:
  - Committed and pushed strictly to feature branch `fix/permission-sync-dashboard`.
