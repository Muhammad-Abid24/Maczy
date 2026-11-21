import SwiftUI

/// High-fidelity Overview dashboard screen directly translated from the approved OpenDesign project (70356bd0-f397-4d5e-983d-93a7952d85c6).
public struct OverviewView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // MARK: - Hero Health Stage Panel
            HeroHealthPanel(appState: appState)

            // MARK: - Permission Notice Strip
            PermissionNoticeStrip()

            // MARK: - Section Header
            HStack {
                Text("Installed Modules")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text("All 7 modules local-first & active")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)

            // MARK: - Module Cards Grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 310, maximum: 380), spacing: 14)], spacing: 14) {
                ForEach(appState.modules) { status in
                    ModuleCardView(status: status, appState: appState)
                }
            }

            // MARK: - Recent Activity Panel
            RecentActivityPanel(appState: appState)
        }
    }
}

/// Hero gradient card featuring the system readiness orb and module readiness indicators.
struct HeroHealthPanel: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0.75, green: 1.0, blue: 0.85))
                        .frame(width: 8, height: 8)
                    Text("Services Nominal")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.75, green: 1.0, blue: 0.85))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12))
                .cornerRadius(12)

                Spacer()

                Text("Apple Silicon arm64")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }

            // Content: Orb + Description
            HStack(spacing: 28) {
                // Readiness Orb (Donut)
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 14)
                        .frame(width: 130, height: 130)

                    Circle()
                        .trim(from: 0.0, to: 0.76)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [Color.white, Color(red: 0.85, green: 0.8, blue: 1.0)]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .frame(width: 130, height: 130)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("76%")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Ready")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                // Copy
                VStack(alignment: .leading, spacing: 8) {
                    Text("One native Mac app.\nLess clutter. More flow.")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineSpacing(2)

                    Text("Maczy consolidates screen capture, battery thresholds, dynamic notch, and maintenance into one lightweight process.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(3)

                    HStack(spacing: 12) {
                        FactBadge(title: "Architecture", value: "arm64")
                        FactBadge(title: "Runtime", value: "Native Swift/Rust")
                        FactBadge(title: "Telemetry", value: "Zero (Local)")
                    }
                    .padding(.top, 4)
                }
            }

            Divider()
                .background(Color.white.opacity(0.15))

            // Module Readiness Chips (7 Modules)
            HStack(spacing: 8) {
                ForEach(MaczyModuleId.allCases) { module in
                    ReadinessChip(module: module, status: appState.status(for: module))
                }
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.09, blue: 0.31), // #23164f
                    Color(red: 0.32, green: 0.20, blue: 0.67), // #5132aa
                    Color(red: 0.52, green: 0.38, blue: 0.89)  // #8462e4
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(MaczyDesignTokens.panelCornerRadius)
        .shadow(color: Color.black.opacity(0.2), radius: 14, x: 0, y: 6)
    }
}

struct FactBadge: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(title + ":")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.65))
            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.1))
        .cornerRadius(6)
    }
}

struct ReadinessChip: View {
    let module: MaczyModuleId
    let status: ModuleStatus?

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(status?.runtimeState == .running ? MaczyDesignTokens.statusGreen : (status?.runtimeState == .blocked ? MaczyDesignTokens.statusRed : MaczyDesignTokens.statusGreen))
                .frame(width: 6, height: 6)
            Text(shortName(module))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.12))
        .cornerRadius(8)
    }

    private func shortName(_ m: MaczyModuleId) -> String {
        switch m {
        case .captureAndRecording: return "Capture"
        case .batteryGuardian: return "Battery"
        case .dynamicNotch: return "Notch"
        case .smartUnlock: return "Unlock"
        case .updates: return "Updates"
        case .alwaysOn: return "Awake"
        case .systemCleaner: return "Cleaner"
        }
    }
}

/// Permission strip highlighting privacy state.
struct PermissionNoticeStrip: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(MaczyDesignTokens.statusGreen)
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 2) {
                Text("Local-First Privacy Architecture")
                    .font(.system(size: 12, weight: .semibold))
                Text("No telemetry, no background network beacons, and no cloud image processing. All operations run on-device.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(MaczyDesignTokens.statusGreen.opacity(0.2), lineWidth: 1)
        )
    }
}

/// Individual module summary card in the Overview grid.
struct ModuleCardView: View {
    let status: ModuleStatus
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(MaczyDesignTokens.brandPurpleSoft)
                        .frame(width: 38, height: 38)
                    Image(systemName: status.iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(MaczyDesignTokens.brandPurple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(status.name)
                        .font(.system(size: 13, weight: .semibold))
                    HStack(spacing: 4) {
                        Circle()
                            .fill(status.runtimeState == .blocked ? MaczyDesignTokens.statusRed : MaczyDesignTokens.statusGreen)
                            .frame(width: 6, height: 6)
                        Text(status.runtimeState.rawValue)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }

            Text(status.summary)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(minHeight: 28, alignment: .topLeading)

            Divider()

            HStack {
                Text(status.id == .smartUnlock ? "Feasibility Gate MZ-023" : "Ready")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(status.id == .smartUnlock ? MaczyDesignTokens.statusRed : .secondary)

                Spacer()

                Button("Open") {
                    appState.selectedTab = .module(status.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Open \(status.name) details")
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

/// Recent activity panel in Overview.
struct RecentActivityPanel: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent System Activity")
                .font(.system(size: 14, weight: .bold))

            HStack(spacing: 12) {
                ActivityTile(icon: "camera.viewfinder", title: "Capture Ready", detail: "Area / Window / OCR ready")
                let battery = appState.batterySnapshot
                let battTitle = battery.isBatteryPresent ? "Battery \(battery.stateOfCharge)%" : "Power: AC"
                let battDetail = battery.isBatteryPresent ? "\(battery.powerSource.rawValue) • \(battery.chargingState.rawValue)" : "Desktop Mac"
                ActivityTile(icon: battery.batteryIconName, title: battTitle, detail: battDetail)
                ActivityTile(icon: "sparkles", title: "Cleaner Standby", detail: "Safe scan available")
            }
        }
        .padding(.top, 6)
    }
}

struct ActivityTile: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(MaczyDesignTokens.brandPurple)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(10)
    }
}
