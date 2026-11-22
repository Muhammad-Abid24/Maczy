import SwiftUI

/// Smart Unlock Screen with Native Fallback Guidance (MZ-022)
/// and fail-closed security boundary gating (MZ-023).
public struct UnlockDetailView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var fallbackManager: NativeUnlockFallbackManager = .shared

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Smart Unlock — macOS Session Security")
                            .font(.system(size: 18, weight: .bold))
                        Text("Native OS authentication fallbacks and lock screen security.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("GATED BY MZ-023")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(MaczyDesignTokens.statusRed.opacity(0.15))
                        .foregroundColor(MaczyDesignTokens.statusRed)
                        .cornerRadius(6)
                }

                // Section 1: OS-Managed Native Fallbacks (MZ-022)
                VStack(alignment: .leading, spacing: 12) {
                    Text("macOS Native Authentication Fallbacks (Active)")
                        .font(.system(size: 13, weight: .bold))

                    // 1. Touch ID Card
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "touchid")
                            .font(.system(size: 22))
                            .foregroundColor(fallbackManager.currentBiometricStatus.isAvailable ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusOrange)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Touch ID (Biometrics)")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text(fallbackManager.currentBiometricStatus.enrollmentStatus.rawValue)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(fallbackManager.currentBiometricStatus.isAvailable ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusOrange)
                            }
                            Text(fallbackManager.currentBiometricStatus.details)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            Button("Configure Touch ID in System Settings") {
                                fallbackManager.openTouchIDSettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .padding(.top, 4)
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    // 2. Apple Watch Auto Unlock Card
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "applewatch")
                            .font(.system(size: 22))
                            .foregroundColor(MaczyDesignTokens.statusBlue)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Apple Watch Auto Unlock")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text("OS Managed")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            Text("Unlocks your Mac automatically whenever you are wearing your unlocked Apple Watch nearby.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            Button("Open Apple Watch Unlock Settings") {
                                fallbackManager.openAppleWatchSettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .padding(.top, 4)
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    // 3. User Password Card
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 20))
                            .foregroundColor(MaczyDesignTokens.brandPurple)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Account Login Password")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text("Always Available")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(MaczyDesignTokens.statusGreen)
                            }
                            Text("Secure Enclave backed password fallback is standard on all restarts, sleep, and session locks.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            Button("Open Password Settings") {
                                fallbackManager.openPasswordSettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .padding(.top, 4)
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                // Section 2: Security Policy & Boundary Box
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(MaczyDesignTokens.statusRed)
                            .font(.system(size: 24))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Rigorous System Security Boundary (ADR-0002)")
                                .font(.system(size: 13, weight: .bold))
                            Text(NativeUnlockFallbackManager.securityStatement)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text("Smart Unlock implementation (MZ-024) is strictly BLOCKED. Third-party Face Unlock cannot dismiss loginwindow without dangerous system modifications or credential storage.")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(MaczyDesignTokens.statusRed)
                        }
                    }
                    .padding(14)
                    .background(MaczyDesignTokens.statusRed.opacity(0.08))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(MaczyDesignTokens.statusRed.opacity(0.3), lineWidth: 1)
                    )

                    HStack(spacing: 12) {
                        Button("Verify Feasibility Gate") {
                            _ = appState.dispatch(.triggerSessionUnlock)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MaczyDesignTokens.statusRed)

                        Button("Re-check Biometrics") {
                            fallbackManager.refreshStatus()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Section 3: MZ-023 Feasibility Scenario Matrix
                VStack(alignment: .leading, spacing: 10) {
                    Text("MZ-023 Feasibility Scenario Matrix")
                        .font(.system(size: 13, weight: .bold))

                    ForEach(FaceUnlockFeasibilityReport.scenarioResults) { result in
                        HStack(alignment: .top, spacing: 10) {
                            Text(result.verdict.rawValue)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(MaczyDesignTokens.statusRed)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(MaczyDesignTokens.statusRed.opacity(0.12))
                                .cornerRadius(4)
                                .frame(width: 80, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.scenario.shortTitle)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(result.obstacle)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding(18)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
    }
}
