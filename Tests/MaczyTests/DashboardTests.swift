import XCTest
@testable import MaczyKit

@MainActor
final class DashboardTests: XCTestCase {
    func testDashboardInitialTabIsOverview() {
        let appState = AppState()
        XCTAssertEqual(appState.selectedTab, .overview)
    }

    func testDashboardTabSwitching() {
        let appState = AppState()

        for module in MaczyModuleId.allCases {
            appState.selectedTab = .module(module)
            XCTAssertEqual(appState.selectedTab, .module(module))
            XCTAssertEqual(appState.selectedTab.displayName, module.displayName)
            XCTAssertEqual(appState.selectedTab.iconName, module.iconName)
        }

        appState.selectedTab = .permissions
        XCTAssertEqual(appState.selectedTab, .permissions)

        appState.selectedTab = .settings
        XCTAssertEqual(appState.selectedTab, .settings)

        appState.selectedTab = .overview
        XCTAssertEqual(appState.selectedTab, .overview)
    }

    func testOverviewHasAllSevenModules() {
        let appState = AppState()
        XCTAssertEqual(appState.modules.count, 7)
    }

    func testDesignTokensMatchesOpenDesignSpecification() {
        XCTAssertEqual(MaczyDesignTokens.sidebarCompactWidth, 64)
        XCTAssertEqual(MaczyDesignTokens.sidebarWideWidth, 224)
        XCTAssertEqual(MaczyDesignTokens.toolbarHeight, 52)
        XCTAssertEqual(MaczyDesignTokens.windowCornerRadius, 13)
        XCTAssertEqual(MaczyDesignTokens.panelCornerRadius, 16)
        XCTAssertEqual(MaczyDesignTokens.buttonCornerRadius, 9)
    }
}
