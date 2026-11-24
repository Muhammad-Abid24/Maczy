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

    private var activeWidth: CGFloat {
        if isExpanded {
            return coordinator.activeExpandedWidth
        } else if hasActiveNotification {
            return coordinator.activeNotificationWidth
        } else if mediaCoordinator.isAudioActive {
            return coordinator.activeAudioCompactWidth
        } else {
            return coordinator.currentCompactWidth
        }
    }

    private var activeHeight: CGFloat {
        if isExpanded {
            return coordinator.activeExpandedHeight
        } else if hasActiveNotification {
            return coordinator.activeNotificationHeight
        } else {
            return coordinator.currentCompactHeight
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                if isExpanded {
                    expandedIslandView
                        .transition(.opacity)
                } else {
                    compactNotchView
                        .transition(.opacity)
                }
            }
            .frame(width: activeWidth, height: activeHeight)
            .background(Color.black)
            .clipShape(
                DynamicNotchShape(
                    cornerRadius: (isExpanded || hasActiveNotification) ? 22 : 14,
                    earRadius: profile.hasPhysicalNotch ? ((isExpanded || hasActiveNotification) ? 14 : 12) : 0,
                    hasEars: profile.hasPhysicalNotch
                )
            )

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.30, dampingFraction: 0.82), value: isExpanded)
        .animation(.spring(response: 0.30, dampingFraction: 0.82), value: mediaCoordinator.isAudioActive)
        .animation(.spring(response: 0.30, dampingFraction: 0.82), value: hasActiveNotification)
        .onHover { hovering in
            if hovering {
                coordinator.cancelScheduledCollapse()
                if coordinator.expansionState != .expanded {
                    coordinator.setExpansionState(.expanded)
                }
            } else {
                coordinator.scheduleCollapseIfMouseOutside()
            }
        }
    }

    private var hasActiveNotification: Bool {
        systemHUD.activeHUD != nil ||
        twsCoordinator.activeConnectionToast != nil ||
        liveCoordinator.primaryActivity != nil
    }

    // MARK: - Compact State View
    private var compactNotchView: some View {
        Button(action: {
            coordinator.toggleExpansion()
        }) {
            if hasActiveNotification {
                // MARK: - Enlarged Dynamic Notch Notification / HUD Banner (Matching user attachment)
                VStack(spacing: 0) {
                    // Space for hardware camera notch cutout at the top
                    Spacer(minLength: 0)

                    // Notification banner row positioned at the bottom of the enlarged notch
                    if let hud = systemHUD.activeHUD {
                        HStack(spacing: 12) {
                            Image(systemName: hud.iconName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 24, alignment: .leading)

                            // Capsule progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.22))
                                        .frame(height: 7)
                                    Capsule()
                                        .fill(Color.white)
                                        .frame(width: max(0, geo.size.width * CGFloat(hud.level)), height: 7)
                                }
                                .frame(maxHeight: .infinity, alignment: .center)
                            }
                            .frame(height: 14)

                            Text("\(hud.percentage)%")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(minWidth: 38, alignment: .trailing)
                        }
                        .padding(.horizontal, 26)
                        .padding(.bottom, 12)

                    } else if let tws = twsCoordinator.activeConnectionToast {
                        HStack(spacing: 10) {
                            Image(systemName: tws.type.iconName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(MaczyDesignTokens.statusGreen)
                                .frame(width: 24, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(tws.name)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                if let battery = tws.battery {
                                    Text(battery.summaryText)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }

                            Spacer(minLength: 4)

                            Circle()
                                .fill(MaczyDesignTokens.statusGreen)
                                .frame(width: 6, height: 6)
                        }
                        .padding(.horizontal, 26)
                        .padding(.bottom, 12)

                    } else if let activity = liveCoordinator.primaryActivity {
                        HStack(alignment: .top, spacing: 12) {
                            if let bundleId = activity.bundleIdentifier,
                               let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: appUrl.path))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                            } else {
                                Image(systemName: activity.iconName)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(activity.priority >= 90 ? MaczyDesignTokens.statusRed : MaczyDesignTokens.brandLavender)
                                    .frame(width: 32, height: 32, alignment: .center)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(activity.title)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(activity.message)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.90))
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 4)

                            if !activity.formattedTimer.isEmpty {
                                Text(activity.formattedTimer)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            } else if !activity.formattedRecording.isEmpty {
                                Text(activity.formattedRecording)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(MaczyDesignTokens.statusRed)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 14)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // MARK: - Regular Compact Idle / Audio State
                if mediaCoordinator.isAudioActive && !hasActiveNotification {
                    // Audio Playing Compact Notch (Matching user attachment media_1795551410991_f116f758.png)
                    HStack {
                        // Left wing: Circular album art / music icon with progress ring
                        NowPlayingCompactArtworkRing(track: mediaCoordinator.currentTrack)
                            .padding(.leading, profile.hasPhysicalNotch ? 22 : 16)

                        Spacer()

                        // Right wing: Animated 4-bar equalizer
                        NowPlayingEqualizerView(isPlaying: mediaCoordinator.isAudioPlaying)
                            .padding(.trailing, profile.hasPhysicalNotch ? 22 : 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

                    // Track Progress Bar / Stream Status
                    if let duration = mediaCoordinator.currentTrack.duration, duration > 0 {
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
                    } else {
                        // Live Audio / Browser Media Stream Status
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(red: 0.85, green: 0.58, blue: 0.38))
                                .frame(width: 5, height: 5)
                            Text("Active Stream • \(mediaCoordinator.currentTrack.artist)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                            Spacer()
                            NowPlayingEqualizerView(isPlaying: mediaCoordinator.isAudioPlaying)
                                .scaleEffect(0.65)
                        }
                        .frame(height: 10)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
            }

            // MARK: - Live Activities Section (Excludes screen recording which is managed via Quick Action button)
            let activeLiveCards = liveCoordinator.activities.filter {
                if case .screenRecording = $0.type { return false }
                return true
            }
            if !activeLiveCards.isEmpty {
                VStack(spacing: 6) {
                    ForEach(activeLiveCards) { act in
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
                    icon: appState.isRecordingScreen ? "stop.circle.fill" : "record.circle",
                    title: appState.isRecordingScreen ? "Stop" : "Record Display",
                    color: MaczyDesignTokens.statusRed
                ) {
                    if appState.isRecordingScreen {
                        _ = appState.dispatch(.stopScreenRecording)
                    } else {
                        _ = appState.dispatch(.startScreenRecording(target: "display", systemAudio: true, microphone: false))
                    }
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
                Text("Click outside to collapse • ⌘⇧N")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

/// Dynamic Notch Shape supporting native Apple top ear flares and smooth bottom continuous curves.
public struct DynamicNotchShape: Shape {
    public var cornerRadius: CGFloat = 20
    public var earRadius: CGFloat = 12
    public var hasEars: Bool = true

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(cornerRadius, earRadius) }
        set {
            cornerRadius = newValue.first
            earRadius = newValue.second
        }
    }

    public init(cornerRadius: CGFloat = 20, earRadius: CGFloat = 12, hasEars: Bool = true) {
        self.cornerRadius = cornerRadius
        self.earRadius = earRadius
        self.hasEars = hasEars
    }

    public func path(in rect: CGRect) -> Path {
        if !hasEars {
            return Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
        }
        var path = Path()
        let topY = rect.minY
        let bottomY = rect.maxY
        let leftX = rect.minX
        let rightX = rect.maxX
        let ear = min(earRadius, max(0, (rightX - leftX) / 6.0))
        let corner = min(cornerRadius, max(0, (rightX - leftX) / 4.0))

        // Top-left corner on top bezel
        path.move(to: CGPoint(x: leftX, y: topY))

        // Top-left concave ear flare (starts horizontal at top bezel, curves smoothly into vertical side)
        path.addArc(
            center: CGPoint(x: leftX, y: topY + ear),
            radius: ear,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )

        // Down left side
        path.addLine(to: CGPoint(x: leftX + ear, y: bottomY - corner))

        // Bottom-left rounded corner
        path.addArc(
            center: CGPoint(x: leftX + ear + corner, y: bottomY - corner),
            radius: corner,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )

        // Across bottom edge
        path.addLine(to: CGPoint(x: rightX - ear - corner, y: bottomY))

        // Bottom-right rounded corner
        path.addArc(
            center: CGPoint(x: rightX - ear - corner, y: bottomY - corner),
            radius: corner,
            startAngle: .degrees(90),
            endAngle: .degrees(0),
            clockwise: true
        )

        // Up right side
        path.addLine(to: CGPoint(x: rightX - ear, y: topY + ear))

        // Top-right concave ear flare (starts vertical from right side, curves smoothly into horizontal top bezel)
        path.addArc(
            center: CGPoint(x: rightX, y: topY + ear),
            radius: ear,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        // Across top bezel back to start
        path.addLine(to: CGPoint(x: leftX, y: topY))
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

/// Circular artwork with dynamic accent progress ring matching native Apple Dynamic Notch style.
struct NowPlayingCompactArtworkRing: View {
    let track: NowPlayingItem

    var body: some View {
        ZStack {
            // Background subtle circular track
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 2)

            // Accent progress ring (orange/amber gradient matching user screenshot)
            Circle()
                .trim(from: 0, to: CGFloat(track.progress > 0 ? track.progress : 0.70))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.96, green: 0.68, blue: 0.38),
                            Color(red: 0.88, green: 0.54, blue: 0.28)
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Inner circular thumbnail / icon container
            ZStack {
                Circle()
                    .fill(Color(white: 0.12))

                Image(systemName: track.artworkIconName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.96, green: 0.68, blue: 0.38))
            }
            .padding(2.5)
        }
        .frame(width: 24, height: 24)
    }
}

/// Animated 4-bar equalizer waveform matching user screenshot media_1795551410991_f116f758.png.
struct NowPlayingEqualizerView: View {
    let isPlaying: Bool
    @State private var phase: Double = 0.0

    private let timer = Timer.publish(every: 0.18, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(Color(red: 0.85, green: 0.58, blue: 0.38).opacity(isPlaying ? 1.0 : 0.45))
                    .frame(
                        width: 3.2,
                        height: isPlaying ? animatedHeight(for: index) : 3.5
                    )
                    .animation(.easeInOut(duration: 0.18), value: phase)
                    .animation(.easeOut(duration: 0.05), value: isPlaying)
            }
        }
        .frame(height: 20)
        .onReceive(timer) { _ in
            if isPlaying {
                phase += 1.0
            }
        }
    }

    private func animatedHeight(for index: Int) -> CGFloat {
        let pattern: [[CGFloat]] = [
            [7, 15, 11, 16],
            [12, 8, 17, 10],
            [16, 14, 9, 13],
            [9, 17, 13, 7]
        ]
        let step = Int(phase) % pattern.count
        return pattern[step][index]
    }
}
