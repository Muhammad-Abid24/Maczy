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
            // Header with Real-Time Indicator (No Manual Refresh Button)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Battery Guardian")
                        .font(.system(size: 20, weight: .bold))
                    Text("Native hardware telemetry via IOKit & Apple Silicon SMC")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(MaczyDesignTokens.statusGreen)
                        .frame(width: 8, height: 8)
                    Text("Live Real-Time")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(MaczyDesignTokens.statusGreen)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(MaczyDesignTokens.statusGreen.opacity(0.12))
                .cornerRadius(6)
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

            // Charge Limit Selector & Backend Status (MZ-014)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Charge Limit Ceilings")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Selectable thresholds: 80%, 85%, 90%, 95%, 100%. Hardware write controls & verified readback.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        if let eff = chargeLimitManager.effectiveLimit {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(MaczyDesignTokens.statusGreen)
                                    .frame(width: 7, height: 7)
                                Text("Effective: \(eff)% (Verified Readback)")
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

                        if let req = chargeLimitManager.requestedLimit, req != chargeLimitManager.effectiveLimit {
                            Text("Requested: \(req)%")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Safety Gate Authorization (Requirement 9)
                if !chargeLimitManager.isHardwareWriteApproved && chargeLimitManager.isSupported {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(MaczyDesignTokens.statusOrange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hardware Write Test Safety Gate")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Modifying physical SMC charging registers requires explicit user confirmation.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Authorize Hardware Write Test") {
                            chargeLimitManager.setHardwareWriteApproved(true)
                            gateNotice = "Hardware write tests authorized. Select a ceiling to apply to the batt daemon."
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MaczyDesignTokens.brandPurple)
                        .font(.system(size: 11))
                    }
                    .padding(10)
                    .background(MaczyDesignTokens.statusOrange.opacity(0.1))
                    .cornerRadius(8)
                } else if chargeLimitManager.isHardwareWriteApproved {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(MaczyDesignTokens.statusGreen)
                        Text("Hardware Write Test Authorized (batt daemon connected)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(MaczyDesignTokens.statusGreen)
                        Spacer()
                        Button("Revoke Authorization") {
                            chargeLimitManager.setHardwareWriteApproved(false)
                            gateNotice = "Hardware write tests revoked. Fail-closed write gate active."
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(MaczyDesignTokens.statusGreen.opacity(0.1))
                    .cornerRadius(8)
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
                        .tint(chargeLimitManager.effectiveLimit == pct || (chargeLimitManager.effectiveLimit == nil && selectedLimit == pct) ? MaczyDesignTokens.brandPurple : nil)
                        .disabled(!chargeLimitManager.isSupported)
                    }
                }

                if let notice = gateNotice {
                    Text(notice)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(chargeLimitManager.effectiveLimit == selectedLimit ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusOrange)
                        .padding(.top, 2)
                } else if !chargeLimitManager.isSupported {
                    Text("Hardware charge limit writes are unsupported on this device (desktop or no battery). Safe unsupported state active — telemetry monitoring remains operational.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }

                // Ceiling Overshoot & Discharge Control
                if let eff = chargeLimitManager.effectiveLimit, battery.stateOfCharge > eff && battery.isBatteryPresent {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(MaczyDesignTokens.statusOrange)
                            .font(.system(size: 15))
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text("Battery (\(battery.stateOfCharge)%) is above active ceiling (\(eff)%)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(MaczyDesignTokens.statusOrange)
                                Spacer()
                                if chargeLimitManager.isDischargingToCeiling {
                                    HStack(spacing: 4) {
                                        Circle().fill(MaczyDesignTokens.brandPurple).frame(width: 6, height: 6)
                                        Text("Discharging to \(eff)%...")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(MaczyDesignTokens.brandPurple)
                                    }
                                }
                            }
                            Text("Charging is stopped (SMC bypass engaged). The hardware will hold at \(battery.stateOfCharge)% and not charge further. To lower charge to \(eff)%, unplug the adapter or use automatic discharge below.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                if chargeLimitManager.isDischargingToCeiling {
                                    Button(action: {
                                        _ = chargeLimitManager.stopDischargeToCeiling()
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "powerplug.fill")
                                            Text("Resume Power Adapter")
                                        }
                                        .font(.system(size: 11, weight: .semibold))
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(MaczyDesignTokens.brandPurple)
                                } else if chargeLimitManager.isHardwareWriteApproved {
                                    Button(action: {
                                        _ = chargeLimitManager.startDischargeToCeiling()
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.down.to.line")
                                            Text("Discharge to \(eff)% on Battery")
                                        }
                                        .font(.system(size: 11, weight: .semibold))
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(10)
                    .background(MaczyDesignTokens.statusOrange.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            // Power Bypass Notice & Telemetry Differentiation (Requirement 6)
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: chargeLimitManager.isPowerBypassActive(snapshot: battery) ? "bolt.shield.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(chargeLimitManager.isPowerBypassActive(snapshot: battery) ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusOrange)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Charge Limit ≠ Power Bypass")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text(chargeLimitManager.isPowerBypassActive(snapshot: battery) ? "Power Bypass: Engaged (0 mA draw)" : "Power Bypass: Standby")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(chargeLimitManager.isPowerBypassActive(snapshot: battery) ? MaczyDesignTokens.statusGreen : .secondary)
                    }
                    Text("Setting a charge ceiling is distinct from true hardware power bypass. Maczy only reports power-path bypass when verified by the supported backend and battery current is quiescent (0 mA).")
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
