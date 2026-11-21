use crate::modules::ModuleId;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Declares system capabilities, platform compatibility, and permission prerequisites for a module.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ModuleCapability {
    pub module_id: ModuleId,
    pub is_supported_on_current_os: bool,
    pub requires_camera_permission: bool,
    pub requires_microphone_permission: bool,
    pub requires_screen_recording_permission: bool,
    pub requires_accessibility_permission: bool,
    pub gating_notes: Option<String>,
}

impl ModuleCapability {
    pub fn default_for(module_id: ModuleId) -> Self {
        match module_id {
            ModuleId::CaptureAndRecording => Self {
                module_id,
                is_supported_on_current_os: true,
                requires_camera_permission: false,
                requires_microphone_permission: true,
                requires_screen_recording_permission: true,
                requires_accessibility_permission: false,
                gating_notes: Some("ScreenCaptureKit available on macOS 14+".to_string()),
            },
            ModuleId::BatteryGuardian => Self {
                module_id,
                is_supported_on_current_os: true,
                requires_camera_permission: false,
                requires_microphone_permission: false,
                requires_screen_recording_permission: false,
                requires_accessibility_permission: false,
                gating_notes: Some("Battery monitoring via IOKit; write controls gated by MZ-014".to_string()),
            },
            ModuleId::DynamicNotch => Self {
                module_id,
                is_supported_on_current_os: true,
                requires_camera_permission: false,
                requires_microphone_permission: false,
                requires_screen_recording_permission: false,
                requires_accessibility_permission: false,
                gating_notes: Some("Hardware notch or virtual island fallback".to_string()),
            },
            ModuleId::SmartUnlock => Self {
                module_id,
                is_supported_on_current_os: false, // Explicitly false until MZ-023 feasibility passes
                requires_camera_permission: true,
                requires_microphone_permission: false,
                requires_screen_recording_permission: false,
                requires_accessibility_permission: false,
                gating_notes: Some(
                    "CRITICAL: macOS Lock Screen Face Unlock feasibility gated by MZ-023. Not implemented. Preserving native Touch ID/password fallback."
                        .to_string(),
                ),
            },
            ModuleId::Updates => Self {
                module_id,
                is_supported_on_current_os: true,
                requires_camera_permission: false,
                requires_microphone_permission: false,
                requires_screen_recording_permission: false,
                requires_accessibility_permission: false,
                gating_notes: Some("Sparkle 2 EdDSA verification".to_string()),
            },
            ModuleId::AlwaysOn => Self {
                module_id,
                is_supported_on_current_os: true,
                requires_camera_permission: false,
                requires_microphone_permission: false,
                requires_screen_recording_permission: false,
                requires_accessibility_permission: false,
                gating_notes: Some("IOPM scoped power assertions".to_string()),
            },
            ModuleId::SystemCleaner => Self {
                module_id,
                is_supported_on_current_os: true,
                requires_camera_permission: false,
                requires_microphone_permission: false,
                requires_screen_recording_permission: false,
                requires_accessibility_permission: false,
                gating_notes: Some("Safe read-only scan first; non-destructive defaults; deletion gated by MZ-029".to_string()),
            },
        }
    }
}

/// System-wide registry of module capabilities.
#[derive(Debug, Clone)]
pub struct CapabilityRegistry {
    capabilities: HashMap<ModuleId, ModuleCapability>,
}

impl Default for CapabilityRegistry {
    fn default() -> Self {
        let mut capabilities = HashMap::new();
        for module in crate::modules::MaczyModule::all() {
            capabilities.insert(module.id, ModuleCapability::default_for(module.id));
        }
        Self { capabilities }
    }
}

impl CapabilityRegistry {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn get_capability(&self, id: ModuleId) -> Option<&ModuleCapability> {
        self.capabilities.get(&id)
    }
}
