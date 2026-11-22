//! cleaner_safety: Safety classification and protection rules for uninstallation and maintenance.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LeftoverSafetyLevel {
    Protected = 0,
    ReviewRequired = 1,
    Safe = 2,
}

/// Evaluates whether a given file path is safe to move to trash as an application leftover.
/// Returns a LeftoverSafetyLevel:
/// - Protected (0): System paths, personal user docs, keychain, repositories, root paths
/// - ReviewRequired (1): Application Support or configuration directories that may contain user databases/settings
/// - Safe (2): Caches, logs, saved application state, temporary files
pub fn classify_leftover_path(path: &str) -> LeftoverSafetyLevel {
    let p = path.trim();
    if p.is_empty() {
        return LeftoverSafetyLevel::Protected;
    }

    // Critical system paths are strictly protected
    let system_prefixes = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/private",
        "/etc",
        "/var/db",
        "/Library/Keychains",
        "/Applications/Safari.app",
        "/Applications/Finder.app",
    ];

    for prefix in &system_prefixes {
        if p.starts_with(prefix) {
            return LeftoverSafetyLevel::Protected;
        }
    }

    // Never touch user personal documents or source control
    if p.contains("/Documents")
        || p.contains("/Desktop")
        || p.contains("/Downloads")
        || p.contains("/Pictures")
        || p.contains("/Music")
        || p.contains("/Movies")
        || p.contains("/.git")
        || p.contains("/.ssh")
        || p.contains("/.gnupg")
        || p.contains("/Keychains")
        || p.contains("/1Password")
        || p.contains("/Bitwarden")
    {
        return LeftoverSafetyLevel::Protected;
    }

    // Database and certificate files are protected
    if p.ends_with(".sqlite")
        || p.ends_with(".db")
        || p.ends_with(".keychain")
        || p.ends_with(".keychain-db")
        || p.ends_with(".pem")
        || p.ends_with(".key")
    {
        return LeftoverSafetyLevel::Protected;
    }

    // Cache, log, and saved state are safe
    if p.contains("/Library/Caches")
        || p.contains("/Library/Logs")
        || p.contains("/Library/Saved Application State")
    {
        return LeftoverSafetyLevel::Safe;
    }

    // Application Support, Containers, and Preferences require user review
    if p.contains("/Library/Application Support")
        || p.contains("/Library/Containers")
        || p.contains("/Library/Preferences")
    {
        return LeftoverSafetyLevel::ReviewRequired;
    }

    LeftoverSafetyLevel::ReviewRequired
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_system_paths_strictly_protected() {
        assert_eq!(
            classify_leftover_path("/System/Library/CoreServices"),
            LeftoverSafetyLevel::Protected
        );
        assert_eq!(
            classify_leftover_path("/usr/bin/tar"),
            LeftoverSafetyLevel::Protected
        );
    }

    #[test]
    fn test_personal_roots_and_repos_protected() {
        assert_eq!(
            classify_leftover_path("/Users/alice/Documents/Report.docx"),
            LeftoverSafetyLevel::Protected
        );
        assert_eq!(
            classify_leftover_path("/Users/alice/Project/.git/config"),
            LeftoverSafetyLevel::Protected
        );
        assert_eq!(
            classify_leftover_path("/Users/alice/.ssh/id_rsa"),
            LeftoverSafetyLevel::Protected
        );
    }

    #[test]
    fn test_caches_and_logs_safe() {
        assert_eq!(
            classify_leftover_path("/Users/alice/Library/Caches/com.example.app"),
            LeftoverSafetyLevel::Safe
        );
        assert_eq!(
            classify_leftover_path("/Users/alice/Library/Logs/com.example.app.log"),
            LeftoverSafetyLevel::Safe
        );
        assert_eq!(
            classify_leftover_path(
                "/Users/alice/Library/Saved Application State/com.example.app.savedState"
            ),
            LeftoverSafetyLevel::Safe
        );
    }

    #[test]
    fn test_app_support_review_required() {
        assert_eq!(
            classify_leftover_path("/Users/alice/Library/Application Support/com.example.app"),
            LeftoverSafetyLevel::ReviewRequired
        );
        assert_eq!(
            classify_leftover_path("/Users/alice/Library/Preferences/com.example.app.plist"),
            LeftoverSafetyLevel::ReviewRequired
        );
    }
}
