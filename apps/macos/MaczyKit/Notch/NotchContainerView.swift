import SwiftUI

/// SwiftUI view rendered inside the non-activating Notch overlay panel.
@MainActor
public struct NotchContainerView: View {
    @ObservedObject var coordinator: NotchCoordinator
    @ObservedObject var appState: AppState = .shared
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
                if profile.isVirtualIsland {
                    // Virtual Island Pill
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
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
                } else {
                    // Physical Notch Integration
                    // Extends black background matching physical notch silhouette
                    HStack {
                        Spacer()
                        Circle()
                            .fill(MaczyDesignTokens.brandPurple)
                            .frame(width: 6, height: 6)
                            .padding(.trailing, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .clipShape(
                        RoundedCornerShape(radius: 12, corners: [.bottomLeft, .bottomRight])
                    )
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

            Divider()
                .background(Color.white.opacity(0.15))

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
                    title: "Always On",
                    color: MaczyDesignTokens.statusOrange
                ) {
                    _ = appState.dispatch(.startAwakeSession(durationMinutes: nil))
                }
            }

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
