use crate::modules::ModuleId;
use crate::permissions::Permission;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Declares system capabilities, platform compatibility, and permission prerequisites for a module.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ModuleCapability {
    pub module_id: ModuleId,
    pub is_supported: bool,
    pub reason: Option<String>,
    pub required_permissions: Vec<Permission>,
    pub backend: Option<String>,
}

impl ModuleCapability {
    pub fn default_for(module_id: ModuleId) -> Self {
        match module_id {
            ModuleId::CaptureAndRecording => Self {
                module_id,
                is_supported: true,
                reason: Some("ScreenCaptureKit available on macOS 14+".to_string()),
                required_permissions: vec![Permission::ScreenRecording],
                backend: Some("ScreenCaptureKit".to_string()),
            },
            ModuleId::BatteryGuardian => Self {
                module_id,
                is_supported: true,
                reason: Some("Battery health monitoring available; write controls gated by MZ-014".to_string()),
                required_permissions: vec![],
                backend: Some("IOKit".to_string()),
            },
            ModuleId::DynamicNotch => Self {
                module_id,
                is_supported: true,
                reason: Some("Hardware notch or virtual island overlay".to_string()),
                required_permissions: vec![],
                backend: Some("AppKit Overlay".to_string()),
            },
            ModuleId::SmartUnlock => Self {
                module_id,
                is_supported: false, // Strictly false until MZ-023 feasibility passes
                reason: Some(
                    "CRITICAL: macOS Lock Screen Face Unlock gated by MZ-023 feasibility and security review. Not implemented. Preserving native Touch ID/password fallback."
                        .to_string(),
                ),
                required_permissions: vec![Permission::Camera],
                backend: None,
            },
            ModuleId::Updates => Self {
                module_id,
                is_supported: true,
                reason: Some("Sparkle 2 EdDSA signed appcast delivery".to_string()),
                required_permissions: vec![],
                backend: Some("Sparkle 2".to_string()),
            },
            ModuleId::AlwaysOn => Self {
                module_id,
                is_supported: true,
                reason: Some("IOPM scoped power assertions".to_string()),
                required_permissions: vec![],
                backend: Some("IOPMAssertion".to_string()),
            },
            ModuleId::SystemCleaner => Self {
                module_id,
                is_supported: true,
                reason: Some("Mole-inspired safe read-only scanner; non-destructive defaults; deletion gated by MZ-029".to_string()),
                required_permissions: vec![],
                backend: Some("ReadOnlyScanner".to_string()),
            },
        }
    }
}

/// Registry of module capabilities.
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

    pub fn set_capability(&mut self, capability: ModuleCapability) {
        self.capabilities.insert(capability.module_id, capability);
    }
}
