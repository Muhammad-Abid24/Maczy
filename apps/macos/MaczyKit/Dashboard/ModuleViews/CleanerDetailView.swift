import SwiftUI

public struct CleanerDetailView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    private var cleanerManager: CleanerManager {
        appState.cleanerManager
    }

    public var body: some View {
        ScrollView {
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
                    StepBadge(index: 1, title: "Scan", active: cleanerManager.lastManifest == nil)
                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.secondary)
                    StepBadge(index: 2, title: "Review", active: cleanerManager.lastManifest != nil)
                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.secondary)
                    StepBadge(index: 3, title: "Confirm (Gated)", active: false)
                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.secondary)
                    StepBadge(index: 4, title: "Clean (MZ-029)", active: false)
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

                            Button(action: {
                                _ = appState.dispatch(.startCleanerScan)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Rescan")
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(MaczyDesignTokens.brandPurple)
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

                // Scanned Results Review (if manifest present)
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

                // MZ-029 Security Gate Notice
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 12))
                            .foregroundColor(MaczyDesignTokens.statusOrange)
                        Text("Safety Gate: Deletion Execution (MZ-029)")
                            .font(.system(size: 12, weight: .semibold))
                    }

                    Text("File mutation, cleaning, and deletion execution remain strictly blocked pending Product Owner release approval and disposable fixture tests. Maczy guarantees zero inadvertent data loss.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            }
            .padding(18)
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
        }
        .buttonStyle(.plain)
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
