import SwiftUI

/// Native macOS Dashboard adhering to OpenDesign specification:
/// - 64px compact icon sidebar expanding on hover to 224px.
/// - Full 7-module navigation.
/// - Distinctive Maczy branding and design tokens.
public struct DashboardView: View {
    @ObservedObject var appState: AppState

    @MainActor
    public init(appState: AppState) {
        self.appState = appState
    }

    @MainActor
    public init() {
        self.appState = .shared
    }

    public var body: some View {
        HStack(spacing: 0) {
            // MARK: - Sidebar (Compact 64px, Expands to 224px on hover)
            SidebarView(appState: appState)
                .frame(width: appState.isSidebarExpanded ? MaczyDesignTokens.sidebarWideWidth : MaczyDesignTokens.sidebarCompactWidth)
                .animation(.easeInOut(duration: 0.2), value: appState.isSidebarExpanded)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
                .onHover { isHovered in
                    appState.isSidebarExpanded = isHovered
                }

            Divider()

            // MARK: - Detail Content Workspace
            VStack(alignment: .leading, spacing: 0) {
                // Top Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.selectedModule.displayName)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text(appState.selectedModule.summary)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    StatusBadge(status: appState.status(for: appState.selectedModule))
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                Divider()

                // Active Module Content Area
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ModuleDetailContent(module: appState.selectedModule)
                    }
                    .padding(28)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct SidebarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 8) {
            // Brand Mark
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(MaczyDesignTokens.brandPurple)
                        .frame(width: 36, height: 36)
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .bold))
                }
                .frame(width: 48)

                if appState.isSidebarExpanded {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Maczy")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text("Mac be Eazy")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(.top, 14)
            .padding(.horizontal, 8)

            Divider()
                .padding(.vertical, 4)

            // Navigation Items for all 7 modules
            ForEach(MaczyModuleId.allCases) { module in
                Button {
                    appState.selectedModule = module
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: module.iconName)
                            .font(.system(size: 16))
                            .frame(width: 48, height: 38)
                            .foregroundColor(appState.selectedModule == module ? MaczyDesignTokens.brandPurple : .primary)

                        if appState.isSidebarExpanded {
                            Text(module.displayName)
                                .font(.system(size: 13, weight: appState.selectedModule == module ? .semibold : .regular))
                                .foregroundColor(appState.selectedModule == module ? MaczyDesignTokens.brandPurple : .primary)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(appState.selectedModule == module ? MaczyDesignTokens.brandPurpleSoft.opacity(0.8) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 6)
            }

            Spacer()

            // Footer note
            if appState.isSidebarExpanded {
                VStack(spacing: 2) {
                    Text("Maczy Foundation v0.1.0")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("Apple Silicon Native")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .padding(.bottom, 12)
            }
        }
    }
}

struct StatusBadge: View {
    let status: ModuleStatus?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status?.isImplemented == true ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusOrange)
                .frame(width: 8, height: 8)
            Text(status?.runtimeState.rawValue ?? "Not Implemented")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct ModuleDetailContent: View {
    let module: MaczyModuleId

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Notice card
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(module == .smartUnlock ? MaczyDesignTokens.statusRed : MaczyDesignTokens.statusOrange)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 6) {
                    Text(module == .smartUnlock ? "Critical Security Boundary" : "Phase Status: Foundation Scaffold")
                        .font(.system(size: 14, weight: .semibold))

                    if module == .smartUnlock {
                        Text("Target: Unlocking actual macOS Lock Screen with camera-based face verification.\n\nCRITICAL REQUIREMENT: This is NOT an in-app privacy gate. Programmatic OS unlock requires rigorous technical feasibility research (MZ-023) and explicit Product Owner authorization before any implementation. FileVault, SIP, and system authentication protections are strictly preserved. Native Touch ID, password, and Apple Watch remain available under macOS control.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else if module == .batteryGuardian {
                        Text("Target: Battery health monitoring and selectable charge thresholds (80%, 85%, 90%, 95%, 100%).\n\nCharge limit is strictly distinguished from true power-path bypass. Write controls are gated by MZ-014 backend verification.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else if module == .systemCleaner {
                        Text("Target: Mole-inspired disk maintenance and optimization.\n\nOperates under strict non-destructive protocol: scan -> review -> explicit confirmation -> Trash. Automated deletion is strictly prohibited.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else {
                        Text("This module is represented as a truthful foundation scaffold placeholder. Core logic is under development in subsequent tasks per BACKLOG.md.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(module == .smartUnlock ? MaczyDesignTokens.statusRed.opacity(0.3) : MaczyDesignTokens.statusOrange.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
