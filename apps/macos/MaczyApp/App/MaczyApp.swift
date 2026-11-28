import SwiftUI
import AppKit
import MaczyKit

final class MaczyAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            _ = NotchCoordinator.shared
        }
    }
}

@main
struct MaczyApp: App {
    @NSApplicationDelegateAdaptor(MaczyAppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        // Main Application Window
        WindowGroup("Maczy — Mac be Eazy") {
            DashboardView(appState: appState)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1080, height: 720)

        // Native Menu Bar Extra
        MenuBarExtra("Maczy", systemImage: "wand.and.stars") {
            MenuBarView(appState: appState)
        }
        .menuBarExtraStyle(.window)
    }
}
