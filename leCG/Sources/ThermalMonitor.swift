import Foundation
import IOKit

public enum TemperatureUnit: Int, CaseIterable {
    case celsius = 0
    case fahrenheit = 1
    
    public var title: String {
        switch self {
        case .celsius: return "Celsius (°C)"
        case .fahrenheit: return "Fahrenheit (°F)"
        }
    }
    
    public var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
}

public enum MetricDisplayMode: Int, CaseIterable {
    case percentages = 0
    case temperatures = 1
    case percentagesAndTemperatures = 2
    
    public var title: String {
        switch self {
        case .percentages: return "Percentages Only (e.g. 14% / 5%)"
        case .temperatures: return "Temperatures Only (e.g. 39° / 38°)"
        case .percentagesAndTemperatures: return "Percentages + Temperatures"
        }
    }
}

public class ThermalMonitor {
    public static let shared = ThermalMonitor()
    
    public private(set) var cpuTemperature: Double = 0.0 // In Celsius
    public private(set) var gpuTemperature: Double = 0.0 // In Celsius
    public private(set) var peakTemperature: Double = 0.0 // In Celsius
    public private(set) var avgTemperature: Double = 0.0 // In Celsius
    public private(set) var thermalStateString: String = "Nominal"
    
    public var currentUnit: TemperatureUnit {
        get {
            let val = UserDefaults.standard.integer(forKey: "leCG.TempUnit")
            return TemperatureUnit(rawValue: val) ?? .celsius
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "leCG.TempUnit")
        }
    }
    
    public var metricMode: MetricDisplayMode {
        get {
            let val = UserDefaults.standard.integer(forKey: "leCG.MetricMode")
            return MetricDisplayMode(rawValue: val) ?? .percentages
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "leCG.MetricMode")
        }
    }
    
    // IOHID Dynamic Function Pointer Types
    private typealias IOHIDEventSystemClientCreateFunc = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
    private typealias IOHIDEventSystemClientSetMatchingFunc = @convention(c) (AnyObject, CFDictionary) -> Void
    private typealias IOHIDEventSystemClientCopyServicesFunc = @convention(c) (AnyObject) -> Unmanaged<CFArray>?
    private typealias IOHIDServiceClientCopyEventFunc = @convention(c) (AnyObject, Int64, Int32, Int64) -> Unmanaged<AnyObject>?
    private typealias IOHIDEventGetFloatValueFunc = @convention(c) (AnyObject, Int64) -> Double
    private typealias IOHIDServiceClientCopyPropertyFunc = @convention(c) (AnyObject, CFString) -> Unmanaged<CFTypeRef>?
    
    private var clientCreate: IOHIDEventSystemClientCreateFunc?
    private var setMatching: IOHIDEventSystemClientSetMatchingFunc?
    private var copyServices: IOHIDEventSystemClientCopyServicesFunc?
    private var copyEvent: IOHIDServiceClientCopyEventFunc?
    private var getFloatValue: IOHIDEventGetFloatValueFunc?
    private var copyProperty: IOHIDServiceClientCopyPropertyFunc?
    
    private var hidClient: AnyObject?
    private var isUpdating: Bool = false
    private var lastUpdate: Date = .distantPast
    
    private init() {
        initHIDClient()
        updateThermalState()
        sampleImmediate()
    }
    
    private func initHIDClient() {
        guard let handle = dlopen(nil, RTLD_NOW) else { return }
        
        if let ptr = dlsym(handle, "IOHIDEventSystemClientCreate") {
            clientCreate = unsafeBitCast(ptr, to: IOHIDEventSystemClientCreateFunc.self)
        }
        if let ptr = dlsym(handle, "IOHIDEventSystemClientSetMatching") {
            setMatching = unsafeBitCast(ptr, to: IOHIDEventSystemClientSetMatchingFunc.self)
        }
        if let ptr = dlsym(handle, "IOHIDEventSystemClientCopyServices") {
            copyServices = unsafeBitCast(ptr, to: IOHIDEventSystemClientCopyServicesFunc.self)
        }
        if let ptr = dlsym(handle, "IOHIDServiceClientCopyEvent") {
            copyEvent = unsafeBitCast(ptr, to: IOHIDServiceClientCopyEventFunc.self)
        }
        if let ptr = dlsym(handle, "IOHIDEventGetFloatValue") {
            getFloatValue = unsafeBitCast(ptr, to: IOHIDEventGetFloatValueFunc.self)
        }
        if let ptr = dlsym(handle, "IOHIDServiceClientCopyProperty") {
            copyProperty = unsafeBitCast(ptr, to: IOHIDServiceClientCopyPropertyFunc.self)
        }
        
        if let cc = clientCreate?(kCFAllocatorDefault)?.takeRetainedValue() {
            self.hidClient = cc
            // Match temperature sensors (Page: Apple Vendor Defined 0xFF00, Usage: 5)
            let matchDict: [String: Any] = [
                "PrimaryUsagePage": 0xff00,
                "PrimaryUsage": 5
            ]
            setMatching?(cc, matchDict as CFDictionary)
        }
    }
    
    /// Trigger asynchronous update if at least 1.5s has elapsed since last sample
    public func updateIfNeeded(force: Bool = false) {
        let now = Date()
        guard force || (now.timeIntervalSince(lastUpdate) >= 1.5 && !isUpdating) else { return }
        isUpdating = true
        lastUpdate = now
        
        updateThermalState()
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.performSample()
            self?.isUpdating = false
        }
    }
    
    public func sampleImmediate() {
        performSample()
        updateThermalState()
    }
    
    private func updateThermalState() {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: self.thermalStateString = "Nominal"
        case .fair: self.thermalStateString = "Fair"
        case .serious: self.thermalStateString = "High (Throttling)"
        case .critical: self.thermalStateString = "Critical"
        @unknown default: self.thermalStateString = "Nominal"
        }
    }
    
    private func performSample() {
        guard let client = hidClient,
              let copyServices = copyServices,
              let copyEvent = copyEvent,
              let getFloatValue = getFloatValue,
              let copyProperty = copyProperty else { return }
        
        guard let services = copyServices(client)?.takeRetainedValue() as? [AnyObject] else { return }
        
        var cpuTemps: [Double] = []
        var gpuTemps: [Double] = []
        var allTemps: [Double] = []
        
        for s in services {
            if let name = copyProperty(s, "Product" as CFString)?.takeRetainedValue() as? String {
                if let event = copyEvent(s, 15, 0, 0)?.takeRetainedValue() {
                    let temp = getFloatValue(event, 15 << 16)
                    if temp > 15 && temp < 125 {
                        allTemps.append(temp)
                        if name.contains("tdie") {
                            let numStr = name.replacingOccurrences(of: "PMU tdie", with: "").trimmingCharacters(in: .whitespaces)
                            if let num = Int(numStr) {
                                if num <= 8 {
                                    cpuTemps.append(temp)
                                } else {
                                    gpuTemps.append(temp)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        guard !allTemps.isEmpty else { return }
        
        let avg = allTemps.reduce(0, +) / Double(allTemps.count)
        let peak = allTemps.max() ?? avg
        let cpu = cpuTemps.isEmpty ? avg : (cpuTemps.reduce(0, +) / Double(cpuTemps.count))
        let gpu = gpuTemps.isEmpty ? avg : (gpuTemps.reduce(0, +) / Double(gpuTemps.count))
        
        DispatchQueue.main.async {
            self.avgTemperature = avg
            self.peakTemperature = peak
            self.cpuTemperature = cpu
            self.gpuTemperature = gpu
        }
    }
    
    // MARK: - Formatting Helpers
    
    public func format(celsius: Double, includeSymbol: Bool = true, short: Bool = false) -> String {
        guard celsius > 0 else { return "--" }
        if currentUnit == .fahrenheit {
            let f = (celsius * 9.0 / 5.0) + 32.0
            if short {
                return String(format: "%.0f°", f)
            } else {
                return includeSymbol ? String(format: "%.1f°F", f) : String(format: "%.1f", f)
            }
        } else {
            if short {
                return String(format: "%.0f°", celsius)
            } else {
                return includeSymbol ? String(format: "%.1f°C", celsius) : String(format: "%.1f", celsius)
            }
        }
    }
}
