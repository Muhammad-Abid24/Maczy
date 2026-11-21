# Maczy — Product Requirements Document (PRD)

> Product: **Maczy — Mac be Eazy** | Date: 2026-11-21 | Stage: specification, not implemented
> Owners: Product Owner approves scope and releases; Antigravity implements one authorized task at a time.
> Related: `AGENT.md`, `ARCHITECTURE.md`, `BACKLOG.md`, `SECURITY.md`, `UI-UX.md`.

## 1. Vision
Maczy is a **free/open-source, native, local-first, safe, fast and lightweight macOS utility suite** for **Apple Silicon M-series only**. Consolidate screenshot/recording, battery charge management, Dynamic Notch, Smart Unlock, app updates, Always On, and Mole-inspired system maintenance. **Every module is accessible in the main app and menu bar**; contextual quick interactions also appear in the Dynamic Notch. Dashboard design follows the **owner-approved OpenDesign design baseline as the sole source of truth** (via OpenDesign MCP); notch/menu bar use macOS-native design language.

## 2. Supported platform
- Minimum: **macOS 14 Sonoma**; currently targeted through **macOS 27 Golden Gate**; forward-compatibility as tested. **arm64 Apple Silicon M1 and newer**; no Intel build or unsupported OS fallback.
- Capability-based compatibility: some Mac desktops lack battery/notch; offer a virtual island for non-notch displays. Never imply every hardware-dependent option works everywhere.
- Validate APIs at runtime, not only compile-time; use `@available`, runtime capability probing, and real hardware matrix.
- Performance budget (targets, not results): idle app <=100 MiB resident memory, sustained idle CPU <=1% over 5 minutes, warm-launch-to-menubar p95 <=1 s on M1/8GB test machine; profile separately with notch animations, screen recording and scanning active. No busy polling.

## 3. Experience and behavioral invariants
- Main Dashboard: full settings, actions, detailed status, histories and permission guidance for all seven modules.
- Menu bar: each module has an entry, quick actions and appropriate on/off controls; actions such as capture and update are buttons, not fake persistent toggles.
- Notch: compact/expanded **native Apple-like UI**, contextual actionable widgets; no sole control path.
- Single shared truth: `module_enabled`, `capability`, `permission_state`, `runtime_state` are distinct; all surfaces update immediately after confirmed state transitions.
- Local-first: no accounts, ads, telemetry, remote face-image processing or silent uploads; network is opt-in for update checks/downloads.
- Never misrepresent unsupported API, incomplete permission, macOS lock, or charge bypass as successful.

## 4. Functional requirements and acceptance criteria

### MZ-CAP — Screen Capture & Recording (REQUIRED product scope)
**Capture:** screenshot selected **area**, full **window** (including shadows preference), and **scrolling screenshot** (long content). Provide preview, copy, save and annotation tools. **OCR** extracts selectable/copyable text offline using Apple Vision. Scrolling capture: select a supported target; controlled scroll + stitching with progress, cancellation and fallback when inaccessible/DRM/dynamic content cannot be stitched. Do not claim universal scrolling in every app.

**Recording:** choose **display**, **specific window**, or **custom region**; provide **output size/resolution** selection (native/source, 720p, 1080p, custom within device limits) and aspect/scale behavior. Two independent options: `System audio (speaker/output) ON/OFF` and `Microphone ON/OFF`, with permission and device selection where supported; default both OFF. User may choose video-only, system-audio only, mic-only, or both. Add elapsed timer, pause/resume if supported, start/stop, proper audio synchronization, save/export MP4/H.264 first. Protect privacy: clear capture indicator and no capture until direct action.

**Acceptance:** capture area/window works on macOS 14+ tested device; screenshot scroll/OCR have fixture and real-app test matrix; recording region/window/display has deterministic output size metadata and all four audio combinations tested; inaccessible audio/device has explicit error, never silently substitutes.

### MZ-BAT — Battery Guardian (REQUIRED product scope)
Monitor percent, charging/adapter state, health/cycles/capacity/temperature **only where supported**. User selects **80%, 85%, 90%, 95%, 100%** as charging upper limit; default is **monitor-only until opted in**. Show actual active limit, backend and achieved state. **Charge limit is NOT synonymous with true power-path bypass**: distinguish `charging limited`, `adapter powers Mac`, `discharging`, `native override`, and `unknown`; never label "bypass active" unless verified by supported telemetry/backend. `100%` means no reduced upper limit (not a guaranteed forced charge). Disable unsupported percentages with actionable explanation and option to use native macOS settings if applicable. Prefer Apple-supported native capability when available, otherwise reviewed batt-compatible adapter; no undocumented SMC or private entitlement bypass as a required feature.

