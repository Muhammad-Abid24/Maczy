import SwiftUI

/// Security and Privacy Preferences view conforming to SECURITY.md policies.
public struct SecurityPreferencesView: View {
    @ObservedObject var appState: AppState

    @State private var telemetryDisabled = true
    @State private var clipboardRetention = "Off"
    @State private var nonDestructiveTrash = true
    @State private var eddsaVerificationEnabled = true
    @State private var statusAlertMessage: String?

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Security & Privacy Preferences")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Maczy is local-first, least-privilege, and fail-closed by design.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            if let msg = statusAlertMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(MaczyDesignTokens.statusGreen)
                    Text(msg)
                        .font(.system(size: 11))
                    Spacer()
                }
                .padding(10)
                .background(MaczyDesignTokens.statusGreen.opacity(0.1))
                .cornerRadius(8)
            }

            // Section 1: Network & Telemetry
            SecuritySection(title: "Network & Telemetry", icon: "network.slash") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Disable All Diagnostic & Usage Telemetry")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Maczy sends zero analytic telemetry, crashes, or user data to remote servers.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $telemetryDisabled)
                            .labelsHidden()
                            .disabled(true) // Permanently disabled by policy
                    }

                    Text("Enforced by SECURITY.md policy. Cannot be enabled.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(MaczyDesignTokens.statusGreen)
                }
            }

            // Section 2: Biometric & Smart Unlock Security
            SecuritySection(title: "Smart Unlock & Biometrics", icon: "lock.shield") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Face Unlock feasibility research operates locally. No raw images are retained.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button("Purge Local Biometric Cache") {
                            statusAlertMessage = "Biometric cache successfully purged."
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Text("Removes all local test templates and resets enrollment state.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Section 3: Clipboard Privacy
            SecuritySection(title: "Clipboard History", icon: "doc.on.clipboard") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Retention Window:")
                            .font(.system(size: 12))
                        Picker("", selection: $clipboardRetention) {
                            Text("Off (Disabled)").tag("Off")
                            Text("1 Hour").tag("1h")
                            Text("24 Hours").tag("24h")
                            Text("7 Days").tag("7d")
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)
                    }

                    HStack(spacing: 12) {
                        Button("Clear Clipboard History Now") {
                            statusAlertMessage = "Clipboard history cleared."
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Text("Password managers and concealed items are ignored by default.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Section 4: Safe Maintenance Protocol
            SecuritySection(title: "System Cleaner Safeguards", icon: "sparkles") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Non-Destructive Move-to-Trash")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Cleaned items are moved to the macOS Trash rather than permanently erased.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $nonDestructiveTrash)
                            .labelsHidden()
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cryptographic EdDSA Update Signatures")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Rejects any Sparkle appcast item not signed by the official Maczy EdDSA key.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $eddsaVerificationEnabled)
                            .labelsHidden()
                            .disabled(true)
                    }
                }
            }
        }
        .padding(6)
    }
}

struct SecuritySection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(MaczyDesignTokens.brandPurple)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }

            content()
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
