import Foundation
import Combine

@MainActor
public final class CleanerManager: ObservableObject {
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var progress: Double = 0.0
    @Published public private(set) var currentCategory: CleanCategory? = nil
    @Published public private(set) var lastManifest: CleanerScanManifest? = nil
    @Published public var selectedCategories: Set<CleanCategory> = Set(CleanCategory.allCases)
    @Published public private(set) var scanError: String? = nil

    private let scanner: CleanerScannerProvider
    private var scanTask: Task<Void, Never>?

    public init(scanner: CleanerScannerProvider = NativeCleanerScannerProvider()) {
        self.scanner = scanner
    }

    public func toggleCategory(_ category: CleanCategory) {
        if selectedCategories.contains(category) {
            if selectedCategories.count > 1 {
                selectedCategories.remove(category)
            }
        } else {
            selectedCategories.insert(category)
        }
    }

    public func startScan() {
        guard !isScanning else { return }
        isScanning = true
        progress = 0.0
        scanError = nil
        currentCategory = nil

        let categoriesToScan = selectedCategories

        scanTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let manifest = try await self.scanner.scan(categories: categoriesToScan) { pct, cat in
                    Task { @MainActor [weak self] in
                        self?.progress = pct
                        self?.currentCategory = cat
                    }
                }
                self.lastManifest = manifest
                self.progress = 1.0
                self.isScanning = false
                self.currentCategory = nil
            } catch is CancellationError {
                self.isScanning = false
                self.currentCategory = nil
                self.scanError = "Scan cancelled"
            } catch {
                self.isScanning = false
                self.currentCategory = nil
                self.scanError = error.localizedDescription
            }
        }
    }

    public func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        currentCategory = nil
        scanError = "Scan cancelled by user"
    }

    /// Strict Security Invariant (MZ-029 Gate):
    /// Cleanup execution (mutating or deleting files) is strictly blocked in this release.
    public func requestCleanupExecution() -> CommandResult {
        CommandResult.failure(
            errorCode: "GATE_MZ_029",
            message: "Cleanup deletion execution is strictly blocked by MZ-029 security review. Maczy operates in 100% read-only scan mode."
        )
    }
}
