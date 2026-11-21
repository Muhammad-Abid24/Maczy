use serde::{Deserialize, Serialize};

/// Standard macOS system permissions governed by TCC and OS security.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Permission {
    ScreenRecording,
    Camera,
    Microphone,
    Accessibility,
    Bluetooth,
    Notifications,
    FullDiskAccess,
}

impl Permission {
    pub const fn display_name(&self) -> &'static str {
        match self {
            Self::ScreenRecording => "Screen Recording",
            Self::Camera => "Camera",
            Self::Microphone => "Microphone",
            Self::Accessibility => "Accessibility",
            Self::Bluetooth => "Bluetooth",
            Self::Notifications => "Notifications",
            Self::FullDiskAccess => "Full Disk Access",
        }
    }
}

/// Authorization status for an OS-managed permission.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PermissionState {
    NotDetermined,
    Granted,
    Denied,
    Restricted,
}

impl PermissionState {
    pub fn is_granted(&self) -> bool {
        matches!(self, Self::Granted)
    }
}
