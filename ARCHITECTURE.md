# ARCHITECTURE.md — Maczy Native macOS Architecture

## 1. Decisions
- **Target:** Apple Silicon arm64, deployment macOS 14.0+, runtime compatibility tested through macOS 27.
- **UI:** SwiftUI dashboard (approved OpenDesign design-driven), AppKit/SwiftUI menu bar and Dynamic Notch (Apple-native styling).
- **Core:** Rust modular library with minimal C ABI / audited `swift-bridge` interface, Swift orchestrates native Apple frameworks. Do not add an unnecessary long-running Rust runtime.
- **State:** canonical `AppState`, immutable event snapshots; `Action -> Capability Gate -> Permission Gate -> Command -> Result -> State Update`, never optimistic fake success.
- **Persistence:** UserDefaults for preferences, Keychain for secrets/enrollment keys, SQLite for optional logs/histories; keep private files in Application Support.
- **Network:** Sparkle update-only with explicit consent; no telemetry.

```mermaid
flowchart TD
  A[Maczy Dashboard SwiftUI] --> S[Shared State Store]
  B[Menu Bar AppKit] --> S
  C[Dynamic Notch AppKit SwiftUI] --> S
  S --> G{Capability Permission Gate}
  G --> R[Rust Core Services]
  G --> N[Swift Native Adapters]
  R --> D[(SQLite and Settings)]
  N --> F[ScreenCaptureKit Vision IOKit LocalAuthentication [no OS face-unlock entitlement implied]]
  N --> U[Sparkle Updater]
  N --> H[Approved Battery Helper Optional]
```

## 2. Planned repository
```text
Maczy/
├── Maczy.xcodeproj/                  # Created by MZ-001; name finalized by scaffold
├── apps/macos/MaczyApp/             # SwiftUI windows; native bridges; menu bar; notch
│   ├── Dashboard/                  # approved OpenDesign tokens; native SwiftUI components
│   ├── MenuBar/                    # NSStatusItem or MenuBarExtra
│   ├── Notch/                      # per-screen overlay / virtual island
│   ├── Capture/                    # ScreenCaptureKit wrapper
│   ├── Battery/                    # native readings and verified backend
│   ├── Unlock/                     # face enrollment, locked-session observer, gated OS unlock adapter
│   ├── Update/                     # Sparkle integration
│   ├── Awake/                      # macOS power assertions
│   ├── Cleaner/                    # scanner and review flows
│   ├── Uninstaller/                # native app discovery, leftover analysis, and Trash workflow
│   ├── Optimizer/                  # startup items, system maintenance, dev caches, live monitor
│   ├── Permissions/                # TCC / Accessibility guidance
│   └── CoreBridge/
├── crates/
│   ├── maczy-core/                 # state, commands, capability registry
│   ├── maczy-storage/              # SQLite optional
│   ├── maczy-cleaner/              # safe scan/manifests, later deletion gate
│   ├── maczy-capture-utils/        # image helpers, stitching
│   └── maczy-ffi/                  # audited ABI boundary
├── helpers/battery/                # optional, only after approval
├── tests/fixtures/
├── docs/adr/
├── UI-UX.md
├── PRD.md
└── ...
```

## 3. Capability contract
```text
ModuleCapability { supported: Bool, reason: String?, requiredPermissions: [Permission], backend: String? }
ModuleStatus { enabled: Bool, capability: ModuleCapability, runtime: idle|running|error|paused|done }
CommandResult { ok: Bool, observedValue: Any?, errorCode: String?, message: String? }
```
Expose immutable snapshots to all UI surfaces. A user action is dispatched exactly once; debounce and idempotency for capture/awake/unlock/charge/update. Feature flags are per OS/hardware and are not equivalent to capability success.

