# TASK.md — Current Antigravity Task

## Active selection: MZ-024 (DONE) — Actual macOS Locked-Session Face Unlock Enrollment, Anti-Spoof Audit & Fail-Closed Gating
**Objective:** Implement on-device face enrollment and template revocation, anti-spoofing sensor audit (2D RGB vs TrueDepth IR), presentation attack rejection testing, lock state observation via `CGSessionCopyCurrentDictionary`, rate-limiting attempt lockout, and fail-closed security gating under `GATE_MZ_024` preserving native Touch ID, Apple Watch, and user password fallbacks.

### Completed this task
- [x] **Switched to Main & Pulled**: Checked out `main` and pulled latest upstream commits (`70aa199`).
- [x] **Created New Feature Branch**: Created branch `feat/mz-024-face-unlock` directly off updated `main`.
- [x] **Implemented Face Unlock Manager (`FaceUnlockManager.swift`)**:
  - `FaceEnrollmentState`: Tracks lifecycle (`.notEnrolled`, `.enrolling`, `.enrolled`, `.revoked`).
  - `BiometricTemplate`: On-device mathematical landmark feature vector hashing (`featureDigest`), quality threshold scoring (>= 0.50), zero plaintext passwords, and zero raw image storage.
  - `AntiSpoofAuditor`: Hardware audit detecting flat 2D RGB FaceTime HD sensor and lack of TrueDepth IR depth dot matrix on Apple Silicon MacBooks; identifies presentation attack vulnerability (`.critical_2DSensorVulnerable`).
  - `LivenessChallenge`: Multi-axis variance evaluation (yaw/pitch angles and eye-blink detection) rejecting static photos.
  - `CGSessionCopyCurrentDictionary`: Real-time session lock state inspection (`CGSSessionScreenIsLocked`).
  - Rate Limiting: Tracks failed unlock attempts and enforces lockout after 3 consecutive failures (`RATE_LIMITED_LOCKOUT`).
  - `GATE_MZ_024` Fail-Closed System Unlock Gating: Truthfully evaluates third-party loginwindow dismissal; withholds dangerous root `auth.db` modification or password keystroke injection, preserving native Touch ID, Apple Watch, and account password fallbacks.
- [x] **Integrated Smart Unlock Lab UI (`UnlockDetailView.swift`)**:
  - Face Unlock Enrollment card: Status badge, Enroll Face button with Vision liveness validation, Revoke Template button, and template metadata.
  - Anti-Spoofing & Hardware Sensor Audit card: Sensor architecture readout, risk classification, Real-Time Liveness check, and 2D Photo Presentation Attack simulation.
  - Locked-Session Unlock Verification: Interactive unlock test button with detailed result banner showing `GATE_MZ_024` fail-closed protection.
  - Retained all existing MZ-022 native fallback cards (Touch ID, Apple Watch, Account Password) and MZ-023 feasibility matrix.
- [x] **Created Formal Threat Model (`docs/security/MZ-024-FACE-UNLOCK-THREAT-MODEL.md`)**:
  - Documented attack vectors (2D Photo, Screen Replay, Synthetic Keystroke, Auth Plugin Bricking, Brute-Force Replay, Credential Exfiltration).
  - Defined gating flowchart and verified security invariants.
- [x] **Implemented Comprehensive Unit Tests (`Tests/MaczyTests/FaceUnlockTests.swift`)**:
  - `testFaceEnrollmentLifecycle`: Enrolls, validates template digest/quality, revokes cleanly.
  - `testFaceEnrollmentQualityAndLivenessGuards`: Asserts rejection of low quality (< 0.50) and failed liveness challenges.
  - `testAntiSpoofHardwareAuditAnd2DPhotoAttack`: Confirms 2D sensor limitation detection and presentation attack rejection.
  - `testSessionUnlockFailsClosedWithGateMZ024`: Verifies `GATE_MZ_024` fail-closed error code, explanation, and native fallback preservation.
  - `testRateLimitingLockoutAfterThreeFailures`: Asserts lockout after 3 attempts and unlock reset via native auth.
  - `testSessionLockStateQuery`: Validates `CGSessionCopyCurrentDictionary` query.
  - `testUnlockDetailViewIntegration`: Verifies SwiftUI view hierarchy binding.
- [x] **Verification**:
  - `./scripts/ci.sh` passed: 23 Rust tests passed, 240 Swift tests passed, Xcode build arm64 succeeded, ad-hoc signature verified.
  - `./scripts/dev.sh` packaged, signed, and launched `/Users/muhammadabid/Applications/Maczy.app`.
