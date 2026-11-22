import SwiftUI

/// SwiftUI view rendered inside the non-activating Notch overlay panel.
@MainActor
public struct NotchContainerView: View {
    @ObservedObject var coordinator: NotchCoordinator
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var mediaCoordinator: MediaHUDCoordinator = .shared
    @ObservedObject var systemHUD: SystemHUDCoordinator = .shared
    @ObservedObject var liveCoordinator: LiveActivityCoordinator = .shared
    @ObservedObject var clipboardManager: ClipboardManager = .shared
    @ObservedObject var windowSnapManager: WindowSnapManager = .shared
    @ObservedObject var twsCoordinator: TWSNotchCoordinator = .shared
    @State private var isHovered: Bool = false

    public init(coordinator: NotchCoordinator) {
        self.coordinator = coordinator
    }

    @MainActor
    public init() {
        self.coordinator = .shared
    }

    private var profile: NotchScreenProfile {
        coordinator.activeProfile
    }

    private var isExpanded: Bool {
        coordinator.expansionState == .expanded
    }

    public var body: some View {
        ZStack {
            if isExpanded {
                expandedIslandView
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.9, anchor: .top).combined(with: .opacity)
                    ))
            } else {
                compactNotchView
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isExpanded)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: - Compact State View
    private var compactNotchView: some View {
        Button(action: {
            coordinator.toggleExpansion()
        }) {
            HStack(spacing: 8) {
                if let hud = systemHUD.activeHUD {
                    // System HUD Level Toast (Volume or Brightness)
                    HStack(spacing: 8) {
                        Image(systemName: hud.iconName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(MaczyDesignTokens.brandLavender)

                        // Progress fill bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 5)
                                Capsule()
                                    .fill(MaczyDesignTokens.brandPurple)
                                    .frame(width: max(0, geo.size.width * CGFloat(hud.level)), height: 5)
                            }
                            .frame(maxHeight: .infinity, alignment: .center)
                        }

                        Text("\(hud.percentage)%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.95))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(MaczyDesignTokens.brandPurple.opacity(0.4), lineWidth: 1))

                } else if let tws = twsCoordinator.activeConnectionToast {
                    // AirPods / TWS Connection Toast Pill
                    HStack(spacing: 8) {
                        Image(systemName: tws.type.iconName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(MaczyDesignTokens.statusGreen)

                        Text(tws.name)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if let battery = tws.battery {
                            Text(battery.summaryText)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                        }

                        Spacer()

                        Circle()
                            .fill(MaczyDesignTokens.statusGreen)
                            .frame(width: 5, height: 5)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.95))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(MaczyDesignTokens.statusGreen.opacity(0.4), lineWidth: 1))

                } else if let activity = liveCoordinator.primaryActivity {
                    // Live Activity or Notification Pill
                    HStack(spacing: 8) {
                        Image(systemName: activity.iconName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(activity.priority >= 90 ? MaczyDesignTokens.statusRed : MaczyDesignTokens.statusOrange)

                        Text(activity.title)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)

                        if !activity.formattedTimer.isEmpty {
                            Text(activity.formattedTimer)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        } else if !activity.formattedRecording.isEmpty {
                            Text(activity.formattedRecording)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(MaczyDesignTokens.statusRed)
                        } else {
                            Text(activity.message)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.95))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))

                } else if mediaCoordinator.isMediaActive {
                    // Now Playing compact pill
                    HStack(spacing: 8) {
                        Image(systemName: mediaCoordinator.currentTrack.isPlaying ? "waveform" : "pause.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(MaczyDesignTokens.brandLavender)

                        Text("\(mediaCoordinator.currentTrack.artist) — \(mediaCoordinator.currentTrack.title)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer()

                        Image(systemName: mediaCoordinator.currentTrack.artworkIconName)
                            .font(.system(size: 10))
                            .foregroundColor(MaczyDesignTokens.brandPurple)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.92))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))

                } else if profile.isVirtualIsland {
                    // Virtual Island Pill with Battery
                    HStack(spacing: 8) {
                        Image(systemName: "macbook.gen2")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)

                        Circle()
                            .fill(MaczyDesignTokens.statusGreen)
                            .frame(width: 5, height: 5)

                        Spacer()

                        Image(systemName: appState.batterySnapshot.batteryIconName)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.85))

                        Text("\(appState.batterySnapshot.stateOfCharge)%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.92))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))

                } else {
                    // Physical Notch Integration
                    HStack {
                        Spacer()
                        Circle()
                            .fill(MaczyDesignTokens.brandPurple)
                            .frame(width: 6, height: 6)
                            .padding(.trailing, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .clipShape(RoundedCornerShape(radius: 12, corners: [.bottomLeft, .bottomRight]))
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded State View
    private var expandedIslandView: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: profile.isVirtualIsland ? "circle.fill" : "macbook.gen2")
                        .font(.system(size: 12))
                        .foregroundColor(MaczyDesignTokens.brandLavender)
                    Text(profile.isVirtualIsland ? "Virtual Island" : "Dynamic Notch")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                HStack(spacing: 8) {
                    // Battery telemetry badge
                    HStack(spacing: 4) {
                        Image(systemName: appState.batterySnapshot.batteryIconName)
                            .font(.system(size: 11))
                        Text("\(appState.batterySnapshot.stateOfCharge)%")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)

                    // Close button
                    Button(action: {
                        coordinator.setExpansionState(.compact)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }

            // MARK: - TWS / AirPods Connection Card
            if let tws = twsCoordinator.activeConnectionToast {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(MaczyDesignTokens.statusGreen.opacity(0.2))
                                .frame(width: 32, height: 32)
                            Image(systemName: tws.type.iconName)
                                .font(.system(size: 14))
                                .foregroundColor(MaczyDesignTokens.statusGreen)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tws.name)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(MaczyDesignTokens.statusGreen)
                                    .frame(width: 5, height: 5)
                                Text("Connected")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }

                        Spacer()

                        Button(action: {
                            twsCoordinator.dismiss()
                        }) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }

                    if let b = tws.battery {
                        HStack(spacing: 10) {
                            if let left = b.left {
                                BatteryBadge(label: "L", percentage: left)
                            }
                            if let right = b.right {
                                BatteryBadge(label: "R", percentage: right)
                            }
                            if let casePct = b.caseBattery {
                                BatteryBadge(label: "Case", percentage: casePct)
                            }
                            if let single = b.single, b.left == nil && b.right == nil {
                                BatteryBadge(label: "Battery", percentage: single)
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
            }

            // MARK: - Now Playing Card (Active Media)
            if mediaCoordinator.isMediaActive {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        // Artwork Icon Tile
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(MaczyDesignTokens.brandPurple.opacity(0.3))
                                .frame(width: 36, height: 36)
                            Image(systemName: mediaCoordinator.currentTrack.artworkIconName)
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(mediaCoordinator.currentTrack.title)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(mediaCoordinator.currentTrack.artist)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                        }

                        Spacer()

                        // Playback Controls
                        HStack(spacing: 12) {
                            Button(action: { mediaCoordinator.previousTrack() }) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            .buttonStyle(.plain)

                            Button(action: { mediaCoordinator.togglePlayPause() }) {
                                Image(systemName: mediaCoordinator.currentTrack.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)

                            Button(action: { mediaCoordinator.nextTrack() }) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Track Progress Bar
                    HStack(spacing: 6) {
                        Text(mediaCoordinator.currentTrack.formattedElapsed)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 3)
                                Capsule()
                                    .fill(MaczyDesignTokens.brandPurple)
                                    .frame(width: max(0, geo.size.width * CGFloat(mediaCoordinator.currentTrack.progress)), height: 3)
                            }
                            .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(height: 10)

                        Text(mediaCoordinator.currentTrack.formattedDuration)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
            }

            // MARK: - Live Activities Section
            if !liveCoordinator.activities.isEmpty {
                VStack(spacing: 6) {
                    ForEach(liveCoordinator.activities) { act in
                        HStack(spacing: 10) {
                            Image(systemName: act.iconName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(act.priority >= 90 ? MaczyDesignTokens.statusRed : MaczyDesignTokens.statusOrange)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(act.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(act.message)
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()

                            if case .timer(_, _, let isRunning) = act.type {
                                Button(action: {
                                    if isRunning {
                                        liveCoordinator.pauseTimer(id: act.id)
                                    } else {
                                        liveCoordinator.resumeTimer(id: act.id)
                                    }
                                }) {
                                    Image(systemName: isRunning ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                                .buttonStyle(.plain)
                            }

                            Button(action: {
                                liveCoordinator.dismissActivity(id: act.id)
                            }) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                    }
                }
            }

            // Quick Actions Stage
            HStack(spacing: 10) {
                NotchActionButton(
                    icon: "camera.viewfinder",
                    title: "Capture Area",
                    color: MaczyDesignTokens.brandPurple
                ) {
                    _ = appState.dispatch(.captureScreenshot(mode: "area"))
                }

                NotchActionButton(
                    icon: "record.circle",
                    title: "Record Display",
                    color: MaczyDesignTokens.statusRed
                ) {
                    _ = appState.dispatch(.startScreenRecording(target: "display", systemAudio: true, microphone: false))
                }

                NotchActionButton(
                    icon: "cup.and.saucer.fill",
                    title: appState.alwaysOnManager.isActive ? "Awake (\(appState.alwaysOnManager.formattedRemainingTime))" : "Always On",
                    color: appState.alwaysOnManager.isActive ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusOrange
                ) {
                    if appState.alwaysOnManager.isActive {
                        _ = appState.dispatch(.stopAwakeSession)
                    } else {
                        _ = appState.dispatch(.startAwakeSession(durationMinutes: nil))
                    }
                }

                NotchActionButton(
                    icon: "doc.on.clipboard",
                    title: "Clip (\(clipboardManager.items.count))",
                    color: MaczyDesignTokens.statusBlue
                ) {
                    if let first = clipboardManager.items.first {
                        clipboardManager.copyToPasteboard(item: first)
                    }
                }

                NotchActionButton(
                    icon: "lock.fill",
                    title: "Lock",
                    color: MaczyDesignTokens.statusRed
                ) {
                    _ = appState.dispatch(.lockScreen)
                }
            }

            // Window Snap Bar
            HStack(spacing: 8) {
                Text("Snap:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Button(action: { _ = appState.dispatch(.snapActiveWindow(preset: .leftHalf)) }) {
                    Image(systemName: "rectangle.lefthalf.filled")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Snap Left Half (⌃⌥←)")

                Button(action: { _ = appState.dispatch(.snapActiveWindow(preset: .rightHalf)) }) {
                    Image(systemName: "rectangle.righthalf.filled")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Snap Right Half (⌃⌥→)")

                Button(action: { _ = appState.dispatch(.snapActiveWindow(preset: .maximize)) }) {
                    Image(systemName: "rectangle.fill")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Maximize (⌃⌥↩)")

                Button(action: { _ = appState.dispatch(.snapActiveWindow(preset: .center)) }) {
                    Image(systemName: "rectangle.center.inset.filled")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Center Window (⌃⌥C)")

                Spacer()

                if windowSnapManager.canUndo {
                    Button(action: { _ = appState.dispatch(.undoWindowSnap) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Undo Snap")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(MaczyDesignTokens.statusOrange)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)

            // Footer Status
            HStack {
                Circle()
                    .fill(MaczyDesignTokens.statusGreen)
                    .frame(width: 6, height: 6)
                Text("Maczy System Nominal • Local-First")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("Press ⌘⇧N to collapse")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}

/// Compact button tile inside the expanded Notch HUD.
struct NotchActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

/// Custom corner radius shape for specific corners.
struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: [RectCorner] = []

    enum RectCorner {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let p1 = CGPoint(x: rect.minX, y: rect.minY)
        let p2 = CGPoint(x: rect.maxX, y: rect.minY)
        let p3 = CGPoint(x: rect.maxX, y: rect.maxY)
        let p4 = CGPoint(x: rect.minX, y: rect.maxY)

        path.move(to: p1)
        path.addLine(to: p2)

        if corners.contains(.bottomRight) {
            path.addLine(to: CGPoint(x: p3.x, y: p3.y - radius))
            path.addArc(center: CGPoint(x: p3.x - radius, y: p3.y - radius), radius: radius, startAngle: .zero, endAngle: .degrees(90), clockwise: false)
        } else {
            path.addLine(to: p3)
        }

        if corners.contains(.bottomLeft) {
            path.addLine(to: CGPoint(x: p4.x + radius, y: p4.y))
            path.addArc(center: CGPoint(x: p4.x + radius, y: p4.y - radius), radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        } else {
            path.addLine(to: p4)
        }

        path.closeSubpath()
        return path
    }
}

/// Compact battery gauge badge for AirPods / TWS components.
private struct BatteryBadge: View {
    let label: String
    let percentage: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
            Image(systemName: percentage > 20 ? "battery.75" : "battery.25")
                .font(.system(size: 10))
                .foregroundColor(percentage > 20 ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusRed)
            Text("\(percentage)%")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.06))
        .cornerRadius(6)
    }
}
