import SwiftUI
import AppKit

/// Unified native application icon view for Maczy surfaces (Sidebar, MenuBar, About, etc.)
public struct MaczyAppIconView: View {
    public let size: CGFloat
    public let cornerRadius: CGFloat

    public init(size: CGFloat = 36, cornerRadius: CGFloat = 8) {
        self.size = size
        self.cornerRadius = cornerRadius
    }

    private var iconImage: NSImage? {
        if let bundleImage = Bundle.module.image(forResource: "AppIcon") {
            return bundleImage
        }
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        if let appIcon = NSImage(named: NSImage.applicationIconName) {
            return appIcon
        }
        return nil
    }

    public var body: some View {
        Group {
            if let image = iconImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.55, blue: 0.2),
                                    Color(red: 0.85, green: 0.35, blue: 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("M")
                        .font(.system(size: size * 0.55, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
