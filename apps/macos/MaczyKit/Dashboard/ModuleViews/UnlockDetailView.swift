import SwiftUI

/// CRITICAL: Smart Unlock Screen enforcing fail-closed security boundary.
public struct UnlockDetailView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Smart Unlock — macOS Lock Screen Face Unlock")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Text("GATED BY MZ-023")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(MaczyDesignTokens.statusRed.opacity(0.15))
                    .foregroundColor(MaczyDesignTokens.statusRed)
                    .cornerRadius(6)
            }

            // CRITICAL Boundary Box
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(MaczyDesignTokens.statusRed)
                        .font(.system(size: 24))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Rigorous System Security Boundary")
                            .font(.system(size: 13, weight: .bold))
                        Text("Maczy Smart Unlock aims to recognize the owner through the Mac camera and unlock the ACTUAL LOCKED macOS USER SESSION.\n\nIt is strictly NOT an in-app privacy gate. The application will NEVER simulate fake in-app unlock success, inject passwords, bypass SIP, or weaken FileVault. Implementation remains BLOCKED pending the MZ-023 technical feasibility review and explicit Product Owner authorization.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(14)
                .background(MaczyDesignTokens.statusRed.opacity(0.08))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(MaczyDesignTokens.statusRed.opacity(0.3), lineWidth: 1)
                )

                Button("Verify Feasibility Gate") {
                    _ = appState.dispatch(.triggerSessionUnlock)
                }
                .buttonStyle(.bordered)

                Text("Native macOS authentication methods (Touch ID, password, Apple Watch) remain standard and fully active.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
    }
}
