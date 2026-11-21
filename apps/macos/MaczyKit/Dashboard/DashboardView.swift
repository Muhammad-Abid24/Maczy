import SwiftUI

/// Native macOS Dashboard adhering faithfully to the approved OpenDesign project (70356bd0-f397-4d5e-983d-93a7952d85c6):
/// - 64px compact icon sidebar expanding on hover/focus to 224px.
/// - Full 7-module navigation plus Overview, Permissions, and Settings.
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
                .background(Color(NSColor.windowBackgroundColor).opacity(0.92))
                .onHover { isHovered in
                    appState.isSidebarExpanded = isHovered
                }

            Divider()

            // MARK: - Detail Content Workspace
            VStack(alignment: .leading, spacing: 0) {
                // Top Header Toolbar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.selectedTab.displayName)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text(toolbarSubtitle(for: appState.selectedTab))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    // Command Search Trigger
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                        Text("Search actions")
                            .font(.system(size: 11))
                        Text("⌘K")
                            .font(.system(size: 9, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.08))
                            .cornerRadius(4)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))

                Divider()

                // Content View routing
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch appState.selectedTab {
                        case .overview:
                            OverviewView(appState: appState)
                        case .module(let module):
                            switch module {
                            case .captureAndRecording:
                                CaptureDetailView(appState: appState)
                            case .batteryGuardian:
                                BatteryDetailView(appState: appState)
                            case .dynamicNotch:
                                NotchDetailView(appState: appState)
                            case .smartUnlock:
                                UnlockDetailView(appState: appState)
                            case .updates:
                                UpdatesDetailView(appState: appState)
                            case .alwaysOn:
                                AlwaysOnDetailView(appState: appState)
                            case .systemCleaner:
                                CleanerDetailView(appState: appState)
                            }
                        case .permissions:
                            PermissionCenterView(appState: appState)
                        case .settings:
                            SecurityPreferencesView(appState: appState)
                        }
                    }
                    .padding(28)
                }
            }
        }
        .frame(minWidth: 840, minHeight: 640)
    }

    private func toolbarSubtitle(for tab: DashboardTab) -> String {
        switch tab {
        case .overview:
            return "System readiness, module overview, and recent events."
        case .module(let m):
            return m.summary
        case .permissions:
            return "Local system permission audit and privacy policy."
        case .settings:
            return "Configure all Maczy surfaces on this Mac."
        }
    }
}

struct SidebarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 6) {
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

            // Overview Nav Item
            SidebarNavItem(
                title: "Overview",
                icon: "square.grid.2x2.fill",
                isSelected: appState.selectedTab == .overview,
                isExpanded: appState.isSidebarExpanded
            ) {
                appState.selectedTab = .overview
            }

            Divider()
                .padding(.vertical, 2)

            // Navigation Items for all 7 modules
            ForEach(MaczyModuleId.allCases) { module in
                SidebarNavItem(
                    title: module.displayName,
                    icon: module.iconName,
                    isSelected: appState.selectedTab == .module(module),
                    isExpanded: appState.isSidebarExpanded
                ) {
                    appState.selectedTab = .module(module)
                }
            }

            Spacer()

            Divider()
                .padding(.vertical, 2)

            // Settings & Permissions Nav Items
            SidebarNavItem(
                title: "Permissions",
                icon: "hand.raised.fill",
                isSelected: appState.selectedTab == .permissions,
                isExpanded: appState.isSidebarExpanded
            ) {
                appState.selectedTab = .permissions
            }

            SidebarNavItem(
                title: "Settings",
                icon: "gearshape.fill",
                isSelected: appState.selectedTab == .settings,
                isExpanded: appState.isSidebarExpanded
            ) {
                appState.selectedTab = .settings
            }

            // Footer note
            if appState.isSidebarExpanded {
                VStack(spacing: 2) {
                    Text("Maczy v0.1.0")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("Apple Silicon Native")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .padding(.bottom, 10)
            }
        }
    }
}

struct SidebarNavItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .frame(width: 48, height: 36)
                    .foregroundColor(isSelected ? MaczyDesignTokens.brandPurple : .primary)

                if isExpanded {
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? MaczyDesignTokens.brandPurple : .primary)
                        .lineLimit(1)
                    Spacer()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? MaczyDesignTokens.brandPurpleSoft : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .accessibilityLabel(title)
    }
}
