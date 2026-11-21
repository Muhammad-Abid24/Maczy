import SwiftUI

public struct UpdatesDetailView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Automatic Updates")
                .font(.system(size: 20, weight: .bold))

            VStack(alignment: .leading, spacing: 8) {
                Text("Sparkle 2 EdDSA Verified Updates")
                    .font(.system(size: 13, weight: .semibold))
                Text("Release channels: Stable, Beta, Nightly. Community builds use ad-hoc signatures with independent Sparkle cryptographic signature checks.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Button("Check for Updates Now") {
                    _ = appState.dispatch(.checkForUpdates)
                }
                .buttonStyle(.borderedProminent)
                .tint(MaczyDesignTokens.brandPurple)
                .padding(.top, 4)
            }
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
    }
}
