import SwiftUI

public struct UpdatesDetailView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    private var updateManager: UpdateManager {
        appState.updateManager
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(MaczyDesignTokens.brandPurple)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Software Updates")
                            .font(.system(size: 18, weight: .bold))

                        Text("Sparkle 2 EdDSA Cryptographically Verified Distribution")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("v\(updateManager.currentVersion)")
                            .font(.system(size: 12, weight: .bold))
                        Text("Build \(updateManager.currentBuild)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }

                // Active Status Hero Card
                VStack(alignment: .leading, spacing: 12) {
                    switch updateManager.status {
                    case .idle:
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Update Status")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(updateManager.lastCheckedDate.map { "Last checked: \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "Not checked yet in this session")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            checkButton
                        }

                    case .checking:
                        HStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.small)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Checking for updates...")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Querying \(updateManager.selectedChannel.displayName) channel appcast feed")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)

                    case .upToDate(let ver):
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(MaczyDesignTokens.statusGreen)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Maczy is up to date")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Version \(ver) is currently the newest available release.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            checkButton
                        }

                    case .updateAvailable(let item):
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(MaczyDesignTokens.statusOrange)
                                        .frame(width: 8, height: 8)
                                    Text("UPDATE AVAILABLE")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(MaczyDesignTokens.statusOrange)
                                }

                                Spacer()

                                HStack(spacing: 4) {
                                    Image(systemName: "lock.shield.fill")
                                        .font(.system(size: 10))
                                    Text("Ed25519 Verified")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(MaczyDesignTokens.statusGreen)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(MaczyDesignTokens.statusGreen.opacity(0.12))
                                .cornerRadius(4)
                            }

                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Maczy \(item.version)")
                                        .font(.system(size: 18, weight: .bold))
                                    Text("Size: \(item.formattedFileSize) • Min macOS: \(item.minimumSystemVersion ?? "14.0")")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Link(destination: item.downloadURL) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.down.circle.fill")
                                        Text("Download")
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(MaczyDesignTokens.brandPurple)
                            }
                        }

                    case .error(let msg):
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(MaczyDesignTokens.statusRed)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Check Failed")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(msg)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            checkButton
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .cornerRadius(10)

                // Release Channel Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Release Channel")
                        .font(.system(size: 12, weight: .semibold))

                    HStack(spacing: 10) {
                        ForEach(UpdateChannel.allCases) { channel in
                            channelCard(channel)
                        }
                    }
                }

                // Automatic Background Updates Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Automatically Check for Updates")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Periodically query the configured channel feed in the background.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { updateManager.automaticallyChecksForUpdates },
                        set: { updateManager.setAutomaticallyChecksForUpdates($0) }
                    ))
                    .toggleStyle(.switch)
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)

                // Cryptographic Guarantee
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "key.horizontal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(MaczyDesignTokens.brandPurple)
                        Text("Cryptographic Security Policy")
                            .font(.system(size: 12, weight: .semibold))
                    }

                    Text("All Maczy updates require an Ed25519 (EdDSA) public key signature embedded directly within the appcast XML. Community and release builds enforce signature validation on the binary payload before opening or executing, preventing tampering and rogue CDN delivery.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            }
            .padding(18)
        }
    }

    private var checkButton: some View {
        Button(action: {
            _ = appState.dispatch(.checkForUpdates)
        }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11))
                Text("Check Now")
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .buttonStyle(.borderedProminent)
        .tint(MaczyDesignTokens.brandPurple)
    }

    private func channelCard(_ channel: UpdateChannel) -> some View {
        let isSelected = updateManager.selectedChannel == channel
        return Button(action: {
            updateManager.setChannel(channel)
        }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(channel.displayName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isSelected ? MaczyDesignTokens.brandPurple : .primary)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(MaczyDesignTokens.brandPurple)
                            .font(.system(size: 12))
                    }
                }

                Text(channel.description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
            .background(isSelected ? MaczyDesignTokens.brandPurple.opacity(0.1) : Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? MaczyDesignTokens.brandPurple.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
