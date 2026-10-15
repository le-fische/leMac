import Foundation
import IOKit

public struct HardwareInfo {
    public static let shared = HardwareInfo()
    
    public let chipName: String
    public let totalCpuCores: Int
    public let performanceCores: Int
    public let efficiencyCores: Int
    public let gpuCores: Int
    public let totalMemoryBytes: UInt64
    
    public var formattedMemory: String {
        let gb = Double(totalMemoryBytes) / 1_073_741_824.0
        return String(format: "%.0f GB", gb)
    }
    
    public var summaryString: String {
        var parts: [String] = []
        parts.append(chipName)
        if performanceCores > 0 && efficiencyCores > 0 {
            parts.append("\(totalCpuCores) Cores (\(performanceCores)P + \(efficiencyCores)E)")
        } else {
            parts.append("\(totalCpuCores) Cores")
        }
        if gpuCores > 0 {
            parts.append("\(gpuCores) GPU Cores")
        }
        return parts.joined(separator: " • ")
    }
    
    private init() {
        self.chipName = HardwareInfo.querySysctlString("machdep.cpu.brand_string") ?? "Apple Silicon"
        self.totalCpuCores = HardwareInfo.querySysctlInt("hw.ncpu") ?? 8
        self.performanceCores = HardwareInfo.querySysctlInt("hw.perflevel0.logicalcpu") ?? 0
        self.efficiencyCores = HardwareInfo.querySysctlInt("hw.perflevel1.logicalcpu") ?? 0
        self.gpuCores = HardwareInfo.queryGpuCoreCount()
        self.totalMemoryBytes = ProcessInfo.processInfo.physicalMemory
    }
    
    private static func querySysctlString(_ name: String) -> String? {
        var size: Int = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var data = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &data, &size, nil, 0)
        let str = String(cString: data).trimmingCharacters(in: .whitespacesAndNewlines)
        return str.isEmpty ? nil : str
    }
    
    private static func querySysctlInt(_ name: String) -> Int? {
        var val: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname(name, &val, &size, nil, 0) == 0 {
            return Int(val)
        }
        return nil
    }
    
    private static func queryGpuCoreCount() -> Int {
        var iterator: io_iterator_t = 0
        let matchDict = IOServiceMatching("IOAccelerator")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator)
        guard result == kIOReturnSuccess else { return 0 }
        
        var coreCount = 0
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let count = IORegistryEntryCreateCFProperty(service, "gpu-core-count" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
                coreCount = count
                IOObjectRelease(service)
                break
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)
        return coreCount
    }
}
