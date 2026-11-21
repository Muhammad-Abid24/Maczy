use serde::{Deserialize, Serialize};

/// Exact count of required Maczy modules per PRD.
pub const MODULE_COUNT: usize = 7;

/// Canonical identifier for the seven Maczy modules.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ModuleId {
    CaptureAndRecording,
    BatteryGuardian,
    DynamicNotch,
    SmartUnlock,
    Updates,
    AlwaysOn,
    SystemCleaner,
}

impl ModuleId {
    pub const fn as_str(&self) -> &'static str {
        match self {
            Self::CaptureAndRecording => "capture_and_recording",
            Self::BatteryGuardian => "battery_guardian",
            Self::DynamicNotch => "dynamic_notch",
            Self::SmartUnlock => "smart_unlock",
            Self::Updates => "updates",
            Self::AlwaysOn => "always_on",
            Self::SystemCleaner => "system_cleaner",
        }
    }

    pub const fn display_name(&self) -> &'static str {
        match self {
            Self::CaptureAndRecording => "Capture & Recording",
            Self::BatteryGuardian => "Battery Guardian",
            Self::DynamicNotch => "Dynamic Notch",
            Self::SmartUnlock => "Smart Unlock",
            Self::Updates => "Updates",
            Self::AlwaysOn => "Always On",
            Self::SystemCleaner => "System Cleaner",
        }
    }

    pub const fn summary(&self) -> &'static str {
        match self {
            Self::CaptureAndRecording => "Screenshots (area, window, scrolling), OCR, and recording with audio toggles",
            Self::BatteryGuardian => "Battery health monitoring and charge thresholds (80-100%)",
            Self::DynamicNotch => "Native notch interactions, media HUD, Live Activities, and virtual island fallback",
            Self::SmartUnlock => "macOS Lock Screen Face Unlock feasibility research; preserves native Touch ID/password fallback",
            Self::Updates => "Sparkle-based EdDSA signed update checks and secure delivery",
            Self::AlwaysOn => "Scoped IOPM power assertions to prevent idle sleep with power-aware safeguards",
            Self::SystemCleaner => "Mole-inspired read-only scanner and safe confirmed cleanup workflow",
        }
    }
}

/// Metadata representation of a Maczy module.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MaczyModule {
    pub id: ModuleId,
    pub name: &'static str,
    pub summary: &'static str,
}

impl MaczyModule {
    pub fn all() -> [Self; MODULE_COUNT] {
        [
            Self {
                id: ModuleId::CaptureAndRecording,
                name: ModuleId::CaptureAndRecording.display_name(),
                summary: ModuleId::CaptureAndRecording.summary(),
            },
            Self {
                id: ModuleId::BatteryGuardian,
                name: ModuleId::BatteryGuardian.display_name(),
                summary: ModuleId::BatteryGuardian.summary(),
            },
            Self {
                id: ModuleId::DynamicNotch,
                name: ModuleId::DynamicNotch.display_name(),
                summary: ModuleId::DynamicNotch.summary(),
            },
            Self {
                id: ModuleId::SmartUnlock,
                name: ModuleId::SmartUnlock.display_name(),
                summary: ModuleId::SmartUnlock.summary(),
            },
            Self {
                id: ModuleId::Updates,
                name: ModuleId::Updates.display_name(),
                summary: ModuleId::Updates.summary(),
            },
            Self {
                id: ModuleId::AlwaysOn,
                name: ModuleId::AlwaysOn.display_name(),
                summary: ModuleId::AlwaysOn.summary(),
            },
            Self {
                id: ModuleId::SystemCleaner,
                name: ModuleId::SystemCleaner.display_name(),
                summary: ModuleId::SystemCleaner.summary(),
            },
        ]
    }
}
