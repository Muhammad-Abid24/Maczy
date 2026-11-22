# TASK.md — Current Antigravity Task

## Active selection: MZ-015-CUSTOM-DIMENSIONS (DONE) — Customizable Dynamic Notch Dimensions (Width & Height)
**Objective:** Implement native macOS functionality allowing users to adjust and customize the width and height of the Dynamic Notch for both compact silhouette (idle / floating pill) and expanded HUD card, with live responsive resizing, persistent settings, reset-to-defaults capabilities, and domain action dispatch.

### Completed this task
- [x] **Geometry Engine Dynamic Sizing**:
  - Enhanced `NotchGeometry.detectProfile` with `customCompactSize: CGSize?` and `customExpandedSize: CGSize?`.
  - Centers and aligns the notch rect flush with the screen top/notch cutout using custom width and height across virtual, auto, and physical modes.
- [x] **Coordinator State & UserDefaults Persistence**:
  - Added `@Published customCompactWidth`, `customCompactHeight`, `customExpandedWidth`, `customExpandedHeight` to `NotchCoordinator`.
  - Automatically loads and persists values via `UserDefaults` keys (`maczy.notch.customCompactWidth`, etc.).
  - Added computed properties (`currentCompactWidth`, `currentCompactHeight`, etc.) and `resetDimensionsToDefault()`.
  - Immediate `updateProfile()` call triggers live panel resizing in real-time.
- [x] **Native Dashboard UI Controls**:
  - Implemented interactive "Notch Dimensions & Scaling" card in `NotchDetailView.swift`.
  - Compact width slider (140–600 pt) & height slider (24–64 pt).
  - Expanded width slider (320–750 pt) & height slider (120–360 pt).
  - Live dimension indicators (`X × Y pt`) and "Reset to Defaults" button.
- [x] **Domain Actions & AppState**:
  - Added `MaczyAction.setNotchDimensions` and `MaczyAction.resetNotchDimensions`.
  - Handled in `AppState.dispatch(...)` for programmatic and testable control.
- [x] **Unit & Integration Tests**:
  - Added `testCustomNotchDimensionsDetection`, `testNotchCoordinatorCustomDimensionsLifecycle`, and `testAppStateNotchDimensionsActionDispatch` in `Tests/MaczyTests/NotchGeometryTests.swift`.
  - Verified 201 Swift tests + 20 Rust tests pass (100% green).
- [x] **Branch & Push**:
  - Committed and pushed strictly to feature branch `fix/dynamic-notch-layout-position` (NEVER to `main`).
