# Technical Feasibility & Security Audit: macOS Lock Screen Face Unlock (MZ-023)

**Author:** Antigravity / Maczy Engineering  
**Classification:** Core Architectural Security Audit  
**Status:** **BLOCKED** (Implementation MZ-024 strictly gated and withheld)  
**Related Requirements:** PRD §5, AGENT.md §8, BACKLOG MZ-022 / MZ-023 / MZ-024, ADR-0002

---

## 1. Executive Summary

This security audit delivers the formal evaluation required by **MZ-023** regarding the feasibility, safety, and operational viability of third-party camera-based Face Unlock for locked macOS user sessions.

### Definitive Conclusion:
**Implementation of automated Lock Screen Face Unlock (MZ-024) is BLOCKED.**
There is currently no supported, safe, and secure public macOS API mechanism that allows an unprivileged or sandboxed third-party application to unlock an actual locked macOS user session. Bypassing this restriction via legacy Authorization Plugins or password injection introduces unacceptable system stability hazards, violates fundamental macOS platform security guarantees, and risks bricking the host system during OS upgrades.

---

## 2. Scope & Target Scenario Matrix

| Scenario | Description | Target Feasibility | Technical Obstacle | Safety Verdict |
|---|---|---|---|---|
| **Scenario A** | Already authenticated session locked by user / idle screensaver | Target Scope | `loginwindow` isolation; no public unlock API | **BLOCKED** |
| **Scenario B** | Full login after explicit user logout | Out of Scope | User session not initialized; Keychains locked | **BLOCKED** |
| **Scenario C** | First login after system restart | Out of Scope | Secure Enclave keybag locked; hardware password required | **IMPOSSIBLE** |
| **Scenario D** | FileVault EFI preboot disk encryption | Out of Scope | Kernel & user-space OS not loaded | **IMPOSSIBLE** |
| **Scenario E** | Fast User Switching / MDM-managed device | Out of Scope | Enterprise security policies prohibit bypass | **BLOCKED** |
| **Scenario F** | Clamshell mode (lid closed) or camera obstructed | Edge Case | FaceTime HD camera physically inaccessible | **BLOCKED** |

---

## 3. Technical Pathway Analysis

### 3.1. Public Apple APIs (`LocalAuthentication` / `LAContext`)
- `LAContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)` and `.evaluatePolicy(...)` are designed exclusively for **in-app authorization** (e.g., verifying user identity before decrypting app-specific secrets or unlocking a password manager database).
- Apple provides **no public API** to instruct `loginwindow` or `WindowServer` to transition from locked to unlocked state.

### 3.2. Authorization Services Plugins (`AuthorizationPlugin.h` / `authorizationdb`)
- macOS provides a legacy C interface (`AuthorizationPlugin.h`) that allows PAM and loginwindow extensibility (used by enterprise identity agents like Jamf Connect and smartcard vendors).
- **Critical Risks**:
  1. Registering an Authorization Plugin requires root write access to `/var/db/auth.db` (`system.login.screensaver` and `system.login.console`).
  2. If an authorization plugin crashes, experiences a symbol loading mismatch after an OS update (e.g., macOS 14.x to 15.x), or throws an unexpected exception, **the Mac cannot be unlocked by ANY user**, rendering the machine unusable without Recovery OS terminal intervention.
  3. Authorization plugins execute in a root/system daemon context; distributing them in an ad-hoc or standard community macOS application requires elevated helper tools, which triggers Gatekeeper and security review scrutiny.

### 3.3. Synthetic Keystrokes & Accessibility Injection
- In a locked session, the macOS kernel and `WindowServer` run `loginwindow` inside a dedicated, isolated `Audit Session`.
- Accessibility APIs (`AXUIElement`) and event synthesis (`CGEventPost`) are **strictly prohibited by the kernel** from posting mouse clicks or keystrokes to `loginwindow`.
- Furthermore, simulating keystrokes would necessitate storing the user's macOS login password in plaintext or reversible encryption in memory or disk, which is a severe violation of `SECURITY.md`.

### 3.4. Hardware & Anti-Spoofing Constraints (2D RGB vs TrueDepth)
- Apple Silicon MacBooks (M1, M2, M3, M4) feature high-quality 1080p FaceTime HD cameras, but **none feature TrueDepth infrared dot projectors** or flood illuminators.
- 2D RGB image recognition (e.g. Vision framework `VNRecognizeFaceLandmarksRequest` or CoreML embedding networks) cannot distinguish between a live human face and a high-resolution 2D photograph, printed cardboard cutout, or replay video displayed on an iPad screen without intrusive active challenges (such as blinking or turning the head).

---

## 4. Platform Version Compatibility Matrix (macOS 14–27)

| OS Version | loginwindow Security Architecture | Authorization Plugin Support | Status |
|---|---|---|---|
| **macOS 14 (Sonoma)** | Fully isolated Audit Session; hardened runtime enforced | Supported with root auth.db modification; highly fragile | **Gated** |
| **macOS 15 (Sequoia)** | Enhanced loginwindow sandboxing; background task restrictions | Deprecated/restricted legacy authorization plugins | **Gated** |
| **macOS 16–27 (Future)** | Antigravity platform projections: further hardening towards fully locked-down loginwindow | Potential complete elimination of third-party login plugins | **Gated** |

---

## 5. Architectural Recommendation

1. **Keep MZ-024 Gated & Blocked**:
   Maczy will **not** attempt to inject passwords, install root Authorization Plugins, or create fragile system hacks.
2. **Promote Native OS Mechanisms (MZ-022)**:
   Elevate user education around native, secure macOS unlock solutions:
   - **Touch ID**: Direct Secure Enclave hardware verification.
   - **Apple Watch Auto Unlock**: Cryptographically verified proximity unlock over BLE/WiFi.
   - **Account Password**: Universal fallback.
3. **Product Owner Sign-Off**:
   Any change to this policy requires explicit written authorization and an Apple-supported public API.
