import Foundation
import AppKit
import CoreGraphics

/// Coordinates interactive and programmatic screen capture flows, export, and preview presentation.
@MainActor
public final class CaptureCoordinator: NSObject, AreaSelectionOverlayDelegate {
    public static let shared = CaptureCoordinator()

    private var activeOverlay: AreaSelectionOverlayWindowController?
    private var completionHandler: ((Result<CapturedImageItem, CaptureError>) -> Void)?
    private var activeSelectionPurpose: AreaSelectionPurpose = .captureArea

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
            activeSelectionPurpose = .captureArea
            presentAreaSelectionOverlay(purpose: .captureArea)

        case "scrolling":
            activeSelectionPurpose = .scrollingCapture
            presentAreaSelectionOverlay(purpose: .scrollingCapture)

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

    private func presentAreaSelectionOverlay(purpose: AreaSelectionPurpose) {
        let overlay = AreaSelectionOverlayWindowController(
            screen: NSScreen.main ?? NSScreen.screens[0],
            purpose: purpose
        )
        overlay.delegate = self
        self.activeOverlay = overlay
        overlay.present()
    }

    // MARK: - AreaSelectionOverlayDelegate

    public func areaSelectionDidSelectRect(_ rect: CGRect, on displayID: CGDirectDisplayID) {
        activeOverlay = nil

        if activeSelectionPurpose == .scrollingCapture {
            Task {
                await ScrollingCaptureCoordinator.shared.startInteractiveSession(
                    rect: rect,
                    displayID: displayID,
                    completion: { [weak self] result in
                        switch result {
                        case .success(let item):
                            self?.handleCaptureSuccess(item)
                        case .failure(let error):
                            self?.handleCaptureFailure(error)
                        }
                    }
                )
            }
        } else {
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
