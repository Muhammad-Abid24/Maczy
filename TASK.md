# TASK.md — Current Antigravity Task

## Active selection: FEAT-SCROLLING-CAPTURE-AREA-AUTO-SCROLL (DONE) — Area Selection, Auto-Scrolling, and Manual Scroll Controls for Scrolling Capture
**Objective:** Enhance Scrolling Capture so the user selects a target scrolling region first (interactive area selection overlay), then controls the capture session via a floating HUD supporting both automated scrolling and manual scroll with step capture.

### Completed this task
- [x] **Switched to Main & Pulled**: Checked out `main` and pulled latest (`3b9e433`).
- [x] **Created New Feature Branch**: Created branch `feat/scrolling-capture-area-auto-scroll` directly off updated `main`.
- [x] **Interactive Area Selection for Scrolling Capture**:
  - Added `AreaSelectionPurpose` (`.captureArea`, `.scrollingCapture`) to `AreaSelectionOverlay.swift`.
  - Added purpose-specific top instructions: *"Drag to select scrolling capture region • Press ESC to cancel"* and dimension tags with `• Scrolling Area`.
  - Updated `CaptureCoordinator.swift` to route `scrolling` capture through area selection first.
- [x] **Floating Interactive Control HUD (`ScrollingControlHUD.swift`)**:
  - Built a floating `NSPanel` containing `ScrollingControlHUDView` with blur background and modern styling.
  - Displays live slice count, estimated composite height, and bottom-of-page indicators.
  - Added **Auto Scroll** button (toggling automated mouse wheel events).
  - Added **Add Slice** button (for manual scrolling mode).
  - Added **Done (Finish & Stitch)** button (triggering seamless vertical stitching and export).
  - Added **Cancel** button (aborting session without residue).
- [x] **Scrolling Capture Coordinator Enhancement (`ScrollingCaptureCoordinator.swift`)**:
  - Maintained complete backward compatibility with existing lifecycle methods.
  - Added Quartz HID mouse scroll wheel event synthesis (`CGEvent(scrollWheelEvent2Source: ...)`).
  - Added interactive session management (`startInteractiveSession`, `captureCurrentSlice`, `startAutoScroll`, `stopAutoScroll`, `finishInteractiveSession`, `cancelInteractiveSession`).
- [x] **Dashboard UI Enhancement (`CaptureDetailView.swift`)**:
  - Updated Scrolling mode subtitle to `"Area + Auto/Manual"`.
- [x] **Validation & CI**:
  - Added unit tests in `CaptureTests.swift`.
  - Ran `./scripts/ci.sh`: all 20 Rust unit + perf tests and 214 Swift unit tests passed with 0 errors and 0 warnings, followed by successful Xcode arm64 build and ad-hoc code sign verification.
- [x] **Branch & Push**:
  - Committed and pushed strictly to `feat/scrolling-capture-area-auto-scroll`.
