import SwiftUI

public enum CleanerSectionTab: String, CaseIterable, Identifiable {
    case cleaner = "Cleaner"
    case uninstall = "Uninstall"
    case optimize = "Optimize"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .cleaner: return "sparkles"
        case .uninstall: return "trash"
        case .optimize: return "gauge.with.needle"
        }
    }
}

public struct CleanerDetailView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var cleanerManager: CleanerManager
    @ObservedObject private var uninstallManager: UninstallManager
    @ObservedObject private var optimizerManager: OptimizerManager
    @State private var selectedTab: CleanerSectionTab = .cleaner

    // Cleanup confirmation state (MZ-029)
    @State private var showCleanupConfirmation: Bool = false
    @State private var cleanupErrorMessage: String? = nil

    // Uninstall confirmation state
    @State private var showUninstallConfirmation: Bool = false
    @State private var uninstallErrorAlert: String? = nil

    public init(appState: AppState) {
        self.appState = appState
        self._cleanerManager = ObservedObject(wrappedValue: appState.cleanerManager)
        self._uninstallManager = ObservedObject(wrappedValue: appState.uninstallManager)
        self._optimizerManager = ObservedObject(wrappedValue: appState.optimizerManager)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Section Switcher matching OpenDesign
            HStack(spacing: 8) {
                ForEach(CleanerSectionTab.allCases) { tab in
                    Button(action: {
                        selectedTab = tab
                        if tab == .uninstall && uninstallManager.installedApps.isEmpty {
                            uninstallManager.scanInstalledApps()
                        } else if tab == .optimize {
                            optimizerManager.refreshMetrics()
                            optimizerManager.loadStartupItems()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: selectedTab == tab ? .bold : .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(selectedTab == tab ? MaczyDesignTokens.brandPurple : Color(NSColor.controlBackgroundColor))
                        .foregroundColor(selectedTab == tab ? .white : .primary)
                        .cornerRadius(6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            // Main Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch selectedTab {
                    case .cleaner:
                        cleanerContent
                    case .uninstall:
                        uninstallContent
                    case .optimize:
                        optimizeContent
                    }
                }
                .padding(18)
            }
        }
        .sheet(isPresented: $showCleanupConfirmation) {
            if let manifest = cleanerManager.lastManifest {
                cleanupConfirmationSheet(manifest: manifest)
            }
        }
        .sheet(isPresented: $showUninstallConfirmation) {
            if let manifest = uninstallManager.pendingUninstallManifest {
                uninstallConfirmationSheet(manifest: manifest)
            }
        }
        .onAppear {
            if selectedTab == .uninstall && uninstallManager.installedApps.isEmpty {
                uninstallManager.scanInstalledApps()
            }
        }
    }

    // MARK: - 1. Cleaner Tab (Preserved MZ-028)
    private var cleanerContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 26))
                    .foregroundColor(MaczyDesignTokens.brandLavender)

                VStack(alignment: .leading, spacing: 3) {
                    Text("System Cleaner & Cache Analyzer")
                        .font(.system(size: 18, weight: .bold))

                    Text("Safe, read-only cache and developer artifact scanner (MZ-028)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundColor(MaczyDesignTokens.statusGreen)
                    Text("READ-ONLY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(MaczyDesignTokens.statusGreen)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(MaczyDesignTokens.statusGreen.opacity(0.12))
                .cornerRadius(6)
            }

            // 4-step workflow indicator
            HStack(spacing: 12) {
                StepBadge(index: 1, title: "Scan", active: cleanerManager.lastManifest == nil && !cleanerManager.isScanning)
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.secondary)
                StepBadge(index: 2, title: "Review", active: cleanerManager.lastManifest != nil && !showCleanupConfirmation && !cleanerManager.isCleaning)
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.secondary)
                StepBadge(index: 3, title: "Confirm", active: showCleanupConfirmation)
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.secondary)
                StepBadge(index: 4, title: "Clean (MZ-029)", active: cleanerManager.isCleaning || cleanerManager.lastCleanupResult != nil)
            }

            // Cleanup Execution Result Toast (MZ-029)
            if let result = cleanerManager.lastCleanupResult {
                HStack(spacing: 8) {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(result.success ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.message)
                            .font(.system(size: 11, weight: .semibold))
                        Text("All items were safely moved to macOS Trash and can be restored at any time.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(MaczyDesignTokens.statusGreen.opacity(0.12))
                .cornerRadius(8)
            }

            // Active Hero Card
            VStack(alignment: .leading, spacing: 12) {
                if cleanerManager.isScanning {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Scanning System...")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Text(String(format: "%.0f%%", cleanerManager.progress * 100))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(MaczyDesignTokens.brandPurple)
                        }

                        ProgressView(value: cleanerManager.progress, total: 1.0)
                            .tint(MaczyDesignTokens.brandPurple)

                        if let current = cleanerManager.currentCategory {
                            Text("Analyzing \(current.displayName)...")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Spacer()
                            Button("Cancel Scan") {
                                _ = appState.dispatch(.cancelCleanerScan)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                } else if let manifest = cleanerManager.lastManifest {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TOTAL RECLAIMABLE SPACE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)

                            Text(manifest.formattedReclaimableSize)
                                .font(.system(size: 30, weight: .heavy, design: .monospaced))
                                .foregroundColor(MaczyDesignTokens.brandLavender)

                            Text("\(manifest.items.count) cache items found across \(manifest.categoryBreakdown.count) categories")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Button(action: {
                                _ = appState.dispatch(.startCleanerScan)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Rescan")
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)

                            Button(action: {
                                showCleanupConfirmation = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash.fill")
                                    Text("Clean Caches to Trash…")
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(MaczyDesignTokens.brandPurple)
                        }
                    }
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ready to Scan")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Scans safely in read-only mode. Documents, repositories, and databases are strictly excluded.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            _ = appState.dispatch(.startCleanerScan)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                Text("Start Safe Scan")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MaczyDesignTokens.brandPurple)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
            .cornerRadius(10)

            // Category Selector Grid
            VStack(alignment: .leading, spacing: 8) {
                Text("Target Categories")
                    .font(.system(size: 12, weight: .semibold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(CleanCategory.allCases) { category in
                        categoryToggleCard(category)
                    }
                }
            }

            // Results Review
            if let manifest = cleanerManager.lastManifest {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Category Breakdown")
                        .font(.system(size: 12, weight: .semibold))

                    VStack(spacing: 6) {
                        ForEach(Array(manifest.categoryBreakdown.keys), id: \.self) { cat in
                            let bytes = manifest.categoryBreakdown[cat] ?? 0
                            let count = manifest.categoryCounts[cat] ?? 0
                            HStack {
                                Image(systemName: cat.icon)
                                    .foregroundColor(MaczyDesignTokens.brandPurple)
                                    .frame(width: 18)
                                Text(cat.displayName)
                                    .font(.system(size: 11, weight: .semibold))
                                Text("(\(count) items)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                            }
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                            .cornerRadius(6)
                        }
                    }
                }
            }

            // MZ-029 Security Gate & Reversibility Guarantee
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 12))
                        .foregroundColor(MaczyDesignTokens.statusGreen)
                    Text("Safe Trash Workflow (MZ-029)")
                        .font(.system(size: 12, weight: .semibold))
                }

                Text("Cache cleaning moves files to macOS Trash with explicit confirmation, preserving full user reversibility. Documents, git repositories, personal files, and databases are strictly protected.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
        }
    }

    private func categoryToggleCard(_ category: CleanCategory) -> some View {
        let isSelected = cleanerManager.selectedCategories.contains(category)
        return Button(action: {
            cleanerManager.toggleCategory(category)
        }) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? MaczyDesignTokens.brandPurple : .secondary)

                Image(systemName: category.icon)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .primary : .secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(category.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isSelected ? .primary : .secondary)
                }

                Spacer()
            }
            .padding(8)
            .background(isSelected ? MaczyDesignTokens.brandPurple.opacity(0.08) : Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? MaczyDesignTokens.brandPurple.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2. Uninstall Tab (Smart Uninstaller)
    private var uninstallContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(MaczyDesignTokens.statusRed)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Smart Application Uninstaller")
                        .font(.system(size: 18, weight: .bold))

                    Text("Identifies application bundles and associated leftovers for safe removal to Trash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    uninstallManager.scanInstalledApps()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Refresh Apps")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.bordered)
            }

            // Search and Sort Bar
            HStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    TextField("Search applications...", text: Binding(
                        get: { uninstallManager.searchQuery },
                        set: { uninstallManager.searchQuery = $0 }
                    ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .cornerRadius(6)

                Picker("Sort", selection: Binding(
                    get: { uninstallManager.sortBy },
                    set: { uninstallManager.sortBy = $0 }
                )) {
                    ForEach(AppSortOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }

            // Split Layout: App List & Leftovers Detail
            HStack(alignment: .top, spacing: 14) {
                // Left Column: Installed Apps List
                VStack(alignment: .leading, spacing: 6) {
                    Text("Installed Applications (\(uninstallManager.filteredApps.count))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    if uninstallManager.isScanningApps {
                        HStack {
                            Spacer()
                            ProgressView("Scanning Applications...")
                                .controlSize(.small)
                            Spacer()
                        }
                        .padding(.vertical, 40)
                    } else if uninstallManager.filteredApps.isEmpty {
                        Text("No applications found.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 20)
                    } else {
                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(uninstallManager.filteredApps) { app in
                                    appRow(app)
                                }
                            }
                        }
                        .frame(maxHeight: 400)
                    }
                }
                .frame(minWidth: 260, maxWidth: 320)

                // Right Column: Detail Inspector & Leftover List
                VStack(alignment: .leading, spacing: 12) {
                    if let app = uninstallManager.selectedApp {
                        appDetailCard(app)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "hand.tap")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                            Text("Select an application from the left to analyze leftovers.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 240)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                        .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Operation history message if any
            if let result = uninstallManager.lastUninstallResult {
                HStack(spacing: 8) {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(result.success ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusRed)
                    Text(result.message)
                        .font(.system(size: 11))
                    Spacer()
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(6)
            }
        }
    }

    private func appRow(_ app: InstalledApp) -> some View {
        let isSelected = uninstallManager.selectedApp?.id == app.id
        return Button(action: {
            uninstallManager.selectApp(app)
        }) {
            HStack(spacing: 8) {
                Image(systemName: "app.fill")
                    .font(.system(size: 16))
                    .foregroundColor(app.isSystemApp ? .secondary : MaczyDesignTokens.brandPurple)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(app.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .primary)
                            .lineLimit(1)

                        if app.isRunning {
                            Circle()
                                .fill(MaczyDesignTokens.statusGreen)
                                .frame(width: 5, height: 5)
                        }
                    }

                    Text(app.formattedBundleSize)
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }

                Spacer()

                if app.isSystemApp {
                    Text("System")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(3)
                }
            }
            .padding(6)
            .background(isSelected ? MaczyDesignTokens.brandPurple : Color(NSColor.controlBackgroundColor).opacity(0.4))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func appDetailCard(_ app: InstalledApp) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // App Hero Info
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "app.fill")
                    .font(.system(size: 28))
                    .foregroundColor(app.isSystemApp ? .secondary : MaczyDesignTokens.brandPurple)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 15, weight: .bold))

                    if let bid = app.bundleIdentifier {
                        Text(bid)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        Text("v\(app.version)")
                            .font(.system(size: 10))
                        if let pub = app.publisher {
                            Text("• \(pub)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(app.formattedBundleSize)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))

                    if app.isSystemApp {
                        Text("Protected System App")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(MaczyDesignTokens.statusOrange)
                    } else if app.isRunning {
                        Text("Currently Running")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(MaczyDesignTokens.statusRed)
                    }
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(8)

            // Associated Leftovers List
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Associated Leftovers")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    if uninstallManager.isAnalyzingLeftovers {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("\(uninstallManager.selectedAppLeftovers.count) items")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                if uninstallManager.selectedAppLeftovers.isEmpty && !uninstallManager.isAnalyzingLeftovers {
                    Text("No associated leftover files detected in standard Library directories.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(uninstallManager.selectedAppLeftovers) { item in
                                leftoverRow(item)
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
            }

            Divider()

            // Uninstall Action Footer
            HStack {
                let totalFreed = app.bundleSizeBytes + uninstallManager.selectedAppLeftovers.filter { $0.isSelected }.reduce(0) { $0 + $1.fileSizeBytes }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Space to Reclaim")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: totalFreed, countStyle: .file))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(MaczyDesignTokens.statusRed)
                }

                Spacer()

                Button(action: {
                    uninstallManager.prepareUninstallManifest()
                    showUninstallConfirmation = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                        Text("Uninstall to Trash…")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(MaczyDesignTokens.statusRed)
                .disabled(app.isSystemApp || app.isRunning)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    private func leftoverRow(_ item: AppLeftoverItem) -> some View {
        HStack(spacing: 8) {
            Button(action: {
                uninstallManager.toggleLeftoverSelection(id: item.id)
            }) {
                Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(item.safety == .protected ? .secondary : MaczyDesignTokens.brandPurple)
            }
            .buttonStyle(.plain)
            .disabled(item.safety == .protected)

            Image(systemName: item.locationType.icon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Text(item.locationType.rawValue)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(item.formattedSize)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(5)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(4)
    }

    private func cleanupConfirmationSheet(manifest: CleanerScanManifest) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Confirm Cache Cleanup (MZ-029)")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button("Cancel") {
                    showCleanupConfirmation = false
                }
                .buttonStyle(.bordered)
            }

            Text("The following \(manifest.items.count) cache items (\(manifest.formattedReclaimableSize)) will be safely moved to macOS Trash:")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(manifest.categoryBreakdown.keys), id: \.self) { cat in
                        let bytes = manifest.categoryBreakdown[cat] ?? 0
                        let count = manifest.categoryCounts[cat] ?? 0
                        HStack {
                            Image(systemName: cat.icon)
                                .foregroundColor(MaczyDesignTokens.brandPurple)
                                .frame(width: 18)
                            Text(cat.displayName)
                                .font(.system(size: 11, weight: .semibold))
                            Text("(\(count) items)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .padding(6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                    }
                }
            }
            .frame(maxHeight: 180)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total to Trash: \(manifest.formattedReclaimableSize)")
                        .font(.system(size: 12, weight: .bold))
                    Text("Reversible: files can be restored anytime from macOS Trash. Documents, git repos, and databases are strictly excluded.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    cleanerManager.isCleanupApproved = true
                    showCleanupConfirmation = false
                    _ = appState.dispatch(.executeCleanerPurge(confirmed: true))
                }) {
                    HStack(spacing: 6) {
                        if cleanerManager.isCleaning {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "trash.fill")
                        }
                        Text("Confirm & Move to Trash")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(MaczyDesignTokens.brandPurple)
                .disabled(cleanerManager.isCleaning)
            }

            if let err = cleanupErrorMessage {
                Text(err)
                    .font(.system(size: 10))
                    .foregroundColor(MaczyDesignTokens.statusRed)
            }
        }
        .padding(18)
        .frame(width: 480)
    }

    private func uninstallConfirmationSheet(manifest: UninstallManifest) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Confirm Application Removal")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button("Cancel") {
                    showUninstallConfirmation = false
                    uninstallManager.dismissManifest()
                }
                .buttonStyle(.bordered)
            }

            Text("The following items for \(manifest.app.name) will be safely moved to macOS Trash:")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "app.fill")
                        Text(manifest.app.bundleURL.path)
                            .font(.system(size: 10, design: .monospaced))
                        Spacer()
                        Text(manifest.app.formattedBundleSize)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)

                    ForEach(manifest.selectedLeftovers) { item in
                        HStack {
                            Image(systemName: item.locationType.icon)
                            Text(item.path)
                                .font(.system(size: 10, design: .monospaced))
                                .lineLimit(1)
                            Spacer()
                            Text(item.formattedSize)
                                .font(.system(size: 10))
                        }
                        .padding(6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                    }
                }
            }
            .frame(maxHeight: 200)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total to Trash: \(manifest.formattedTotalSize)")
                        .font(.system(size: 12, weight: .bold))
                    Text("You can restore these files anytime from the macOS Trash.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Move to Trash") {
                    do {
                        _ = try uninstallManager.confirmUninstallToTrash()
                        showUninstallConfirmation = false
                    } catch {
                        uninstallErrorAlert = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(MaczyDesignTokens.statusRed)
            }
        }
        .padding(18)
        .frame(width: 480)
    }

    // MARK: - 3. Optimize Tab (Safe macOS Optimization)
    private var optimizeContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "gauge.with.needle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(MaczyDesignTokens.brandPurple)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Safe System Optimization")
                        .font(.system(size: 18, weight: .bold))

                    Text("Measurable maintenance, developer cache tuning, and live system monitoring")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    optimizerManager.refreshMetrics()
                    optimizerManager.loadStartupItems()
                    optimizerManager.scanDeveloperArtifacts()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Refresh Telemetry")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.bordered)
            }

            // Top Telemetry Metrics Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricTile(
                    title: "CPU LOAD",
                    value: String(format: "%.1f%%", optimizerManager.systemMetrics.cpuUsagePercent),
                    detail: "Active",
                    icon: "cpu"
                )

                metricTile(
                    title: "MEMORY",
                    value: String(format: "%.0f%%", optimizerManager.systemMetrics.memoryPressurePercent),
                    detail: optimizerManager.systemMetrics.formattedMemory,
                    icon: "memorychip"
                )

                metricTile(
                    title: "DISK FREE",
                    value: optimizerManager.systemMetrics.formattedDiskFree,
                    detail: "Available storage",
                    icon: "internaldrive"
                )

                metricTile(
                    title: "RUNNING APPS",
                    value: "\(optimizerManager.systemMetrics.heavyAppsCount)",
                    detail: "Foreground apps",
                    icon: "app.badge"
                )
            }

            // Two-column Maintenance Workspace matching OpenDesign
            HStack(alignment: .top, spacing: 14) {
                // Left Column: Actions List
                VStack(alignment: .leading, spacing: 6) {
                    Text("Maintenance Actions")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    VStack(spacing: 4) {
                        ForEach(optimizerManager.maintenanceActions) { action in
                            actionRow(action)
                        }
                    }
                }
                .frame(minWidth: 260, maxWidth: 320)

                // Right Column: Action Inspector
                VStack(alignment: .leading, spacing: 12) {
                    if let action = optimizerManager.selectedAction {
                        actionInspector(action)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Developer Artifacts Quick Overview Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "hammer.fill")
                        .foregroundColor(MaczyDesignTokens.brandPurple)
                    Text("Developer Build Artifacts")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Button("Scan Developer Caches") {
                        optimizerManager.scanDeveloperArtifacts()
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.borderless)
                }

                if optimizerManager.developerArtifacts.isEmpty {
                    Text("Xcode DerivedData, Cargo caches, and npm packages will appear here when scanned.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 4) {
                        ForEach(optimizerManager.developerArtifacts) { item in
                            HStack {
                                Image(systemName: item.category.icon)
                                    .frame(width: 16)
                                Text(item.name)
                                    .font(.system(size: 11))
                                Spacer()
                                Text(item.formattedSize)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                            }
                            .padding(6)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                            .cornerRadius(4)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)

            // OpenDesign Safety Guarantee
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 12))
                        .foregroundColor(MaczyDesignTokens.statusGreen)
                    Text("Evidence-First macOS Maintenance")
                        .font(.system(size: 12, weight: .semibold))
                }

                Text("No fake RAM boosters or speculative speed tweaks. Every action documents its exact change, expected effect, risk level, and reversibility prior to execution.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
        }
    }

    private func metricTile(title: String, value: String, detail: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(MaczyDesignTokens.brandPurple)
            }
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
            Text(detail)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(8)
    }

    private func actionRow(_ action: MaintenanceAction) -> some View {
        let isSelected = optimizerManager.selectedAction?.id == action.id
        return Button(action: {
            optimizerManager.selectAction(action)
        }) {
            HStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? .white : MaczyDesignTokens.brandPurple)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(action.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                    Text(action.category)
                        .font(.system(size: 9))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }

                Spacer()

                Text(action.riskLevel.rawValue)
                    .font(.system(size: 9))
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .padding(8)
            .background(isSelected ? MaczyDesignTokens.brandPurple : Color(NSColor.controlBackgroundColor).opacity(0.4))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func actionInspector(_ action: MaintenanceAction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Inspector Hero
            HStack(spacing: 10) {
                Image(systemName: action.icon)
                    .font(.system(size: 22))
                    .foregroundColor(MaczyDesignTokens.brandPurple)

                VStack(alignment: .leading, spacing: 1) {
                    Text(action.title)
                        .font(.system(size: 14, weight: .bold))
                    Text(action.category)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(action.riskLevel.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(action.riskLevel == .low ? MaczyDesignTokens.statusGreen : MaczyDesignTokens.statusOrange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(8)

            // Inspector Detail List
            VStack(alignment: .leading, spacing: 8) {
                inspectorItem(label: "What changes", detail: action.whatChanges)
                Divider()
                inspectorItem(label: "Expected effect", detail: action.expectedEffect)
                Divider()
                inspectorItem(label: "Reversibility", detail: action.reversible)
                Divider()
                inspectorItem(label: "Potential impact", detail: action.potentialImpact)
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
            .cornerRadius(8)

            // Result if executed
            if let result = optimizerManager.lastActionResult {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(MaczyDesignTokens.statusGreen)
                    Text(result)
                        .font(.system(size: 11))
                }
                .padding(8)
                .background(MaczyDesignTokens.statusGreen.opacity(0.1))
                .cornerRadius(6)
            }

            // Action Trigger
            HStack {
                Spacer()
                Button(action: {
                    Task {
                        await optimizerManager.executeSelectedAction()
                    }
                }) {
                    HStack(spacing: 6) {
                        if optimizerManager.isExecutingAction {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: action.id == .loginItemsReview ? "gearshape" : "play.fill")
                        }
                        Text(action.id == .loginItemsReview ? "Open System Settings…" : "Run Maintenance Action")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(MaczyDesignTokens.brandPurple)
                .disabled(optimizerManager.isExecutingAction)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    private func inspectorItem(label: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
            Text(detail)
                .font(.system(size: 11))
                .lineSpacing(2)
        }
    }
}

public struct StepBadge: View {
    public let index: Int
    public let title: String
    public let active: Bool

    public init(index: Int, title: String, active: Bool) {
        self.index = index
        self.title = title
        self.active = active
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text("\(index)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(active ? .white : .secondary)
                .frame(width: 16, height: 16)
                .background(active ? MaczyDesignTokens.brandPurple : Color.secondary.opacity(0.2))
                .clipShape(Circle())
            Text(title)
                .font(.system(size: 11, weight: active ? .semibold : .regular))
                .foregroundColor(active ? MaczyDesignTokens.brandPurple : .secondary)
        }
    }
}
