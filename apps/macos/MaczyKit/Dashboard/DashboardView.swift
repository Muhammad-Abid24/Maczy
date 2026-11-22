import SwiftUI

/// Native macOS Dashboard adhering faithfully to the approved OpenDesign project (70356bd0-f397-4d5e-983d-93a7952d85c6):
/// - 64px compact icon sidebar expanding on hover/focus to 224px.
/// - Full 7-module navigation plus Overview, Permissions, and Settings.
/// - Distinctive Maczy branding and design tokens.
public struct DashboardView: View {
    @ObservedObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                .contentShape(Rectangle())
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: appState.isSidebarExpanded)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
                .onHover { isHovered in
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        appState.isSidebarExpanded = isHovered
                    }
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
                    Button {
                        // Quick action palette trigger
                    } label: {
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
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Search actions")
                    .accessibilityHint("Opens quick action command palette, shortcut Command K")
                    .accessibilityIdentifier(MaczyAccessibilityIdentifier.dashboardOverviewSearchButton)
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
        .onAppear {
            appState.refreshPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appState.refreshPermissions()
        }
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
        VStack(spacing: 0) {
            // Brand Mark (Header - Clickable to return to Overview)
            Button {
                appState.selectedTab = .overview
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(MaczyDesignTokens.brandPurple)
                            .frame(width: 36, height: 36)
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .bold))
                    }
                    .frame(width: appState.isSidebarExpanded ? 36 : 48)

                    if appState.isSidebarExpanded {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Maczy")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("Mac be Eazy")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, appState.isSidebarExpanded ? 10 : 6)
                .frame(maxWidth: .infinity, alignment: appState.isSidebarExpanded ? .leading : .center)
                .contentShape(Rectangle())
            }
            .buttonStyle(SidebarItemButtonStyle())
            .padding(.top, 14)
            .padding(.bottom, 8)
            .accessibilityLabel("Maczy Overview")
            .accessibilityHint("Navigates back to the Overview dashboard")

            Divider()
                .padding(.horizontal, 8)
                .padding(.bottom, 6)

            // Scrollable Middle List for Navigation Items
            ScrollView(showsIndicators: false) {
                VStack(spacing: 3) {
                    // Overview Nav Item
                    SidebarNavItem(
                        title: "Overview",
                        icon: "square.grid.2x2.fill",
                        isSelected: appState.selectedTab == .overview,
                        isExpanded: appState.isSidebarExpanded,
                        accessibilityIdentifier: MaczyAccessibilityIdentifier.dashboardTab(.overview)
                    ) {
                        appState.selectedTab = .overview
                    }

                    Divider()
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)

                    // Navigation Items for all 7 modules
                    ForEach(MaczyModuleId.allCases) { module in
                        SidebarNavItem(
                            title: module.displayName,
                            icon: module.iconName,
                            isSelected: appState.selectedTab == .module(module),
                            isExpanded: appState.isSidebarExpanded,
                            accessibilityIdentifier: MaczyAccessibilityIdentifier.dashboardModuleTab(module)
                        ) {
                            appState.selectedTab = .module(module)
                            appState.selectedModule = module
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Divider()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

            // Bottom Settings & Permissions
            VStack(spacing: 3) {
                SidebarNavItem(
                    title: "Permissions",
                    icon: "hand.raised.fill",
                    isSelected: appState.selectedTab == .permissions,
                    isExpanded: appState.isSidebarExpanded,
                    accessibilityIdentifier: MaczyAccessibilityIdentifier.dashboardTab(.permissions)
                ) {
                    appState.selectedTab = .permissions
                }

                SidebarNavItem(
                    title: "Settings",
                    icon: "gearshape.fill",
                    isSelected: appState.selectedTab == .settings,
                    isExpanded: appState.isSidebarExpanded,
                    accessibilityIdentifier: MaczyAccessibilityIdentifier.dashboardTab(.settings)
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
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}

/// Custom responsive button style for sidebar items providing immediate visual click/press feedback.
struct SidebarItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SidebarNavItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let isExpanded: Bool
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .frame(width: isExpanded ? 24 : 36, height: 36)
                    .foregroundColor(
                        isSelected
                            ? MaczyDesignTokens.brandPurple
                            : (isHovered ? .primary : .secondary)
                    )

                if isExpanded {
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(
                            isSelected
                                ? MaczyDesignTokens.brandPurple
                                : (isHovered ? .primary : .primary.opacity(0.85))
                        )
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, isExpanded ? 10 : 0)
            .frame(maxWidth: .infinity, alignment: isExpanded ? .leading : .center)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isSelected
                            ? MaczyDesignTokens.brandPurpleSoft
                            : (isHovered ? Color.primary.opacity(0.06) : Color.clear)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(SidebarItemButtonStyle())
        .padding(.horizontal, 6)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(isSelected ? "Currently selected tab" : "Switch to \(title) tab")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier(accessibilityIdentifier ?? "maczy.sidebar.\(title.lowercased())")
    }
}
