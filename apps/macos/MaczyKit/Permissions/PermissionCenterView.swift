import SwiftUI

/// Permission Center interface displaying live system permission statuses, least-privilege explanations, and deep links.
public struct PermissionCenterView: View {
    @ObservedObject var appState: AppState
    @State private var permissions: [MaczyPermission: PermissionState] = [:]

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Permission Center")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Maczy adheres strictly to least privilege. Permissions are requested only on explicit user action.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    refreshStatuses()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                        Text("Refresh Status")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Notice strip
            PermissionNoticeStrip()

            // Permission Cards List
            VStack(spacing: 10) {
                ForEach(MaczyPermission.allCases, id: \.self) { perm in
                    PermissionCard(
                        permission: perm,
                        state: appState.permissionState(perm),
                        onGrant: {
                            Task {
                                let newState = await PermissionManager.shared.requestAuthorization(for: perm)
                                await MainActor.run {
                                    appState.setPermissionState(perm, state: newState)
                                }
                            }
                        },
                        onOpenSettings: {
                            PermissionManager.shared.openSettings(for: perm)
                        },
                        onConfirmGranted: {
                            appState.markPermissionGranted(perm)
                        }
                    )
                }
            }
        }
        .onAppear {
            refreshStatuses()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshStatuses()
        }
    }

    private func refreshStatuses() {
        appState.refreshPermissions()
    }
}

struct PermissionCard: View {
    let permission: MaczyPermission
    let state: PermissionState
    let onGrant: () -> Void
    let onOpenSettings: () -> Void
    let onConfirmGranted: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconBackgroundColor(for: state))
                    .frame(width: 40, height: 40)
                Image(systemName: iconName(for: permission))
                    .font(.system(size: 18))
                    .foregroundColor(iconForegroundColor(for: state))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(permission.displayName)
                        .font(.system(size: 13, weight: .semibold))

                    // Associated Module tag
                    Text(PermissionManager.shared.associatedModule(for: permission).displayName)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(4)

                    Spacer()

                    // Status pill
                    HStack(spacing: 5) {
                        Circle()
                            .fill(stateColor(for: state))
                            .frame(width: 6, height: 6)
                        Text(statusLabel(for: state))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(stateColor(for: state))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(stateColor(for: state).opacity(0.12))
                    .cornerRadius(12)
                }

                Text(PermissionManager.shared.rationale(for: permission))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if state == .granted {
                        Text("Authorization active")
                            .font(.system(size: 11))
                            .foregroundColor(MaczyDesignTokens.statusGreen)
                    } else {
                        Button("Request Access") {
                            onGrant()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(MaczyDesignTokens.brandPurple)

                        Button("Open Settings") {
                            onOpenSettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Confirm Granted") {
                            onConfirmGranted()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(MaczyDesignTokens.brandPurple)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func iconName(for p: MaczyPermission) -> String {
        switch p {
        case .screenRecording: return "camera.viewfinder"
        case .camera: return "video.fill"
        case .microphone: return "mic.fill"
        case .accessibility: return "figure.walk.circle.fill"
        case .bluetooth: return "wave.3.forward.circle.fill"
        case .notifications: return "bell.badge.fill"
        case .fullDiskAccess: return "internaldrive.fill"
        }
    }

    private func statusLabel(for s: PermissionState) -> String {
        switch s {
        case .granted: return "Granted"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Requested"
        }
    }

    private func stateColor(for s: PermissionState) -> Color {
        switch s {
        case .granted: return MaczyDesignTokens.statusGreen
        case .denied: return MaczyDesignTokens.statusRed
        case .restricted: return .gray
        case .notDetermined: return MaczyDesignTokens.statusOrange
        }
    }

    private func iconBackgroundColor(for s: PermissionState) -> Color {
        stateColor(for: s).opacity(0.12)
    }

    private func iconForegroundColor(for s: PermissionState) -> Color {
        stateColor(for: s)
    }
}
