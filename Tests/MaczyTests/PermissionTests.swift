import XCTest
@testable import MaczyKit

@MainActor
final class PermissionTests: XCTestCase {
    func testDeepLinkURLsForAllSevenPermissions() {
        let manager = PermissionManager.shared
        for perm in MaczyPermission.allCases {
            guard let url = manager.settingsURL(for: perm) else {
                XCTFail("Missing deep link URL for \(perm)")
                continue
            }
            XCTAssertTrue(url.absoluteString.hasPrefix("x-apple.systempreferences:"), "URL for \(perm) should use x-apple.systempreferences scheme, got: \(url.absoluteString)")
        }
    }

    func testAssociatedModulesForAllPermissions() {
        let manager = PermissionManager.shared
        XCTAssertEqual(manager.associatedModule(for: .screenRecording), .captureAndRecording)
        XCTAssertEqual(manager.associatedModule(for: .microphone), .captureAndRecording)
        XCTAssertEqual(manager.associatedModule(for: .camera), .smartUnlock)
        XCTAssertEqual(manager.associatedModule(for: .accessibility), .dynamicNotch)
        XCTAssertEqual(manager.associatedModule(for: .bluetooth), .dynamicNotch)
        XCTAssertEqual(manager.associatedModule(for: .notifications), .dynamicNotch)
        XCTAssertEqual(manager.associatedModule(for: .fullDiskAccess), .systemCleaner)
    }

    func testPermissionRationalesAreNonEmpty() {
        let manager = PermissionManager.shared
        for perm in MaczyPermission.allCases {
            let rationale = manager.rationale(for: perm)
            XCTAssertFalse(rationale.isEmpty, "Rationale for \(perm) must not be empty")
        }
    }

    func testAppStatePermissionTransitions() {
        let appState = AppState()
        // Defaults to notDetermined
        for perm in MaczyPermission.allCases {
            XCTAssertEqual(appState.permissionState(perm), .notDetermined)
        }

        // Transition to granted
        appState.setPermissionState(.screenRecording, state: .granted)
        XCTAssertEqual(appState.permissionState(.screenRecording), .granted)

        // Transition to denied
        appState.setPermissionState(.screenRecording, state: .denied)
        XCTAssertEqual(appState.permissionState(.screenRecording), .denied)

        // Transition to restricted
        appState.setPermissionState(.camera, state: .restricted)
        XCTAssertEqual(appState.permissionState(.camera), .restricted)
    }

    func testCheckStatusReturnsValidState() {
        let manager = PermissionManager.shared
        for perm in MaczyPermission.allCases {
            let status = manager.checkStatus(for: perm)
            // Status must be one of the valid enum cases
            XCTAssertTrue([PermissionState.granted, .denied, .restricted, .notDetermined].contains(status))
        }
    }

    func testAppStateRefreshPermissionsSync() {
        let appState = AppState()
        // Prior to refresh, all are notDetermined
        XCTAssertEqual(appState.permissionState(.screenRecording), .notDetermined)

        appState.refreshPermissions()

        // Permissions should reflect PermissionManager system states
        for perm in MaczyPermission.allCases {
            let state = appState.permissionState(perm)
            XCTAssertTrue([PermissionState.granted, .denied, .restricted, .notDetermined].contains(state))
        }
    }

    func testPublishedPermissionsDictionaryObservability() {
        let appState = AppState()
        var notificationReceived = false
        let cancellable = appState.$permissions.sink { perms in
            if perms[.screenRecording] == .granted {
                notificationReceived = true
            }
        }

        appState.setPermissionState(.screenRecording, state: .granted)
        XCTAssertTrue(notificationReceived)
        cancellable.cancel()
    }

    func testRequestAuthorizationNonThrowing() async {
        let manager = PermissionManager.shared
        for perm in MaczyPermission.allCases {
            let state = await manager.requestAuthorization(for: perm)
            XCTAssertTrue([PermissionState.granted, .denied, .restricted, .notDetermined].contains(state), "Failed valid state for \(perm)")
        }
    }

    func testCheckFullDiskAccessReturnsValidState() {
        let manager = PermissionManager.shared
        let state = manager.checkFullDiskAccess()
        XCTAssertTrue([PermissionState.granted, .notDetermined].contains(state))
    }

    func testMarkPermissionGrantedUpdatesStateAndNotification() {
        let appState = AppState()
        for perm in MaczyPermission.allCases {
            appState.markPermissionGranted(perm)
            XCTAssertEqual(appState.permissionState(perm), .granted)

            // Calling refreshPermissions should not demote an explicitly granted permission
            appState.refreshPermissions()
            XCTAssertEqual(appState.permissionState(perm), .granted)
        }
    }
}
