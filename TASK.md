# TASK.md — Current Antigravity Task

## Active selection: FIX-CAPTURE-PREVIEW-QUALITY (DONE) — Fix Screenshot Preview HUD & Enhance Capture Quality
**Objective:** Resolve the issue where captured screenshots fail to show a preview thumbnail, and improve capture output quality to full native Retina resolution.

### Completed this task
- [x] **Switched to Main & Pulled**: Checked out `main` and pulled latest (`6c00198`).
- [x] **Created New Feature/Fix Branch**: Created branch `fix/capture-preview-quality` directly off updated `main`.
- [x] **Retina High-Quality Capture in `ScreenCaptureEngine`**:
  - Computed display `backingScaleFactor` across fullscreen, window, and area targets.
  - Configured `SCStreamConfiguration` width/height to match physical Retina pixels (`rect.width * scale`), eliminating blurriness and downsampling.
  - Set `scalesToFit = false`, `pixelFormat = kCVPixelFormatType_32BGRA`, and `colorSpaceName = CGColorSpace.displayP3` for maximum fidelity.
  - Embedded DPI scaling metadata in `CaptureExportManager.encodeImage` so PNG and pasteboard exports are recognized as @2x Retina.
- [x] **Floating Capture Preview HUD Visibility**:
  - Elevated `CapturePreviewHUD` window level to `NSWindow.Level(Int(CGWindowLevelForKey(.maximumWindow)))` to always float over full-screen and active apps.
  - Configured `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]`.
  - Replaced `orderFront(nil)` with `orderFrontRegardless()` with smooth fade-in animations.
- [x] **In-Dashboard Recent Capture Preview**:
  - Added `@Published public var lastCapturedImage: CGImage?` to `AppState`.
  - Added a "Recent Capture Preview" card to `CaptureDetailView` with resolution details, copy button, and Finder reveal.
- [x] **Validation**:
  - Added unit tests in `CaptureTests.swift`.
  - Ran `./scripts/ci.sh`: all 20 Rust unit + perf tests and 211 Swift unit tests passed with 0 errors and 0 warnings.
- [x] **Branch & Push**:
  - Committed and pushed strictly to `fix/capture-preview-quality`.