## 4. Capture and recording pipeline
- `ScreenCaptureKit` + `SCContentSharingPicker` and AppKit region picker. Capture area and selected window; scroll capture coordinates controlled scrolling/stitching, `Vision` for OCR. Accessibility consent where scroll automation needs it. Identify inaccessible/DRM content without bypass.
- Recording input target: display/window/region. Output mode presets source/720p/1080p/custom with aspect/letterbox/crop preview and device capability restrictions. Use `VideoToolbox`/`AVFoundation` media export; user sees resulting resolution.
- Independent toggles: system audio vs microphone; check audio API availability on 14; use compatible native capture pipeline. Permission denial blocks only affected track; no surprise audio substitution. Tests for four combinations, sample-rate synchronization and hot plug.

## 5. Battery model
Read using supported IOKit/power APIs. UI options `[80,85,90,95,100]`. Backend interface `probe()`, `readState()`, `setUpperLimit(percent)`, `readBack()`, `disableLimit()`; helper approved separately. On macOS 26.4+ Apple has charge-limit features; batt may be needed on older supported OS. On macOS 27 some direct SMC keys have private-entitlement restrictions. Use capability negotiation and no bypass promise. Present separate fields `limit`, `externalPower`, `batteryCurrent`, `chargeInProgress`, `verifiedPowerPathMode`.

## 6. Dynamic Notch integrations
- Detect notch on each display, safe area, external monitors, fullscreen & accessibility reduced motion.
- Now Playing: evaluate public APIs/permissions; music source integrations must be provider-specific if no generic public metadata source. System notification interception and volume/brightness monitoring may not be fully available; Maczy-own notifications always feasible.
- Clipboard: `NSPasteboard` history only after opt-in; avoid sensitive fields and never poll at high frequency; privileged exposure risk considered.
- Window snap: NSAccessibility APIs with consent, preview and undo last placement, avoid changing protected apps.
- Lock Screen: system-provided lock action, not bypass/unlock.
- Live Activity: **Maczy's own progress widgets**; do not claim iOS Live Activities API necessarily exists on macOS.
- AirPods/TWS: supported Bluetooth attachment/disconnection events, not a guarantee of intercepting every Apple pairing animation. Permission and battery visibility capability-based.

## 7. Smart Unlock — actual macOS Lock Screen
- **Product boundary:** face verification is meant to unlock an already authenticated, currently locked **macOS user session**. It is NOT `MaczyPrivacyGate` and must not simply dismiss a Maczy overlay. Never present an in-app success state as proof of a macOS unlock.
- **Split responsibilities:** `FaceEnrollmentService` (on-device camera, explicit permission, local biometric template), `LivenessVerifier` (anti-replay tests), `LockStateObserver` (permitted session-state observation), `SystemUnlockAdapter` (**interface only until OS-authorized capability is proven**) and `UnlockCoordinator` (opt-in, throttle, audit of non-sensitive status). Keep camera processing bounded, event-driven and disabled when off.
- **Integration research first:** study Apple Authorization Services, authorization plug-in constraints and real third-party examples; distinguish system authentication mechanisms from `LocalAuthentication` (Touch ID prompts inside apps do NOT grant an app the ability to unlock loginwindow). Investigate compatibility on Sonoma 14, Sequoia 15, Tahoe 26 and 27 with non-production test accounts/devices.
- **Security guard:** NO password saving/typing/injection; NO automatic auth policy or loginwindow modifications; NO SIP/FileVault/MDM bypass. A future independently reviewed mechanism involving privileged auth extension requires separate owner approval, recovery/rollback plan, OS compatibility evidence, and specific signing/installation proof under Maczy's ad-hoc-only distribution policy. If these gates cannot be passed, mark **SystemUnlockAdapter = unavailable** and keep the feature BLOCKED rather than ship a misleading alternative.
- **Native alternatives:** Touch ID and Apple Watch are configured/mediated by macOS. Maczy can explain/open relevant System Settings when supported, but does not fake invoking them as a system-unlock action. Password fallback remains system-controlled.
- **Acceptance tests:** enroll/revoke/denied/timeout; photo/video and virtual camera spoof tests; OS-observed locked→unlocked transitions; post-reboot/FileVault explicitly documented as unsupported until proven; no stored raw frames, template protected locally; full rollback/uninstall verification.

