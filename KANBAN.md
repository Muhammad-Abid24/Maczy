# KANBAN.md — Maczy Execution Board

> Planning status only. Do not infer any completed implementation. Keep exactly one active Antigravity task unless Product Owner authorizes parallel work. Move tasks only with proof.

## READY
- [ ] MZ-034 Ad-hoc signed community build validation
- [ ] MZ-032 Release readiness

## BLOCKED — RELEASE/SECURITY GATE
- [ ] **MZ-014** Charge limit/write controls (requires backend, license, hardware tests + owner authorization)
- [ ] **MZ-024** actual macOS locked-session Face Unlock (requires proven OS pathway, anti-spoof audit and Product Owner authorization; NOT Maczy-only auth)
- [ ] **MZ-029** Cleanup deletion execution (explicit approval and disposable fixture tests)

## IN PROGRESS
- [ ] None

## REVIEW
- [ ] None

## DONE
- [x] **MZ-007-SEPARATED-CAPTURE-RECORDING** Separated dedicated configuration tabs for Screenshot Capture and Screen Recording (`fix/dynamic-notch-layout-position`)
- [x] **MZ-007-FIX-CAPTURE-PERMISSIONS** Fix Capture & Recording execution + Dashboard permission live synchronization (`fix/dynamic-notch-layout-position`)
- [x] **MZ-015-SEPARATED-DIMENSIONS** Separated Force Physical Notch & Force Virtual Island width/height dimension adjustments (`fix/dynamic-notch-layout-position`)
- [x] **MZ-015-CUSTOM-DIMENSIONS** Dynamic Notch height & width customizable dimensions (`fix/dynamic-notch-layout-position`)
- [x] **MZ-015-FIX-NOTCH-SHAPE** Dynamic Notch expansion shape (top-flush, rounded bottom) & click-outside dismissal (`fix/dynamic-notch-layout-position`)
- [x] **MZ-031** Cross-surface accessibility audit (`feat/mz-031-accessibility-audit`)
- [x] **MZ-030** Uninstaller and Optimizer (`feat/mz-030-uninstaller-optimizer`)
- [x] **MZ-028** Cleaner scan-only (`feat/mz-028-cleaner-scan`)
- [x] **MZ-027** Sparkle updates (`feat/mz-027-sparkle-updates`)
- [x] **MZ-026** Always On Manager (`feat/mz-026-always-on`)
- [x] **MZ-025** OS/API/license compatibility matrix (`feat/mz-025-compatibility-matrix`)
- [x] **MZ-023** real macOS Lock Screen Face Unlock API/security feasibility (`feat/mz-023-face-unlock-feasibility`)
- [x] **MZ-022** macOS native unlock fallback guidance (`feat/mz-022-unlock-fallback`)
- [x] **MZ-021** AirPods/TWS connection animation (`feat/mz-021-tws-animation`)
- [x] **MZ-020** Lock screen system action (`feat/mz-020-lock-screen`)
- [x] **MZ-019** Window snap (`feat/mz-019-window-snap`)
- [x] **MZ-018** Clipboard history (`feat/mz-018-clipboard-history`)
- [x] **MZ-001** Repository foundation / initial scaffold (`feat/mz-001-foundation`)
- [x] **MZ-002** Shared state, event bus, module/capability registry (`feat/mz-002-shared-state`)
- [x] **MZ-003** Menu bar module coverage + keyboard quick actions (`feat/mz-003-menubar`)
- [x] **MZ-033** OpenDesign MCP connection + design-source verification (`feat/mz-033-opendesign-verification`)
- [x] **MZ-004** OpenDesign-only approved dashboard handoff (`feat/mz-004-dashboard-handoff`)
- [x] **MZ-005** Permission center, TCC guidance & app security prefs (`feat/mz-005-permissions`)
- [x] **MZ-006** CI static checks, unit tests, baseline perf harness (`feat/mz-006-ci-perf-harness`)
- [x] **MZ-007** Capture area and full window + preview/export (`feat/mz-007-capture-core`)
- [x] **MZ-008** OCR with Vision, text copy, offline operation (`feat/mz-008-vision-ocr`)
- [x] **MZ-009** Display/window/region recording (`feat/mz-009-recording-core`)
- [x] **MZ-010** Resolution/size settings (`feat/mz-010-resolution-presets`)
- [x] **MZ-011** Speaker/system audio + mic switches (`feat/mz-011-audio-switches`)
- [x] **MZ-012** Scrolling capture & image stitching (`feat/mz-012-scrolling-capture`)
- [x] **MZ-013** Battery monitoring (`feat/mz-013-battery-monitoring`)
- [x] **MZ-015** Native Dynamic Notch + virtual fallback (`feat/mz-015-dynamic-notch`)
- [x] **MZ-016** Now Playing + volume/brightness HUD (`feat/mz-016-media-hud`)
- [x] **MZ-017** Notifications + Live Activity widgets (`feat/mz-017-live-activities`)

