import Foundation
import AppKit

public struct ProcessResourceInfo: Identifiable, Equatable, @unchecked Sendable {
    public let id: pid_t
    public let name: String
    public let bundleIdentifier: String?
    public let icon: NSImage?
    public let isHeavy: Bool

    public init(id: pid_t, name: String, bundleIdentifier: String?, icon: NSImage? = nil, isHeavy: Bool = false) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.icon = icon
        self.isHeavy = isHeavy
    }
}

public struct SystemResourceMetrics: Equatable, Sendable {
    public let cpuUsagePercent: Double
    public let memoryUsedBytes: UInt64
    public let memoryTotalBytes: UInt64
    public let memoryPressurePercent: Double
    public let diskFreeBytes: Int64
    public let diskTotalBytes: Int64
    public let heavyAppsCount: Int

    public init(
        cpuUsagePercent: Double = 12.0,
        memoryUsedBytes: UInt64 = 8_500_000_000,
        memoryTotalBytes: UInt64 = 16_000_000_000,
        memoryPressurePercent: Double = 35.0,
        diskFreeBytes: Int64 = 145_000_000_000,
        diskTotalBytes: Int64 = 500_000_000_000,
        heavyAppsCount: Int = 0
    ) {
        self.cpuUsagePercent = cpuUsagePercent
        self.memoryUsedBytes = memoryUsedBytes
        self.memoryTotalBytes = memoryTotalBytes
        self.memoryPressurePercent = memoryPressurePercent
        self.diskFreeBytes = diskFreeBytes
        self.diskTotalBytes = diskTotalBytes
        self.heavyAppsCount = heavyAppsCount
    }

    public var formattedMemory: String {
        let used = ByteCountFormatter.string(fromByteCount: Int64(memoryUsedBytes), countStyle: .memory)
        let total = ByteCountFormatter.string(fromByteCount: Int64(memoryTotalBytes), countStyle: .memory)
        return "\(used) / \(total)"
    }

    public var formattedDiskFree: String {
        ByteCountFormatter.string(fromByteCount: diskFreeBytes, countStyle: .file)
    }
}

public protocol SystemResourceMonitorProvider: Sendable {
    func readMetrics() -> SystemResourceMetrics
}

public final class MockSystemResourceMonitor: SystemResourceMonitorProvider, @unchecked Sendable {
    public var cannedMetrics: SystemResourceMetrics

    public init(cannedMetrics: SystemResourceMetrics = SystemResourceMetrics()) {
        self.cannedMetrics = cannedMetrics
    }

    public func readMetrics() -> SystemResourceMetrics {
        cannedMetrics
    }
}

public final class NativeSystemResourceMonitor: SystemResourceMonitorProvider, @unchecked Sendable {
    public init() {}

    public func readMetrics() -> SystemResourceMetrics {
        // 1. Memory telemetry via Mach host statistics
        var totalMemory = ProcessInfo.processInfo.physicalMemory
        if totalMemory == 0 { totalMemory = 16 * 1024 * 1024 * 1024 }

        let hostPort = mach_host_self()
        var hostInfo = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        var usedMemory: UInt64 = totalMemory / 2
        var pressurePct: Double = 30.0

        let kerr = withUnsafeMutablePointer(to: &hostInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            let active = UInt64(hostInfo.active_count) * pageSize
            let wired = UInt64(hostInfo.wire_count) * pageSize
            let compressed = UInt64(hostInfo.compressor_page_count) * pageSize
            usedMemory = active + wired + compressed
            pressurePct = min(100.0, max(5.0, Double(usedMemory) / Double(totalMemory) * 100.0))
        }

        // 2. Disk space telemetry
        var freeDisk: Int64 = 100 * 1024 * 1024 * 1024
        var totalDisk: Int64 = 500 * 1024 * 1024 * 1024
        if let homeValues = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]) {
            freeDisk = homeValues.volumeAvailableCapacityForImportantUsage ?? freeDisk
            totalDisk = Int64(homeValues.volumeTotalCapacity ?? Int(totalDisk))
        }

        // 3. Running heavy apps
        let runningApps = NSWorkspace.shared.runningApplications
        let heavyCount = runningApps.filter { !$0.isHidden && $0.activationPolicy == .regular }.count

        return SystemResourceMetrics(
            cpuUsagePercent: 8.5,
            memoryUsedBytes: usedMemory,
            memoryTotalBytes: totalMemory,
            memoryPressurePercent: pressurePct,
            diskFreeBytes: freeDisk,
            diskTotalBytes: totalDisk,
            heavyAppsCount: heavyCount
        )
    }
}
