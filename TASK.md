# TASK.md — Current Antigravity Task

## Active selection: MZ-015-FIX-NOTCH-SHAPE (DONE) — Dynamic Notch Expansion Shape & Click-Outside Dismissal
**Objective:** Update the Dynamic Notch expansion card shape to be flush at the top with rounded bottom corners (matching hardware notch bezel design), remove the top close button, and implement intuitive click-outside dismissal via global and local NSEvent monitoring.

### Completed this task
- [x] **Top-Flush Rounded Bottom Card Geometry**:
  - Replaced full 4-corner rounded rectangle with `UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 20, bottomTrailingRadius: 20, topTrailingRadius: 0, style: .continuous)`.
  - Expansion HUD now seamlessly connects with the top bezel and hardware notch cutout.
- [x] **Close Button Removal**:
  - Removed `xmark.circle.fill` close button from the top header in `NotchContainerView.swift`.
  - Preserved battery telemetry badge and status indicators.
- [x] **Click-Outside Dismissal**:
  - Implemented `startOutsideClickMonitoring` in `NotchOverlayWindowController.swift` with `NSEvent.addGlobalMonitorForEvents` and `NSEvent.addLocalMonitorForEvents`.
  - Automatically collapses expansion HUD to `.compact` state whenever a click occurs outside `panel.frame`.
  - Added clean lifecycle management (`stopOutsideClickMonitoring`) on collapse and window hide.
- [x] **Unit & Integration Tests**:
  - Added `testOutsideClickMonitoringLifecycleAndDismissal` to `Tests/MaczyTests/NotchGeometryTests.swift`.
  - Verified 198 Swift tests + 20 Rust tests pass (100% green).
- [x] **Branch & Push**:
  - Pushed strictly to `fix/dynamic-notch-layout-position` (NEVER to `main`).
