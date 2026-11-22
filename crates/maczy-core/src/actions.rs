use crate::modules::ModuleId;
use serde::{Deserialize, Serialize};

/// High-level user or system action dispatched to a Maczy module.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload")]
pub enum Action {
    // Capture & Recording
    CaptureScreenshot {
        mode: String,
    },
    StartScreenRecording {
        target: String,
        system_audio: bool,
        microphone: bool,
    },
    StopScreenRecording,

    // Battery Guardian
    SelectChargeLimit {
        percentage: u8,
    },

    // Dynamic Notch
    ToggleNotchExpanded,

    // Smart Unlock (Feasibility / Gated)
    RequestFaceUnlockEnrollment,
    TriggerSessionUnlock,

    // Updates
    CheckForUpdates,

    // Always On
    StartAwakeSession {
        duration_minutes: Option<u32>,
    },
    StopAwakeSession,

    // System Cleaner
    StartCleanerScan,
    CancelCleanerScan,
    ExecuteCleanerPurge {
        confirmed: bool,
    },
}

impl Action {
    pub fn target_module_id(&self) -> ModuleId {
        match self {
            Self::CaptureScreenshot { .. }
            | Self::StartScreenRecording { .. }
            | Self::StopScreenRecording => ModuleId::CaptureAndRecording,

            Self::SelectChargeLimit { .. } => ModuleId::BatteryGuardian,

            Self::ToggleNotchExpanded => ModuleId::DynamicNotch,

            Self::RequestFaceUnlockEnrollment | Self::TriggerSessionUnlock => ModuleId::SmartUnlock,

            Self::CheckForUpdates => ModuleId::Updates,

            Self::StartAwakeSession { .. } | Self::StopAwakeSession => ModuleId::AlwaysOn,

            Self::StartCleanerScan | Self::CancelCleanerScan | Self::ExecuteCleanerPurge { .. } => {
                ModuleId::SystemCleaner
            }
        }
    }
}

/// Output result of an executed command or action pipeline.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CommandResult {
    pub ok: bool,
    pub observed_value: Option<String>,
    pub error_code: Option<String>,
    pub message: Option<String>,
}

impl CommandResult {
    pub fn success(message: impl Into<String>) -> Self {
        Self {
            ok: true,
            observed_value: None,
            error_code: None,
            message: Some(message.into()),
        }
    }

    pub fn failure(code: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            ok: false,
            observed_value: None,
            error_code: Some(code.into()),
            message: Some(message.into()),
        }
    }
}
