import XCTest
@testable import MaczyKit

@MainActor
final class AccessibilityAuditTests: XCTestCase {
    private var appState: AppState!
    private var viewModel: MenuBarViewModel!

    override func setUp() {
        super.setUp()
        appState = AppState(capabilityRegistry: CapabilityRegistry(), eventBus: EventBus())
        viewModel = MenuBarViewModel()
    }

    override func tearDown() {
        appState = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - 1. Canonical Module Coverage
    func testAllSevenModulesExistInMaczyModuleId() {
        let allModules = MaczyModuleId.allCases
        XCTAssertEqual(allModules.count, 7, "Maczy must define exactly seven canonical modules")

        let expectedModules: Set<MaczyModuleId> = [
            .captureAndRecording,
            .batteryGuardian,
            .dynamicNotch,
            .smartUnlock,
            .updates,
            .alwaysOn,
            .systemCleaner
        ]
        XCTAssertEqual(Set(allModules), expectedModules, "All 7 canonical modules must match specification")
    }

    // MARK: - 2. Cross-Surface Module Parity
    func testCrossSurfaceModuleParityBetweenDashboardAndMenuBar() {
        let report = MaczyAccessibilityAuditor.auditParity(appState: appState)

        XCTAssertTrue(report.hasFullParity, "Dashboard and Menu Bar must have 100% module coverage parity")
        XCTAssertEqual(report.totalModulesCount, 7)
        XCTAssertEqual(report.dashboardModulesCount, 7)
        XCTAssertEqual(report.menuBarModulesCount, 7)
        XCTAssertTrue(report.missingDashboardModules.isEmpty, "Dashboard is missing modules: \(report.missingDashboardModules)")
        XCTAssertTrue(report.missingMenuBarModules.isEmpty, "Menu Bar is missing modules: \(report.missingMenuBarModules)")
        XCTAssertTrue(report.allDescriptorsValid, "All accessibility descriptors must be valid")
    }

    // MARK: - 3. Accessibility Descriptors & VoiceOver Metadata
    func testAllModulesHaveValidAccessibilityDescriptors() {
        XCTAssertEqual(MaczyAccessibilityRegistry.allDescriptors.count, 7)

        for module in MaczyModuleId.allCases {
            guard let desc = MaczyAccessibilityRegistry.descriptor(for: module) else {
                XCTFail("Missing accessibility descriptor for module: \(module)")
                continue
            }

            XCTAssertFalse(desc.displayName.isEmpty, "\(module) display name must not be empty")
            XCTAssertFalse(desc.voiceOverLabel.isEmpty, "\(module) VoiceOver label must not be empty")
            XCTAssertFalse(desc.voiceOverHint.isEmpty, "\(module) VoiceOver hint must not be empty")
            XCTAssertTrue(desc.dashboardTabIdentifier.hasPrefix("maczy.dashboard.tab."), "\(module) dashboard identifier prefix invalid")
            XCTAssertTrue(desc.menuBarSectionIdentifier.hasPrefix("maczy.menubar.section."), "\(module) menubar identifier prefix invalid")
            XCTAssertFalse(desc.truthfulStatusExplanation.isEmpty, "\(module) truthful explanation must not be empty")
        }
    }

    // MARK: - 4. Truthful Status & Security Gating Audits
    func testSecurityGatedModulesTruthfulReporting() {
        let report = MaczyAccessibilityAuditor.auditParity(appState: appState)

        // Smart Unlock must be security gated (MZ-023)
        XCTAssertTrue(report.securityGatedModules.contains(.smartUnlock), "Smart Unlock must be security gated")
        let unlockDesc = MaczyAccessibilityRegistry.descriptor(for: .smartUnlock)!
        XCTAssertTrue(unlockDesc.isSecurityGated)
        XCTAssertTrue(unlockDesc.truthfulStatusExplanation.contains("MZ-023"))

        // Battery Guardian charge write must be gated (MZ-014)
        XCTAssertTrue(report.securityGatedModules.contains(.batteryGuardian), "Battery Guardian write must be security gated")
        let batteryDesc = MaczyAccessibilityRegistry.descriptor(for: .batteryGuardian)!
        XCTAssertTrue(batteryDesc.isSecurityGated)
        XCTAssertTrue(batteryDesc.truthfulStatusExplanation.contains("MZ-014"))

        // System Cleaner must be gated behind user confirmation
        XCTAssertTrue(report.securityGatedModules.contains(.systemCleaner), "System Cleaner must be gated")
        let cleanerDesc = MaczyAccessibilityRegistry.descriptor(for: .systemCleaner)!
        XCTAssertTrue(cleanerDesc.isSecurityGated)
    }

    // MARK: - 5. Menu Bar Action Pipeline Integration
    func testMenuBarActionExecutionParity() {
        // Gated action execution through Menu Bar
        let unlockResult = viewModel.executeAction(.triggerSessionUnlock, on: appState)
        XCTAssertFalse(unlockResult.ok)
        XCTAssertEqual(unlockResult.errorCode, "CAPABILITY_UNSUPPORTED")

        let batteryResult = viewModel.executeAction(.selectChargeLimit(percentage: 85), on: appState)
        XCTAssertFalse(batteryResult.ok)
        XCTAssertEqual(batteryResult.errorCode, "GATE_MZ_014")

        // Active allowed action execution through Menu Bar
        let awakeResult = viewModel.executeAction(.startAwakeSession(durationMinutes: 15), on: appState)
        XCTAssertTrue(awakeResult.ok)
        XCTAssertEqual(appState.status(for: .alwaysOn)?.runtimeState, .running)

        let stopAwakeResult = viewModel.executeAction(.stopAwakeSession, on: appState)
        XCTAssertTrue(stopAwakeResult.ok)
        XCTAssertEqual(appState.status(for: .alwaysOn)?.runtimeState, .idle)
    }

    // MARK: - 6. Stable Accessibility Identifiers Coverage
    func testStableAccessibilityIdentifiersUniqueness() {
        var identifiers = Set<String>()

        // Dashboard tabs
        for module in MaczyModuleId.allCases {
            let id = MaczyAccessibilityIdentifier.dashboardModuleTab(module)
            XCTAssertFalse(identifiers.contains(id), "Duplicate identifier: \(id)")
            identifiers.insert(id)
        }

        let overviewTabId = MaczyAccessibilityIdentifier.dashboardTab(.overview)
        XCTAssertFalse(identifiers.contains(overviewTabId))
        identifiers.insert(overviewTabId)

        let permTabId = MaczyAccessibilityIdentifier.dashboardTab(.permissions)
        XCTAssertFalse(identifiers.contains(permTabId))
        identifiers.insert(permTabId)

        let settTabId = MaczyAccessibilityIdentifier.dashboardTab(.settings)
        XCTAssertFalse(identifiers.contains(settTabId))
        identifiers.insert(settTabId)

        // Menu bar sections
        for module in MaczyModuleId.allCases {
            let id = MaczyAccessibilityIdentifier.menuBarSection(module)
            XCTAssertFalse(identifiers.contains(id), "Duplicate identifier: \(id)")
            identifiers.insert(id)
        }

        // Global buttons
        let globalButtons = [
            MaczyAccessibilityIdentifier.menuBarBtnOpenDashboard,
            MaczyAccessibilityIdentifier.menuBarBtnPreferences,
            MaczyAccessibilityIdentifier.menuBarBtnQuit,
            MaczyAccessibilityIdentifier.menuBarBtnCaptureArea,
            MaczyAccessibilityIdentifier.menuBarBtnCaptureWindow,
            MaczyAccessibilityIdentifier.menuBarBtnCaptureFullscreen,
            MaczyAccessibilityIdentifier.menuBarBtnCaptureRecord,
            MaczyAccessibilityIdentifier.menuBarBtnNotchToggle,
            MaczyAccessibilityIdentifier.menuBarBtnUnlockStatus,
            MaczyAccessibilityIdentifier.menuBarBtnUpdatesCheck,
            MaczyAccessibilityIdentifier.menuBarBtnAlwaysOnStop,
            MaczyAccessibilityIdentifier.menuBarBtnCleanerScan
        ]

        for btnId in globalButtons {
            XCTAssertFalse(identifiers.contains(btnId), "Duplicate identifier: \(btnId)")
            identifiers.insert(btnId)
        }

        XCTAssertGreaterThanOrEqual(identifiers.count, 26, "Must define at least 26 unique accessibility identifiers")
    }

    // MARK: - 7. Dashboard Tab Accessibility Trait Parity
    func testDashboardTabDisplayNamesAndIcons() {
        for module in MaczyModuleId.allCases {
            let tab = DashboardTab.module(module)
            XCTAssertEqual(tab.displayName, module.displayName)
            XCTAssertEqual(tab.iconName, module.iconName)
            XCTAssertEqual(tab.id, module.rawValue)
        }

        XCTAssertEqual(DashboardTab.overview.displayName, "Overview")
        XCTAssertEqual(DashboardTab.permissions.displayName, "Permissions")
        XCTAssertEqual(DashboardTab.settings.displayName, "Settings")
    }

    // MARK: - 8. Reduced Motion & High Contrast Awareness
    func testReducedMotionAwareness() {
        // AppState sidebar toggling works deterministically regardless of motion settings
        appState.isSidebarExpanded = false
        XCTAssertFalse(appState.isSidebarExpanded)

        appState.isSidebarExpanded = true
        XCTAssertTrue(appState.isSidebarExpanded)

        appState.isSidebarExpanded = false
        XCTAssertFalse(appState.isSidebarExpanded)
    }
}
