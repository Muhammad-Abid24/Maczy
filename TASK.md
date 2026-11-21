# TASK.md — Current Antigravity Task

## Active selection: MZ-030 (DONE) — Awaiting User Command for Next Task
**Objective:** Completed native macOS Uninstaller and System Optimizer, fully integrated into `CleanerDetailView.swift` as a unified three-tab workspace: **Cleaner | Uninstall | Optimize**, backed by Rust safety classification, non-destructive macOS Trash workflow, and real-time native telemetry.

### Completed this task
- [x] **OpenDesign MCP Integration**:
  - Connected and verified authoritative OpenDesign project `70356bd0-f397-4d5e-983d-93a7952d85c6` (Maczy Premium Native macOS Design Execution).
  - Extracted and implemented design tokens, 3-tab layout, and evidence-first inspector panels.
- [x] **Rust Core & C FFI (`cleaner_safety.rs`, `maczy-ffi`)**:
  - Implemented `LeftoverSafetyLevel` (`Protected = 0`, `ReviewRequired = 1`, `Safe = 2`).
  - Implemented `classify_leftover_path(path: &str) -> LeftoverSafetyLevel`: pure Rust safety engine protecting system directories, user personal folders (`Documents`, `Desktop`, `Downloads`), `.git` repositories, credentials, keychains, and databases.
  - Exposed via C FFI `maczy_classify_leftover_path` in `maczy_ffi.h` and bridged to Swift.
- [x] **Uninstall — Smart Application Uninstaller**:
  - Discovered installed apps across `/Applications` and `~/Applications`.
  - Extracted bundle metadata: icon, bundle ID, version, publisher, bundle size, last used date.
  - Implemented 7-category leftover analysis (`Application Support`, `Caches`, `Preferences`, `Logs`, `Saved State`, `Containers`, `Other`).
  - Search, sort, multi-selection, and leftover item selection toggles.
  - Fail-closed security: system applications (`/System/Applications`, `/System/Library`) and running processes are blocked from uninstallation.
  - Non-destructive removal via macOS Trash (`NSFileManager.trashItem`) with itemized confirmation manifest.
- [x] **Optimize — Safe macOS System Optimization**:
  - Discovered startup and login items via supported Apple APIs (with deep link to `x-apple.systempreferences:com.apple.LoginItems-Settings.extension`).
  - Implemented evidence-first maintenance tasks: DNS cache review, Quick Look cache maintenance, stale user temporary file review.
  - Categorized developer artifact scanner: Xcode DerivedData, iOS Simulator caches, SPM caches, Cargo caches, npm caches.
  - Real-time native system monitoring: CPU utilization, Mach host memory pressure, disk capacity & availability, foreground heavy processes.
  - Zero fake RAM boosters, zero speculative speed-up claims.
- [x] **Three-Tab Native Workspace (`CleanerDetailView.swift`)**:
  - Top tab switcher: `Cleaner | Uninstall | Optimize`.
  - Preserved complete MZ-028 4-step cache cleaner workflow.
  - Integrated split-view app uninstaller with itemized leftover inspection and confirmation sheet.
  - Integrated optimizer dashboard with live telemetry tiles, action list, action inspector, and developer artifacts breakdown.
- [x] **Unit & Integration Tests**:
  - 8 uninstaller tests in `Tests/MaczyTests/UninstallerTests.swift` (metadata, safety levels, manifest calculations, system app block, running app block, search/sort, mock trash execution, disposable fixture trash removal).
  - 6 optimizer tests in `Tests/MaczyTests/OptimizerTests.swift` (action configurations, startup provider mock & deep link, developer artifact scanner, system resource monitor, lifecycle execution, evidence-first safety).
  - 20 Rust tests + 189 Swift tests passing with 0 warnings on `./scripts/ci.sh`.
- [x] **Tracked & Committed**:
  - Cleaned `.gitignore` so `KANBAN.md`, `TASK.md`, `PRD.md`, `ARCHITECTURE.md`, `UI-UX.md`, `SECURITY.md`, `BACKLOG.md` are properly tracked in git.
  - Committed and pushed strictly to feature branch `feat/mz-030-uninstaller-optimizer` (NEVER to `main`).
