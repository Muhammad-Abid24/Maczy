import SwiftUI

public struct NotchDetailView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var coordinator: NotchCoordinator = .shared
    @ObservedObject var mediaCoordinator: MediaHUDCoordinator = .shared
    @ObservedObject var systemHUD: SystemHUDCoordinator = .shared
    @ObservedObject var liveCoordinator: LiveActivityCoordinator = .shared

    @State private var dimensionTab: NotchDisplayMode = .alwaysPhysical

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
                    Text("Contextual live activities, media HUD, volume/brightness toasts, and virtual fallback")
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

            // MARK: - Now Playing & Media HUD Stage
            VStack(alignment: .leading, spacing: 10) {
                Text("Now Playing Media HUD")
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(MaczyDesignTokens.brandPurple.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: mediaCoordinator.currentTrack.artworkIconName)
                            .foregroundColor(MaczyDesignTokens.brandPurple)
                            .font(.system(size: 18))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(mediaCoordinator.currentTrack.title)
                            .font(.system(size: 13, weight: .semibold))
                        Text(mediaCoordinator.currentTrack.artist)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: { mediaCoordinator.previousTrack() }) {
                            Image(systemName: "backward.fill")
                        }
                        .buttonStyle(.bordered)

                        Button(action: { mediaCoordinator.togglePlayPause() }) {
                            Image(systemName: mediaCoordinator.currentTrack.isPlaying ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MaczyDesignTokens.brandPurple)

                        Button(action: { mediaCoordinator.nextTrack() }) {
                            Image(systemName: "forward.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
            }

            // MARK: - Live Activities & Notifications
            VStack(alignment: .leading, spacing: 10) {
                Text("Live Activities & Notifications")
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 8) {
                    Button("Test Notification") {
                        liveCoordinator.postNotification(
                            title: "Messages",
                            message: "Review requested for PR #14",
                            appIcon: "bubble.left.and.bubble.right.fill"
                        )
                    }
                    .buttonStyle(.bordered)

                    Button("Start 5m Timer") {
                        liveCoordinator.startTimer(id: "timer_demo", totalSeconds: 300)
                    }
                    .buttonStyle(.bordered)

                    Button("Simulate Download") {
                        liveCoordinator.setTaskProgress(id: "dl_demo", status: "Xcode.xip", progress: 0.75)
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    if !liveCoordinator.activities.isEmpty {
                        Button("Clear") {
                            liveCoordinator.clearAll()
                        }
                        .buttonStyle(.bordered)
                        .tint(MaczyDesignTokens.statusRed)
                    }
                }
            }

            // MARK: - System HUD Sliders (Volume & Brightness)
            VStack(alignment: .leading, spacing: 10) {
                Text("System HUD Feedback")
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 16) {
                    // Volume Slider
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: systemHUD.isVolumeMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 11))
                                .foregroundColor(systemHUD.isVolumeMuted ? MaczyDesignTokens.statusRed : .primary)
                            Text(systemHUD.isVolumeMuted ? "Volume: Muted (0%)" : "Volume: \(Int(systemHUD.currentVolume * 100))%")
                                .font(.system(size: 11, weight: .medium))
                        }
                        Slider(value: Binding(
                            get: { systemHUD.currentVolume },
                            set: { systemHUD.setVolume($0) }
                        ), in: 0.0...1.0)
                        .tint(MaczyDesignTokens.brandPurple)
                    }

                    // Brightness Slider
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 11))
                            Text("Brightness: \(Int(systemHUD.currentBrightness * 100))%")
                                .font(.system(size: 11, weight: .medium))
                        }
                        Slider(value: Binding(
                            get: { systemHUD.currentBrightness },
                            set: { systemHUD.setBrightness($0) }
                        ), in: 0.0...1.0)
                        .tint(MaczyDesignTokens.statusOrange)
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
            }

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
                .onChange(of: coordinator.displayMode) { _, newMode in
                    if newMode == .alwaysVirtual {
                        dimensionTab = .alwaysVirtual
                    } else if newMode == .alwaysPhysical {
                        dimensionTab = .alwaysPhysical
                    } else {
                        dimensionTab = coordinator.isPhysicalActive ? .alwaysPhysical : .alwaysVirtual
                    }
                }
            }

            // MARK: - Notch Dimensions & Scaling (Separated Physical vs Virtual)
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notch Dimensions & Scaling")
                            .font(.system(size: 13, weight: .semibold))
                        Text(dimensionTab == .alwaysPhysical
                            ? "Customize hardware camera notch silhouette and expanded card for MacBook displays."
                            : "Customize floating capsule silhouette and expanded card for external / desktop displays.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if dimensionTab == .alwaysPhysical && coordinator.hasCustomPhysicalDimensions {
                        Button("Reset Physical Defaults") {
                            coordinator.resetPhysicalDimensionsToDefault()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else if dimensionTab == .alwaysVirtual && coordinator.hasCustomVirtualDimensions {
                        Button("Reset Virtual Defaults") {
                            coordinator.resetVirtualDimensionsToDefault()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                // Configuration Target Switcher
                Picker("Target Configuration", selection: $dimensionTab) {
                    Text("Force Physical Notch").tag(NotchDisplayMode.alwaysPhysical)
                    Text("Force Virtual Island").tag(NotchDisplayMode.alwaysVirtual)
                }
                .pickerStyle(.segmented)

                if dimensionTab == .alwaysPhysical {
                    // MARK: Physical Notch Dimensions Controls
                    VStack(spacing: 14) {
                        // Compact Silhouette Dimensions
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Physical Notch Silhouette (Camera Housing)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(coordinator.physicalCompactWidth)) × \(Int(coordinator.physicalCompactHeight)) pt")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(MaczyDesignTokens.brandPurple)
                            }

                            HStack(spacing: 16) {
                                // Width Slider
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "arrow.left.and.right")
                                            .font(.system(size: 10))
                                        Text("Width: \(Int(coordinator.physicalCompactWidth)) pt")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    Slider(
                                        value: Binding(
                                            get: { coordinator.physicalCompactWidth },
                                            set: { coordinator.physicalCompactWidth = $0 }
                                        ),
                                        in: 140...480,
                                        step: 5
                                    )
                                    .tint(MaczyDesignTokens.brandPurple)
                                }

                                // Height Slider
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "arrow.up.and.down")
                                            .font(.system(size: 10))
                                        Text("Height: \(Int(coordinator.physicalCompactHeight)) pt")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    Slider(
                                        value: Binding(
                                            get: { coordinator.physicalCompactHeight },
                                            set: { coordinator.physicalCompactHeight = $0 }
                                        ),
                                        in: 24...54,
                                        step: 1
                                    )
                                    .tint(MaczyDesignTokens.brandLavender)
                                }
                            }
                        }

                        Divider()

                        // Expanded Card Dimensions
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Physical Expanded HUD Card")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(coordinator.physicalExpandedWidth)) × \(Int(coordinator.physicalExpandedHeight)) pt")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(MaczyDesignTokens.brandPurple)
                            }

                            HStack(spacing: 16) {
                                // Width Slider
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "arrow.left.and.right")
                                            .font(.system(size: 10))
                                        Text("Width: \(Int(coordinator.physicalExpandedWidth)) pt")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    Slider(
                                        value: Binding(
                                            get: { coordinator.physicalExpandedWidth },
                                            set: { coordinator.physicalExpandedWidth = $0 }
                                        ),
                                        in: 320...680,
                                        step: 10
                                    )
                                    .tint(MaczyDesignTokens.brandPurple)
                                }

                                // Height Slider
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "arrow.up.and.down")
                                            .font(.system(size: 10))
                                        Text("Height: \(Int(coordinator.physicalExpandedHeight)) pt")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    Slider(
                                        value: Binding(
                                            get: { coordinator.physicalExpandedHeight },
                                            set: { coordinator.physicalExpandedHeight = $0 }
                                        ),
                                        in: 120...320,
                                        step: 5
                                    )
                                    .tint(MaczyDesignTokens.brandLavender)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                } else {
                    // MARK: Virtual Island Dimensions Controls
                    VStack(spacing: 14) {
                        // Compact Silhouette Dimensions
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Virtual Island Silhouette (Floating Capsule)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(coordinator.virtualCompactWidth)) × \(Int(coordinator.virtualCompactHeight)) pt")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(MaczyDesignTokens.statusBlue)
                            }

                            HStack(spacing: 16) {
                                // Width Slider
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "arrow.left.and.right")
                                            .font(.system(size: 10))
                                        Text("Width: \(Int(coordinator.virtualCompactWidth)) pt")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    Slider(
                                        value: Binding(
                                            get: { coordinator.virtualCompactWidth },
                                            set: { coordinator.virtualCompactWidth = $0 }
                                        ),
                                        in: 180...600,
                                        step: 5
                                    )
                                    .tint(MaczyDesignTokens.statusBlue)
                                }

                                // Height Slider
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "arrow.up.and.down")
                                            .font(.system(size: 10))
                                        Text("Height: \(Int(coordinator.virtualCompactHeight)) pt")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    Slider(
                                        value: Binding(
                                            get: { coordinator.virtualCompactHeight },
                                            set: { coordinator.virtualCompactHeight = $0 }
                                        ),
                                        in: 24...64,
                                        step: 1
                                    )
                                    .tint(MaczyDesignTokens.brandLavender)
                                }
                            }
                        }

                        Divider()

                        // Expanded Card Dimensions
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Virtual Expanded HUD Card")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(coordinator.virtualExpandedWidth)) × \(Int(coordinator.virtualExpandedHeight)) pt")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(MaczyDesignTokens.statusBlue)
                            }

                            HStack(spacing: 16) {
                                // Width Slider
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "arrow.left.and.right")
                                            .font(.system(size: 10))
                                        Text("Width: \(Int(coordinator.virtualExpandedWidth)) pt")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    Slider(
                                        value: Binding(
                                            get: { coordinator.virtualExpandedWidth },
                                            set: { coordinator.virtualExpandedWidth = $0 }
                                        ),
                                        in: 320...750,
                                        step: 10
                                    )
                                    .tint(MaczyDesignTokens.statusBlue)
                                }

                                // Height Slider
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "arrow.up.and.down")
                                            .font(.system(size: 10))
                                        Text("Height: \(Int(coordinator.virtualExpandedHeight)) pt")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    Slider(
                                        value: Binding(
                                            get: { coordinator.virtualExpandedHeight },
                                            set: { coordinator.virtualExpandedHeight = $0 }
                                        ),
                                        in: 120...360,
                                        step: 5
                                    )
                                    .tint(MaczyDesignTokens.brandLavender)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                }
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
