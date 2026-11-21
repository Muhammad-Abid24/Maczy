import SwiftUI
import AppKit
import MaczyKit

@main
struct MaczyApp: App {
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
