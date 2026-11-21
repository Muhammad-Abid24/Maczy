# ADR 0003: macOS 14–27 API Risk Register and Open-Source License Compatibility Matrix (MZ-025)

## Status
Accepted

## Date
2026-11-22

## Context
Maczy is architected as a native, lightweight, privacy-first macOS utility for Apple Silicon (`arm64`). To guarantee multi-year forward compatibility (macOS 14 Sonoma through macOS 15 Sequoia and prospective releases up to macOS 27) and ensure clean, unencumbered open-source distribution under the MIT license, Maczy requires:
1. A rigorous **API Risk Register** cataloging all macOS system frameworks, private symbols, permissions, and fallback mechanisms.
2. A strict **Third-Party License Audit** ensuring that no copyleft licenses (GPL, AGPL, LGPL with static linkage) contaminate the codebase.
3. An automated runtime **Compatibility Engine** that detects unsupported hardware/OS configurations and fails safely.

## Decisions

### 1. OS Compatibility Policy & Support Tiers
- **Tier 1 (Fully Supported & Validated in CI)**:
  - macOS 14.0+ (Sonoma)
  - macOS 15.0+ (Sequoia)
- **Tier 2 (Forward-Compatible Projections macOS 16–27)**:
  - Strict reliance on public Apple SDK frameworks (`ScreenCaptureKit`, `Vision`, `AVFoundation`, `LocalAuthentication`, `AppKit`).
  - Strict isolation and dual-fallback architecture for any system bridges.
- **Unsupported (< macOS 14.0)**:
  - macOS 13 (Ventura) and older are rejected at launch. `ScreenCaptureKit` modern APIs and advanced Swift 6 concurrency require macOS 14.0 minimum deployment target.
- **Hardware Architecture**:
  - Apple Silicon (`arm64`) only. Intel `x86_64` build slices and Rosetta 2 translations are excluded to optimize binary footprint and leverage native Neural Engine/Media Engine hardware.

### 2. API Risk Register & Fallback Architecture
- **ScreenCaptureKit**:
  - *Risk*: Low. Primary screen & audio capture interface since macOS 12.3.
  - *Gating*: Checked via `SCShareableContent` preflight. Missing Screen Recording permission transitions cleanly to `.permissionDenied` guidance.
- **IOKit Battery Telemetry (`IOPowerSources` & `AppleSmartBattery`)**:
  - *Risk*: Low-Medium. Standard SBS 1.1 smart battery dictionary parsing.
  - *Fallback*: Headless/desktop Macs without batteries report AC Power active without crashing.
- **System Lock Screen Bridge (`SACLockScreenImmediate`)**:
  - *Risk*: Medium (Dynamic loading of `login.framework`).
  - *Fallback*: If dynamic symbol lookup fails, falls back immediately to `/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession -suspend`.
- **Window Snapping Accessibility (`AXUIElement`)**:
  - *Risk*: Low-Medium (Requires Accessibility TCC permission).
  - *Fallback*: Checked via `AXIsProcessTrusted()`. Fails closed if untrusted with clear user guidance.
- **Smart Unlock (Camera Face Recognition)**:
  - *Risk*: Critical.
  - *Policy*: Gated by MZ-023. Real macOS lock screen Face Unlock remains BLOCKED to avoid system destabilization or credential exposure.

### 3. Open-Source License Compliance Policy
- **Permitted Licenses**: Permissive open-source licenses only:
  - MIT License
  - Apache License 2.0
  - BSD 2-Clause / 3-Clause
  - Unicode-DFS-2016
- **Prohibited Licenses**:
  - GPLv2, GPLv3, AGPLv3 (Strictly prohibited to prevent copyleft contamination).
  - LGPLv3 (Prohibited for statically linked binaries).
  - Proprietary/Commercial dependencies with usage restrictions.
- All transitive Rust and Swift dependencies must be audited in CI.

## Consequences

### Positive
- Predictable longevity and stability across upcoming macOS releases.
- Zero legal/licensing encumbrances for community adoption and commercial deployment.
- Clear degradation paths when system APIs or permissions are restricted.
