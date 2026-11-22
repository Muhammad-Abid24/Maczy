# TASK.md — Current Antigravity Task

## Active selection: MZ-007-SEPARATED-CAPTURE-RECORDING (DONE) — Dedicated Tabbed Configuration for Capture (Screenshot) and Recording (Video)
**Objective:** Separate the Capture & Recording interface in `CaptureDetailView` into dedicated, independent sections so that Screenshot Capture and Screen Recording are configured separately with tailored target pickers, settings, and action controls.

### Completed this task
- [x] **Dedicated Sub-Navigation Tabs**:
  - Implemented `CaptureSubTab` enum (`.capture` = "Screenshot Capture", `.recording` = "Screen Recording") with icon badges.
  - Added native segmented tab selector at the top of `CaptureDetailView`.
- [x] **Dedicated Capture (Screenshot) Section**:
  - Isolated screenshot target selection (`Area`, `Window`, `Fullscreen`, `Scrolling`).
  - Added feature badges for Apple Vision OCR, instant Clipboard sync, and lossless PNG output.
  - Added dedicated trigger button `Capture Screenshot (<Mode>)` with purple brand styling.
  - Added quick keyboard shortcut references (`⌘⇧1`, `⌘⇧2`, `⌘⇧3`).
- [x] **Dedicated Recording (Screen Recording) Section**:
  - Isolated recording target selection (`Display`, `Window`, `Region`).
  - Added resolution preset selector (`Native`, `4K`, `1440p`, `1080p`, `720p`).
  - Added independent audio toggles for System Audio (Speaker) and Microphone Voice.
  - Added live pulsating recording status indicator and dedicated `Start Recording` / `Stop Recording` buttons.
- [x] **CI & Build Verification**:
  - Passed all 20 Rust unit/perf tests + 207 Swift package tests with 0 errors and 0 warnings.
  - Verified Xcode universal arm64 build and ad-hoc code signing.
  - Updated `~/Applications/Maczy.app` and `.build/Maczy.app`.
- [x] **Branch & Push**:
  - Committed and pushed strictly to feature branch `fix/dynamic-notch-layout-position` (NEVER to `main`).
