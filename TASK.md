# TASK.md — Current Antigravity Task

## Active selection: FIX-SWIFT6-SENDABLE-WARNING (DONE) — Fix Swift 6 Sendable Conformance Warning for ProcessResourceInfo
**Objective:** Resolve the GitHub Actions and Swift 6 compiler warning where stored property `icon` (`NSImage?`) in `Sendable`-conforming struct `ProcessResourceInfo` caused non-sendable warnings across multiple compilation units.

### Completed this task
- [x] **Switched to Main & Synced**: Checked out `main` and pulled latest from `origin/main` (`cb168c8`).
- [x] **Created New Feature/Fix Branch**: Created branch `fix/system-resource-monitor-sendable` branching directly from up-to-date `main`.
- [x] **Fixed Swift 6 Sendable Conformance**:
  - Updated `ProcessResourceInfo` in `apps/macos/MaczyKit/Optimizer/SystemResourceMonitor.swift` to declare `@unchecked Sendable`.
  - Suppressed compiler warnings for non-Sendable AppKit `NSImage?` reference type in strict concurrency modes.
- [x] **Validation**:
  - Ran `./scripts/ci.sh`: all 20 Rust unit + perf tests and 207 Swift tests passed.
  - Verified Xcode universal arm64 build and ad-hoc code signing.
- [x] **Branch & Push**:
  - Committed and pushed strictly to `fix/system-resource-monitor-sendable`.
