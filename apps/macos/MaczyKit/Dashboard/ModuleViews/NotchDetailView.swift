import SwiftUI

public struct NotchDetailView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Dynamic Notch")
                .font(.system(size: 20, weight: .bold))

            VStack(alignment: .leading, spacing: 8) {
                Text("Physical Notch & Virtual Island Overlay")
                    .font(.system(size: 13, weight: .semibold))
                Text("Provides contextual live activities, media HUD, volume/brightness feedback, and window snapping on supported displays.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Button("Toggle Dynamic Notch View") {
                    _ = appState.dispatch(.toggleNotchExpanded)
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
