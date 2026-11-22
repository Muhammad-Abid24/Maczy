# TASK.md — Current Antigravity Task

## Active selection: MZ-007-FIX-CAPTURE-PERMISSIONS (DONE) — Fix Capture & Recording Execution + Dashboard Permission Synchronization
**Objective:** Resolve end-to-end screen capture and recording failures and fix permission synchronization in the Dashboard so that granted macOS permissions (Screen Recording, Microphone, Accessibility) properly reflect immediately and eliminate false-positive `PERMISSION_REQUIRED` blocks.

### Completed this task
- [x] **Live Permission State Synchronization**:
  - Upgraded `AppState.permissions` to `@Published public var permissions: [MaczyPermission: PermissionState] = [:]` so SwiftUI views reactively re-render when permissions change.
  - Implemented `@MainActor public func refreshPermissions()` in `AppState` that queries system TCC status via `PermissionManager.shared.checkStatus(for:)` for all permissions.
  - Bound `NSApplication.didBecomeActiveNotification` observers in `AppState`, `DashboardView`, `PermissionCenterView`, and `CaptureDetailView` to automatically refresh permission states when returning from macOS System Settings.
  - In `AppState.dispatch(...)`, added live TCC check during the permission gate: if `PermissionManager.shared.checkStatus(for: reqPerm) == .granted`, state is immediately promoted to `.granted`, permanently eliminating false-positive blocks.
  - Added "Refresh Status" button in `PermissionCenterView` header.
- [x] **Screen Capture & Window Target Fixes**:
  - In `ScreenCaptureEngine.captureWindow`: added intelligent resolution for `windowID == 0` to select the frontmost visible on-screen application window (excluding Maczy's own process ID).
  - In `ScreenCaptureEngine.captureArea`: corrected coordinate space mapping by flipping Y coordinates from AppKit's bottom-left origin to ScreenCaptureKit's top-left origin.
  - In `ScreenCaptureEngine.captureDisplay`: added fallback to `CGDisplayCreateImage` for display capture.
- [x] **Screen Recording Lifecycle Fixes**:
  - In `ScreenRecordingEngine.startRecording`: handled `windowID == 0` by dynamically resolving the frontmost application window.
  - In `CaptureDetailView`:
    - Added reactive Screen Recording permission status banner with deep link to System Settings and live "Refresh Status" button.
    - Added active recording progress indicator and a prominent "Stop Recording" button mapped to `MaczyAction.stopScreenRecording`.
    - Dynamically mapped screenshot mode ("area" -> "region", "window" -> "window", "fullscreen" -> "display") when starting recording.
- [x] **Unit & Integration Tests**:
  - Added `testAppStateRefreshPermissionsSync` and `testPublishedPermissionsDictionaryObservability` in `Tests/MaczyTests/PermissionTests.swift`.
  - Added `testCaptureWindowTargetZeroEquivalence` and `testAppStateStopScreenRecordingPipelineIntegration` in `Tests/MaczyTests/CaptureTests.swift`.
  - Passed all 20 Rust unit/perf tests + 206 Swift package tests with 0 errors and 0 warnings.
  - Verified Xcode arm64 build and ad-hoc code signing.
- [x] **Branch & Push**:
  - Committed and pushed strictly to feature branch `fix/dynamic-notch-layout-position` (NEVER to `main`).
