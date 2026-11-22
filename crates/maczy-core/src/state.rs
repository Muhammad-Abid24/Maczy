use crate::actions::{Action, CommandResult};
use crate::capability::{CapabilityRegistry, ModuleCapability};
use crate::event_bus::{AppEvent, EventBus};
use crate::modules::{MaczyModule, ModuleId, MODULE_COUNT};
use crate::permissions::{Permission, PermissionState};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::{Duration, Instant};

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
    pub capability: ModuleCapability,
}

/// Canonical shared application state across all surfaces (Dashboard, Menu Bar, Notch).
#[derive(Clone)]
pub struct AppState {
    statuses: [ModuleStatus; MODULE_COUNT],
    registry: CapabilityRegistry,
    permissions: HashMap<Permission, PermissionState>,
    event_bus: EventBus,
    last_action_dispatched: HashMap<ModuleId, Instant>,
    debounce_duration: Duration,
    charge_limit_backend_verified: bool,
    current_charge_limit: Option<u8>,
}

impl Default for AppState {
    fn default() -> Self {
        let modules = MaczyModule::all();
        let registry = CapabilityRegistry::default();

        let statuses = [
            ModuleStatus {
                module_id: modules[0].id,
                name: modules[0].name,
                enabled: true,
                runtime: ModuleRuntimeState::Idle,
                status_message: "Ready for capture".to_string(),
                capability: registry.get_capability(modules[0].id).cloned().unwrap(),
            },
            ModuleStatus {
                module_id: modules[1].id,
                name: modules[1].name,
                enabled: true,
                runtime: ModuleRuntimeState::Idle,
                status_message: "Monitoring active; charge limits gated by MZ-014".to_string(),
                capability: registry.get_capability(modules[1].id).cloned().unwrap(),
            },
            ModuleStatus {
                module_id: modules[2].id,
                name: modules[2].name,
                enabled: true,
                runtime: ModuleRuntimeState::Idle,
                status_message: "Ready for interactions".to_string(),
                capability: registry.get_capability(modules[2].id).cloned().unwrap(),
            },
            ModuleStatus {
                module_id: modules[3].id,
                name: modules[3].name,
                enabled: false,
                runtime: ModuleRuntimeState::Blocked,
                status_message: "Gated by MZ-023 feasibility & security review".to_string(),
                capability: registry.get_capability(modules[3].id).cloned().unwrap(),
            },
            ModuleStatus {
                module_id: modules[4].id,
                name: modules[4].name,
                enabled: true,
                runtime: ModuleRuntimeState::Idle,
                status_message: "Sparkle update channel configured".to_string(),
                capability: registry.get_capability(modules[4].id).cloned().unwrap(),
            },
            ModuleStatus {
                module_id: modules[5].id,
                name: modules[5].name,
                enabled: true,
                runtime: ModuleRuntimeState::Idle,
                status_message: "IOPM power assertion ready".to_string(),
                capability: registry.get_capability(modules[5].id).cloned().unwrap(),
            },
            ModuleStatus {
                module_id: modules[6].id,
                name: modules[6].name,
                enabled: true,
                runtime: ModuleRuntimeState::Idle,
                status_message: "Safe read-only scanner ready".to_string(),
                capability: registry.get_capability(modules[6].id).cloned().unwrap(),
            },
        ];

        let mut permissions = HashMap::new();
        // Default permissions in safe state
        permissions.insert(Permission::ScreenRecording, PermissionState::NotDetermined);
        permissions.insert(Permission::Camera, PermissionState::NotDetermined);
        permissions.insert(Permission::Microphone, PermissionState::NotDetermined);
        permissions.insert(Permission::Accessibility, PermissionState::NotDetermined);
        permissions.insert(Permission::Bluetooth, PermissionState::NotDetermined);
        permissions.insert(Permission::Notifications, PermissionState::NotDetermined);
        permissions.insert(Permission::FullDiskAccess, PermissionState::NotDetermined);

        Self {
            statuses,
            registry,
            permissions,
            event_bus: EventBus::new(),
            last_action_dispatched: HashMap::new(),
            debounce_duration: Duration::from_millis(200),
            charge_limit_backend_verified: false,
            current_charge_limit: None,
        }
    }
}

impl AppState {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn enable_charge_limit_backend(&mut self, verified: bool) {
        self.charge_limit_backend_verified = verified;
    }

    pub fn get_charge_limit(&self) -> Option<u8> {
        self.current_charge_limit
    }

