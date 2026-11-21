import SwiftUI
import AppKit

/// Native macOS Menu Bar surface providing comprehensive controls and truthful status for all seven Maczy modules.
public struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @StateObject private var viewModel = MenuBarViewModel()

    @MainActor
    public init(appState: AppState) {
        self.appState = appState
    }

    @MainActor
    public init() {
        self.appState = .shared
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Header
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(MaczyDesignTokens.brandPurple)
                    .font(.system(size: 14, weight: .bold))
                Text("Maczy")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text("Mac be Eazy")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Text("v0.1.0")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.quaternaryLabelColor))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Result banner (if any)
            if let result = viewModel.lastActionResult {
                HStack(spacing: 6) {
                    Image(systemName: result.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(result.ok ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusOrange)
                        .font(.system(size: 11))
                    Text(result.message ?? (result.ok ? "Action executed" : "Action gated"))
                        .font(.system(size: 10))
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(result.ok ? MaczyDesignTokens.statusGreen.opacity(0.1) : MaczyDesignTokens.statusOrange.opacity(0.1))

                Divider()
            }

            // MARK: - Scrollable Modules Section
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    // 1. Capture & Recording
                    MenuBarModuleSection(
                        title: "Capture & Recording",
                        icon: "camera.viewfinder",
                        statusText: appState.status(for: .captureAndRecording)?.runtimeState.rawValue ?? "Idle",
                        statusColor: MaczyDesignTokens.brandPurple
                    ) {
                        HStack(spacing: 6) {
                            MenuBarButton(title: "Area", shortcut: "⌘⇧1") {
                                _ = viewModel.executeAction(.captureScreenshot(mode: "area"), on: appState)
                            }
                            MenuBarButton(title: "Window", shortcut: "⌘⇧2") {
                                _ = viewModel.executeAction(.captureScreenshot(mode: "window"), on: appState)
                            }
                            MenuBarButton(title: "Full", shortcut: "⌘⇧3") {
                                _ = viewModel.executeAction(.captureScreenshot(mode: "fullscreen"), on: appState)
                            }
                            MenuBarButton(title: "Record", shortcut: "⌘⇧R") {
                                _ = viewModel.executeAction(.startScreenRecording(target: "display", systemAudio: false, microphone: false), on: appState)
                            }
                        }
                    }

                    // 2. Battery Guardian
                    let battery = appState.batterySnapshot
                    let batteryStatusText: String = battery.isBatteryPresent
                        ? "\(battery.stateOfCharge)% • \(battery.chargingState.rawValue)"
                        : "Desktop (AC)"
                    let batteryStatusColor: Color = battery.stateOfCharge > 20
                        ? MaczyDesignTokens.statusGreen
                        : MaczyDesignTokens.statusOrange

                    MenuBarModuleSection(
                        title: "Battery Guardian",
                        icon: battery.batteryIconName,
                        statusText: batteryStatusText,
                        statusColor: batteryStatusColor
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Charge Ceiling (80 - 100%):")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                ForEach([80, 85, 90, 95, 100], id: \.self) { pct in
                                    MenuBarButton(title: "\(pct)%") {
                                        _ = viewModel.executeAction(.selectChargeLimit(percentage: pct), on: appState)
                                    }
                                }
                            }
                        }
                    }

                    // 3. Dynamic Notch
                    MenuBarModuleSection(
                        title: "Dynamic Notch",
                        icon: "macbook.gen2",
                        statusText: appState.status(for: .dynamicNotch)?.runtimeState.rawValue ?? "Idle",
                        statusColor: MaczyDesignTokens.statusBlue
                    ) {
                        HStack {
                            Text("Virtual Island & Contextual HUD")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            MenuBarButton(title: "Toggle", shortcut: "⌘⇧N") {
                                _ = viewModel.executeAction(.toggleNotchExpanded, on: appState)
                            }
                        }
                    }

                    // 4. Smart Unlock (CRITICAL Gated Status)
                    MenuBarModuleSection(
                        title: "Smart Unlock",
                        icon: "lock.trianglebadge.exclamationmark",
                        statusText: "Gated (MZ-023)",
                        statusColor: MaczyDesignTokens.statusRed
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("macOS Lock Screen Face Unlock feasibility research. Native Touch ID/password fallback preserved.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Button("Check Feasibility Status") {
                                _ = viewModel.executeAction(.triggerSessionUnlock, on: appState)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .accessibilityLabel("Check Smart Unlock feasibility status")
                        }
                    }

                    // 5. Updates
                    MenuBarModuleSection(
                        title: "Updates",
                        icon: "arrow.triangle.2.circlepath",
                        statusText: "Sparkle EdDSA",
                        statusColor: MaczyDesignTokens.statusBlue
                    ) {
                        HStack {
                            Text("Channel: Stable")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            MenuBarButton(title: "Check Updates", shortcut: "⌘U") {
                                _ = viewModel.executeAction(.checkForUpdates, on: appState)
                            }
                        }
                    }

                    // 6. Always On
                    MenuBarModuleSection(
                        title: "Always On",
                        icon: "sun.max.fill",
                        statusText: appState.status(for: .alwaysOn)?.runtimeState.rawValue ?? "Idle",
                        statusColor: MaczyDesignTokens.statusOrange
                    ) {
                        HStack(spacing: 5) {
                            MenuBarButton(title: "30m") {
                                _ = viewModel.executeAction(.startAwakeSession(durationMinutes: 30), on: appState)
                            }
                            MenuBarButton(title: "1h") {
                                _ = viewModel.executeAction(.startAwakeSession(durationMinutes: 60), on: appState)
                            }
                            MenuBarButton(title: "Indefinite") {
                                _ = viewModel.executeAction(.startAwakeSession(durationMinutes: nil), on: appState)
                            }
                            MenuBarButton(title: "Stop") {
                                _ = viewModel.executeAction(.stopAwakeSession, on: appState)
                            }
                        }
                    }

                    // 7. System Cleaner
                    MenuBarModuleSection(
                        title: "System Cleaner",
                        icon: "sparkles",
                        statusText: "Mole-inspired Scanner",
                        statusColor: MaczyDesignTokens.brandLavender
                    ) {
                        HStack {
                            Text("Safe, read-only cache analyzer")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            MenuBarButton(title: "Scan", shortcut: "⌘⇧C") {
                                _ = viewModel.executeAction(.startCleanerScan, on: appState)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 460)

            Divider()

            // MARK: - Footer Controls
            VStack(spacing: 2) {
                HStack {
                    Button {
                        appState.selectedModule = .captureAndRecording
                        NSApp.activate(ignoringOtherApps: true)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "macwindow")
                            Text("Open Maczy Dashboard")
                        }
                        .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open Maczy Dashboard")

                    Spacer()
                    Text("⌘O")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)

                HStack {
                    Button("Preferences...") {
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .accessibilityLabel("Open Preferences")

                    Spacer()
                    Text("⌘,")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)

                Divider()
                    .padding(.vertical, 2)

                HStack {
                    Button("Quit Maczy") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(MaczyDesignTokens.statusRed)
                    .accessibilityLabel("Quit Maczy")

                    Spacer()
                    Text("⌘Q")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
            .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
        }
        .frame(width: 320)
    }
}

/// Modular subview for an individual section in the Menu Bar.
struct MenuBarModuleSection<Content: View>: View {
    let title: String
    let icon: String
    let statusText: String
    let statusColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(statusText)
                    .font(.system(size: 10))
                    .foregroundColor(statusColor)
            }
            content()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
        )
    }
}

/// Standardized mini action button with optional shortcut accelerator tag.
struct MenuBarButton: View {
    let title: String
    var shortcut: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(title)
                if let sc = shortcut {
                    Text(sc)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("\(title) action")
    }
}
