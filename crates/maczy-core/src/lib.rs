//! maczy-core: Core domain logic and state management for Maczy.
//!
//! Designed for Apple Silicon (arm64) macOS 14+ systems.
//! Prioritizes zero idle polling, low memory usage, and strict fail-closed security.

pub mod capability;
pub mod modules;
pub mod state;

pub use capability::{CapabilityRegistry, ModuleCapability};
pub use modules::{MaczyModule, ModuleId, MODULE_COUNT};
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
    fn test_all_modules_initially_not_implemented() {
        let state = AppState::new();
        for module in MaczyModule::all() {
            let status = state.get_module_status(module.id);
            assert!(status.is_some());
            assert_eq!(status.unwrap().runtime, ModuleRuntimeState::NotImplemented);
        }
    }
}
