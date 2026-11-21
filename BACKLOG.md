# BACKLOG.md — Maczy prioritized work items

> IDs are stable. P0=foundation/security prerequisite, P1=core feature, P2=advanced feature, P3=polish. Every ticket remains TODO until evidence-backed completion. `KANBAN.md` is the execution board.

| ID | Priority | Task | Depends on | Acceptance evidence |
|---|---|---|---|---|
| MZ-001 | P0 | Repo arm64 SwiftUI/AppKit + Rust scaffold and builds | — | Xcode/Cargo build on Mac, tests/log |
| MZ-002 | P0 | Shared state, event bus, module/capability registry | 001 | state transition tests across surfaces |
| MZ-003 | P0 | Menu bar all modules + keyboard quick actions | 002 | 7 entries and correct actions, keyboard audit |
| MZ-004 | P0 | OpenDesign-only MCP connection + approved dashboard design handoff | 001,033 | verified `od` CLI + MCP tools; owner-approved OpenDesign project/screen/revision, tokens, screenshots and native comparison |
| MZ-005 | P0 | Permission center + app security prefs | 002 | TCC denied/retry and onboarding tests |
| MZ-006 | P0 | CI static checks, unit tests, baseline perf harness | 001 | arm64 lint/tests and measured test method |
| MZ-007 | P1 | Capture area and full window + preview/export | 002,005 | screenshots on macOS 14+ physical device |
| MZ-008 | P1 | OCR with Vision, text copy, offline operation | 007 | multilingual/text fixtures, permission handling |
| MZ-009 | P1 | Recording target: display/window/custom region | 005,007 | 3 target modes create playable MP4 |
| MZ-010 | P1 | Recording size presets/custom output & scaling | 009 | metadata/pixel test per preset |
| MZ-011 | P1 | Independent system audio and mic toggles | 009 | test OFF/OFF, ON/OFF, OFF/ON, ON/ON and denied perms |
| MZ-012 | P2 | Scrolling screenshot + stitching | 007 | Safari/scrollable apps, seam/interrupt tests |
| MZ-013 | P1 | Battery monitor and backend capability detection | 002 | plugged/unplugged and desktop unavailable tests |
| MZ-014 | P2 | Limit selection 80/85/90/95/100 + readback | 013,025 | verified backend tests; safe unsupported state |
| MZ-015 | P1 | Native notch shell + virtual island fallback | 002,004 | notch/non-notch displays, fullscreen test |
| MZ-016 | P2 | Now Playing + volume/brightness HUD feasibility | 015,025 | public API proof or blocked capability report |
| MZ-017 | P2 | Notifications + Maczy Live Activity widgets | 015 | foreground/background status and native UX |
| MZ-018 | P2 | Opt-in clipboard history + redaction | 015,005 | no capture when disabled; privacy review |
| MZ-019 | P2 | Window snap / accessibility integration | 015,005 | snap presets, undo, no protected window changes |
| MZ-020 | P2 | Lock screen quick action | 015 | uses system lock API; no bypass |
| MZ-021 | P2 | AirPods/TWS connection animation | 015,025 | real device event tests and fallback |
| MZ-022 | P1 | Document OS-managed Touch ID/password/Apple Watch unlock fallbacks and settings deep links | 005 | native OS support tested; no fake programmatic login unlock |
| MZ-023 | P0 | **macOS Lock Screen Face Unlock feasibility + security gate**: OS auth integration, M1+/14–27 capability matrix, liveness, ad-hoc distribution | 005,025 | Apple API research, tested proof or BLOCKED, explicit owner decision; no auth policy modification |
| MZ-024 | P3 | **Actual macOS locked-session Face Unlock** enrollment + secure system integration | 022,023 | real macOS locked→unlocked confirmation, anti-spoof/failure tests, independent audit + owner approval; else BLOCKED |
| MZ-025 | P0 | Compatibility/API/license feasibility matrix | 001 | macOS14-27 risk register, dependencies/ADR |
| MZ-026 | P1 | Awake system/display assertion & timers | 002 | start/stop/exit/thermal/power tests |
| MZ-027 | P1 | Sparkle signed update check/appcast | 001,025 | signature verification/failure tests |
| MZ-028 | P1 | Cleaner scanner: safe, read-only, category manifests | 002,005 | no mutations; fixture scan and exclusions |
| MZ-029 | P2 | Cleanup review, confirm, safe Trash & audit | 028,025 | isolate-fixture destructive tests only |
| MZ-030 | P2 | Smart uninstaller, safe optimizer, and dev cache analyzer | 028,025 | DONE: app inventory, leftover safety levels, macOS Trash workflow, startup items deep link, maintenance tasks, dev caches, live resource monitor |
| MZ-031 | P2 | Main app & menubar module coverage audits | 003,004,007,013,015,022,026,027,028 | DONE: MaczyAccessibility, 7-module parity, VoiceOver labels/hints/traits, stable identifiers, reduced motion |
| MZ-032 | P3 | Profiling, ad-hoc signing, Sparkle community-update and distribution | all release P0/P1/P2 dependencies incl. 034 | verified ad-hoc DMG, documented Gatekeeper limitations, EdDSA appcast tests; owner-approved publish |

## Notes
- Scope includes all requested features; feasibility-gated does **not** mean silently dropped. Agent produces blocker evidence if OS APIs prohibit feature, and requests owner decision.
- Never start `MZ-014`, `MZ-024`, or `MZ-029` without security/owner approval and device/fixture tests. In MZ-023, **research only**: never change authorizationdb, install authentication plug-ins, store macOS passwords, or run live unlock automation without a separately approved plan.
- Split a ticket into subtasks if needed while retaining stable parent ID and acceptance evidence.

## MZ-004 detailed design acceptance (required)
1. Verify `command -v od` points to OpenDesign CLI and not `/usr/bin/od`; capture CLI version/help and available OpenDesign MCP tools as real evidence. Do not claim connection from installation alone.
2. After reviewing official OpenDesign instructions, connect Antigravity via `od mcp install antigravity`, then restart/refresh the MCP client as needed. Keep credentials out of source control.
3. Inventory existing Maczy OpenDesign projects/screens; capture real OpenDesign project/screen/revision IDs. Never invent a project, link, frame or version.
4. Document the owner's final approved design baseline and its precedence, export a token/component map, produce native SwiftUI preview and record macOS light/dark screenshot comparisons.
5. Check keyboard navigation, VoiceOver, reduced motion, window scaling and native AppKit consistency. Report blockers for disconnected MCP or missing approval; no DONE until accepted.

## MZ-033 (P0) — MCP connection and design-source verification
**Depends on:** MZ-001. **Before MZ-004.** Verify OpenDesign/Antigravity installation, trust boundary and MCP capabilities; record actionable evidence and exclusive OpenDesign design authority. No production styling until approved. `MZ-004` now depends on **MZ-001 and MZ-033**; preserve original ticket IDs and adjust task planner accordingly.

## MZ-034 (P1) — Community build/ad-hoc signing acceptance
**Depends on:** MZ-006, MZ-025, MZ-027. Build arm64 release, verify nested signing, inspect Gatekeeper quarantine onboarding, test screen/camera/mic/Accessibility permission continuity and Sparkle EdDSA negative cases. Do not release without owner approval; MZ-032 depends on MZ-034.
