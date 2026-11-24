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
    @State private var isAccessibilityGranted: Bool = FaceUnlockManager.isAccessibilityGranted()

    public init(appState: AppState) {
        self.appState = appState
    }

    private var isFullyReady: Bool {
        faceManager.storedTemplate != nil && hasStoredPassword && isAccessibilityGranted && faceManager.isSmartUnlockActive
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
                    Text(isFullyReady ? "SIAP DIGUNAKAN" : (faceManager.isSmartUnlockActive ? "BUTUH KONFIGURASI" : "NONAKTIF"))
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isFullyReady ? MaczyDesignTokens.statusGreen.opacity(0.15) : (faceManager.isSmartUnlockActive ? MaczyDesignTokens.statusOrange.opacity(0.15) : Color.secondary.opacity(0.15)))
                        .foregroundColor(isFullyReady ? MaczyDesignTokens.statusGreen : (faceManager.isSmartUnlockActive ? MaczyDesignTokens.statusOrange : .secondary))
                        .cornerRadius(6)
                }

                // Section: Checklist Kesiapan Smart Unlock (Readiness Checklist)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checklist")
                            .font(.system(size: 15))
                            .foregroundColor(MaczyDesignTokens.brandPurple)
                        Text("Daftar Kesiapan Smart Unlock")
                            .font(.system(size: 13, weight: .bold))
                        Spacer()
                        Button("Refresh Status") {
                            hasStoredPassword = SmartUnlockKeychain.shared.hasPassword()
                            isAccessibilityGranted = FaceUnlockManager.isAccessibilityGranted()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(MaczyDesignTokens.brandPurple)
                    }

                    VStack(spacing: 8) {
                        // 1. Wajah Terdaftar
                        HStack(spacing: 10) {
                            Image(systemName: faceManager.storedTemplate != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(faceManager.storedTemplate != nil ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusOrange)
                                .font(.system(size: 14))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("1. Pendaftaran Wajah")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(faceManager.storedTemplate != nil ? "Wajah Anda telah terdaftar dan template biometrik tersimpan." : "Wajah belum didaftarkan. Nyalakan kamera dan daftarkan wajah di bawah.")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }

                        Divider()

                        // 2. Sandi Login macOS di Keychain
                        HStack(spacing: 10) {
                            Image(systemName: hasStoredPassword ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(hasStoredPassword ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusRed)
                                .font(.system(size: 14))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("2. Sandi Login Akun macOS di Keychain")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(hasStoredPassword ? "Sandi login Mac tersimpan dengan aman di macOS Keychain." : "Sandi login belum disimpan! macOS memerlukan sandi ini untuk membuka lockscreen saat wajah Anda cocok.")
                                    .font(.system(size: 10))
                                    .foregroundColor(hasStoredPassword ? .secondary : MaczyDesignTokens.statusRed)
                            }
                            Spacer()
                        }

                        Divider()

                        // 3. Izin Aksesibilitas macOS
                        HStack(spacing: 10) {
                            Image(systemName: isAccessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(isAccessibilityGranted ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusRed)
                                .font(.system(size: 14))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("3. Izin Aksesibilitas macOS")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(isAccessibilityGranted ? "Izin Aksesibilitas telah aktif untuk Maczy." : "Belum diberikan. Wajib diaktifkan di Pengaturan Sistem agar Maczy dapat mengetik sandi ke lockscreen.")
                                    .font(.system(size: 10))
                                    .foregroundColor(isAccessibilityGranted ? .secondary : MaczyDesignTokens.statusRed)
                            }
                            Spacer()
                            if !isAccessibilityGranted {
                                Button("Beri Izin") {
                                    FaceUnlockManager.requestAccessibilityPermission()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        isAccessibilityGranted = FaceUnlockManager.isAccessibilityGranted()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .tint(MaczyDesignTokens.statusRed)
                            }
                        }

                        Divider()

                        // 4. Status Aktif
                        HStack(spacing: 10) {
                            Image(systemName: faceManager.isSmartUnlockActive ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(faceManager.isSmartUnlockActive ? MaczyDesignTokens.statusGreen : .secondary)
                                .font(.system(size: 14))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("4. Smart Unlock Diaktifkan")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(faceManager.isSmartUnlockActive ? "Fitur aktif dan memantau lockscreen macOS." : "Fitur saat ini nonaktif.")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $faceManager.isSmartUnlockActive)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                    .cornerRadius(8)

                    // Action Banner: Jika sandi belum diisi
                    if !hasStoredPassword || isEditingPassword {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "key.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(MaczyDesignTokens.statusOrange)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Langkah Wajib: Simpan Sandi Login Mac Anda")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(MaczyDesignTokens.statusOrange)
                                    Text("Karena macOS tidak mengizinkan aplikasi pihak ketiga membuka layar tanpa kredensial, Maczy menyimpan sandi akun Anda secara terenkripsi di macOS Keychain lokal. Sandi ini HANYA dikirim saat wajah Anda terverifikasi di kamera.")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)

                                    HStack(spacing: 8) {
                                        SecureField("Masukkan sandi login Mac Anda...", text: $passwordInput)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(size: 11))

                                        Button("Simpan ke Keychain") {
                                            guard !passwordInput.isEmpty else { return }
                                            let saved = SmartUnlockKeychain.shared.savePassword(passwordInput)
                                            if saved {
                                                hasStoredPassword = true
                                                isEditingPassword = false
                                                passwordInput = ""
                                                passwordSaveStatus = "Sandi berhasil disimpan ke Keychain!"
                                            } else {
                                                passwordSaveStatus = "Gagal menyimpan sandi."
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
                                    .padding(.top, 4)

                                    if let status = passwordSaveStatus {
                                        Text(status)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(MaczyDesignTokens.statusGreen)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(MaczyDesignTokens.statusOrange.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(MaczyDesignTokens.statusOrange.opacity(0.3), lineWidth: 1)
                        )
                    }

                    // Action Banner: Jika semua siap
                    if isFullyReady {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 20))
                                .foregroundColor(MaczyDesignTokens.statusGreen)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Smart Unlock Siap Digunakan!")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(MaczyDesignTokens.statusGreen)
                                Text("Kunci layar Mac Anda sekarang. Hadapkan wajah Anda ke kamera, Maczy akan otomatis mengenali wajah dan membuka lockscreen.")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Kunci Layar Sekarang (Tes)") {
                                _ = SystemLockManager.shared.lockScreen()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(MaczyDesignTokens.statusGreen)
                            .controlSize(.small)
                        }
                        .padding(12)
                        .background(MaczyDesignTokens.statusGreen.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(MaczyDesignTokens.statusGreen.opacity(0.3), lineWidth: 1)
                        )
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
                                        Text(faceManager.storedTemplate != nil ? "Wajah Telah Terdaftar" : "Kamera Belum Aktif")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text(faceManager.storedTemplate != nil ? "Template biometrik Anda aktif. Klik 'Nyalakan Kamera' untuk menguji deteksi wajah langsung." : "Klik 'Nyalakan Kamera' untuk memulai deteksi wajah secara real-time dan mendaftarkan wajah Anda.")
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
        .onAppear {
            hasStoredPassword = SmartUnlockKeychain.shared.hasPassword()
            isAccessibilityGranted = FaceUnlockManager.isAccessibilityGranted()
        }
    }
}
