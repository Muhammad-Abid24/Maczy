import SwiftUI

public struct CaptureDetailView: View {
    @ObservedObject var appState: AppState
    @State private var selectedMode = "area"
    @State private var selectedResolution: RecordingResolutionPreset = .native

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Capture & Recording")
                .font(.system(size: 20, weight: .bold))

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

            HStack(spacing: 12) {
                Button("Capture Screenshot (\(selectedMode.capitalized))") {
                    _ = appState.dispatch(.captureScreenshot(mode: selectedMode))
                }
                .buttonStyle(.borderedProminent)
                .tint(MaczyDesignTokens.brandPurple)

                Button("Start Recording (\(selectedResolution.displayName))") {
                    _ = appState.dispatch(.startScreenRecording(target: "display", systemAudio: false, microphone: false))
                }
                .buttonStyle(.bordered)
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
