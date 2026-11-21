import SwiftUI

public struct NotchDetailView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var coordinator: NotchCoordinator = .shared

    public init(appState: AppState) {
        self.appState = appState
    }

    private var profile: NotchScreenProfile {
        coordinator.activeProfile
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dynamic Notch")
                        .font(.system(size: 20, weight: .bold))
                    Text("Contextual live activities, media HUD, and virtual island fallback")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                // Expansion Status Pill
                Text(coordinator.expansionState.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(coordinator.expansionState == .expanded ? MaczyDesignTokens.brandPurple : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(6)
            }

            // MARK: - Active Screen & Geometry Profile Card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: profile.isVirtualIsland ? "circle.fill" : "macbook.gen2")
                        .font(.system(size: 28))
                        .foregroundColor(profile.hasPhysicalNotch ? MaczyDesignTokens.brandPurple : MaczyDesignTokens.statusBlue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.screenName)
                            .font(.system(size: 15, weight: .semibold))
                        HStack(spacing: 6) {
                            Text(profile.hasPhysicalNotch ? "Physical Camera Notch" : "Virtual Island Fallback")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(profile.hasPhysicalNotch ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusBlue)

                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            Text("\(Int(profile.screenFrame.width))×\(Int(profile.screenFrame.height)) pt")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }

                Divider()

                HStack(spacing: 16) {
                    ProfileMetric(label: "Notch Width", value: "\(Int(profile.notchRect.width)) pt")
                    ProfileMetric(label: "Notch Height", value: "\(Int(profile.notchRect.height)) pt")
                    ProfileMetric(label: "Expanded Size", value: "\(Int(profile.expandedSize.width))×\(Int(profile.expandedSize.height)) pt")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(MaczyDesignTokens.panelCornerRadius)

            // MARK: - Display Mode Selector
            VStack(alignment: .leading, spacing: 10) {
                Text("Presentation Mode")
                    .font(.system(size: 13, weight: .semibold))

                Picker("Mode", selection: $coordinator.displayMode) {
                    ForEach(NotchDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            // MARK: - Overlay Controls
            VStack(alignment: .leading, spacing: 10) {
                Text("Interactive Controls")
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 12) {
                    Button(action: {
                        _ = appState.dispatch(.toggleNotchExpanded)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: coordinator.expansionState == .expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            Text(coordinator.expansionState == .expanded ? "Collapse Notch" : "Expand Notch")
                        }
                        .frame(minWidth: 130)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MaczyDesignTokens.brandPurple)

                    Button(action: {
                        coordinator.toggleOverlay()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: coordinator.isOverlayVisible ? "eye.slash" : "eye")
                            Text(coordinator.isOverlayVisible ? "Hide Overlay Window" : "Show Overlay Window")
                        }
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("Shortcut:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("⌘⇧N")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.08))
                            .cornerRadius(4)
                    }
                }
            }

            // MARK: - Architectural Callout
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundColor(MaczyDesignTokens.brandPurple)
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Seamless Multi-Display Architecture")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Maczy automatically adapts its layout: conforming seamlessly to the camera housing on MacBook displays, or rendering a floating dynamic island capsule on external and non-notch monitors.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MaczyDesignTokens.brandPurple.opacity(0.08))
            .cornerRadius(10)
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
    }
}

/// Compact metric tile.
struct ProfileMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
    }
}
