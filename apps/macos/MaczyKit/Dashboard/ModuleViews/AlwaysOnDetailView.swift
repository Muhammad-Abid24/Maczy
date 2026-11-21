import SwiftUI

public struct AlwaysOnDetailView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Always On")
                .font(.system(size: 20, weight: .bold))

            VStack(alignment: .leading, spacing: 8) {
                Text("Scoped IOPM Power Assertions")
                    .font(.system(size: 13, weight: .semibold))
                Text("Prevents idle system and display sleep without overriding FileVault, manual lock, or closed-lid sleep.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Button("30 Minutes") {
                        _ = appState.dispatch(.startAwakeSession(durationMinutes: 30))
                    }
                    .buttonStyle(.bordered)

                    Button("1 Hour") {
                        _ = appState.dispatch(.startAwakeSession(durationMinutes: 60))
                    }
                    .buttonStyle(.bordered)

                    Button("Indefinite") {
                        _ = appState.dispatch(.startAwakeSession(durationMinutes: nil))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MaczyDesignTokens.brandPurple)

                    Button("End Session") {
                        _ = appState.dispatch(.stopAwakeSession)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
    }
}
