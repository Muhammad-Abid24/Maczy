//! C-compatible ABI boundary exposing maczy-core functionality to Swift.

use maczy_core::{AppState, MaczyModule, MODULE_COUNT};
use std::ffi::CString;
use std::os::raw::c_char;
use std::sync::OnceLock;

static GLOBAL_STATE: OnceLock<AppState> = OnceLock::new();

fn get_state() -> &'static AppState {
    GLOBAL_STATE.get_or_init(AppState::new)
}

/// Returns the maczy-core version as a null-terminated C string.
/// The returned pointer must NOT be freed by the caller (static lifetime).
#[no_mangle]
pub extern "C" fn maczy_core_version() -> *const c_char {
    static VERSION: OnceLock<CString> = OnceLock::new();
    VERSION
        .get_or_init(|| CString::new(maczy_core::CORE_VERSION).unwrap_or_default())
        .as_ptr()
}

/// Returns the total number of required Maczy modules (always 7).
#[no_mangle]
pub extern "C" fn maczy_module_count() -> u32 {
    MODULE_COUNT as u32
}

/// Returns the unique module identifier string at `index` (0..6).
/// Returns null if `index` is out of bounds. Caller must NOT free this pointer.
#[no_mangle]
pub extern "C" fn maczy_module_id(index: u32) -> *const c_char {
    let modules = MaczyModule::all();
    if let Some(m) = modules.get(index as usize) {
        match m.id {
            maczy_core::ModuleId::CaptureAndRecording => c"capture_and_recording".as_ptr(),
            maczy_core::ModuleId::BatteryGuardian => c"battery_guardian".as_ptr(),
            maczy_core::ModuleId::DynamicNotch => c"dynamic_notch".as_ptr(),
            maczy_core::ModuleId::SmartUnlock => c"smart_unlock".as_ptr(),
            maczy_core::ModuleId::Updates => c"updates".as_ptr(),
            maczy_core::ModuleId::AlwaysOn => c"always_on".as_ptr(),
            maczy_core::ModuleId::SystemCleaner => c"system_cleaner".as_ptr(),
        }
    } else {
        std::ptr::null()
    }
}

/// Returns the human-readable display name for the module at `index` (0..6).
/// Returns null if out of bounds. Caller must NOT free this pointer.
#[no_mangle]
pub extern "C" fn maczy_module_name(index: u32) -> *const c_char {
    let modules = MaczyModule::all();
    if let Some(m) = modules.get(index as usize) {
        match m.id {
            maczy_core::ModuleId::CaptureAndRecording => c"Capture & Recording".as_ptr(),
            maczy_core::ModuleId::BatteryGuardian => c"Battery Guardian".as_ptr(),
            maczy_core::ModuleId::DynamicNotch => c"Dynamic Notch".as_ptr(),
            maczy_core::ModuleId::SmartUnlock => c"Smart Unlock".as_ptr(),
            maczy_core::ModuleId::Updates => c"Updates".as_ptr(),
            maczy_core::ModuleId::AlwaysOn => c"Always On".as_ptr(),
            maczy_core::ModuleId::SystemCleaner => c"System Cleaner".as_ptr(),
        }
    } else {
        std::ptr::null()
    }
}

/// Returns whether the module at `index` is actively implemented.
/// For MZ-001 scaffold, all modules return false (truthful reporting).
#[no_mangle]
pub extern "C" fn maczy_module_is_implemented(index: u32) -> bool {
    let _ = index;
    false
}

/// Returns a human-readable status message for the module at `index`.
/// Pointer must be freed by caller using `maczy_free_string`.
#[no_mangle]
pub extern "C" fn maczy_module_status_message(index: u32) -> *mut c_char {
    let state = get_state();
    let statuses = state.all_statuses();
    if let Some(s) = statuses.get(index as usize) {
        if let Ok(c_str) = CString::new(s.status_message.as_str()) {
            return c_str.into_raw();
        }
    }
    std::ptr::null_mut()
}

/// Safely frees a string previously returned by a Maczy FFI function.
///
/// # Safety
/// Caller must ensure `s` was returned by `maczy_module_status_message` or is null.
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn maczy_free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            let _ = CString::from_raw(s);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CStr;

    #[test]
    fn test_ffi_version_string() {
        let ptr = maczy_core_version();
        assert!(!ptr.is_null());
        let c_str = unsafe { CStr::from_ptr(ptr) };
        assert_eq!(c_str.to_str().unwrap(), maczy_core::CORE_VERSION);
    }

    #[test]
    fn test_ffi_module_count() {
        assert_eq!(maczy_module_count(), 7);
    }

    #[test]
    fn test_ffi_module_indices() {
        for i in 0..7 {
            let id_ptr = maczy_module_id(i);
            assert!(!id_ptr.is_null());
            let name_ptr = maczy_module_name(i);
            assert!(!name_ptr.is_null());
            assert!(!maczy_module_is_implemented(i));

            let status_ptr = maczy_module_status_message(i);
            assert!(!status_ptr.is_null());
            maczy_free_string(status_ptr);
        }

        // Out of bounds
        assert!(maczy_module_id(7).is_null());
        assert!(maczy_module_name(7).is_null());
        assert!(maczy_module_status_message(7).is_null());
    }
}
