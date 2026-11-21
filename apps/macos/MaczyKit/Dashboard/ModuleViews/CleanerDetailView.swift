import SwiftUI

public struct CleanerDetailView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("System Cleaner & Optimizer")
                .font(.system(size: 20, weight: .bold))

            // 4-step workflow indicator
            HStack(spacing: 12) {
                StepBadge(index: 1, title: "Scan", active: true)
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.secondary)
                StepBadge(index: 2, title: "Review", active: false)
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.secondary)
                StepBadge(index: 3, title: "Confirm", active: false)
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.secondary)
                StepBadge(index: 4, title: "Clean", active: false)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Safe, Read-Only Cache Analyzer")
                    .font(.system(size: 13, weight: .semibold))
                Text("Allowlisted locations only. Documents, source repositories, and databases are strictly excluded. Deletion operations are gated by MZ-029.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    Button("Start Safe Scan") {
                        _ = appState.dispatch(.startCleanerScan)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MaczyDesignTokens.brandPurple)

                    Button("Cancel Scan") {
                        _ = appState.dispatch(.cancelCleanerScan)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
    }
}

struct StepBadge: View {
    let index: Int
    let title: String
    let active: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text("\(index)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(active ? .white : .secondary)
                .frame(width: 16, height: 16)
                .background(active ? MaczyDesignTokens.brandPurple : Color.secondary.opacity(0.2))
                .clipShape(Circle())
            Text(title)
                .font(.system(size: 11, weight: active ? .semibold : .regular))
                .foregroundColor(active ? MaczyDesignTokens.brandPurple : .secondary)
        }
    }
}