## History format
`YYYY-MM-DD | task | from -> to | branch | actual evidence | reviewer`.

2026-11-22 | MZ-007-FIX-CAPTURE-PERMISSIONS | IN PROGRESS -> DONE | fix/dynamic-notch-layout-position | Verified on branch fix/dynamic-notch-layout-position: AppState @Published permissions with live TCC refresh, didBecomeActive observers across Dashboard, windowID=0 frontmost window capture/recording resolution, ScreenCaptureKit Y-coord flipping, CaptureDetailView permission banner & Stop Recording controls, 20 Rust + 206 Swift tests pass, zero warnings | Product Owner

2026-11-22 | MZ-031 | READY -> DONE | feat/mz-031-accessibility-audit | Verified on branch feat/mz-031-accessibility-audit: MaczyAccessibility, 7-module parity between Dashboard and Menu Bar, VoiceOver labels/hints/traits, stable identifiers, reduced motion handling, 20 Rust + 197 Swift tests pass, zero warnings | Product Owner

2026-11-22 | MZ-030 | IN PROGRESS -> DONE | feat/mz-030-uninstaller-optimizer | Verified on branch feat/mz-030-uninstaller-optimizer: Uninstaller (app inventory, bundle metadata, 7 leftover domains, Rust safety levels, fail-closed system/running blocks, macOS Trash workflow) & Optimizer (StartupItems with deep link, 5 maintenance tasks, developer artifact scanner, system resource monitor), CleanerDetailView three-tab UI, 20 Rust + 189 Swift tests pass, zero warnings | Product Owner

2026-11-22 | MZ-030 | READY -> IN PROGRESS | feat/mz-030-uninstaller-optimizer | Implementing Uninstaller (app discovery, leftover analysis, Trash workflow) & Optimizer (startup items, system/developer maintenance, system monitor) | In Progress

2026-11-22 | MZ-028 | IN PROGRESS -> DONE | feat/mz-028-cleaner-scan | Verified on branch feat/mz-028-cleaner-scan: CleanCategory (6 categories), CleanerExclusions (strict system/docs/repo protection), CleanerScanManifest, CleanerManager, CleanerDetailView 4-step UX, MZ-029 gate fail-closed, 15 Rust + 174 Swift tests pass, zero warnings | Product Owner

2026-11-22 | MZ-028 | READY -> IN PROGRESS | feat/mz-028-cleaner-scan | Implementing read-only cache analyzer, safe allowlisted paths, category exclusions, CleanerScanManifest, and zero-mutation UI | In Progress

2026-11-22 | MZ-027 | IN PROGRESS -> DONE | feat/mz-027-sparkle-updates | Verified on branch feat/mz-027-sparkle-updates: Sparkle 2 Ed25519 signature verification, UpdateChannel (Stable/Beta/Nightly), AppcastParser, UpdateManager, UpdatesDetailView, 15 Rust + 166 Swift tests pass, zero warnings | Product Owner

2026-11-22 | MZ-027 | READY -> IN PROGRESS | feat/mz-027-sparkle-updates | Implementing Sparkle 2 signed update check, Ed25519 appcast validator, release channels (Stable/Beta/Nightly), UpdatesDetailView | In Progress

2026-11-22 | MZ-026 | IN PROGRESS -> DONE | feat/mz-026-always-on | Verified on branch feat/mz-026-always-on: AlwaysOnManager, NativePowerAssertionProvider IOPMLib, presets, battery/thermal guardrails, countdown ticker, AlwaysOnDetailView, MenuBar & Notch integration, 15 Rust + 157 Swift tests pass, zero warnings | Product Owner

2026-11-22 | MZ-026 | READY -> IN PROGRESS | feat/mz-026-always-on | Implementing IOPMAssertionCreateWithName power assertions, sleep prevention presets, thermal/battery guardrails, countdown timer, and AlwaysOnManager | In Progress

2026-11-22 | MZ-025 | IN PROGRESS -> DONE | feat/mz-025-compatibility-matrix | Pushed to branch feat/mz-025-compatibility-matrix: ADR-0003, MZ-025 risk register, LICENSES-THIRD-PARTY, CompatibilityMatrix runtime engine, 15 Rust + 149 Swift tests pass, zero warnings | Product Owner

