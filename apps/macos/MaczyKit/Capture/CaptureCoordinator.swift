import Foundation
import AppKit
import CoreGraphics

/// Coordinates interactive and programmatic screen capture flows, export, and preview presentation.
@MainActor
public final class CaptureCoordinator: NSObject, AreaSelectionOverlayDelegate {
    public static let shared = CaptureCoordinator()

    private var activeOverlay: AreaSelectionOverlayWindowController?
    private var completionHandler: ((Result<CapturedImageItem, CaptureError>) -> Void)?

    private override init() {
        super.init()
    }

    /// Triggers screen capture for the specified mode.
    public func triggerCapture(mode: String, completion: ((Result<CapturedImageItem, CaptureError>) -> Void)? = nil) {
        self.completionHandler = completion

        // Ensure macOS Screen Recording permission is active before presenting capture UI
        guard ScreenCaptureEngine.shared.isAuthorized() else {
            _ = CGRequestScreenCaptureAccess()
            PermissionManager.shared.openSettings(for: .screenRecording)
            self.handleCaptureFailure(.permissionDenied)
            return
        }

        switch mode.lowercased() {
        case "area":
            presentAreaSelectionOverlay()

        case "window":
            Task {
                do {
                    // Capture first available non-desktop window
                    let content = try await ScreenCaptureEngine.shared.capture(target: .window(windowID: 0))
                    self.handleCaptureSuccess(content)
                } catch let error as CaptureError {
                    self.handleCaptureFailure(error)
                } catch {
                    self.handleCaptureFailure(.captureFailed(error.localizedDescription))
                }
            }

        case "fullscreen":
            Task {
                do {
                    let content = try await ScreenCaptureEngine.shared.capture(target: .fullscreen(displayID: nil))
                    self.handleCaptureSuccess(content)
                } catch let error as CaptureError {
                    self.handleCaptureFailure(error)
                } catch {
                    self.handleCaptureFailure(.captureFailed(error.localizedDescription))
                }
            }

        case "scrolling":
            Task {
                do {
                    ScrollingCaptureCoordinator.shared.startSession()
                    let firstSlice = try await ScreenCaptureEngine.shared.capture(target: .window(windowID: 0))
                    ScrollingCaptureCoordinator.shared.appendSlice(firstSlice.image)
                    let stitched = try ScrollingCaptureCoordinator.shared.finishSession()
                    self.handleCaptureSuccess(stitched)
                } catch let error as CaptureError {
                    self.handleCaptureFailure(error)
                } catch {
                    self.handleCaptureFailure(.captureFailed(error.localizedDescription))
                }
            }

        default:
            Task {
                do {
                    let content = try await ScreenCaptureEngine.shared.capture(target: .fullscreen(displayID: nil))
                    self.handleCaptureSuccess(content)
                } catch let error as CaptureError {
                    self.handleCaptureFailure(error)
                } catch {
                    self.handleCaptureFailure(.captureFailed(error.localizedDescription))
                }
            }
        }
    }

    private func presentAreaSelectionOverlay() {
        let overlay = AreaSelectionOverlayWindowController(screen: NSScreen.main ?? NSScreen.screens[0])
        overlay.delegate = self
        self.activeOverlay = overlay
        overlay.present()
    }

    // MARK: - AreaSelectionOverlayDelegate

    public func areaSelectionDidSelectRect(_ rect: CGRect, on displayID: CGDirectDisplayID) {
        activeOverlay = nil
        Task {
            do {
                let item = try await ScreenCaptureEngine.shared.capture(target: .area(rect: rect, displayID: displayID))
                self.handleCaptureSuccess(item)
            } catch let error as CaptureError {
                self.handleCaptureFailure(error)
            } catch {
                self.handleCaptureFailure(.captureFailed(error.localizedDescription))
            }
        }
    }

    public func areaSelectionDidCancel() {
        activeOverlay = nil
        completionHandler?(.failure(.captureFailed("User canceled area selection")))
        completionHandler = nil
    }

    private func handleCaptureSuccess(_ item: CapturedImageItem) {
        // 1. Copy to clipboard
        CaptureExportManager.shared.copyToPasteboard(item.image)

        // 2. Save to ~/Pictures/Screenshots
        let savedURL = try? CaptureExportManager.shared.saveToDisk(item.image, format: .png)

        // 3. Present floating HUD
        CapturePreviewHUD.shared.present(image: item.image, fileURL: savedURL)

        completionHandler?(.success(item))
        completionHandler = nil
    }

    private func handleCaptureFailure(_ error: CaptureError) {
        completionHandler?(.failure(error))
        completionHandler = nil
    }
}
