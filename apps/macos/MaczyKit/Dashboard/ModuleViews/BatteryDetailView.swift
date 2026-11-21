import SwiftUI

public struct BatteryDetailView: View {
    @ObservedObject var appState: AppState
    @State private var selectedLimit: Int = 80

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Battery Guardian")
                .font(.system(size: 20, weight: .bold))

            // Charge Limit Selector
            VStack(alignment: .leading, spacing: 10) {
                Text("Charge Limit Ceilings")
                    .font(.system(size: 13, weight: .semibold))
                Text("Selectable charging thresholds: 80%, 85%, 90%, 95%, 100%. Write controls are verified via backend.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    ForEach([80, 85, 90, 95, 100], id: \.self) { pct in
                        Button("\(pct)%") {
                            selectedLimit = pct
                            _ = appState.dispatch(.selectChargeLimit(percentage: pct))
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedLimit == pct ? MaczyDesignTokens.brandPurple : nil)
                    }
                }
            }

            // Power Bypass Notice
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(MaczyDesignTokens.statusOrange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Charge Limit ≠ Power Bypass")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Setting a charge ceiling is distinct from true hardware power bypass. Maczy only reports power-path bypass when verified by the supported backend.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(MaczyDesignTokens.statusOrange.opacity(0.1))
            .cornerRadius(10)
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
    }
}
