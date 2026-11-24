import SwiftUI

/// Smart Unlock Screen with Native Fallback Guidance (MZ-022),
/// fail-closed security boundary gating (MZ-023), and Face Unlock Enrollment & Auto-Unlock Engine (MZ-024).
public struct UnlockDetailView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var fallbackManager: NativeUnlockFallbackManager = .shared
    @ObservedObject var faceManager: FaceUnlockManager = .shared

    @State private var lastUnlockResult: UnlockExecutionResult?
    @State private var enrollmentMessage: String?
    @State private var passwordInput: String = ""
    @State private var hasStoredPassword: Bool = SmartUnlockKeychain.shared.hasPassword()
    @State private var isEditingPassword: Bool = false
    @State private var passwordSaveStatus: String?

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Smart Unlock — macOS Face Unlock & Session Security")
                            .font(.system(size: 18, weight: .bold))
                        Text("Buka lockscreen macOS secara otomatis dengan pengenalan wajah kamera FaceTime. Touch ID, sandi, dan Apple Watch tetap aktif sebagai fallback.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(faceManager.isSmartUnlockActive ? "SMART UNLOCK AKTIF" : "SMART UNLOCK NONAKTIF")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(faceManager.isSmartUnlockActive ? MaczyDesignTokens.statusGreen.opacity(0.15) : Color.secondary.opacity(0.15))
                        .foregroundColor(faceManager.isSmartUnlockActive ? MaczyDesignTokens.statusGreen : .secondary)
                        .cornerRadius(6)
                }

                // Section 1: Smart Unlock Activation & macOS Keychain Password Management
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "lock.open.trianglebadge.exclamationmark")
                            .font(.system(size: 16))
                            .foregroundColor(MaczyDesignTokens.brandPurple)
                        Text("Pengaturan Smart Unlock & Kredensial Lockscreen")
                            .font(.system(size: 13, weight: .bold))
                        Spacer()
                    }

                    // Toggle Smart Unlock
                    Toggle("Aktifkan Smart Unlock untuk Lockscreen macOS", isOn: $faceManager.isSmartUnlockActive)
                        .font(.system(size: 12, weight: .semibold))
                        .toggleStyle(.switch)

                    Divider()

                    // Keychain Password Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sandi Login Akun macOS (Disimpan di Keychain yang Aman)")
                            .font(.system(size: 11, weight: .semibold))

                        Text("Untuk membuka lockscreen secara otomatis saat wajah Anda dikenali oleh kamera, Maczy menggunakan sandi login akun Anda yang disimpan secara terenkripsi di macOS Keychain lokal.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        if hasStoredPassword && !isEditingPassword {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(MaczyDesignTokens.statusGreen)
                                    .font(.system(size: 14))

                                Text("Sandi login Mac Anda telah tersimpan dengan aman di Keychain.")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(MaczyDesignTokens.statusGreen)

                                Spacer()

                                Button("Ubah Sandi") {
                                    isEditingPassword = true
                                    passwordSaveStatus = nil
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button("Hapus") {
                                    SmartUnlockKeychain.shared.deletePassword()
                                    hasStoredPassword = false
                                    passwordSaveStatus = "Sandi dihapus dari Keychain."
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(10)
                            .background(MaczyDesignTokens.statusGreen.opacity(0.08))
                            .cornerRadius(6)
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    SecureField("Masukkan sandi login Mac Anda", text: $passwordInput)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 11))

                                    Button("Simpan ke Keychain") {
                                        guard !passwordInput.isEmpty else { return }
                                        let saved = SmartUnlockKeychain.shared.savePassword(passwordInput)
                                        if saved {
                                            hasStoredPassword = true
                                            isEditingPassword = false
                                            passwordInput = ""
                                            passwordSaveStatus = "Sandi berhasil disimpan ke Keychain."
                                        } else {
                                            passwordSaveStatus = "Gagal menyimpan sandi ke Keychain."
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(MaczyDesignTokens.brandPurple)
                                    .controlSize(.small)
                                    .disabled(passwordInput.isEmpty)

                                    if isEditingPassword {
                                        Button("Batal") {
                                            isEditingPassword = false
                                            passwordInput = ""
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }

                                if let status = passwordSaveStatus {
                                    Text(status)
                                        .font(.system(size: 10))
                                        .foregroundColor(MaczyDesignTokens.brandPurple)
                                }
                            }
                        }
                    }

                    // Fallback Guarantee Callout
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 14))
                            .foregroundColor(MaczyDesignTokens.statusBlue)
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Jaminan Keamanan & Fallback")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(MaczyDesignTokens.statusBlue)
                            Text("Ketika layar terkunci dan wajah Anda TIDAK dikenali atau tidak ada orang di depan kamera, Maczy sama sekali tidak melakukan input apa pun. Layar tetap terkunci dengan aman dan Anda tetap bisa membukanya melalui Touch ID, Apple Watch, atau mengetik sandi seperti biasa.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(MaczyDesignTokens.statusBlue.opacity(0.08))
                    .cornerRadius(6)

                    // Quick Lock Screen Button
                    HStack {
                        Button("Kunci Layar Sekarang (Tes Smart Unlock)") {
                            _ = SystemLockManager.shared.lockScreen()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MaczyDesignTokens.brandPurple)
                        .controlSize(.small)

                        Text("Klik untuk langsung mengunci Mac Anda dan mencoba membuka layar dengan wajah.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(14)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                // Section 2: Face Unlock Enrollment & Anti-Spoof Audit (MZ-024)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Pendaftaran Wajah (Face Enrollment) — Live Camera")
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

                    // Live Camera Viewport & Vision HUD
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .bottomLeading) {
                            if faceManager.isCameraActive {
                                CameraPreviewView(session: faceManager.captureEngine.captureSession)
                                    .frame(height: 180)
                                    .cornerRadius(8)
                                    .clipped()

                                // HUD Overlay on Camera Feed
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(faceManager.liveLivenessStatus)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.black.opacity(0.65))
                                            .cornerRadius(4)

                                        Spacer()

                                        if faceManager.liveQualityScore > 0 {
                                            Text("Quality: \(Int(faceManager.liveQualityScore * 100))%")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(faceManager.liveQualityScore >= 0.5 ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusOrange)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.black.opacity(0.65))
                                                .cornerRadius(4)
                                        }

                                        if let sim = faceManager.liveMatchSimilarity {
                                            Text("\(Int(sim * 100))% Match")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(sim >= 0.72 ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusRed)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.black.opacity(0.65))
                                                .cornerRadius(4)
                                        }
                                    }

                                    HStack(spacing: 6) {
                                        Text(faceManager.eyeBlinkDetected ? "Kedipan Mata: ✓" : "Kedipan Mata: menunggu...")
                                            .font(.system(size: 9))
                                            .foregroundColor(faceManager.eyeBlinkDetected ? MaczyDesignTokens.statusGreen : .white.opacity(0.8))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.black.opacity(0.55))
                                            .cornerRadius(4)

                                        Text(faceManager.headMotionDetected ? "Gerakan Kepala: ✓" : "Gerakan Kepala: menunggu...")
                                            .font(.system(size: 9))
                                            .foregroundColor(faceManager.headMotionDetected ? MaczyDesignTokens.statusGreen : .white.opacity(0.8))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.black.opacity(0.55))
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(8)
                            } else {
                                ZStack {
                                    Color.black.opacity(0.85)
                                    VStack(spacing: 8) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.secondary)
                                        Text("Kamera Belum Aktif")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("Klik 'Nyalakan Kamera' untuk memulai deteksi wajah secara real-time dan mendaftarkan wajah Anda.")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(height: 180)
                                .cornerRadius(8)
                            }
                        }

                        // Camera Controls & Enrollment Progress
                        if case .enrolling(let progress) = faceManager.enrollmentState {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Merekam Fitur Wajah...")
                                        .font(.system(size: 11, weight: .semibold))
                                    Spacer()
                                    Text("\(Int(progress * 100))%")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                ProgressView(value: progress, total: 1.0)
                                    .tint(MaczyDesignTokens.brandPurple)
                            }
                            .padding(.vertical, 4)
                        }

                        HStack(spacing: 8) {
                            if !faceManager.isCameraActive {
                                Button("Nyalakan Kamera") {
                                    Task {
                                        await faceManager.startCamera()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(MaczyDesignTokens.brandPurple)
                                .controlSize(.small)
                            } else {
                                Button("Matikan Kamera") {
                                    faceManager.stopCamera()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                if !faceManager.enrollmentState.isEnrolled {
                                    Button("Daftarkan Wajah (Vision)") {
                                        faceManager.beginLiveEnrollment()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(MaczyDesignTokens.brandPurple)
                                    .controlSize(.small)
                                }
                            }

                            if faceManager.enrollmentState.isEnrolled {
                                Button("Hapus Wajah Terdaftar") {
                                    faceManager.revokeEnrollment()
                                    enrollmentMessage = "Data biometrik wajah telah dihapus."
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            Button("Simulasi Buka Layar") {
                                lastUnlockResult = faceManager.attemptLockedSessionUnlock()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
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
                                    Text("Sensor Hardware: \(faceManager.lastAudit.sensorType)")
                                        .font(.system(size: 11, weight: .semibold))
                                    Spacer()
                                    Text(faceManager.lastAudit.riskLevel.rawValue)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(MaczyDesignTokens.statusOrange)
                                }

                                Text(faceManager.lastAudit.auditSummary)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)

                                HStack(spacing: 8) {
                                    Button("Audit Anti-Spoof Real-Time") {
                                        faceManager.runAntiSpoofAudit(simulatedPhotoAttack: false)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)

                                    Button("Simulasi Serangan Foto 2D") {
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
                                    Text(result.errorCode ?? (result.success ? "BERHASIL DIBUKA" : "TERKUNCI"))
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

                // Section 3: OS-Managed Native Fallbacks (MZ-022)
                VStack(alignment: .leading, spacing: 12) {
                    Text("macOS Native Authentication Fallbacks (Selalu Aktif)")
                        .font(.system(size: 13, weight: .bold))

                    // 1. Touch ID Card
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "touchid")
                            .font(.system(size: 22))
                            .foregroundColor(fallbackManager.currentBiometricStatus.isAvailable ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusOrange)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Touch ID (Biometrik)")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text(fallbackManager.currentBiometricStatus.enrollmentStatus.rawValue)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(fallbackManager.currentBiometricStatus.isAvailable ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusOrange)
                            }
                            Text(fallbackManager.currentBiometricStatus.details)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            Button("Buka Pengaturan Touch ID di macOS") {
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
                                Text("Dikelola macOS")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            Text("Membuka Mac Anda secara otomatis ketika Apple Watch yang tidak terkunci sedang Anda kenakan.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            Button("Buka Pengaturan Apple Watch Unlock") {
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
                                Text("Sandi Login Akun Mac")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text("Selalu Tersedia")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(MaczyDesignTokens.statusGreen)
                            }
                            Text("Fallback sandi berbasis Apple Silicon Secure Enclave selalu tersedia saat Mac dinyalakan ulang, sleep, atau saat layar terkunci.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            Button("Buka Pengaturan Sandi") {
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
            }
            .padding(18)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
    }
}
