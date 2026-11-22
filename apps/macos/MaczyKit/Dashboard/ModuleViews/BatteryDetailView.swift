import SwiftUI

public struct BatteryDetailView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var chargeLimitManager: ChargeLimitManager
    @State private var selectedLimit: Int = 80
    @State private var gateNotice: String?

    public init(appState: AppState) {
        self.appState = appState
        self._chargeLimitManager = ObservedObject(wrappedValue: appState.chargeLimitManager)
    }

    private var battery: BatterySnapshot {
        appState.batterySnapshot
    }

    private var batteryColor: Color {
        guard battery.isBatteryPresent else { return MaczyDesignTokens.statusBlue }
        if battery.stateOfCharge > 50 {
            return MaczyDesignTokens.statusGreen
        } else if battery.stateOfCharge > 20 {
            return MaczyDesignTokens.statusOrange
        } else {
            return MaczyDesignTokens.statusRed
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header with Refresh
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Battery Guardian")
                        .font(.system(size: 20, weight: .bold))
                    Text("Native hardware telemetry via IOKit & Apple Silicon SMC")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    _ = appState.dispatch(.refreshBatteryTelemetry)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
            }

            // Primary Battery Stage Card
            VStack(alignment: .leading, spacing: 14) {
                if battery.isBatteryPresent {
                    HStack(spacing: 20) {
                        Image(systemName: battery.batteryIconName)
                            .font(.system(size: 44))
                            .foregroundColor(batteryColor)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("\(battery.stateOfCharge)%")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                Text(battery.chargingState.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(batteryColor)
                            }

                            HStack(spacing: 8) {
                                Label(battery.powerSource.rawValue, systemImage: battery.isACConnected ? "powerplug" : "battery.50")
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.primary.opacity(0.06))
                                    .cornerRadius(6)

                                if let timeStr = battery.formattedTimeToFull ?? battery.formattedTimeToEmpty {
                                    Label(timeStr, systemImage: "clock")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        Spacer()
                    }
                } else {
                    HStack(spacing: 16) {
                        Image(systemName: "powerplug.fill")
                            .font(.system(size: 36))
                            .foregroundColor(MaczyDesignTokens.statusBlue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Desktop Mac (AC Powered)")
                                .font(.system(size: 16, weight: .bold))
                            Text("No internal battery installed. System running on direct power.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(MaczyDesignTokens.panelCornerRadius)

            // 4-Item Hardware Telemetry Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                TelemetryCard(
                    title: "Maximum Health",
                    value: "\(battery.maxCapacityPercent)%",
                    subtitle: battery.healthCondition.rawValue,
                    icon: "heart.fill",
                    color: MaczyDesignTokens.statusGreen
                )

                TelemetryCard(
                    title: "Cycle Count",
                    value: "\(battery.cycleCount)",
                    subtitle: battery.isBatteryPresent ? "Design limit: 1000" : "N/A",
                    icon: "arrow.triangle.2.circlepath",
                    color: MaczyDesignTokens.brandPurple
                )

                TelemetryCard(
                    title: "Cell Temperature",
                    value: battery.formattedTemperature,
                    subtitle: battery.temperatureCelsius != nil ? "Optimal Thermal Range" : "Unavailable",
                    icon: "thermometer.medium",
                    color: MaczyDesignTokens.statusOrange
                )

                TelemetryCard(
                    title: "Voltage & Power",
                    value: battery.voltageMilliVolts != nil ? String(format: "%.2f V", Double(battery.voltageMilliVolts!) / 1000.0) : "—",
                    subtitle: battery.amperageMilliAmps != nil ? "\(battery.amperageMilliAmps!) mA" : "Nominal",
                    icon: "bolt.fill",
                    color: MaczyDesignTokens.statusBlue
                )
            }

            // Charge Limit Selector (MZ-014)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Charge Limit Ceilings")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Selectable thresholds: 80%, 85%, 90%, 95%, 100%. Hardware write controls & readback.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if let active = chargeLimitManager.activeLimit {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(MaczyDesignTokens.statusGreen)
                                .frame(width: 7, height: 7)
                            Text("Active Ceiling: \(active)% (Readback Verified)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(MaczyDesignTokens.brandPurple)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(MaczyDesignTokens.brandPurple.opacity(0.1))
                        .cornerRadius(6)
                    } else if !chargeLimitManager.isSupported {
                        Text("Safe Unsupported State")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(6)
                    }
                }

                HStack(spacing: 8) {
                    ForEach([80, 85, 90, 95, 100], id: \.self) { pct in
                        Button("\(pct)%") {
                            selectedLimit = pct
                            let res = appState.dispatch(.selectChargeLimit(percentage: pct))
                            if !res.ok {
                                gateNotice = res.message ?? "Charge write controls gated."
                            } else {
                                gateNotice = "Charge ceiling set to \(pct)% (readback verified)."
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(chargeLimitManager.activeLimit == pct || (chargeLimitManager.activeLimit == nil && selectedLimit == pct) ? MaczyDesignTokens.brandPurple : nil)
                        .disabled(!chargeLimitManager.isSupported)
                    }
                }

                if let notice = gateNotice {
                    Text(notice)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(chargeLimitManager.activeLimit == selectedLimit ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusOrange)
                        .padding(.top, 2)
                } else if !chargeLimitManager.isSupported {
                    Text("Hardware charge limit writes are unsupported on this device (desktop or no battery). Safe unsupported state active — telemetry monitoring remains operational.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MaczyDesignTokens.statusOrange.opacity(0.1))
            .cornerRadius(10)
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
    }
}

/// Compact telemetry summary tile.
struct TelemetryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}
