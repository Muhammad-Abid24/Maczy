import SwiftUI

/// Smart Unlock Screen with Native Fallback Guidance (MZ-022),
/// fail-closed security boundary gating (MZ-023), and Face Unlock Enrollment & Anti-Spoof Audit (MZ-024).
public struct UnlockDetailView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var fallbackManager: NativeUnlockFallbackManager = .shared
    @ObservedObject var faceManager: FaceUnlockManager = .shared

    @State private var lastUnlockResult: UnlockExecutionResult?
    @State private var enrollmentMessage: String?

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
                        Text("Native OS authentication fallbacks, on-device face enrollment, and anti-spoof audit.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("GATED BY MZ-024")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(MaczyDesignTokens.statusRed.opacity(0.15))
                        .foregroundColor(MaczyDesignTokens.statusRed)
                        .cornerRadius(6)
                }

                // Section 1: Face Unlock Enrollment & Anti-Spoof Audit (MZ-024)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Face Unlock Enrollment & Anti-Spoof Audit (MZ-024)")
                            .font(.system(size: 13, weight: .bold))
                        Spacer()
                        Text(faceManager.enrollmentState.displayTitle)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(faceManager.enrollmentState.isEnrolled ? MaczyDesignTokens.statusGreen.opacity(0.15) : Color.secondary.opacity(0.15))
                            .foregroundColor(faceManager.enrollmentState.isEnrolled ? MaczyDesignTokens.statusGreen : .secondary)
                            .cornerRadius(4)
                    }

                    // Enrollment Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: faceManager.enrollmentState.isEnrolled ? "faceid" : "person.crop.circle.badge.plus")
                                .font(.system(size: 24))
                                .foregroundColor(faceManager.enrollmentState.isEnrolled ? MaczyDesignTokens.brandPurple : .secondary)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("On-Device Biometric Template")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(faceManager.enrollmentState.isEnrolled
                                     ? "Mathematical feature vector registered locally. Zero plaintext credentials, zero cloud processing."
                                     : "No biometric template enrolled. Enroll face locally with liveness verification.")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)

                                if let template = faceManager.storedTemplate {
                                    Text("Template ID: \(template.id.prefix(8))... | Quality: \(Int(template.qualityScore * 100))%")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }

                                HStack(spacing: 8) {
                                    if !faceManager.enrollmentState.isEnrolled {
                                        Button("Enroll Face (Vision Liveness)") {
                                            let res = faceManager.enrollFace()
                                            switch res {
                                            case .success(let tmpl):
                                                enrollmentMessage = "Enrolled template \(tmpl.id.prefix(8)) successfully."
                                            case .failure(let err):
                                                enrollmentMessage = "Enrollment failed: \(err)"
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(MaczyDesignTokens.brandPurple)
                                        .controlSize(.small)
                                    } else {
                                        Button("Revoke Template") {
                                            faceManager.revokeEnrollment()
                                            enrollmentMessage = "Biometric template destroyed."
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }

                                    Button("Test Locked-Session Unlock") {
                                        lastUnlockResult = faceManager.attemptLockedSessionUnlock()
                                        _ = appState.dispatch(.triggerSessionUnlock)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .padding(.top, 4)

                                if let msg = enrollmentMessage {
                                    Text(msg)
                                        .font(.system(size: 10))
                                        .foregroundColor(MaczyDesignTokens.brandPurple)
                                        .padding(.top, 2)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    // Anti-Spoof & Hardware Sensor Audit Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "camera.metering.matrix")
                                .font(.system(size: 20))
                                .foregroundColor(MaczyDesignTokens.statusOrange)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Sensor Architecture: \(faceManager.lastAudit.sensorType)")
                                        .font(.system(size: 11, weight: .semibold))
                                    Spacer()
                                    Text(faceManager.lastAudit.riskLevel.rawValue)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(MaczyDesignTokens.statusRed)
                                }

                                Text(faceManager.lastAudit.auditSummary)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)

                                HStack(spacing: 8) {
                                    Button("Verify Real-Time Liveness") {
                                        faceManager.runAntiSpoofAudit(simulatedPhotoAttack: false)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)

                                    Button("Simulate 2D Photo Presentation Attack") {
                                        faceManager.runAntiSpoofAudit(simulatedPhotoAttack: true)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .padding(.top, 2)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    // Last Unlock Execution Banner
                    if let result = lastUnlockResult {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "shield.lefthalf.filled.trianglebadge.exclamationmark")
                                .foregroundColor(result.success ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusRed)
                                .font(.system(size: 16))

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(result.errorCode ?? (result.success ? "UNLOCKED" : "LOCKED"))
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(result.success ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusRed)
                                    Spacer()
                                    Text("Fallback: \(result.fallbackRecommended)")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                                Text(result.message)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(10)
                        .background(result.success ? MaczyDesignTokens.statusGreen.opacity(0.08) : MaczyDesignTokens.statusRed.opacity(0.08))
                        .cornerRadius(6)
                    }
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
