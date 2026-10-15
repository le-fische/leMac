import Foundation
import Darwin
import IOKit

public struct ProcessItem: Identifiable {
    public let id: Int // PID
    public let name: String
    public let cpuPercentage: Double
}

public class SystemMonitor {
    public static let shared = SystemMonitor()
    
    public private(set) var cpuTotalUsage: Double = 0.0
    public private(set) var cpuUserUsage: Double = 0.0
    public private(set) var cpuSystemUsage: Double = 0.0
    public private(set) var cpuIdleUsage: Double = 0.0
    public private(set) var perCoreUsage: [Double] = []
    
    public private(set) var gpuUsage: Double = 0.0
    public private(set) var gpuRendererUsage: Double = 0.0
    public private(set) var gpuTilerUsage: Double = 0.0
    public private(set) var gpuInUseMemoryBytes: UInt64 = 0
    public private(set) var gpuAllocatedMemoryBytes: UInt64 = 0
    
    public private(set) var ramUsedBytes: UInt64 = 0
    public private(set) var ramTotalBytes: UInt64 = 0
    public private(set) var ramUsagePercentage: Double = 0.0
    
    public private(set) var topProcesses: [ProcessItem] = []
    
    // Rolling history for graphics (up to 30 data points)
    public let maxHistorySamples: Int = 30
    public private(set) var cpuHistory: [Double] = []
    public private(set) var gpuHistory: [Double] = []
    
    // Mach state caches & timing protection
    private var prevHostCpuInfo: host_cpu_load_info?
    private var prevProcessorInfo: processor_info_array_t?
    private var prevProcessorInfoCount: mach_msg_type_number_t = 0
    
    private var lastCpuSampleTime: CFAbsoluteTime = 0
    private var lastPerCoreSampleTime: CFAbsoluteTime = 0
    private var lastGpuSampleTime: CFAbsoluteTime = 0
    private var lastHistoryPushTime: CFAbsoluteTime = 0
    private var lastProcessFetchTime: Date = .distantPast
    
    private init() {
        self.ramTotalBytes = ProcessInfo.processInfo.physicalMemory
        // Pre-fill history with zeroes so sparklines have full width from the start
        self.cpuHistory = Array(repeating: 0.0, count: maxHistorySamples)
        self.gpuHistory = Array(repeating: 0.0, count: maxHistorySamples)
        
        // Initial warmup sample
        _ = sampleHostCpu()
        _ = samplePerCoreCpu()
        updateGpu(force: true)
        updateRam()
    }
    
