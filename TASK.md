# TASK.md — Current Antigravity Task

## Active selection: MZ-029 (DONE) — System Cleaner Button Responsiveness & Cleanup Deletion Execution
**Objective:** Fix System Cleaner button unresponsiveness, implement safe reversible cleanup execution via macOS Trash, enforce strict protection exclusions, provide explicit user confirmation before deletion, and verify with disposable temporary fixture tests.

### Completed this task
- [x] **Switched to Main & Pulled**: Checked out `main` and pulled latest upstream commits (`cf3783b`).
- [x] **Created New Feature Branch**: Created branch `feat/mz-029-cleaner-deletion-execution` directly off updated `main`.
- [x] **Fixed System Cleaner Button Responsiveness (`CleanerDetailView.swift`, `CleanerManager.swift`)**:
  - Bound `@ObservedObject private var cleanerManager`, `@ObservedObject private var uninstallManager`, and `@ObservedObject private var optimizerManager` in `CleanerDetailView`. Previously, observing `AppState` alone failed to propagate `@Published` property changes from nested child managers to SwiftUI views, causing buttons and category toggles to seem unresponsive.
  - Offloaded file system enumeration and cache scanning to a background cooperative thread pool (`Task.detached(priority: .userInitiated)` with isolated `@Sendable` progress reporting), preventing `@MainActor` thread starvation.
  - Added `.contentShape(Rectangle())` to tab buttons and category cards for instant, edge-to-edge hit testing.
- [x] **Implemented Cleanup Deletion Execution (MZ-029)**:
  - Added `Action::ExecuteCleanerPurge { confirmed: bool }` in Rust core (`crates/maczy-core/src/actions.rs`, `state.rs`, `lib.rs`) with fail-closed gating `GATE_MZ_029` when unconfirmed.
  - Added `MaczyAction.executeCleanerPurge(confirmed: Bool)` in `MaczyAction.swift` with debounce key `cleaner_purge_\(confirmed)`.
  - Created `CleanupExecutionProvider` protocol and `NativeCleanupExecutionProvider` in `CleanerManager.swift`:
    - Safely moves files to macOS Trash using `FileManager.default.trashItem(at:resultingItemURL:)` — **never deletes permanently**.
    - Re-validates all candidate paths through `CleanerExclusions.isProtected(path)` right before trashing to guarantee `.git`, user documents, photos, desktop items, and protected system files are never touched.
    - Implemented `MockCleanupExecutionProvider` for deterministic testing.
  - Created `CleanupResult` struct reporting trashed item count, failed items, reclaimed byte count, and human-readable string.
  - Added `executeCleanup() async throws -> CleanupResult` and `requestCleanupExecution(isExplicitlyConfirmed:)` with fail-closed `GATE_MZ_029` validation.
  - Added confirmation review sheet (`cleanupConfirmationSheet`) in `CleanerDetailView` with an itemized category breakdown, total reclaimable size, safety explanation, and clear Cancel / Clean buttons before any mutation occurs.
  - Added post-cleanup result banner displaying reclaimed space and trashed item counts.
- [x] **Configured Step 4 as Empty Trash (Menghapus Trash)**:
  - Updated the 4-step workflow indicator: `Step 1: Scan` -> `Step 2: Review` -> `Step 3: Move to Trash` -> `Step 4: Empty Trash`.
  - Added `Action::EmptyTrash { confirmed: bool }` in Rust core with fail-closed `GATE_MZ_029` enforcement.
  - Added `MaczyAction.emptyTrash(confirmed: Bool)` in `MaczyAction.swift` targeting `.systemCleaner`.
  - Added `emptyTrash() async throws -> Bool`, `openTrashInFinder()`, and `resetCleanerWorkflow()` to `CleanerManager.swift`.
  - Designed interactive Step 4 Card in `CleanerDetailView.swift`:
    - Shows items and storage ready to be permanently freed from Trash.
    - Prominent "Empty Trash Permanently" button triggering native Finder AppleScript and shell cleanup.
    - "Open Trash in Finder" option allowing user to inspect items before permanent deletion.
    - "Start New Scan" reset action.
- [x] **Testing & CI Verification**:
  - Added tests in `CleanerScanTests.swift`:
    - `testAppStateCleanerPurgeAction`: verifies unconfirmed fails closed with `GATE_MZ_029` and confirmed succeeds.
    - `testAppStateEmptyTrashAction`: verifies unconfirmed fails closed with `GATE_MZ_029` and confirmed succeeds.
    - `testCleanerManagerWorkflowReset`: verifies clean reset back to initial state.
    - `testMZ029ExecutionMovesItemsToTrashInDisposableFixture`: creates an isolated `FileManager.default.temporaryDirectory` fixture, populates dummy cache files, executes cleanup, and verifies items are moved to trash.
    - `testMZ029ExecutionStrictlyRejectsProtectedFiles`: verifies `.git` and document paths are skipped and recorded in failed paths without deletion.
  - Added Rust core tests: `test_cleaner_purge_gated_by_mz_029` and `test_empty_trash_gated_by_mz_029`.
  - Executed `./scripts/ci.sh`: Rust fmt, clippy (0 warnings), 23 Rust tests, 232 Swift tests pass, Xcode arm64 build, and ad-hoc codesign passed.
  - Executed `./scripts/dev.sh`: Rebuilt, codesigned, and re-launched `/Users/muhammadabid/Applications/Maczy.app`.
