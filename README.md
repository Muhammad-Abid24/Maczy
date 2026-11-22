<div align="center">

# Maczy
### Mac be Eazy.

**One native Mac app. Less clutter. More flow.**

An open-source, Apple Silicon-first vision for screen capture, battery care, a smarter notch, system maintenance, and everyday macOS controls—all in one place.

**SwiftUI + AppKit · Rust core · macOS 14+ · Apple Silicon only**

[Discover Maczy](#what-is-maczy) · [Features](#everything-in-one-place) · [Roadmap](#roadmap) · [Contribute](#help-build-maczy)

> 🚧 **Pre-release / implementation stage.** Maczy is being designed and built. The features below are product goals, **not a claim that a working application or download is available**.

</div>

---

## What is Maczy?

Your Mac is powerful. Your workflow shouldn't need seven separate utilities.

**Maczy (Mac be Eazy)** aims to bring essential macOS conveniences into **one fast, native, privacy-first experience**—without Electron, mandatory accounts, or background telemetry.

Use the **Dashboard** for complete control, the **Menu Bar** for quick actions, and the optional **Dynamic Notch** for contextual interactions. All three interfaces share the same underlying application state.

### Three ways to use Maczy

| Dashboard | Menu Bar | Dynamic Notch |
| --- | --- | --- |
| Full controls, module workflows, settings and history | Quick actions, status and toggles | Contextual previews, live status and supported system interactions |

The Dashboard follows an **owner-approved OpenDesign project through OpenDesign MCP**. Menu Bar and Notch follow native macOS conventions. The finished application is implemented with **SwiftUI/AppKit**, not a web UI.

## Everything in one place

| Module | Planned capabilities |
| --- | --- |
| **Capture & Recording** | Area, full-window, fullscreen and scrolling screenshots; OCR; display/window/custom-region recording; output size selection; independent system-audio and microphone toggles |
| **Battery Guardian** | Battery health and charging monitoring; selectable charge ceilings **80 / 85 / 90 / 95 / 100%**; charging and true power-bypass state displayed only when verified by a supported backend |
| **Dynamic Notch** | Now Playing, notifications, volume/brightness HUD, clipboard, window snapping, Lock Screen action, Maczy live activities and AirPods/TWS pairing animations—where supported |
| **Smart Unlock** | **Goal: unlock the actual locked macOS user session with on-device facial recognition via a Mac camera**, with opt-in enrollment, liveness/security checks and normal macOS authentication fallback. **System-unlock integration is a research and security gate, not a working or guaranteed capability.** |
| **Automatic Updates** | Sparkle-based signed update verification, checks/downloads and planned stable/beta/nightly channels |
| **Always On** | Prevent idle system/display sleep, timed sessions, power-aware policies and quick toggles |
| **System Cleaner & Optimizer** | Three integrated sections: **Cleaner** (safe cache scan & review), **Uninstall** (smart application uninstaller, leftover safety analysis, macOS Trash workflow), and **Optimize** (login items with deep link, evidence-first maintenance, developer artifact caches, real-time system monitoring) |

**Every module is accessible from the Dashboard and Menu Bar.** Dynamic Notch remains optional; controls adapt to hardware, macOS versions and permissions.

## Why Maczy?

- **Native at heart.** SwiftUI/AppKit for macOS experiences, Rust for appropriate core logic.
- **Lightweight by design.** Lazy initialization, minimal idle work and real-device performance measurements, including the M1/8 GB baseline.
- **Privacy first.** No required accounts or telemetry; captures and biometric processing remain local by default.
- **Your Mac, your rules.** Transparent permissions, independent modules, reversible settings and no silent cleanup.
- **Community-first.** Reviewable source, open collaboration and planned ad-hoc-signed community releases.

Performance goals are **targets, not benchmark results**. Real CPU, RAM, startup and battery-impact figures will be published only after testing.

## Built for Apple Silicon

| Requirement | Target |
| --- | --- |
| Processor | Apple M-series (`arm64`) |
| macOS | **Sonoma 14 or newer** |
| Interface | SwiftUI + AppKit |
| Core | Rust |
| Design source | OpenDesign via MCP |
| Distribution | Source and future community GitHub releases |
| Code signing | **Ad-hoc** for development and community builds |
| App Store | Not planned |

Battery and physical-notch features are capability-dependent. Support for each future macOS version must be validated rather than assumed.

## Roadmap

These are **planned milestones**, not completed features.

- [ ] **Foundation:** repository scaffold, native window, Dashboard, Menu Bar, shared state and hardware capability detection
- [ ] **Design handoff:** OpenDesign MCP integration, design tokens, accessible native SwiftUI components
- [ ] **Everyday tools:** screenshot capture, battery monitoring and Always On
- [ ] **Dynamic Notch:** native-feeling activities, previews and supported media/system controls
- [ ] **Advanced workflows:** scrolling capture, OCR, recording and safe cleaner operations
- [ ] **Smart Unlock feasibility:** investigate a secure, supportable path to unlocking the **actual macOS Lock Screen**; assess privacy, spoofing and OS integration before implementation
- [ ] **Delivery:** Sparkle updates, ad-hoc-signed community packaging and permissions testing
- [ ] **Validation:** Apple Silicon/macOS compatibility, accessibility, performance, security and third-party license review

### Smart Unlock: ambitious goal, strict security boundary

**Smart Unlock does not mean unlocking Maczy's own screens.** The intended experience is recognizing the Mac owner through the built-in camera and unlocking an **already signed-in but locked macOS session**.

This is **not Apple's Face ID**. Mac webcams do not expose the same Face ID/TrueDepth system available on supported iPhones. A third-party app cannot assume that facial recognition alone grants access to macOS login authentication.

Before shipping this feature, contributors must establish a legitimate, secure and tested system integration path. **We will not** silently capture or inject macOS passwords, bypass System Integrity Protection (SIP), weaken FileVault, tamper with the login system, or misrepresent facial recognition as a successful OS unlock. Normal password/Touch ID/Apple Watch authentication remains under macOS control where available.

A successful face match **is not** a successful Mac unlock. If no supportable unlock integration is found, the feature stays **blocked** rather than being quietly replaced with in-app authentication.

## Technical reality, not marketing promises

- **Charge limit ≠ power bypass.** Available behavior varies by Mac model, firmware, OS and battery-control backend; Maczy will show verified states separately.
- **System HUD, notifications, media and Bluetooth.** Public macOS APIs may limit system-wide interception; unsupported interactions must be labeled clearly.
- **Always On.** Sleep assertions do not defeat manual locking, lid-close rules, FileVault or managed-device policies.
- **Cleaner.** Destructive actions follow **scan → review → confirm → clean**. No silent file deletion.
- **Privacy and permissions.** Camera, microphone, screen recording, Accessibility and other permissions are requested only when needed, with understandable explanations.
- **Ad-hoc signing.** Community builds will not have Developer ID trust or notarization. Gatekeeper may require a user-approved exception. Sparkle's signed-update verification is separate from Apple code signing; permissions and privileged helpers need dedicated tests.

## UI/UX: premium, distinctly Maczy

The Dashboard is designed in **OpenDesign**, with approved screens handed to engineering through **OpenDesign MCP**. The result must feel like a crafted **native desktop utility**, not a SaaS dashboard or embedded website.

The Menu Bar and Dynamic Notch use native macOS interaction conventions. Maczy's visual identity should be distinctive, accessible and lightweight, without copying another application's proprietary design assets.

## Building Maczy

### Prerequisites
- macOS 14.0 Sonoma or newer on Apple Silicon (`arm64`).
- Xcode 15+ / 16+ command line tools (`xcode-select --install`).
- Rust 1.80+ (`rustc` and `cargo`).

### Build & Test Core (Rust)
```bash
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
```

### Build & Test Application (Swift / Xcode)
```bash
# Using Swift Package Manager
swift build
swift test

# Using xcodebuild
xcodebuild -scheme Maczy -destination "generic/platform=macOS" build
```

## Help build Maczy

**Maczy is looking for contributors** who care about thoughtful Mac software.

- **SwiftUI / AppKit:** native windows, controls, accessibility and macOS integration
- **Rust:** modular core services, FFI boundaries, tests and performance profiling
- **Design:** OpenDesign components, interactions and visual consistency
- **Testing:** Apple Silicon devices, macOS versions, permission behavior and usability
- **Security:** facial-recognition threat modeling, OS-unlock feasibility, update verification and safe maintenance
- **Community:** documentation, translations, issues and reproducible bug reports

> **Interested?** Star the repository, share the vision and open an issue or discussion with a concrete idea or device-specific test case when those features are enabled.

Start with [PRD.md](PRD.md), [AGENT.md](AGENT.md), [ARCHITECTURE.md](ARCHITECTURE.md), [UI-UX.md](UI-UX.md), [SECURITY.md](SECURITY.md), [BACKLOG.md](BACKLOG.md), [KANBAN.md](KANBAN.md) and [TASK.md](TASK.md).

## Security & privacy

Maczy prioritizes **least privilege, local processing, explicit user consent and verifiable outcomes**.

Sensitive capture data, biometric templates, credentials and cleanup manifests must not be uploaded or logged by default. Security-sensitive functionality—especially macOS system unlock—must pass a documented review before release.

Please **do not post exploitable vulnerability details publicly**. Follow [SECURITY.md](SECURITY.md) for project security guidance.

## Inspiration & acknowledgments

Maczy takes inspiration from excellent macOS tools: **CleanShot X** (capture workflows), **[batt](https://github.com/charlie0129/batt)** (battery management), **Notchy** (notch interactions), and **[Mole](https://github.com/tw93/mole)** (maintenance).

Maczy is an **independent project** and is not affiliated with or endorsed by these projects or Apple. Inspiration does not grant permission to copy proprietary code, art or designs. Any third-party integration must pass a license and security review before distribution.

## License

**To be finalized before distributing implemented source code or binaries.** Compatibility among potential battery and cleaner integrations needs review. Until a license is added, do not assume repository contents are licensed for reuse simply because open-source distribution is the goal.

---

<div align="center">

### Make your Mac feel easy again.

**Maczy — Mac be Eazy.** ✨

*Built for Apple Silicon. Designed for people who love macOS.*

</div>
