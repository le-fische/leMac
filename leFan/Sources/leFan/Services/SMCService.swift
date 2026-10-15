import Foundation
import SMCBridge

public final class SMCService {
    public static let shared = SMCService()

    private init() {
        _ = smc_init()
    }

    deinit {
        smc_cleanup()
    }

    public func readFans() -> [Fan] {
        let count = Int(smc_get_fan_count())
        guard count > 0 else { return [] }

        var fans: [Fan] = []
        for i in 0..<count {
            var info = FanInfo_t()
            if smc_get_fan_info(Int32(i), &info) {
                let name = withUnsafeBytes(of: info.name) { ptr -> String in
                    if let base = ptr.baseAddress?.assumingMemoryBound(to: CChar.self) {
                        return String(cString: base)
                    }
                    return "Fan \(i + 1)"
                }
                let isManual = (info.mode != 0)
                let fan = Fan(
                    id: i,
                    name: name.isEmpty ? "Fan \(i + 1)" : name,
                    actualRPM: Double(info.actualRPM),
                    minRPM: Double(info.minRPM),
                    maxRPM: Double(info.maxRPM),
                    targetRPM: Double(info.targetRPM),
                    mode: isManual ? .constant(rpm: Double(info.targetRPM)) : .auto,
                    isManual: isManual
                )
                fans.append(fan)
            }
        }
        return fans
    }

    public func readSensors() -> (sensors: [Sensor], cpuAvg: Double, cpuMax: Double, highest: Double) {
        var rawSensors = [SensorInfo_t](repeating: SensorInfo_t(), count: 128)
        let count = Int(smc_get_all_sensors(&rawSensors, 128))

        var result: [Sensor] = []
        var cpuTemps: [Double] = []
        var highestTemp: Double = 0.0

        for i in 0..<count {
            let s = rawSensors[i]
            let key = withUnsafeBytes(of: s.key) { ptr -> String in
                if let base = ptr.baseAddress?.assumingMemoryBound(to: CChar.self) {
                    return String(cString: base)
                }
                return "S\(i)"
            }
            let name = withUnsafeBytes(of: s.name) { ptr -> String in
                if let base = ptr.baseAddress?.assumingMemoryBound(to: CChar.self) {
                    return String(cString: base)
                }
                return "Sensor \(i)"
            }
            let catStr = withUnsafeBytes(of: s.category) { ptr -> String in
                if let base = ptr.baseAddress?.assumingMemoryBound(to: CChar.self) {
                    return String(cString: base)
                }
                return "System"
            }

            let category = SensorCategory(rawValue: catStr) ?? .system
            let tempC = Double(s.temperatureC)

            if tempC > highestTemp {
                highestTemp = tempC
            }

            if category == .cpu {
                cpuTemps.append(tempC)
            }

            let sensor = Sensor(
                id: key,
                name: name,
                category: category,
                temperatureC: tempC
            )
            result.append(sensor)
        }

        let cpuAvg = cpuTemps.isEmpty ? highestTemp : (cpuTemps.reduce(0, +) / Double(cpuTemps.count))
        let cpuMax = cpuTemps.isEmpty ? highestTemp : (cpuTemps.max() ?? highestTemp)

        // Add virtual composite sensors to the list
        if !cpuTemps.isEmpty {
            let avgSensor = Sensor(
                id: "CPU_AVG",
                name: "CPU Average Package",
                category: .cpu,
                temperatureC: cpuAvg
            )
            let maxSensor = Sensor(
                id: "CPU_MAX",
                name: "CPU Core Max",
                category: .cpu,
                temperatureC: cpuMax
            )
            result.insert(maxSensor, at: 0)
            result.insert(avgSensor, at: 0)
        }

        return (result, cpuAvg, cpuMax, highestTemp)
    }
}
