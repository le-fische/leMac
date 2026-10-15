import Foundation
import SwiftUI

public enum SensorCategory: String, CaseIterable, Identifiable, Codable {
    case all = "All"
    case cpu = "CPU"
    case gpu = "GPU"
    case battery = "Battery"
    case storage = "Storage"
    case system = "System"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .cpu: return "cpu"
        case .gpu: return "display"
        case .battery: return "battery.100"
        case .storage: return "internaldrive"
        case .system: return "gearshape.2"
        }
    }
}

public enum ThermalStatus {
    case cool
    case optimal
    case warm
    case hot

    public var title: String {
        switch self {
        case .cool: return "Cool"
        case .optimal: return "Optimal"
        case .warm: return "Warm"
        case .hot: return "Hot"
        }
    }

    public var color: Color {
        switch self {
        case .cool: return .cyan
        case .optimal: return .green
        case .warm: return .orange
        case .hot: return .red
        }
    }
}

public struct Sensor: Identifiable, Equatable, Codable {
    public let id: String // Key or unique identifier
    public var name: String
    public var category: SensorCategory
    public var temperatureC: Double
    public var minTempRecorded: Double
    public var maxTempRecorded: Double
    public var history: [Double]

    public var temperatureF: Double {
        return (temperatureC * 9.0 / 5.0) + 32.0
    }

    public var status: ThermalStatus {
        if temperatureC < 50.0 {
            return .cool
        } else if temperatureC < 70.0 {
            return .optimal
        } else if temperatureC < 85.0 {
            return .warm
        } else {
            return .hot
        }
    }

    public init(
        id: String,
        name: String,
        category: SensorCategory,
        temperatureC: Double,
        history: [Double] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.temperatureC = temperatureC
        self.minTempRecorded = temperatureC
        self.maxTempRecorded = temperatureC
        self.history = history.isEmpty ? [temperatureC] : history
    }

    public mutating func updateTemperature(_ newTemp: Double) {
        self.temperatureC = newTemp
        if newTemp < minTempRecorded || minTempRecorded == 0 {
            minTempRecorded = newTemp
        }
        if newTemp > maxTempRecorded {
            maxTempRecorded = newTemp
        }
        history.append(newTemp)
        if history.count > 30 {
            history.removeFirst()
        }
    }
}
