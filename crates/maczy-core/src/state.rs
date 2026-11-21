use crate::capability::CapabilityRegistry;
use crate::modules::{MaczyModule, ModuleId, MODULE_COUNT};
use serde::{Deserialize, Serialize};

/// Immutable runtime state of an individual module.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ModuleRuntimeState {
    NotImplemented,
    Idle,
    Running,
    Paused,
    Blocked,
    Error,
}

impl ModuleRuntimeState {
    pub const fn as_str(&self) -> &'static str {
        match self {
            Self::NotImplemented => "Not Implemented",
            Self::Idle => "Idle",
            Self::Running => "Running",
            Self::Paused => "Paused",
            Self::Blocked => "Blocked",
            Self::Error => "Error",
        }
    }
}

/// Status snapshot of a module.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ModuleStatus {
    pub module_id: ModuleId,
    pub name: &'static str,
    pub enabled: bool,
    pub runtime: ModuleRuntimeState,
    pub status_message: String,
}

/// Canonical shared application state across all surfaces (Dashboard, Menu Bar, Notch).
#[derive(Debug, Clone)]
pub struct AppState {
    statuses: [ModuleStatus; MODULE_COUNT],
    registry: CapabilityRegistry,
}

impl Default for AppState {
    fn default() -> Self {
        let modules = MaczyModule::all();
        let registry = CapabilityRegistry::default();

        let statuses = [
            ModuleStatus {
                module_id: modules[0].id,
                name: modules[0].name,
                enabled: false,
                runtime: ModuleRuntimeState::NotImplemented,
                status_message: "Foundation scaffold placeholder (MZ-001)".to_string(),
            },
            ModuleStatus {
                module_id: modules[1].id,
                name: modules[1].name,
                enabled: false,
                runtime: ModuleRuntimeState::NotImplemented,
                status_message: "Foundation scaffold placeholder (MZ-001)".to_string(),
            },
            ModuleStatus {
                module_id: modules[2].id,
                name: modules[2].name,
                enabled: false,
                runtime: ModuleRuntimeState::NotImplemented,
                status_message: "Foundation scaffold placeholder (MZ-001)".to_string(),
            },
            ModuleStatus {
                module_id: modules[3].id,
                name: modules[3].name,
                enabled: false,
                runtime: ModuleRuntimeState::NotImplemented,
                status_message: "Gated by MZ-023 feasibility & security review".to_string(),
            },
            ModuleStatus {
                module_id: modules[4].id,
                name: modules[4].name,
                enabled: false,
                runtime: ModuleRuntimeState::NotImplemented,
                status_message: "Foundation scaffold placeholder (MZ-001)".to_string(),
            },
            ModuleStatus {
                module_id: modules[5].id,
                name: modules[5].name,
                enabled: false,
                runtime: ModuleRuntimeState::NotImplemented,
                status_message: "Foundation scaffold placeholder (MZ-001)".to_string(),
            },
            ModuleStatus {
                module_id: modules[6].id,
                name: modules[6].name,
                enabled: false,
                runtime: ModuleRuntimeState::NotImplemented,
                status_message: "Foundation scaffold placeholder (MZ-001)".to_string(),
            },
        ];

        Self { statuses, registry }
    }
}

impl AppState {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn all_statuses(&self) -> &[ModuleStatus; MODULE_COUNT] {
        &self.statuses
    }

    pub fn get_module_status(&self, id: ModuleId) -> Option<&ModuleStatus> {
        self.statuses.iter().find(|s| s.module_id == id)
    }

    pub fn registry(&self) -> &CapabilityRegistry {
        &self.registry
    }
}
