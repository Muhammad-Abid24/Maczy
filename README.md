<div align="center">

# ✨ Maczy
### Mac be Eazy.

**One native Mac app. Less clutter. More flow.**

An open-source, Apple Silicon-first toolkit bringing screen capture, battery care, a smarter notch, privacy controls, and Mac maintenance into one place.

**SwiftUI + AppKit · Rust core · macOS 14+ · Apple Silicon only**

[Explore the vision](#-what-is-maczy) · [Features](#-everything-in-one-place) · [Roadmap](#-roadmap) · [Contribute](#-help-build-maczy)

</div>

---

## 🌟 What is Maczy?

Your Mac is powerful. Your workflow shouldn't require seven utilities running at once.

**Maczy (Mac be Eazy)** is a community-driven attempt to bring essential macOS conveniences into **one lightweight, native experience**—without Electron, mandatory accounts, or background telemetry.

Use the **Dashboard** for complete control, the **Menu Bar** for quick actions, and the optional **Dynamic Notch** for contextual interactions. One shared state keeps all three in sync.

### The three ways to use Maczy

| 🖥️ Dashboard | 🎛️ Menu Bar | ✨ Dynamic Notch |
| --- | --- | --- |
| Full settings, history, advanced tools | Fast toggles and everyday actions | Live status, previews, notifications, contextual controls |

The Dashboard follows an **owner-approved OpenDesign project through OpenDesign MCP**. Menu Bar and Notch follow native macOS design conventions, implemented with SwiftUI/AppKit.

## 🧰 Everything in one place

| Module | Planned capabilities |
| --- | --- |
| 📸 **Capture & Record** | Area, window, and scrolling screenshots; OCR; display/window/region recording; output sizing; separate system-audio and microphone toggles |
| 🔋 **Battery Guardian** | Battery health/status monitoring; selectable charge ceilings **80 / 85 / 90 / 95 / 100%**; actual charging/bypass state only when verified by the device/backend |
| 🏝️ **Dynamic Notch** | Now Playing, notifications, volume/brightness HUD, clipboard, window snapping, Lock Screen shortcut, Maczy live activities, AirPods/TWS connection animations |
| 🔐 **Smart Unlock** | Opt-in **in-app** Face Unlock with Touch ID alternative for protected Maczy features; subject to security validation |
| 🔄 **Automatic Updates** | Sparkle-based update checks and verified downloads, with planned stable/beta/nightly channels |
| ☕ **Always On** | Keep system/display awake, timed sessions, power-aware rules, and quick toggles |
| 🧹 **System Cleaner** | Disk analysis, uninstall leftovers review, developer cache analysis, explicit cleanup confirmation and history |

**Everything remains accessible from the Dashboard and Menu Bar.** The Notch is optional; supported controls adapt to the hardware and permissions available.

## 💚 Why build Maczy?

- **Native by default.** SwiftUI/AppKit for macOS experiences, Rust for carefully selected core logic.
- **Lightweight by design.** Lazy-load modules, avoid unnecessary polling, measure memory/CPU on real hardware—including baseline M1/8 GB.
- **Private by default.** No account required, no mandatory telemetry, sensitive data stays on-device unless explicitly requested.
- **You stay in control.** Transparent permissions, independent modules, reversible settings, and no silent file deletion.
- **Community-first.** Open development, reviewable code, and community releases without a paid Apple Developer membership.

Performance goals are **targets**, not measured results. Benchmarks will be published only after real builds are tested.

## 🧱 Built for Apple Silicon

| Requirement | Plan |
| --- | --- |
| Processor | Apple M-series (`arm64`) |
| macOS | **Sonoma 14 or newer** |
| Interface | SwiftUI + AppKit |
| Core | Rust |
| Distribution | Source + community GitHub releases, once ready |
| Code signing | **Ad-hoc** development/community builds |
| App Store | Not planned |

Macs without batteries or physical notches will have those hardware-specific capabilities gracefully disabled or adapted. Future macOS releases require testing before support can be claimed.

## 🗺️ Roadmap

The project is in **planning**, so these are proposed milestones—not completed deliverables.

- [ ] **Foundation:** repository scaffold, native Dashboard, Menu Bar, shared state, capability detection
- [ ] **Design system:** OpenDesign MCP handoff and accessible SwiftUI components
- [ ] **Everyday essentials:** screenshot capture, battery monitoring, Always On
- [ ] **Notch experience:** contextual activities and supported media/system controls
- [ ] **Advanced tools:** scrolling capture, OCR, recording, safe cleaner workflows
- [ ] **Security & delivery:** Smart Unlock validation, verified auto-update pipeline, packaged community builds
- [ ] **Compatibility & release:** device testing, permissions, signing, usability, security and licensing review

Track implementation in [BACKLOG.md](BACKLOG.md), [TASK.md](TASK.md), and [KANBAN.md](KANBAN.md). A checked box requires verification—not just an implementation claim.

## ⚠️ Technical reality, not marketing promises

Some features need careful platform-specific work:

- **Face Unlock is not Apple Face ID.** Macs do not expose iPhone-style Face ID for webcam authentication. Maczy's planned face verification protects **Maczy's own UI**, not the macOS login screen. Touch ID uses Apple's native authentication APIs where available.
- **Charge limit ≠ true power bypass.** Whether a Mac supports a particular charging or power-path behavior depends on its model, firmware, macOS version, and validated backend.
- **System HUD, media, Bluetooth and notifications** may have public API limitations. Maczy will not promise unsupported OS-wide interception or rely silently on fragile private APIs.
- **Always On** cannot override manual locks, lid-close behavior, FileVault, or organization policies.
- **Cleaner** will use **scan → review → confirm → clean**. Never silent deletion.
- **Ad-hoc signing** does not equal Apple Developer ID signing or notarization. Gatekeeper may require user-approved exceptions for community downloads. Sparkle update signatures are a separate security mechanism.

## 🤝 Help build Maczy

**Maczy needs contributors**—especially people who enjoy native macOS development, Rust, accessibility, security, and device testing.

You can help with:

- SwiftUI/AppKit components and macOS integrations
- Rust core modules, FFI, testing, and performance profiling
- UX design and OpenDesign components
- Testing on different Apple Silicon Macs and macOS versions
- Documentation, translations, accessibility, and issue triage

> **Interested in the project?** Star the repository to show interest, share it with other Mac users, and open a discussion or issue with a useful idea, device-specific test case, or implementation proposal—once those GitHub features are enabled.

## 🔒 Security & privacy

Maczy is designed around **explicit user consent**: capture permissions, microphone and camera access, system-control boundaries, and cleanup confirmations are handled as separate capabilities.

Please **do not post exploitable security reports publicly**.

## 🙏 Inspiration and acknowledgments

Maczy takes inspiration from excellent macOS tools: **CleanShot X** (capture workflows), **[batt](https://github.com/charlie0129/batt)** (battery management), **Notchy** (notch interactions), and **[Mole](https://github.com/tw93/mole)** (maintenance).

Maczy is an **independent project**, not affiliated with or endorsed by these projects or Apple. Inspiration is not a license to copy proprietary assets or code. Third-party code and license compatibility must be reviewed **before** integration or redistribution.

## 📄 License

**To be finalized before distributing source implementations or binaries.** License compatibility—particularly across battery and cleaner integrations—requires review. Until a license is added, do not assume the repository's contents carry an open-source license solely because this is the project's goal.

---

<div align="center">

### Make your Mac feel easy again.

**Maczy — Mac be Eazy.** ✨

*Built for Apple Silicon. Designed for people who love their MacOS.*

</div>