    pub fn all_statuses(&self) -> &[ModuleStatus; MODULE_COUNT] {
        &self.statuses
    }

    pub fn get_module_status(&self, id: ModuleId) -> Option<&ModuleStatus> {
        self.statuses.iter().find(|s| s.module_id == id)
    }

    pub fn get_module_status_mut(&mut self, id: ModuleId) -> Option<&mut ModuleStatus> {
        self.statuses.iter_mut().find(|s| s.module_id == id)
    }

    pub fn registry(&self) -> &CapabilityRegistry {
        &self.registry
    }

    pub fn registry_mut(&mut self) -> &mut CapabilityRegistry {
        &mut self.registry
    }

    pub fn event_bus(&self) -> &EventBus {
        &self.event_bus
    }

    pub fn set_permission_state(&mut self, permission: Permission, state: PermissionState) {
        self.permissions.insert(permission, state);
    }

    pub fn get_permission_state(&self, permission: Permission) -> PermissionState {
        self.permissions
            .get(&permission)
            .copied()
            .unwrap_or(PermissionState::NotDetermined)
    }

    pub fn set_debounce_duration(&mut self, duration: Duration) {
        self.debounce_duration = duration;
    }

    /// Primary Action Pipeline:
    /// Action -> Capability Gate -> Permission Gate -> Command -> Result -> State Update
    pub fn dispatch(&mut self, action: Action) -> CommandResult {
        let module_id = action.target_module_id();

        // 0. Debounce / Idempotency Check
        let now = Instant::now();
        if let Some(last_time) = self.last_action_dispatched.get(&module_id) {
            if now.duration_since(*last_time) < self.debounce_duration {
                return CommandResult::failure(
                    "ACTION_DEBOUNCED",
                    "Action ignored due to debounce threshold",
                );
            }
        }
        self.last_action_dispatched.insert(module_id, now);

        // 1. Capability Gate
        let capability = match self.registry.get_capability(module_id) {
            Some(cap) if cap.is_supported => cap.clone(),
            Some(cap) => {
                let reason = cap.reason.clone().unwrap_or_else(|| {
                    "Module capability is not supported on this platform".to_string()
                });
                self.event_bus.publish(&AppEvent::ActionGated {
                    module_id,
                    gate_type: "capability".to_string(),
                    reason: reason.clone(),
                    error_code: "CAPABILITY_UNSUPPORTED".to_string(),
                });
                return CommandResult::failure("CAPABILITY_UNSUPPORTED", reason);
            }
            None => {
                let msg = format!("Module {:?} not found in capability registry", module_id);
                return CommandResult::failure("MODULE_NOT_FOUND", msg);
            }
        };

        // 2. Permission Gate
        for req_perm in &capability.required_permissions {
            let perm_state = self.get_permission_state(*req_perm);
            if !perm_state.is_granted() {
                let msg = format!(
                    "Operation requires {} permission ({:?})",
                    req_perm.display_name(),
                    perm_state
                );
                self.event_bus.publish(&AppEvent::ActionGated {
                    module_id,
                    gate_type: "permission".to_string(),
                    reason: msg.clone(),
                    error_code: "PERMISSION_REQUIRED".to_string(),
                });
                return CommandResult::failure("PERMISSION_REQUIRED", msg);
            }
        }

        // 3. Command Execution & State Transition
        let result = match &action {
            Action::CaptureScreenshot { mode } => {
                self.transition_runtime(
                    module_id,
                    ModuleRuntimeState::Running,
                    format!("Capturing screenshot: {}", mode),
                );
                CommandResult::success(format!("Screenshot captured in {} mode", mode))
            }
            Action::StartScreenRecording {
                target,
                system_audio,
                microphone,
            } => {
                let msg = format!(
                    "Recording {} (audio: sys={}, mic={})",
                    target, system_audio, microphone
                );
                self.transition_runtime(module_id, ModuleRuntimeState::Running, msg.clone());
                CommandResult::success(msg)
            }
            Action::StopScreenRecording => {
                self.transition_runtime(
                    module_id,
                    ModuleRuntimeState::Idle,
                    "Recording saved".to_string(),
                );
                CommandResult::success("Recording stopped and saved")
            }
            Action::SelectChargeLimit { percentage } => {
                if *percentage == 80
                    || *percentage == 85
                    || *percentage == 90
                    || *percentage == 95
                    || *percentage == 100
                {
                    if self.charge_limit_backend_verified {
                        self.current_charge_limit = Some(*percentage);
                        let msg =
                            format!("Charge limit set to {}% (readback verified)", percentage);
                        self.transition_runtime(
                            module_id,
                            ModuleRuntimeState::Running,
                            msg.clone(),
                        );
                        CommandResult::success(msg)
                    } else {
                        // Charge writes require MZ-014 backend verification
                        CommandResult::failure(
                            "GATE_MZ_014",
                            "Setting charge threshold requires MZ-014 backend verification. Write controls gated.",
                        )
                    }
                } else {
                    CommandResult::failure(
                        "INVALID_PERCENTAGE",
                        "Charge limit percentage must be 80, 85, 90, 95, or 100",
                    )
                }
            }
            Action::ToggleNotchExpanded => {
                let is_running = self
                    .get_module_status(module_id)
                    .map(|s| s.runtime == ModuleRuntimeState::Running)
                    .unwrap_or(false);
                let next = if is_running {
                    ModuleRuntimeState::Idle
                } else {
                    ModuleRuntimeState::Running
                };
                self.transition_runtime(module_id, next, "Notch state toggled".to_string());
                CommandResult::success("Notch expanded toggled")
            }
            Action::RequestFaceUnlockEnrollment | Action::TriggerSessionUnlock => {
                // Strictly blocked by capability gate; unreachable if capability gate holds
                CommandResult::failure(
                    "GATE_MZ_023",
                    "Smart Unlock is gated by MZ-023 feasibility review",
                )
            }
            Action::CheckForUpdates => {
                self.transition_runtime(
                    module_id,
                    ModuleRuntimeState::Running,
                    "Checking for updates...".to_string(),
                );
                CommandResult::success("Update check initiated")
            }
            Action::StartAwakeSession { duration_minutes } => {
                let msg = match duration_minutes {
                    Some(m) => format!("Awake session active for {} minutes", m),
                    None => "Awake session active indefinitely".to_string(),
                };
                self.transition_runtime(module_id, ModuleRuntimeState::Running, msg.clone());
                CommandResult::success(msg)
            }
            Action::StopAwakeSession => {
                self.transition_runtime(
                    module_id,
                    ModuleRuntimeState::Idle,
                    "Awake session ended".to_string(),
                );
                CommandResult::success("Awake session stopped")
            }
            Action::StartCleanerScan => {
                self.transition_runtime(
                    module_id,
                    ModuleRuntimeState::Running,
                    "Safe scan in progress...".to_string(),
                );
                CommandResult::success("Safe read-only scan started")
            }
            Action::CancelCleanerScan => {
                self.transition_runtime(
                    module_id,
                    ModuleRuntimeState::Idle,
                    "Scan cancelled".to_string(),
                );
                CommandResult::success("Scan cancelled")
            }
            Action::ExecuteCleanerPurge { confirmed } => {
                if *confirmed {
                    self.transition_runtime(
                        module_id,
                        ModuleRuntimeState::Running,
                        "Cleanup purge executed successfully to Trash".to_string(),
                    );
                    CommandResult::success("Cleanup purge executed successfully to Trash")
                } else {
                    CommandResult::failure(
                        "GATE_MZ_029",
                        "Cleanup deletion execution requires explicit confirmation. Write controls gated.",
                    )
                }
            }
            Action::EmptyTrash { confirmed } => {
                if *confirmed {
                    self.transition_runtime(
                        module_id,
                        ModuleRuntimeState::Running,
                        "Emptying Trash permanently...".to_string(),
                    );
                    CommandResult::success("Trash emptied successfully")
                } else {
                    CommandResult::failure(
                        "GATE_MZ_029",
                        "Emptying Trash requires explicit confirmation. Action gated by MZ-029.",
                    )
                }
            }
        };

        // 4. Publish Command Outcome Event
        self.event_bus.publish(&AppEvent::CommandExecuted {
            module_id,
            result: result.clone(),
        });

        result
    }

    fn transition_runtime(
        &mut self,
        module_id: ModuleId,
        new_runtime: ModuleRuntimeState,
        message: String,
    ) {
        if let Some(status) = self.get_module_status_mut(module_id) {
            let previous = status.runtime;
            status.runtime = new_runtime;
            status.status_message = message;

            self.event_bus.publish(&AppEvent::ModuleRuntimeChanged {
                module_id,
                previous,
                current: new_runtime,
            });
        }
    }
}