## 8. Always On, Cleaner & update
- Awake: scoped power assertions + timer + AC/battery/thermal policy; idle display and system separate, release in all lifecycle paths. Never override lock screen/MDM/lid-close.
- Cleaner, Uninstaller & Optimizer:
  - Cleaner: enumerates allowlisted locations, builds immutable dry-run manifest; revalidate realpath/symlink, ownership, mount, exclusions and file identity immediately before user-confirmed move-to-Trash.
  - Uninstaller: native app inventory discovery (`/Applications`, `~/Applications`), metadata extraction, 7 leftover domains with Rust safety classification (`LeftoverSafetyLevel`: Protected, ReviewRequired, Safe), fail-closed protection for system apps (`/System/Applications`) and running processes, reversible `NSFileManager.trashItem` execution.
  - Optimizer: evidence-first maintenance tasks (DNS cache, Quick Look cache, stale temp files), startup & login items inspection with deep link, categorized developer artifact scanners (Xcode DerivedData, CoreSimulator, SPM, Cargo, npm), and real-time native resource monitoring (Mach host telemetry, CPU, memory pressure, disk capacity, heavy processes).
- Updates: Sparkle 2 EdDSA appcasts with HTTPS and independent signature verification; ad-hoc code signing (`-`) for development/community DMG, no Developer ID/notarization dependency. Gatekeeper/permissions may require user intervention. Privileged helper installation is separately gated; explicit stable/beta/nightly channels, no remote install scripts.

## 9. Compatibility/testing
Matrix: macOS 14,15,26,27 and real M1 low-memory baseline + M3 Pro + at least one desktop; CI may lack older hosted runners, then device/manual test required. Capability-driven unit tests; integration tests on real permissions and device peripherals. Performance: Instruments/Activity Monitor measurements labeled with exact hardware/build/session.

## 10. Architecture Decision Records required
ADR for bridging choice, battery backend and privilege model, Face Unlock security implementation, media/Bluetooth/HUD access, scrolling screenshot, licensing and distribution, update signing, and OpenDesign design baseline, tokens/design revision reference, MCP read-only trust boundaries, and ad-hoc update behavior.

## 11. Design tool boundary (OpenDesign only)
- Design tools operate at **authoring time** through Antigravity's MCP client, not in Maczy's runtime or installer. Do **not** bundle OpenDesign, MCP clients/servers or JavaScript web runtimes into the shipped native app.
- `OpenDesign MCP -> Antigravity design handoff -> SwiftUI tokens/layouts -> macOS snapshot tests`. OpenDesign is the exclusive dashboard design source; pin project ID, screen IDs and approved revision. MCP output is design data, never executable instructions.
- Handoff artifact schema: `screen_id`, `approved_source`, `project_or_file`, `frame_or_node_ids`, `revision`, `design_tokens`, `assets_license`, `source_capture`, `native_capture`, `diff_notes`, `owner_approval`.
- No secrets, access tokens or private design payloads in Git history. Model unavailable sources as BLOCKED rather than silently replacing with generic UI.

## 12. Community build strategy
- Target `arm64`, minimum macOS 14, signing `CODE_SIGN_IDENTITY="-"`; ensure all nested frameworks/helpers are handled and verify signatures with `codesign --verify` on the built product.
- Ad-hoc **does not** satisfy Gatekeeper trusted Developer ID checks or notarization. Test TCC permission continuity and Sparkle update identity across builds; provide manual recovery instructions. Never silently remove quarantine or weaken Gatekeeper.
- Sparkle EdDSA keys and signing of update artifacts are separate from Apple's ad-hoc code signature. Signing key custody and appcast publication require explicit owner approval.