**Acceptance:** all five options available as UI values, backend capability negotiated safely; readback checks confirm requested vs effective limits; unsupported scenario retains previous valid state and reports failure; no privileged helper silently installed.

### MZ-NOT — Dynamic Notch (REQUIRED product scope)
Features: (1) physical notch UI and virtual-island fallback, (2) **Now Playing** with artwork/control where legal/available, (3) **notifications** from Maczy and permitted system channels, (4) **volume/brightness HUDs** where officially observable/controllable, (5) **clipboard history** opt-in, (6) **window snap** presets with Accessibility consent as needed, (7) **Lock Screen quick action** invoking *standard macOS lock*, (8) **Live Activities** (Maczy session progress: recording, scanning, awake, updates, charge), (9) **AirPods/TWS connection animation** on observable connection events with opt-in Bluetooth permission where required. Do not promise system-wide notification interception, third-party media metadata, all HUD changes, or every Bluetooth pairing event if public APIs cannot provide them. Use graceful fallback and proof-of-feasibility tasks.

**Acceptance:** all nine use cases have design screens and capability/error states; notch interactions are keyboard accessible, respect reduced-motion, do not cover camera/system menus or interfere with fullscreen apps.

### MZ-UNL — Smart Unlock (macOS Lock Screen Face Unlock; REQUIRED product goal)
**Corrected product intent:** Maczy Smart Unlock aims to recognize the enrolled Mac owner through the built-in or explicitly authorized camera and **unlock the actual already-logged-in, locked macOS user session**. It is **NOT** an in-app Maczy privacy gate. The UI must never substitute an app-only unlock and label it as system unlock.

**Desired user flow:** owner explicitly opts in → camera/face enrollment → local matching and anti-spoof/liveness checks → when an eligible macOS session is locked, initiate a **validated, OS-compatible and security-reviewed unlock pathway** → macOS itself confirms unlocked state. Any unlock operation must fail closed and preserve Apple's normal authentication methods.

**Requirements:** on-device recognition and enrollment/revocation; liveness/replay resistance; detect screen/session lock state using permitted methods; device/OS capability probe; clear manual fallback; enable/disable from app and menu bar with truthful status; permission explanation; strict limits on attempts; zero biometric cloud processing. **Touch ID is an optional native macOS unlock alternative, managed by the OS, not an unlock action Maczy can arbitrarily trigger.** No claims of Apple-certified Face ID or iPhone TrueDepth hardware.

**Feasibility gate (MZ-023):** separately research and test: (A) already authenticated session locked by user/idle; (B) login after logout; (C) first login after reboot; (D) FileVault/preboot; (E) fast user switching/MDM; (F) MacBook lid closed or camera unavailable. The minimum intended deliverable is (A) **only if** safe OS integration is proven. (B)–(F) are not promised. Evaluate documented Authorization Services plug-in techniques, platform/OS constraints and open-source precedents as research, **not authorization to install auth plug-ins or change authorization policy**. Document macOS 14–27 differences and test on disposable/test machines before any sensitive system modification. Third-party programmatic system-unlock is not a standard public `LocalAuthentication` operation.

**Prohibited shortcuts:** silently collecting/storing/injecting macOS account passwords, simulating keyboard typing to the lock screen, disabling SIP/FileVault/MDM/Gatekeeper, replacing loginwindow or modifying authorizationdb without an independently audited approach and explicit owner authorization. Default approach MUST NOT rely on such shortcuts. Where a reviewed system-supported unlock method cannot be demonstrated, keep **macOS Face Unlock = BLOCKED / unavailable** rather than fabricating a working security feature.

**Acceptance:** owner-approved written threat model and feasibility ADR; test matrix for supported OS/device states; opt-in enrollment and removal; spoof/liveness attack evaluation; actual macOS locked→unlocked evidence verified from OS/session state (not a mock UI change); safe failure, rate limiting and normal Touch ID/password fallback. No public release of this feature without independent security review and explicit Product Owner approval.

### MZ-UPD — Updates
Use Sparkle 2 for HTTPS, signed feed and EdDSA-verified updates; optional periodic check and download; release channels stable/beta/nightly (beta/nightly opt-in), manual check, notification, rollback considerations. macOS distributes `.app`/`.dmg`/`.pkg`, not Android `.apk`. No arbitrary installer shell scripts.

### MZ-AWK — Always On
Prevent idle system sleep and optionally idle display sleep via scoped IOPM assertions or ProcessInfo. Timed / indefinite until manual stop; optionally only on AC. **Cannot guarantee preventing all auto locks**, manual lock, MDM policies, lid-close sleep, FileVault or critical thermal events. Offer visible status on dashboard/menu bar/notch. Must release assertions on stop/error/crash.

