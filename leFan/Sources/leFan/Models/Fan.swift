import Foundation

public enum FanControlMode: Equatable, Codable {
    case auto
    case constant(rpm: Double)
    case sensorCurve(sensorKey: String, lowTemp: Double, highTemp: Double)

    public var title: String {
        switch self {
        case .auto:
            return "Auto (System)"
        case .constant:
            return "Constant RPM"
        case .sensorCurve:
            return "Sensor Curve"
        }
    }
}

public struct Fan: Identifiable, Equatable, Codable {
    public let id: Int
    public var name: String
    public var actualRPM: Double
    public var minRPM: Double
    public var maxRPM: Double
    public var targetRPM: Double
    public var mode: FanControlMode
    public var isManual: Bool

    public var percentage: Double {
        guard maxRPM > minRPM else { return 0 }
        let clamped = min(max(actualRPM, minRPM), maxRPM)
        return (clamped - minRPM) / (maxRPM - minRPM) * 100.0
    }

    public init(
        id: Int,
        name: String,
        actualRPM: Double,
        minRPM: Double,
        maxRPM: Double,
        targetRPM: Double,
        mode: FanControlMode = .auto,
        isManual: Bool = false
    ) {
        self.id = id
        self.name = name
        self.actualRPM = actualRPM
        self.minRPM = minRPM
        self.maxRPM = maxRPM
        self.targetRPM = targetRPM
        self.mode = mode
        self.isManual = isManual
    }
}
