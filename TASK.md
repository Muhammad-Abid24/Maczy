# TASK.md — Current Antigravity Task

## Active selection: MZ-031 (DONE) — Awaiting User Command for Next Task
**Objective:** Completed comprehensive cross-surface accessibility and module coverage audit across Maczy's two primary native macOS surfaces (Dashboard and Menu Bar), guaranteeing 100% module parity for all seven canonical modules, VoiceOver metadata compliance, stable accessibility identifiers, truthful status reporting, and reduced-motion awareness.

### Completed this task
- [x] **Cross-Surface Module Parity**:
  - Implemented `MaczyAccessibility.swift` with `MaczyAccessibilityAuditor.auditParity(appState:)`.
  - Verified 100% parity across all 7 canonical modules (`captureAndRecording`, `batteryGuardian`, `dynamicNotch`, `smartUnlock`, `updates`, `alwaysOn`, `systemCleaner`) between Dashboard and Menu Bar.
- [x] **VoiceOver & Accessibility Semantics**:
  - Added VoiceOver labels, accessibility hints, and trait configurations across all interactive controls.
  - Enhanced `SidebarNavItem` in `DashboardView.swift` with `.accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)`, labels, and hints.
  - Enhanced `MenuBarView.swift` with `.accessibilityElement(children: .contain)` and truthful status reporting on each section.
  - Enhanced `OverviewView.swift` with readiness orb semantics, module chips, and card accessibility labels.
- [x] **Stable Accessibility Identifiers**:
  - Defined centralized `MaczyAccessibilityIdentifier` registry covering dashboard tabs, overview elements, menubar sections, action buttons, and global controls (`open_dashboard`, `preferences`, `quit`).
- [x] **Truthful Status & Security Gating**:
  - Ensured security-gated features truthfully communicate their gating boundaries:
    - Smart Unlock: explicitly labeled as gated under MZ-023 feasibility research (no fake active unlock claims).
    - Battery Guardian: charge write ceilings gated under MZ-014 backend authorization.
    - System Cleaner: safe scan review with confirmed deletion gating.
- [x] **Reduced Motion & macOS Human Interface Guidelines**:
  - Integrated `@Environment(\.accessibilityReduceMotion)` in `DashboardView.swift` and `MenuBarView.swift`.
  - Disabled or smoothed transition animations when user requests reduced motion in macOS System Settings.
- [x] **Unit & Integration Test Suite**:
  - Implemented 8 comprehensive tests in `Tests/MaczyTests/AccessibilityAuditTests.swift`:
    1. `testAllSevenModulesExistInMaczyModuleId`
    2. `testCrossSurfaceModuleParityBetweenDashboardAndMenuBar`
    3. `testAllModulesHaveValidAccessibilityDescriptors`
    4. `testSecurityGatedModulesTruthfulReporting`
    5. `testMenuBarActionExecutionParity`
    6. `testStableAccessibilityIdentifiersUniqueness`
    7. `testDashboardTabDisplayNamesAndIcons`
    8. `testReducedMotionAwareness`
  - All 197 Swift tests + 20 Rust tests pass cleanly with 0 warnings on `./scripts/ci.sh`.
- [x] **Git Branch & Push**:
  - Committed and pushed strictly to feature branch `feat/mz-031-accessibility-audit` (NEVER to `main`).
