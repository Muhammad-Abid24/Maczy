# TASK.md — Current Antigravity Task

## Active selection: MZ-015-SEPARATED-DIMENSIONS (DONE) — Separated Force Physical Notch & Force Virtual Island Dimension Adjustments
**Objective:** Decouple and independently configure dimensions (width & height for both compact silhouette and expanded card) between Force Physical Notch (hardware camera housing integration) and Force Virtual Island (floating capsule on external/desktop monitors), with isolated UserDefaults persistence, independent reset actions, and tabbed UI controls.

### Completed this task
- [x] **Decoupled Geometry Engine**:
  - Extended `NotchGeometry.detectProfile` with dedicated `physicalCompactSize`, `physicalExpandedSize`, `virtualCompactSize`, and `virtualExpandedSize` parameters.
  - Provided backwards-compatible overload for legacy callers.
  - Strictly routes physical sizes to physical notch calculations and virtual sizes to floating island calculations.
- [x] **Isolated Coordinator State & Persistence**:
  - Implemented 8 distinct `@Published` properties in `NotchCoordinator`:
    - Physical: `customPhysicalCompactWidth`, `customPhysicalCompactHeight`, `customPhysicalExpandedWidth`, `customPhysicalExpandedHeight`.
    - Virtual: `customVirtualCompactWidth`, `customVirtualCompactHeight`, `customVirtualExpandedWidth`, `customVirtualExpandedHeight`.
  - Persisted separately in `UserDefaults` (`maczy.notch.physical.*` vs `maczy.notch.virtual.*`).
  - Added dedicated reset functions: `resetPhysicalDimensionsToDefault()`, `resetVirtualDimensionsToDefault()`, and global `resetDimensionsToDefault()`.
  - Maintained proxy bindings (`currentCompactWidth`, etc.) for active mode responsiveness.
- [x] **Tabbed Native Dashboard UI**:
  - Added segmented target selector `[Force Physical Notch | Force Virtual Island]` in `NotchDetailView.swift`.
  - Synced automatically with active presentation mode changes while allowing cross-mode configuration.
  - Tailored slider ranges and color accents:
    - Physical Notch: compact width 140–480 pt, compact height 24–54 pt, expanded width 320–680 pt, expanded height 120–320 pt.
    - Virtual Island: compact width 180–600 pt, compact height 24–64 pt, expanded width 320–750 pt, expanded height 120–360 pt.
  - Dedicated "Reset Physical Defaults" and "Reset Virtual Defaults" buttons.
- [x] **Unit & Integration Tests**:
  - Added `testSeparatedPhysicalAndVirtualDimensions` in `Tests/MaczyTests/NotchGeometryTests.swift`.
  - Verified 202 Swift tests + 20 Rust tests pass (100% green).
- [x] **Branch & Push**:
  - Committed and pushed strictly to feature branch `fix/dynamic-notch-layout-position` (NEVER to `main`).
