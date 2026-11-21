import SwiftUI

/// Approved design tokens extracted from the authoritative OpenDesign project (70356bd0-f397-4d5e-983d-93a7952d85c6).
public enum MaczyDesignTokens {
    // MARK: - Geometry & Spacing
    public static let sidebarCompactWidth: CGFloat = 64
    public static let sidebarWideWidth: CGFloat = 224
    public static let toolbarHeight: CGFloat = 52
    public static let windowCornerRadius: CGFloat = 13
    public static let panelCornerRadius: CGFloat = 16
    public static let buttonCornerRadius: CGFloat = 9

    // MARK: - Colors (Adaptive to Light & Dark)
    public static let brandPurple = Color(red: 111 / 255, green: 75 / 255, blue: 242 / 255) // #6f4bf2
    public static let brandPurpleSoft = Color(red: 238 / 255, green: 233 / 255, blue: 255 / 255) // #eee9ff
    public static let brandLavender = Color(red: 198 / 255, green: 183 / 255, blue: 255 / 255) // #c6b7ff

    public static let statusGreen = Color(red: 43 / 255, green: 154 / 255, blue: 98 / 255) // #2b9a62
    public static let statusOrange = Color(red: 199 / 255, green: 107 / 255, blue: 24 / 255) // #c76b18
    public static let statusRed = Color(red: 212 / 255, green: 72 / 255, blue: 75 / 255) // #d4484b
    public static let statusBlue = Color(red: 57 / 255, green: 120 / 255, blue: 208 / 255) // #3978d0

    public static let textPrimary = Color.primary
    public static let textSecondary = Color.secondary
}
