# ADR 0002: macOS Lock Screen Face Unlock Feasibility & Security Gate (MZ-023)

## Status
Accepted — **FEASIBILITY GATE: BLOCKED (Implementation MZ-024 Withheld)**

## Date
2026-11-22

## Context
A key vision explored for Maczy Smart Unlock is providing a camera-based "Face Unlock" experience on Apple Silicon MacBooks (M1–M4). As stated in `PRD.md` and `AGENT.md`:
- Smart Unlock targets unlocking the **ACTUAL LOCKED macOS USER SESSION**, not merely displaying an in-app privacy screen.
- Maczy must never simulate fake in-app unlock success, inject credentials blindly, compromise System Integrity Protection (SIP), weaken FileVault, or store user plaintext account passwords.
- This Architecture Decision Record (ADR) and its accompanying technical audit (`docs/security/MZ-023-FACE-UNLOCK-FEASIBILITY.md`) evaluate the technical mechanisms, system APIs, OS constraints across macOS 14 Sonoma through macOS 15+ Sequoia, and security risks.

## Evaluated Scenarios

1. **Scenario A (User Session Locked / Screensaver Idle)**:
   - User is logged in; display locked via `SACLockScreenImmediate()` or screensaver lock.
   - Target: Camera detects owner face and dismisses lock screen.
2. **Scenario B (Login After Logout)**:
   - User has completely logged out; system is at clean `loginwindow`.
3. **Scenario C (First Login After Boot)**:
   - System powered on; user credential required to initialize user Keychain and FileVault keybag.
4. **Scenario D (FileVault Preboot)**:
   - Early boot environment before macOS kernel is fully loaded.
5. **Scenario E (Fast User Switching / MDM-Enforced Lock)**:
   - Enterprise or multi-user environment with strict PIN/smartcard policies.
6. **Scenario F (Clamshell Mode / Obstructed Camera)**:
   - MacBook lid closed, connected to external monitor without webcam.

## Evaluated Technical Pathways & Findings

### Pathway 1: Public LocalAuthentication Framework (`LAContext`)
- **Finding**: `LAContext` allows third-party apps to authenticate the user *within the application context* (e.g., verifying Touch ID before revealing secrets).
- **Limitation**: Apple provides **zero public APIs** within `LocalAuthentication` to unlock or dismiss the system `loginwindow` or screensaver lock screen from user-space.

### Pathway 2: Authorization Services Plugin (`authorizationdb` / PAM)
- **Finding**: macOS supports Authorization Plugins (e.g. `AuthorizationPlugin.h`, `system.login.screensaver`, `system.login.console`). Products like Jamf Connect or Yubico PAM use this mechanism.
- **Risks & Blockers**:
  1. Registering an Authorization Plugin modifies `/var/db/auth.db` (root privileges required).
  2. If the plugin crashes, panics, or has dynamic linker mismatches during macOS point upgrades (e.g., macOS 14.5 -> 15.0), **the user is completely locked out of their Mac**, requiring Single User Mode or Recovery OS terminal recovery.
  3. Ad-hoc and Developer ID signed third-party distribution cannot safely install auth plugins without explicit Gatekeeper and root MDM intervention.
  4. macOS 15+ increasingly isolates the loginwindow architecture and deprecates legacy authorization plugins.

### Pathway 3: Synthetic Keystroke / Accessibility Injection (`CGEventPost` / `AXUIElement`)
- **Finding**: Simulating the user's password into the lock screen password field.
- **Limitation & Policy Violation**:
  1. The macOS kernel and WindowServer deliberately isolate the `loginwindow` session into a distinct `Audit Session`. Accessibility APIs (`AXUIElement`) and `CGEventPost` are **strictly blocked by the OS kernel** from interacting with `loginwindow` controls to prevent malware keylogging or password replay.
  2. Storing the user's macOS login password in plaintext or reversible encryption in order to type it violates `SECURITY.md` rules.

### Pathway 4: Anti-Spoofing & Sensor Limitations (2D RGB vs TrueDepth)
- **Finding**: Unlike iPhone/iPad Face ID, all existing Mac FaceTime HD cameras are **standard 2D RGB sensors** without TrueDepth infrared dot projectors, flood illuminators, or time-of-flight depth hardware.
- **Risk**: 2D RGB face detection (using Apple Vision or CoreML) is trivially spoofable via photographs, iPad screens, or printed images unless intrusive active liveness challenges (eye tracking, head turning) are mandated.

## Decision

1. **Gate MZ-024 (Actual System Face Unlock Implementation) is MARKED BLOCKED**:
   - Maczy will **NOT** modify `/var/db/auth.db`, install authorization plugins, or store macOS login passwords.
   - Maczy will **NEVER** simulate a fake in-app unlock overlay.
2. **Uphold Native macOS Authentication Exclusivity (MZ-022)**:
   - Touch ID (Secure Enclave), Apple Watch Auto Unlock, and user login passwords remain the sole authorized unlock methods.
3. **Product Owner Authorization Requirement**:
   - Any future work on automated lock dismissal requires a non-intrusive, Apple-sanctioned API, hardware depth sensing, and explicit written Product Owner authorization.

## Consequences

### Positive
- **Guaranteed System Safety**: Zero risk of bricking user loginwindow or causing recovery lockouts during macOS updates.
- **Full SIP & FileVault Compliance**: Application conforms strictly to macOS security architecture.
- **Zero Credential Exposure**: Plaintext passwords are never collected, stored, or processed.
- **Transparent User Trust**: Users are informed of macOS Secure Enclave boundaries rather than being misled by dangerous hacks.
