import SwiftUI

public struct AlwaysOnDetailView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var alwaysOnManager: AlwaysOnManager

    public init(appState: AppState) {
        self.appState = appState
        self._alwaysOnManager = ObservedObject(wrappedValue: appState.alwaysOnManager)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 26))
                        .foregroundColor(alwaysOnManager.isActive ? MaczyDesignTokens.statusOrange : .secondary)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Always On Manager")
                            .font(.system(size: 18, weight: .bold))

                        Text("Native IOPM power assertions preventing idle system & display sleep")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if alwaysOnManager.isActive {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(MaczyDesignTokens.statusGreen)
                                .frame(width: 8, height: 8)
                            Text("ACTIVE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(MaczyDesignTokens.statusGreen)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(MaczyDesignTokens.statusGreen.opacity(0.12))
                        .cornerRadius(6)
                    } else {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.secondary)
                                .frame(width: 8, height: 8)
                            Text("IDLE")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(6)
                    }
                }

                // Active Hero Card
                VStack(alignment: .leading, spacing: 12) {
                    if let session = alwaysOnManager.activeSession {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("REMAINING TIME")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)

                                Text(alwaysOnManager.formattedRemainingTime)
                                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
                                    .foregroundColor(MaczyDesignTokens.statusOrange)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 6) {
                                Text("Mode: \(session.mode.displayName)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)

                                Button(action: {
                                    _ = appState.dispatch(.stopAwakeSession)
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "stop.fill")
                                            .font(.system(size: 10))
                                        Text("End Session")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(MaczyDesignTokens.statusRed)
                            }
                        }
                    } else {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("System Sleep Normal")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Mode ready: \(alwaysOnManager.currentMode.displayName) — \(alwaysOnManager.currentMode.description)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)

                                if let reason = alwaysOnManager.lastReleaseReason {
                                    HStack(spacing: 6) {
                                        Image(systemName: "info.circle.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(MaczyDesignTokens.brandPurple)
                                        Text(reason.message)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(MaczyDesignTokens.brandPurple)
                                    }
                                    .padding(.top, 2)
                                }
                            }

                            Spacer()

                            Button(action: {
                                _ = appState.dispatch(.startAwakeSession(durationMinutes: nil))
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 10))
                                    Text("Start Always On")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(MaczyDesignTokens.statusOrange)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(alwaysOnManager.isActive ? MaczyDesignTokens.statusOrange.opacity(0.4) : Color.clear, lineWidth: 1)
                )

                // Mode Selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assertion Mode")
                        .font(.system(size: 12, weight: .semibold))

                    HStack(spacing: 10) {
                        modeButton(
                            title: "System & Display",
                            subtitle: "Display stays on, system awake",
                            icon: "display",
                            mode: .systemAndDisplay
                        )

                        modeButton(
                            title: "System Only",
                            subtitle: "Display may sleep, background awake",
                            icon: "cpu",
                            mode: .systemOnly
                        )
                    }
                }

                // Preset Grid
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration Presets")
                        .font(.system(size: 12, weight: .semibold))

                    HStack(spacing: 8) {
                        presetButton(title: "15m", minutes: 15)
                        presetButton(title: "30m", minutes: 30)
                        presetButton(title: "1h", minutes: 60)
                        presetButton(title: "2h", minutes: 120)
                        presetButton(title: "Indefinite", minutes: nil)
                    }
                }

                // Hardware & Safety Guardrails Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 13))
                            .foregroundColor(MaczyDesignTokens.brandPurple)
                        Text("Hardware Safety Guardrails")
                            .font(.system(size: 12, weight: .semibold))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        guardrailRow(
                            icon: "thermometer.sun.fill",
                            title: "Thermal Protection",
                            desc: "Auto-releases assertion when SoC thermal state reaches Serious or Critical.",
                            badge: "Serious / Critical Cutoff",
                            badgeColor: MaczyDesignTokens.statusRed
                        )

                        Divider()

                        guardrailRow(
                            icon: "battery.25",
                            title: "Low Battery Protection",
                            desc: "Auto-cancels when discharging below 15% to safeguard battery longevity.",
                            badge: "≤ 15% Cutoff",
                            badgeColor: MaczyDesignTokens.statusOrange
                        )

                        Divider()

                        guardrailRow(
                            icon: "laptopcomputer",
                            title: "Clamshell Lid Policy",
                            desc: "Respects native macOS sleep when laptop lid is closed without external display.",
                            badge: "Hardware Safe",
                            badgeColor: MaczyDesignTokens.statusGreen
                        )
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                }
            }
            .padding(18)
        }
    }

    private func modeButton(title: String, subtitle: String, icon: String, mode: AlwaysOnMode) -> some View {
        let isSelected = alwaysOnManager.currentMode == mode
        return Button(action: {
            alwaysOnManager.setMode(mode)
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? MaczyDesignTokens.brandPurple : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected ? .primary : .secondary)

                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(MaczyDesignTokens.brandPurple)
                        .font(.system(size: 14))
                }
            }
            .padding(10)
            .background(isSelected ? MaczyDesignTokens.brandPurple.opacity(0.1) : Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? MaczyDesignTokens.brandPurple.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func presetButton(title: String, minutes: Int?) -> some View {
        let isCurrent = alwaysOnManager.activeSession?.preset.durationMinutes == minutes
        return Button(action: {
            _ = appState.dispatch(.startAwakeSession(durationMinutes: minutes))
        }) {
            Text(title)
                .font(.system(size: 12, weight: isCurrent ? .bold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(isCurrent ? MaczyDesignTokens.statusOrange : Color(NSColor.controlBackgroundColor))
                .foregroundColor(isCurrent ? .black : .primary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func guardrailRow(icon: String, title: String, desc: String, badge: String, badgeColor: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(badgeColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))

                Text(desc)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(badge)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(badgeColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeColor.opacity(0.12))
                .cornerRadius(4)
        }
    }
}