    deinit {
        if let prev = prevProcessorInfo {
            let prevSize = vm_size_t(prevProcessorInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), prevSize)
        }
    }
    
    /// Sample all system metrics
    public func update(includeProcesses: Bool = false) {
        let now = CFAbsoluteTimeGetCurrent()
        let shouldPushHistory = (now - lastHistoryPushTime >= 0.25)
        
        updateCpu(pushHistory: shouldPushHistory)
        updateGpu(force: false, pushHistory: shouldPushHistory)
        updateRam()
        
        if shouldPushHistory {
            lastHistoryPushTime = now
        }
        
        if includeProcesses {
            updateTopProcessesIfNeeded()
        }
    }
    
    // MARK: - CPU Sampling
    
    private func updateCpu(pushHistory: Bool = true) {
        let (total, user, sys, idle, hasNewData) = sampleHostCpu()
        
        if hasNewData {
            if self.cpuTotalUsage > 0 {
                // Gentle smoothing (75% new, 25% previous) prevents sudden 1-frame spikes or 0 dips
                self.cpuTotalUsage = (0.75 * total) + (0.25 * self.cpuTotalUsage)
            } else {
                self.cpuTotalUsage = total
            }
            self.cpuUserUsage = user
            self.cpuSystemUsage = sys
            self.cpuIdleUsage = idle
        }
        
        self.perCoreUsage = samplePerCoreCpu()
        
        if pushHistory && hasNewData {
            appendHistory(&cpuHistory, value: self.cpuTotalUsage)
        }
    }
    
    private func sampleHostCpu() -> (total: Double, user: Double, sys: Double, idle: Double, hasNewData: Bool) {
        let now = CFAbsoluteTimeGetCurrent()
        // If called rapidly (< 150ms), return cached usage without zeroing out
        if now - lastCpuSampleTime < 0.15 && lastCpuSampleTime > 0 {
            return (cpuTotalUsage, cpuUserUsage, cpuSystemUsage, cpuIdleUsage, false)
        }
        
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var cpuInfo = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else {
            return (cpuTotalUsage, cpuUserUsage, cpuSystemUsage, cpuIdleUsage, false)
        }
        
        guard let prev = prevHostCpuInfo else {
            prevHostCpuInfo = cpuInfo
            lastCpuSampleTime = now
            return (cpuTotalUsage, cpuUserUsage, cpuSystemUsage, cpuIdleUsage, false)
        }
        
        let userDelta = Double(cpuInfo.cpu_ticks.0 - prev.cpu_ticks.0)
        let sysDelta  = Double(cpuInfo.cpu_ticks.1 - prev.cpu_ticks.1)
        let idleDelta = Double(cpuInfo.cpu_ticks.2 - prev.cpu_ticks.2)
        let niceDelta = Double(cpuInfo.cpu_ticks.3 - prev.cpu_ticks.3)
        
        let totalDelta = userDelta + sysDelta + idleDelta + niceDelta
        if totalDelta <= 0 {
            // No ticks elapsed: DO NOT advance baseline, reuse previous valid readings
            return (cpuTotalUsage, cpuUserUsage, cpuSystemUsage, cpuIdleUsage, false)
        }
        
        // Only advance baseline when a meaningful delta has elapsed
        prevHostCpuInfo = cpuInfo
        lastCpuSampleTime = now
        
        let userPct = (userDelta / totalDelta) * 100.0
        let sysPct = (sysDelta / totalDelta) * 100.0
        let idlePct = (idleDelta / totalDelta) * 100.0
        let usedPct = ((userDelta + sysDelta + niceDelta) / totalDelta) * 100.0
        
        return (usedPct, userPct, sysPct, idlePct, true)
    }
    
    private func samplePerCoreCpu() -> [Double] {
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastPerCoreSampleTime < 0.15 && !perCoreUsage.isEmpty {
            return perCoreUsage
        }
        
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var count: mach_msg_type_number_t = 0
        
        let res = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &count)
        guard res == KERN_SUCCESS, let curInfo = info else { return perCoreUsage }
        
        guard let prev = prevProcessorInfo else {
            prevProcessorInfo = curInfo
            prevProcessorInfoCount = count
            lastPerCoreSampleTime = now
            return perCoreUsage
        }
        
        var usages: [Double] = []
        let ticksPerCPU = Int(CPU_STATE_MAX)
        var totalAllCores: Double = 0.0
        
        for i in 0..<Int(cpuCount) {
            let base = i * ticksPerCPU
            let user = Double(curInfo[base + Int(CPU_STATE_USER)] - prev[base + Int(CPU_STATE_USER)])
            let sys  = Double(curInfo[base + Int(CPU_STATE_SYSTEM)] - prev[base + Int(CPU_STATE_SYSTEM)])
            let idle = Double(curInfo[base + Int(CPU_STATE_IDLE)] - prev[base + Int(CPU_STATE_IDLE)])
            let nice = Double(curInfo[base + Int(CPU_STATE_NICE)] - prev[base + Int(CPU_STATE_NICE)])
            
            let total = user + sys + idle + nice
            totalAllCores += total
            if total > 0 {
                let pct = ((user + sys + nice) / total) * 100.0
                usages.append(min(100.0, max(0.0, pct)))
            } else {
                let fallback = (i < perCoreUsage.count) ? perCoreUsage[i] : 0.0
                usages.append(fallback)
            }
        }
        
        if totalAllCores <= 0 && !perCoreUsage.isEmpty {
            // Delta too small across all cores, discard curInfo and keep previous baseline
            let deallocSize = vm_size_t(count) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: curInfo), deallocSize)
            return perCoreUsage
        }
        
        // Deallocate previous baseline and advance
        let prevSize = vm_size_t(prevProcessorInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), prevSize)
        
        prevProcessorInfo = curInfo
        prevProcessorInfoCount = count
        lastPerCoreSampleTime = now
        return usages
    }
    
    // MARK: - GPU Sampling
    
    private func updateGpu(force: Bool = false, pushHistory: Bool = true) {
        let now = CFAbsoluteTimeGetCurrent()
        if !force && now - lastGpuSampleTime < 0.15 && lastGpuSampleTime > 0 {
            return
        }
        lastGpuSampleTime = now
        
        var iterator: io_iterator_t = 0
        let matchDict = IOServiceMatching("IOAccelerator")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator)
        guard result == kIOReturnSuccess else { return }
        
        var service = IOIteratorNext(iterator)
        var sampledGpu: Double?
        
        while service != 0 {
            if let props = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
                if let devUtil = props["Device Utilization %"] as? NSNumber {
                    sampledGpu = devUtil.doubleValue
                }
                if let rendUtil = props["Renderer Utilization %"] as? NSNumber {
                    self.gpuRendererUsage = rendUtil.doubleValue
                }
                if let tilerUtil = props["Tiler Utilization %"] as? NSNumber {
                    self.gpuTilerUsage = tilerUtil.doubleValue
                }
                if let inUseMem = props["In use system memory"] as? NSNumber {
                    self.gpuInUseMemoryBytes = inUseMem.uint64Value
                }
                if let allocMem = props["Alloc system memory"] as? NSNumber {
                    self.gpuAllocatedMemoryBytes = allocMem.uint64Value
                }
                
                IOObjectRelease(service)
                break
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)
        
        if let rawGpu = sampledGpu {
            // Smoothing at high frequency (0.5s):
            // Apple Silicon GPU often power-gates for a brief 500ms slice.
            // Rather than plunging instantly from 22% to 0% and jumping back, smooth decay prevents flickering.
            if rawGpu == 0 && self.gpuUsage > 0 {
                self.gpuUsage = max(0.0, self.gpuUsage * 0.5)
                if self.gpuUsage < 0.5 { self.gpuUsage = 0.0 }
            } else if self.gpuUsage > 0 {
                self.gpuUsage = (0.75 * rawGpu) + (0.25 * self.gpuUsage)
            } else {
                self.gpuUsage = rawGpu
            }
        }
        
        if pushHistory {
            appendHistory(&gpuHistory, value: gpuUsage)
        }
    }
    
    // MARK: - RAM Sampling
    
    private func updateRam() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            let active = UInt64(stats.active_count) * pageSize
            let wired = UInt64(stats.wire_count) * pageSize
            let compressed = UInt64(stats.compressor_page_count) * pageSize
            let used = active + wired + compressed
            self.ramUsedBytes = used
            if ramTotalBytes > 0 {
                self.ramUsagePercentage = (Double(used) / Double(ramTotalBytes)) * 100.0
            }
        }
    }
    
    // MARK: - Top Processes Sampling
    
    public func updateTopProcessesIfNeeded(force: Bool = false) {
        let now = Date()
        if !force && now.timeIntervalSince(lastProcessFetchTime) < 2.0 {
            return
        }
        lastProcessFetchTime = now
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/ps")
            process.arguments = ["-Aceo", "pid,pcpu,comm", "-r"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8) else { return }
                
                var items: [ProcessItem] = []
                let lines = output.components(separatedBy: .newlines)
                
                for line in lines.dropFirst() { // Skip header
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty { continue }
                    
                    let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
                    guard parts.count >= 3,
                          let pid = Int(parts[0]),
                          let cpu = Double(parts[1]) else { continue }
                    
                    let fullPath = String(parts[2])
                    let name = (fullPath as NSString).lastPathComponent
                    items.append(ProcessItem(id: pid, name: name, cpuPercentage: cpu))
                    if items.count >= 5 { break }
                }
                
                DispatchQueue.main.async {
                    self?.topProcesses = items
                }
            } catch {
                // Ignore process launch errors silently
            }
        }
    }
    
    private func appendHistory(_ array: inout [Double], value: Double) {
        array.append(value)
        if array.count > maxHistorySamples {
            array.removeFirst(array.count - maxHistorySamples)
        }
    }
}
