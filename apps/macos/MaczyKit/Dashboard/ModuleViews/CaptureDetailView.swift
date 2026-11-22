import SwiftUI

/// Sub-navigation section within the Capture & Recording module.
public enum CaptureSubTab: String, CaseIterable, Identifiable {
    case capture = "Screenshot Capture"
    case recording = "Screen Recording"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .capture: return "camera.viewfinder"
        case .recording: return "record.circle"
        }
    }
}

/// Unified Dashboard view for Capture and Recording, strictly separating Screenshot and Video Recording configurations.
public struct CaptureDetailView: View {
    @ObservedObject var appState: AppState

    @State private var activeTab: CaptureSubTab = .capture

    // MARK: - Capture (Screenshot) States
    @State private var selectedCaptureMode: String = "area"

    // MARK: - Recording (Screen Recording) States
    @State private var selectedRecordingTarget: String = "display"
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
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Capture & Recording")
                        .font(.system(size: 20, weight: .bold))
                    Text("Capture pixel-perfect screenshots with OCR or record hardware-accelerated screen video.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

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
                permissionWarningBanner
            }

            // MARK: - Dedicated Sub-Navigation Tabs
            Picker("Section", selection: $activeTab) {
                ForEach(CaptureSubTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.iconName).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 2)

            // Content Switcher
            switch activeTab {
            case .capture:
                captureSectionView
            case .recording:
                recordingSectionView
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

    // MARK: - Capture (Screenshot) Section
    private var captureSectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Target Selection
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Screenshot Target")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("Select region, single app window, full display, or scrolling web page")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 10) {
                    ModeSelectButton(
                        title: "Area",
                        subtitle: "Interactive selection",
                        icon: "crop",
                        isSelected: selectedCaptureMode == "area"
                    ) {
                        selectedCaptureMode = "area"
                    }

                    ModeSelectButton(
                        title: "Window",
                        subtitle: "Frontmost window",
                        icon: "macwindow",
                        isSelected: selectedCaptureMode == "window"
                    ) {
                        selectedCaptureMode = "window"
                    }

                    ModeSelectButton(
                        title: "Fullscreen",
                        subtitle: "Entire active screen",
                        icon: "display",
                        isSelected: selectedCaptureMode == "fullscreen"
                    ) {
                        selectedCaptureMode = "fullscreen"
                    }

                    ModeSelectButton(
                        title: "Scrolling",
                        subtitle: "Vertical stitch",
                        icon: "arrow.up.and.down.text.horizontal",
                        isSelected: selectedCaptureMode == "scrolling"
                    ) {
                        selectedCaptureMode = "scrolling"
                    }
                }
            }

            // Screenshot Settings & Capabilities Card
            VStack(alignment: .leading, spacing: 10) {
                Text("Capture Features & Integrations")
                    .font(.system(size: 12, weight: .semibold))

                HStack(spacing: 16) {
                    FeaturePill(icon: "text.viewfinder", title: "Apple Vision OCR", description: "Extracts text automatically")
                    FeaturePill(icon: "doc.on.clipboard", title: "Clipboard Sync", description: "Instantly available to paste")
                    FeaturePill(icon: "photo.badge.checkmark", title: "Lossless PNG", description: "Highest image fidelity")
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
            .cornerRadius(8)

            // Trigger Button
            HStack(spacing: 12) {
                Button(action: {
                    _ = appState.dispatch(.captureScreenshot(mode: selectedCaptureMode))
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                        Text("Capture Screenshot (\(selectedCaptureMode.capitalized))")
                    }
                    .frame(minWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .tint(MaczyDesignTokens.brandPurple)

                Spacer()

                HStack(spacing: 6) {
                    Text("Quick shortcuts:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    ShortcutBadge(text: "⌘⇧1 Area")
                    ShortcutBadge(text: "⌘⇧2 Window")
                    ShortcutBadge(text: "⌘⇧3 Full")
                }
            }

            Divider()

            // Info note
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(MaczyDesignTokens.brandPurple)
                    .font(.system(size: 11))
                Text("Screenshots display a floating interactive preview HUD with instant annotation, OCR text copying, and drag-and-drop export.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Recording (Screen Video) Section
    private var recordingSectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Recording Target
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Recording Target")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("Choose fullscreen display, frontmost window, or custom region")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 10) {
                    ModeSelectButton(
                        title: "Display",
                        subtitle: "Entire active screen",
                        icon: "display",
                        isSelected: selectedRecordingTarget == "display"
                    ) {
                        selectedRecordingTarget = "display"
                    }

                    ModeSelectButton(
                        title: "Window",
                        subtitle: "Frontmost window",
                        icon: "macwindow",
                        isSelected: selectedRecordingTarget == "window"
                    ) {
                        selectedRecordingTarget = "window"
                    }

                    ModeSelectButton(
                        title: "Region",
                        subtitle: "Custom bounding rect",
                        icon: "crop",
                        isSelected: selectedRecordingTarget == "region"
                    ) {
                        selectedRecordingTarget = "region"
                    }
                }
            }

            // Resolution Presets
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Recording Quality & Resolution")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("Hardware-accelerated HEVC / H.264")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Picker("", selection: $selectedResolution) {
                    ForEach(RecordingResolutionPreset.allCases, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Audio Sources
            VStack(alignment: .leading, spacing: 8) {
                Text("Audio Inputs")
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 24) {
                    Toggle("System Audio (Speaker)", isOn: $systemAudioEnabled)
                        .toggleStyle(.switch)
                        .font(.system(size: 12))

                    Toggle("Microphone Voice", isOn: $microphoneEnabled)
                        .toggleStyle(.switch)
                        .font(.system(size: 12))
                }
            }

            // Active Recording Indicator
            if isRecording {
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(MaczyDesignTokens.statusRed)
                            .frame(width: 10, height: 10)
                        Text("Screen recording in progress...")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(MaczyDesignTokens.statusRed)
                    }

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

            // Start Recording Action (when not recording)
            if !isRecording {
                HStack(spacing: 12) {
                    Button(action: {
                        _ = appState.dispatch(.startScreenRecording(
                            target: selectedRecordingTarget,
                            systemAudio: systemAudioEnabled,
                            microphone: microphoneEnabled
                        ))
                        isRecording = ScreenRecordingEngine.shared.isRecording
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "record.circle")
                            Text("Start Recording (\(selectedResolution.displayName))")
                        }
                        .frame(minWidth: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MaczyDesignTokens.brandPurple)

                    Spacer()

                    Text("MP4 files saved automatically to Movies/Maczy")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Recording Notes:")
                    .font(.system(size: 11, weight: .semibold))
                Text("• Video is hardware-encoded in real-time with zero CPU lag using ScreenCaptureKit and AVAssetWriter.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("• You can stop recording anytime from this Dashboard or via the Dynamic Notch HUD.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Permission Warning Banner
    private var permissionWarningBanner: some View {
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
}

// MARK: - Subcomponents

struct ModeSelectButton: View {
    let title: String
    var subtitle: String = ""
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(isSelected ? MaczyDesignTokens.brandPurple.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .padding(.vertical, 4)
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

struct FeaturePill: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(MaczyDesignTokens.brandPurple)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ShortcutBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.08))
            .cornerRadius(4)
    }
}
