import SwiftUI

/// Native macOS Menu Bar surface providing quick actions and status for all seven Maczy modules.
public struct MenuBarView: View {
    @ObservedObject var appState: AppState

    @MainActor
    public init(appState: AppState) {
        self.appState = appState
    }

    @MainActor
    public init() {
        self.appState = .shared
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Maczy")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text("v0.1.0")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            // All seven module entries with truthful status
            ForEach(MaczyModuleId.allCases) { module in
                HStack(spacing: 10) {
                    Image(systemName: module.iconName)
                        .frame(width: 18)
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(module.displayName)
                            .font(.system(size: 12, weight: .medium))
                        Text(module == .smartUnlock ? "Gated (MZ-023)" : "Not implemented")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Action placeholder
                    Button("Open") {
                        appState.selectedModule = module
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            Divider()

            // App Controls
            HStack {
                Button("Open Maczy Dashboard") {
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.red)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 280)
    }
}
