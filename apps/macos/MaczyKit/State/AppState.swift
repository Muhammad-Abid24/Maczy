import Foundation
import SwiftUI
import Combine

/// Observable application state driving Dashboard and Menu Bar surfaces.
@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var selectedModule: MaczyModuleId = .captureAndRecording
    @Published public var modules: [ModuleStatus] = []
    @Published public var isSidebarExpanded: Bool = false

    private init() {
        self.modules = MaczyCoreBridge.shared.fetchAllModuleStatuses()
    }

    public func status(for id: MaczyModuleId) -> ModuleStatus? {
        modules.first { $0.id == id }
    }
}