### MZ-CLN — System Cleaner & Optimizer (Mole-inspired)
Integrated three-tab workspace:
1. **Cleaner:** Read-only disk scan, space analysis, category filters (User Caches, System Logs, Xcode DerivedData, Xcode Archives, Package Manager Caches, Browser Web Caches), preview of exact paths/sizes, exclusion/allowlist, dry-run, explicit confirmation, safe deletion via Trash when feasible, cleanup history, cancellation.
2. **Uninstall:** Native application inventory discovery (`/Applications`, `~/Applications`), bundle metadata inspection (icon, bundle ID, version, publisher, size, last used date), 7-category leftover analysis (Application Support, Caches, Preferences, Logs, Saved Application State, Containers, Other) with 3 safety levels (Safe, Review Required, Protected), non-destructive macOS Trash workflow, fail-closed protection for system apps (`/System/Applications`) and running applications.
3. **Optimize:** Startup & login items inspection via supported Apple APIs (with deep link to macOS Login Items Settings), evidence-first system maintenance (DNS cache, Quick Look cache, stale temp files), categorized developer artifact scanner (Xcode DerivedData, CoreSimulator caches, SPM caches, Cargo caches, npm caches), real-time system monitoring (CPU utilization, memory pressure, disk availability, foreground heavy processes). No fake RAM boosters or speculative speed-up claims. No destructive cleanup in unattended mode and never delete user documents, source repos, databases, Docker volumes or system paths by default.

## 5. Delivery phases (features remain in scope even if staged)
- **P0 Foundation:** Maczy branding, shared state, SwiftUI/AppKit shell, menu bar, OpenDesign MCP design handoff contract, permissions/capability registry, CI.
- **P1 Essential:** screenshot area/window, OCR, recording display/window/region with audio toggles + resolution, Awake, battery read-only, native notch shell.
- **P2 Advanced:** scrolling capture, charging 80–100% backend, notch media/HUD/clipboard/window snap/live activities/connection animation, updates, cleaner scan & review.
- **P3 Security/Release:** macOS Lock Screen Face Unlock gated implementation, native Touch ID fallback documentation, reviewed cleanup execution, security/license audit, packaging/ad-hoc signing, secure community updates and release.
- All user-requested features in this document are required *product goals*. Blockers and availability must be reported; cannot be silently dropped from scope. Public ship date is contingent on gates.

## 6. Non-goals / constraints
No Intel, no Electron/Tauri, no cloud dependency, no collection of user data, no unverified macOS Face Unlock promises or unsafe authentication bypass, no forced lid-closed awake, no private system notification/HUD hooks as promised guarantees, no unlicensed third-party code copies, no autonomous release/merge.

## 7. Approvals and release blockers
- Product Owner approves new dependencies, privileged helpers, biometric design, destructive tests and any release or `main` merge.
- Legal: batt license and Mole CLI GPL-3.0 compatibility must be assessed before bundled integration. Names, artwork, code of CleanShot X and Notchy not copied.
- Feasibility: macOS Lock Screen Face Unlock integration and camera anti-spoof, system HUD and third-party media/Bluetooth observability, window snap, scroll capture and charging backend need capability proofs.
- No official benchmarks/compatibility claims until measured on devices and recorded in PR evidence.

## 8. References
- https://developer.apple.com/documentation/screencapturekit
- https://developer.apple.com/documentation/localauthentication
- https://github.com/charlie0129/batt
- https://github.com/tw93/mole
- https://sparkle-project.org/documentation/

## Dashboard design authority and community distribution
- OpenDesign is the **exclusive design source of truth for the Maczy dashboard**. Antigravity uses verified OpenDesign MCP to discover/create/revise designs. Product Owner must approve a specific OpenDesign project, screen set and revision before fidelity acceptance.
- Dashboard custom visuals originate in approved design baseline; Menu Bar and Dynamic Notch follow native macOS patterns, never copied from generated web UIs.
- No OpenDesign runtime dependency shipped in Maczy; all design output is manually adapted into native SwiftUI/AppKit.
- Developer/community releases use **ad-hoc code signing**, no paid Apple Developer ID or notarization expected. Gatekeeper warnings must be documented; automatic updates require independent Sparkle EdDSA signatures and proven safe behavior. Never equate ad-hoc with a trusted developer identity.
- Required acceptance: OpenDesign MCP verified in Antigravity with a real tool call; owner design snapshot recorded; screenshot and accessibility QA on a real Mac; release test records explicitly note limitations.

## Documentation scope
Use only the root documentation set listed in `README.md`. This is the initial implementation specification; no PRD release numbering or documentation changelog is required. Approved OpenDesign design revision identifiers remain necessary for design traceability.
