//! maczy-core: Core domain logic and state management for Maczy.
//!
//! Designed for Apple Silicon (arm64) macOS 14+ systems.
//! Prioritizes zero idle polling, low memory usage, and strict fail-closed security.

pub mod actions;
pub mod capability;
pub mod cleaner_safety;
pub mod event_bus;
pub mod modules;
pub mod permissions;
pub mod state;

pub use actions::{Action, CommandResult};
pub use capability::{CapabilityRegistry, ModuleCapability};
pub use cleaner_safety::{classify_leftover_path, LeftoverSafetyLevel};
pub use event_bus::{AppEvent, EventBus};
pub use modules::{MaczyModule, ModuleId, MODULE_COUNT};
pub use permissions::{Permission, PermissionState};
pub use state::{AppState, ModuleRuntimeState, ModuleStatus};

/// Current core engine version.
pub const CORE_VERSION: &str = env!("CARGO_PKG_VERSION");

/// Target architecture verification string.
pub const TARGET_ARCH: &str = if cfg!(target_arch = "aarch64") {
    "arm64"
} else {
    "unsupported"
};

/// Minimum supported macOS deployment target.
pub const MIN_MACOS_DEPLOYMENT: &str = "14.0";

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::Arc;

    #[test]
    fn test_core_version_valid() {
        assert!(!CORE_VERSION.is_empty());
    }

    #[test]
    fn test_module_count_exact() {
        assert_eq!(MODULE_COUNT, 7);
        assert_eq!(MaczyModule::all().len(), 7);
    }

    #[test]
    fn test_all_modules_registered_in_registry() {
        let registry = CapabilityRegistry::default();
        for module in MaczyModule::all() {
            let cap = registry.get_capability(module.id);
            assert!(cap.is_some(), "Module {:?} must be registered", module.id);
        }
    }

    #[test]
    fn test_capability_gate_blocks_smart_unlock() {
        let mut state = AppState::new();
        let action = Action::TriggerSessionUnlock;

        let result = state.dispatch(action);
        assert!(!result.ok);
        assert_eq!(result.error_code.as_deref(), Some("CAPABILITY_UNSUPPORTED"));

        // Status should remain Blocked, never fake running/success
        let status = state.get_module_status(ModuleId::SmartUnlock).unwrap();
        assert_eq!(status.runtime, ModuleRuntimeState::Blocked);
    }

    #[test]
    fn test_permission_gate_blocks_capture_when_unauthorized() {
        let mut state = AppState::new();
        // Permission is initially NotDetermined
        let action = Action::CaptureScreenshot {
            mode: "area".to_string(),
        };

        let result = state.dispatch(action);
        assert!(!result.ok);
        assert_eq!(result.error_code.as_deref(), Some("PERMISSION_REQUIRED"));

        let status = state
            .get_module_status(ModuleId::CaptureAndRecording)
            .unwrap();
        assert_eq!(status.runtime, ModuleRuntimeState::Idle);
    }

    #[test]
    fn test_action_succeeds_when_permission_granted() {
        let mut state = AppState::new();
        state.set_permission_state(Permission::ScreenRecording, PermissionState::Granted);

        let action = Action::CaptureScreenshot {
            mode: "area".to_string(),
        };

        let result = state.dispatch(action);
        assert!(result.ok);
        assert!(result.message.unwrap().contains("captured"));

        let status = state
            .get_module_status(ModuleId::CaptureAndRecording)
            .unwrap();
        assert_eq!(status.runtime, ModuleRuntimeState::Running);
    }

    #[test]
    fn test_event_bus_notifies_subscribers() {
        let mut state = AppState::new();
        state.set_permission_state(Permission::ScreenRecording, PermissionState::Granted);

        let event_counter = Arc::new(AtomicUsize::new(0));
        let counter_clone = Arc::clone(&event_counter);

        state.event_bus().subscribe(move |_event| {
            counter_clone.fetch_add(1, Ordering::SeqCst);
        });

        let action = Action::CaptureScreenshot {
            mode: "window".to_string(),
        };
        let _ = state.dispatch(action);

        // Should have received ModuleRuntimeChanged and CommandExecuted events
        assert!(event_counter.load(Ordering::SeqCst) >= 2);
    }

    #[test]
    fn test_charge_limit_gated_by_mz_014() {
        let mut state = AppState::new();
        let action = Action::SelectChargeLimit { percentage: 80 };

        let result = state.dispatch(action);
        assert!(!result.ok);
        assert_eq!(result.error_code.as_deref(), Some("GATE_MZ_014"));
    }

    #[test]
    fn test_charge_limit_verified_backend_and_readback() {
        let mut state = AppState::new();
        state.set_debounce_duration(std::time::Duration::from_millis(0));
        state.enable_charge_limit_backend(true);

        for pct in [80, 85, 90, 95, 100] {
            let res = state.dispatch(Action::SelectChargeLimit { percentage: pct });
            assert!(res.ok, "Expected ok for {}%, got {:?}", pct, res);
            assert_eq!(state.get_charge_limit(), Some(pct));
        }

        // Invalid percentage rejected
        let invalid = state.dispatch(Action::SelectChargeLimit { percentage: 73 });
        assert!(!invalid.ok);
        assert_eq!(invalid.error_code.as_deref(), Some("INVALID_PERCENTAGE"));
        assert_eq!(state.get_charge_limit(), Some(100)); // preserves last valid limit
    }

    #[test]
    fn test_debounce_ignores_duplicate_rapid_actions() {
        let mut state = AppState::new();
        state.set_permission_state(Permission::ScreenRecording, PermissionState::Granted);

        let action1 = Action::CaptureScreenshot {
            mode: "fullscreen".to_string(),
        };
        let result1 = state.dispatch(action1);
        assert!(result1.ok);

        let action2 = Action::CaptureScreenshot {
            mode: "fullscreen".to_string(),
        };
        let result2 = state.dispatch(action2);
        assert!(!result2.ok);
        assert_eq!(result2.error_code.as_deref(), Some("ACTION_DEBOUNCED"));
    }

    #[test]
    fn test_cleaner_purge_gated_by_mz_029() {
        let mut state = AppState::new();
        state.set_debounce_duration(std::time::Duration::from_millis(0));

        let unconfirmed = Action::ExecuteCleanerPurge { confirmed: false };
        let res = state.dispatch(unconfirmed);
        assert!(!res.ok);
        assert_eq!(res.error_code.as_deref(), Some("GATE_MZ_029"));

        let confirmed = Action::ExecuteCleanerPurge { confirmed: true };
        let res_ok = state.dispatch(confirmed);
        assert!(res_ok.ok);
        assert!(res_ok.message.unwrap().contains("Trash"));
    }
}
