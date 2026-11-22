import SwiftUI

public struct CaptureDetailView: View {
    @ObservedObject var appState: AppState
    @State private var selectedMode = "area"
    @State private var selectedResolution: RecordingResolutionPreset = .native
    @State private var systemAudioEnabled: Bool = false
    @State private var microphoneEnabled: Bool = false
    @State private var isRecording: Bool = false

    public init(appState: AppState) {
        self.appState = appState
    }

    private var hasScreenRecordingPermission: Bool {
        appState.permissionState(.screenRecording) == .granted
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Capture & Recording")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                if hasScreenRecordingPermission {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(MaczyDesignTokens.statusGreen)
                            .frame(width: 7, height: 7)
                        Text("Permission Granted")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(MaczyDesignTokens.statusGreen)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(MaczyDesignTokens.statusGreen.opacity(0.12))
                    .cornerRadius(6)
                }
            }

            // Permission Warning Banner if Screen Recording is not granted
            if !hasScreenRecordingPermission {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(MaczyDesignTokens.statusOrange)
                            .font(.system(size: 20))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Screen Recording Permission Required")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.primary)
                            Text("macOS requires explicit authorization to capture screenshots and record video.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Request Access") {
                            Task {
                                _ = await PermissionManager.shared.requestAuthorization(for: .screenRecording)
                                await MainActor.run {
                                    appState.refreshPermissions()
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MaczyDesignTokens.brandPurple)
                        .controlSize(.small)

                        Button("Open Settings") {
                            PermissionManager.shared.openSettings(for: .screenRecording)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Refresh") {
                            appState.refreshPermissions()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Divider()

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("Not in System Settings list? Click '+' below the list in System Settings and select Maczy from Applications. If toggled ON, restart Maczy to apply.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Relaunch App") {
                            PermissionManager.shared.relaunchApp()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(MaczyDesignTokens.brandPurple)
                    }
                }
                .padding(12)
                .background(MaczyDesignTokens.statusOrange.opacity(0.12))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(MaczyDesignTokens.statusOrange.opacity(0.35), lineWidth: 1)
                )
            }

            // Modes
            VStack(alignment: .leading, spacing: 10) {
                Text("Screenshot Mode")
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 10) {
                    ModeSelectButton(title: "Area", icon: "crop", isSelected: selectedMode == "area") {
                        selectedMode = "area"
                    }
                    ModeSelectButton(title: "Window", icon: "macwindow", isSelected: selectedMode == "window") {
                        selectedMode = "window"
                    }
                    ModeSelectButton(title: "Fullscreen", icon: "display", isSelected: selectedMode == "fullscreen") {
                        selectedMode = "fullscreen"
                    }
                    ModeSelectButton(title: "Scrolling", icon: "arrow.up.and.down.text.horizontal", isSelected: selectedMode == "scrolling") {
                        selectedMode = "scrolling"
                    }
                }
            }

            // Resolution Presets
            VStack(alignment: .leading, spacing: 8) {
                Text("Recording Resolution Preset")
                    .font(.system(size: 13, weight: .semibold))

                Picker("", selection: $selectedResolution) {
                    ForEach(RecordingResolutionPreset.allCases, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Audio Switches
            VStack(alignment: .leading, spacing: 8) {
                Text("Audio Sources")
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 20) {
                    Toggle("System Audio", isOn: $systemAudioEnabled)
                        .toggleStyle(.switch)
                        .font(.system(size: 12))

                    Toggle("Microphone Voice", isOn: $microphoneEnabled)
                        .toggleStyle(.switch)
                        .font(.system(size: 12))
                }
            }

            // Active Recording Indicator & Stop Action
            if isRecording {
                HStack(spacing: 12) {
                    Circle()
                        .fill(MaczyDesignTokens.statusRed)
                        .frame(width: 10, height: 10)
                    Text("Recording in progress...")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(MaczyDesignTokens.statusRed)

                    Spacer()

                    Button("Stop Recording") {
                        _ = appState.dispatch(.stopScreenRecording)
                        isRecording = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MaczyDesignTokens.statusRed)
                }
                .padding(12)
                .background(MaczyDesignTokens.statusRed.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(MaczyDesignTokens.statusRed.opacity(0.3), lineWidth: 1)
                )
            }

            HStack(spacing: 12) {
                Button("Capture Screenshot (\(selectedMode.capitalized))") {
                    _ = appState.dispatch(.captureScreenshot(mode: selectedMode))
                }
                .buttonStyle(.borderedProminent)
                .tint(MaczyDesignTokens.brandPurple)

                if !isRecording {
                    Button("Start Recording (\(selectedResolution.displayName))") {
                        let recordingTarget: String
                        switch selectedMode {
                        case "area": recordingTarget = "region"
                        case "window": recordingTarget = "window"
                        default: recordingTarget = "display"
                        }
                        _ = appState.dispatch(.startScreenRecording(
                            target: recordingTarget,
                            systemAudio: systemAudioEnabled,
                            microphone: microphoneEnabled
                        ))
                        isRecording = ScreenRecordingEngine.shared.isRecording
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider()

            // Capabilities description
            VStack(alignment: .leading, spacing: 6) {
                Text("Features in scope:")
                    .font(.system(size: 12, weight: .semibold))
                Text("• Area, Window, and Fullscreen capture with Apple Vision OCR")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("• Scrolling screenshot stitching (safari & document scrolling)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("• Display, Window, and Region recording with independent System Audio & Microphone toggles")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
        .onAppear {
            appState.refreshPermissions()
            isRecording = ScreenRecordingEngine.shared.isRecording
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appState.refreshPermissions()
            isRecording = ScreenRecordingEngine.shared.isRecording
        }
    }
}

struct ModeSelectButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .frame(width: 90, height: 60)
            .background(isSelected ? MaczyDesignTokens.brandPurpleSoft : Color(NSColor.controlBackgroundColor))
            .foregroundColor(isSelected ? MaczyDesignTokens.brandPurple : .primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? MaczyDesignTokens.brandPurple : Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
