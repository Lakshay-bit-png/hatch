import Foundation
import Darwin
import IOKit
import IOKit.ps
import Observation

/// Live machine vitals, sampled straight from the kernel — no shelling out.
@Observable
@MainActor
final class SystemMonitor {
    static let shared = SystemMonitor()

    struct VolumeInfo: Identifiable {
        let id: String
        let name: String
        let total: Int64
        let free: Int64
        var used: Int64 { max(0, total - free) }
        var fraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
    }

    struct BatteryInfo {
        var percentage: Int
        var isCharging: Bool
        var isPlugged: Bool
        var cycleCount: Int?
        var health: Int?
        var minutesRemaining: Int?
    }

    private(set) var cpuUsage: Double = 0
    private(set) var cpuHistory: [Double] = []
    private(set) var memoryUsed: UInt64 = 0
    private(set) var memoryTotal: UInt64 = 0
    private(set) var memoryHistory: [Double] = []
    private(set) var volumes: [VolumeInfo] = []
    private(set) var battery: BatteryInfo?

    /// How many samples the sparkline keeps.
    private let historyLength = 48

    private var ticker: Timer?
    private var previousCPU: host_cpu_load_info?
    private var volumeCountdown = 0

    var memoryFraction: Double {
        memoryTotal > 0 ? Double(memoryUsed) / Double(memoryTotal) : 0
    }

    var coreCount: Int { ProcessInfo.processInfo.processorCount }

    var uptimeText: String {
        let seconds = Int(ProcessInfo.processInfo.systemUptime)
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private init() {}

    // MARK: - Lifecycle

    /// Sampling only runs while the page is on screen, so the app stays idle otherwise.
    func start() {
        guard ticker == nil else { return }
        sample()
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
        previousCPU = nil
    }

    private func sample() {
        sampleCPU()
        sampleMemory()
        sampleBattery()

        // Disks change slowly — refresh every 10th pass.
        if volumeCountdown <= 0 {
            sampleVolumes()
            volumeCountdown = 10
        }
        volumeCountdown -= 1

        cpuHistory.append(cpuUsage)
        memoryHistory.append(memoryFraction)
        if cpuHistory.count > historyLength { cpuHistory.removeFirst() }
        if memoryHistory.count > historyLength { memoryHistory.removeFirst() }
    }

    // MARK: - CPU

    private func sampleCPU() {
        var info = host_cpu_load_info()
        var size = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size
        )

        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard status == KERN_SUCCESS else { return }

        if let previous = previousCPU {
            let user = Double(info.cpu_ticks.0 &- previous.cpu_ticks.0)
            let system = Double(info.cpu_ticks.1 &- previous.cpu_ticks.1)
            let idle = Double(info.cpu_ticks.2 &- previous.cpu_ticks.2)
            let nice = Double(info.cpu_ticks.3 &- previous.cpu_ticks.3)
            let total = user + system + idle + nice
            if total > 0 {
                cpuUsage = min(1, max(0, (user + system + nice) / total))
            }
        }
        previousCPU = info
    }

    // MARK: - Memory

    private func sampleMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )

        let status = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return }

        let page = UInt64(vm_kernel_page_size)
        // Matches Activity Monitor's "Memory Used": active + wired + compressed.
        let active = UInt64(stats.active_count) * page
        let wired = UInt64(stats.wire_count) * page
        let compressed = UInt64(stats.compressor_page_count) * page

        memoryUsed = active + wired + compressed
        memoryTotal = ProcessInfo.processInfo.physicalMemory
    }

    // MARK: - Disks

    private func sampleVolumes() {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeIsBrowsableKey,
            .volumeIsLocalKey
        ]

        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else { return }

        var found: [VolumeInfo] = []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.volumeIsBrowsable == true,
                  values.volumeIsLocal == true,
                  let total = values.volumeTotalCapacity, total > 0
            else { continue }

            let free = values.volumeAvailableCapacityForImportantUsage ?? 0
            found.append(
                VolumeInfo(
                    id: url.path,
                    name: values.volumeName ?? url.lastPathComponent,
                    total: Int64(total),
                    free: free
                )
            )
        }
        volumes = found.sorted { $0.total > $1.total }
    }

    // MARK: - Battery

    private func sampleBattery() {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let description = IOPSGetPowerSourceDescription(blob, first)?
                  .takeUnretainedValue() as? [String: Any]
        else {
            battery = nil
            return
        }

        let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maximum = description[kIOPSMaxCapacityKey] as? Int ?? 100
        let charging = description[kIOPSIsChargingKey] as? Bool ?? false
        let state = description[kIOPSPowerSourceStateKey] as? String
        let minutes = description[kIOPSTimeToEmptyKey] as? Int

        battery = BatteryInfo(
            percentage: maximum > 0 ? Int((Double(current) / Double(maximum)) * 100) : 0,
            isCharging: charging,
            isPlugged: state == kIOPSACPowerValue,
            cycleCount: smartBatteryValue("CycleCount"),
            health: batteryHealth(),
            minutesRemaining: (minutes ?? -1) > 0 ? minutes : nil
        )
    }

    /// Reads a key out of the AppleSmartBattery IORegistry entry.
    private func smartBatteryValue(_ key: String) -> Int? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let value = IORegistryEntryCreateCFProperty(
            service, key as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? Int else { return nil }
        return value
    }

    /// Maximum capacity as a percentage of the original design capacity.
    private func batteryHealth() -> Int? {
        let design = smartBatteryValue("DesignCapacity")
        let maximum = smartBatteryValue("AppleRawMaxCapacity")
            ?? smartBatteryValue("NominalChargeCapacity")

        guard let design, let maximum, design > 0 else { return nil }
        return Int((Double(maximum) / Double(design)) * 100)
    }
}

enum ByteText {
    static func string(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func string(_ bytes: UInt64) -> String {
        string(Int64(clamping: bytes))
    }
}
