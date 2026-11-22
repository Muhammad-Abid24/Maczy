import Foundation
import AppKit
import SwiftUI
import CoreGraphics

/// Floating interactive control panel displayed during scrolling capture sessions.
@MainActor
public final class ScrollingControlHUD: NSPanel {
    public static let shared = ScrollingControlHUD()

    private var hostingView: NSHostingView<ScrollingControlHUDView>?

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 72),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = NSWindow.Level(Int(CGWindowLevelForKey(.maximumWindow)))
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false
    }

    /// Positions and presents the scrolling control HUD anchored near the selection rect.
    public func present(anchoredTo targetRect: CGRect, on screen: NSScreen = NSScreen.main ?? NSScreen.screens[0]) {
        let view = ScrollingControlHUDView(
            onToggleAutoScroll: {
                ScrollingCaptureCoordinator.shared.toggleAutoScroll()
            },
            onAddSlice: {
                Task {
                    _ = await ScrollingCaptureCoordinator.shared.captureCurrentSlice()
                }
            },
            onFinish: {
                ScrollingCaptureCoordinator.shared.finishInteractiveSession()
            },
            onCancel: {
                ScrollingCaptureCoordinator.shared.cancelInteractiveSession()
            }
        )

        let hosting = NSHostingView(rootView: view)
        self.hostingView = hosting
        self.contentView = hosting

        let hudWidth: CGFloat = 460
        let hudHeight: CGFloat = 72

        let screenFrame = screen.visibleFrame
        var posX = targetRect.midX - (hudWidth / 2)
        posX = max(screenFrame.minX + 16, min(screenFrame.maxX - hudWidth - 16, posX))

        var posY = targetRect.maxY + 16
        if posY + hudHeight > screenFrame.maxY {
            posY = targetRect.minY - hudHeight - 16
        }
        if posY < screenFrame.minY {
            posY = screenFrame.maxY - hudHeight - 24
        }

        self.setFrame(NSRect(x: posX, y: posY, width: hudWidth, height: hudHeight), display: true)
        self.alphaValue = 0.0
        self.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 1.0
        }
    }

    public func dismiss() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            self.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                self?.orderOut(nil)
                self?.contentView = nil
                self?.hostingView = nil
            }
        })
    }
}

/// SwiftUI View rendering the floating controls for scrolling capture.
public struct ScrollingControlHUDView: View {
    @ObservedObject private var coordinator = ScrollingCaptureCoordinator.shared

    let onToggleAutoScroll: () -> Void
    let onAddSlice: () -> Void
    let onFinish: () -> Void
    let onCancel: () -> Void

    public init(
        onToggleAutoScroll: @escaping () -> Void,
        onAddSlice: @escaping () -> Void,
        onFinish: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onToggleAutoScroll = onToggleAutoScroll
        self.onAddSlice = onAddSlice
        self.onFinish = onFinish
        self.onCancel = onCancel
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Live Status Indicator & Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(coordinator.isAutoScrolling ? MaczyDesignTokens.brandPurple : MaczyDesignTokens.statusGreen)
                        .frame(width: 8, height: 8)
                    Text("Scrolling Capture")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)

                    if coordinator.isEndReached {
                        Text("• Bottom")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(MaczyDesignTokens.statusGreen)
                    }
                }

                Text("\(coordinator.activeSliceCount) \(coordinator.activeSliceCount == 1 ? "slice" : "slices") • ~\(coordinator.estimatedTotalHeight)px")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 130, alignment: .leading)

            Divider()
                .frame(height: 28)

            // Auto Scroll Button
            Button(action: onToggleAutoScroll) {
                HStack(spacing: 5) {
                    Image(systemName: coordinator.isAutoScrolling ? "pause.fill" : "play.fill")
                        .font(.system(size: 11))
                    Text(coordinator.isAutoScrolling ? "Pause" : "Auto Scroll")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .tint(coordinator.isAutoScrolling ? MaczyDesignTokens.statusOrange : MaczyDesignTokens.brandPurple)
            .controlSize(.small)

            // Manual Step Button ("Add Slice")
            Button(action: onAddSlice) {
                HStack(spacing: 5) {
                    Image(systemName: "camera.badge.plus")
                        .font(.system(size: 11))
                    Text("Add Slice")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Scroll manually with trackpad or mouse, then click to capture slice")

            // Finish & Stitch Button
            Button(action: onFinish) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                    Text("Done")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .tint(MaczyDesignTokens.statusGreen)
            .controlSize(.small)

            // Cancel Button
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Cancel capture")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
    }
}
