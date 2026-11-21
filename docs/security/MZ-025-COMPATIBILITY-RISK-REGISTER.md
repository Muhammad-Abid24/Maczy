# macOS 14–27 System API Risk Register (MZ-025)

**Document ID:** SEC-RISK-025  
**Version:** 1.0  
**Scope:** Core Modules, Apple Frameworks, TCC Permissions, and Forward Evolution

---

## 1. System API Inventory & Risk Classification

| Module | Primary API / Framework | Permission Required | Risk Level | Forward macOS 14–27 Hazard | Mitigation / Fallback Architecture |
|---|---|---|---|---|---|
| **Capture & Recording** | `ScreenCaptureKit` (`SCStream`, `SCShareableContent`) | Screen Recording | Low | Apple frequently updates permission prompt behavior and audio taps | Explicit preflight checking with error states; zero crash fallback |
| **Vision OCR** | Apple `Vision` (`VNRecognizeTextRequest`) | None | Low | Deprecation of legacy recognition levels | Uses modern `.accurate` mode with language automatic detection; fully offline |
| **Audio Capture** | `AVFoundation` & `AudioToolbox` (AAC 48kHz) | Microphone | Low | Mic indicator LED active; user consent prompt | Fail-closed preflight; system audio only if mic denied |
| **Battery Guardian** | `IOKit` (`IOPowerSources`, `AppleSmartBattery`) | None | Low-Med | Apple internal property key renames | SBS 1.1 standard parsing; desktop/AC power detection |
| **Dynamic Notch** | `AppKit` (`NSPanel`, `.canJoinAllSpaces`) | None | Low | Spaces transitions and multi-display arrangement changes | Window level `.floating`; dynamic geometry recalculated per screen |
| **Window Snap** | `ApplicationServices` (`AXUIElement`) | Accessibility | Medium | Hardened TCC policies in macOS 15+ | Protected process filter; bounds checking; undo stack |
| **Lock Screen** | `SACLockScreenImmediate` via `login.framework` | None | Medium | Private symbol relocation or removal | Dynamic `dlsym` probe; automatic fallback to `CGSession -suspend` |
| **AirPods / TWS** | `IOBluetooth` & `IOKit` HID events | Bluetooth | Low | Bluetooth notification delivery changes | Safe notification center observer; mockable injection for headless tests |
| **Smart Unlock** | `LocalAuthentication` (`LAContext`) | Camera (when active) | Critical | Loginwindow unlock API does not exist | **BLOCKED by MZ-023**. Strict preservation of Touch ID/Password fallbacks |
| **Always On** | `IOKit` (`IOPMAssertionCreateWithName`) | None | Low | Energy saver restrictions | Scoped assertion lifecycle with automatic release on app exit |
| **Sparkle Updates** | Sparkle 2 framework (`SPUStandardUpdaterController`) | Network | Low | Appcast tampering | Mandatory Ed25519 cryptographic signature verification |
| **System Cleaner** | `Foundation` (`FileManager.trashItem`) | Full Disk Access (opt-in) | Low-Med | User data deletion | Read-only scan first; non-destructive macOS Trash only; zero `rm -rf` |

---

## 2. macOS Version Evolution Matrix

### macOS 14 (Sonoma) — Supported Baseline
- `ScreenCaptureKit` audio capture and screenshot streaming stable.
- SwiftUI Window and MenuBarExtra fully integrated.
- Accessibility AXUIElement functions normally with user TCC approval.

### macOS 15 (Sequoia) — Current Stable
- Stricter monthly/periodic TCC prompts for Screen Recording.
- Window tiling natively introduced by macOS; Maczy Window Snap integrates alongside native tiling without conflicts.
- Hardened loginwindow sandboxing.

### macOS 16–27 — Long-Term Projections
- Complete elimination of legacy Authorization Plugins.
- Stricter sandboxing for background helper daemons.
- Maczy's zero-root, local-first, fail-closed architecture ensures continuous compatibility.