2026-11-22 | MZ-013 | REVIEW -> DONE | feat/mz-013-battery-monitoring | Merged PR #12 (865f103): BatteryMonitor, IOKitBatteryTelemetryReader, AppleSmartBattery & IOPS telemetry, BatteryDetailView, MenuBarView, 15 Rust + 80 Swift tests pass, CI in 14s | Product Owner
2026-11-22 | MZ-015 | REVIEW -> DONE | feat/mz-015-dynamic-notch | Merged PR #13 (b5b81de): NotchGeometry, NotchCoordinator, NotchOverlayWindowController, NotchContainerView, 15 Rust + 90 Swift tests pass, zero warnings | Product Owner
2026-11-22 | MZ-016 | REVIEW -> DONE | feat/mz-016-media-hud | Merged PR #14 (785294d): MediaHUDCoordinator, SystemHUDCoordinator, Now Playing player card, volume/brightness HUD toast, 15 Rust + 97 Swift tests pass, zero warnings | Product Owner
2026-11-22 | MZ-017 | REVIEW -> DONE | feat/mz-017-live-activities | Fast-forward merged into main (ef71e37): LiveActivityCoordinator, LiveActivityItem, timer countdowns, notifications, Notch HUD card stack, 15 Rust + 102 Swift tests pass, zero warnings | Product Owner
2026-11-22 | MZ-020 | IN PROGRESS -> DONE | feat/mz-020-lock-screen | Merged into main (1b0cd5a): SystemLockController, SACLockScreenImmediate + CGSession fallback, SystemLockManager, Notch HUD Lock action, 15 Rust + 128 Swift tests pass, zero warnings | Product Owner
2026-11-22 | MZ-021 | REVIEW -> DONE | feat/mz-021-tws-animation | Verified on branch feat/mz-021-tws-animation (056b5ca): AudioDeviceConnection, NativeBluetoothAudioObserver, IORegistry battery telemetry, TWSNotchCoordinator, NotchContainerView pill & card, CI arm64 fix, 15 Rust + 133 Swift tests pass, zero warnings | Product Owner
2026-11-22 | MZ-022 | REVIEW -> DONE | feat/mz-022-unlock-fallback | Pushed to branch feat/mz-022-unlock-fallback (124be1b): NativeUnlockFallbackManager, LocalAuthentication evaluator, deep links, UnlockDetailView fallback cards, 15 Rust + 139 Swift tests pass, zero warnings | Product Owner
2026-11-22 | MZ-023 | REVIEW -> DONE | feat/mz-023-face-unlock-feasibility | Pushed to branch feat/mz-023-face-unlock-feasibility (6b041a8): ADR-0002, MZ-023 security audit, Scenarios A-F matrix, FaceUnlockFeasibilityReport, UnlockDetailView matrix, 15 Rust + 144 Swift tests pass, zero warnings | Product Owner
2026-11-22 | MZ-025 | READY -> IN PROGRESS | feat/mz-025-compatibility-matrix | Formulating macOS 14-27 API risk register, third-party open-source license audit, ADR-0003, and CompatibilityMatrix runtime inspection engine | In Progress
2026-11-22 | MZ-019 | IN PROGRESS -> DONE | feat/mz-019-window-snap | Merged into main (25c14f9): WindowSnapPreset, WindowGeometryEngine, WindowSnapManager with AXUIElement, undo stack, protected window filtering, Notch quick snap bar, 15 Rust + 123 Swift tests pass, zero warnings | Product Owner
2026-11-22 | MZ-020 | READY -> IN PROGRESS | feat/mz-020-lock-screen | Implementing native Lock Screen quick action via SACLockScreenImmediate() system bridge, fallback, and Notch trigger | In Progress
2026-11-22 | MZ-018 | IN PROGRESS -> DONE | feat/mz-018-clipboard-history | Fast-forward merged into main (5d9e72b): ClipboardManager, password manager concealment filtering (1Password/Bitwarden), FIFO eviction, retention policies, 15 Rust + 110 Swift tests pass, zero warnings | Product Owner
2026-11-22 | MZ-019 | READY -> IN PROGRESS | feat/mz-019-window-snap | Implementing native Accessibility AXUIElement window snapping engine, preset rect calculations, undo stack, and Dynamic Notch snap zone | In Progress
2026-11-22 | MZ-012 | REVIEW -> DONE | feat/mz-012-scrolling-capture | Merged PR #11 (016c730): ImageStitchingEngine, row correlation vertical overlap, bounded canvas, ScrollingCaptureCoordinator, 15 Rust + 70 Swift tests pass, Node 24 actions | Product Owner
2026-11-22 | MZ-001 | REVIEW -> DONE | feat/mz-001-foundation | Committed 74c8e02f: 21 files, tests passed, approved by user | Product Owner
2026-11-22 | MZ-002 | REVIEW -> DONE | feat/mz-002-shared-state | Committed 3db3e87: action pipeline, capability/permission gates, event bus, 21 tests pass | Product Owner
2026-11-22 | MZ-003 | REVIEW -> DONE | feat/mz-003-menubar | Committed ed053cc: MenuBarView with all 7 modules, shortcuts, 13 tests pass, approved | Product Owner
2026-11-22 | MZ-033 | REVIEW -> DONE | feat/mz-033-opendesign-verification | Committed a84cd44: ADR-0001, design-tokens.json, OpenDesign MCP verified | Product Owner
2026-11-22 | MZ-004 | REVIEW -> DONE | feat/mz-004-dashboard-handoff | Committed a240fb5: Native SwiftUI Overview with health orb, readiness chips, activity tiles, 7 module detail views, 17 Swift tests pass | Product Owner
2026-11-22 | MZ-005 | REVIEW -> DONE | feat/mz-005-permissions | Committed 7ec1075: PermissionManager, PermissionCenterView, SecurityPreferencesView, 26 tests pass | Product Owner
2026-11-22 | MZ-006 | REVIEW -> DONE | feat/mz-006-ci-perf-harness | Merged PR #4 and PR #5 into main (5c0fb30): GitHub Actions CI macos-15, perf harnesses calibrated, 15 Rust + 27 Swift tests pass, ad-hoc codesign verified | Product Owner
2026-11-22 | MZ-007 | REVIEW -> DONE | feat/mz-007-capture-core | Committed 5c19e1e: ScreenCaptureEngine (area, window, fullscreen), AreaSelectionOverlay, CaptureExportManager, CapturePreviewHUD, CaptureCoordinator, 15 Rust + 35 Swift tests pass, ad-hoc codesign verified | Product Owner
2026-11-22 | MZ-008 | REVIEW -> DONE | feat/mz-008-vision-ocr | Committed 6c26982: VisionOCREngine (Apple Vision text recognition), offline multilingual extraction, pasteboard copy, 15 Rust + 44 Swift tests pass | Product Owner
2026-11-22 | MZ-009 | REVIEW -> DONE | feat/mz-009-recording-core | Committed 402b022: ScreenRecordingEngine (display, window, region), ScreenCaptureKit + AVAssetWriter hardware-accelerated MP4, 15 Rust + 47 Swift tests pass | Product Owner
2026-11-22 | MZ-010 | REVIEW -> DONE | feat/mz-010-resolution-presets | Committed 0994032: ResolutionSettings presets (Native, 4K, 1440p, 1080p, 720p), scale modes, aspect fit, even dimension alignment, 15 Rust + 55 Swift tests pass | Product Owner
2026-11-22 | MZ-011 | REVIEW -> DONE | feat/mz-011-audio-switches | Merged PR #10 (904e86e): AudioRecordingManager, 4-state audio matrix, ScreenCaptureKit audio tap, AAC stereo 48kHz writer, mic gating, 15 Rust + 62 Swift tests pass, CI 100% green | Product Owner
2026-11-22 | MZ-012 | IN PROGRESS -> REVIEW | feat/mz-012-scrolling-capture | ImageStitchingEngine, row-correlation vertical overlap detection, memory-bounded canvas, ScrollingCaptureCoordinator, CaptureDetailView Scrolling mode, 15 Rust + 70 Swift tests pass | Product Owner
2026-11-22 | MZ-012 | READY -> IN PROGRESS | feat/mz-012-scrolling-capture | Implementing native visual image stitching engine, overlap detection, scrolling capture coordinator, and tests | In Progress
2026-11-22 | MZ-008 | REVIEW -> DONE | feat/mz-008-vision-ocr | Committed 6c26982: VisionOCREngine (Apple Vision VNRecognizeTextRequest), multilingual offline recognition, pasteboard copy, CapturePreviewHUD OCR action, 15 Rust + 40 Swift tests pass, ad-hoc codesign verified | Product Owner
2026-11-22 | MZ-009 | REVIEW -> DONE | feat/mz-009-recording-core | Committed 402b022: ScreenRecordingEngine (SCStream + AVAssetWriter hardware-accelerated MP4), 3 modes (display, window, region), RecordingCoordinator, 15 Rust + 47 Swift tests pass, ad-hoc codesign verified | Product Owner
2026-11-22 | MZ-010 | REVIEW -> DONE | feat/mz-010-resolution-presets | Committed 0994032: ResolutionCalculator (native, 4K, 1440p, 1080p, 720p, scale), aspect-fit ratio calculations, even-dimension alignment, 15 Rust + 55 Swift tests pass, ad-hoc codesign verified | Product Owner
2026-11-22 | MZ-011 | READY -> IN PROGRESS | feat/mz-011-audio-switches | Implementing independent system audio and mic switches, AAC audio stream writer input, permission checks, and 4-way audio matrix tests | In Progress

Do not mark task DONE merely because a prototype screen exists. Scope blockers must be reported, not erased from backlog.
