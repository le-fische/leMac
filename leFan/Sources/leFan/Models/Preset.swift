import Foundation

public struct FanPresetConfig: Codable, Equatable {
    public var mode: FanControlMode
    public var targetRPM: Double?
    public var sensorKey: String?
    public var lowTemp: Double?
    public var highTemp: Double?

    public init(
        mode: FanControlMode,
        targetRPM: Double? = nil,
        sensorKey: String? = nil,
        lowTemp: Double? = nil,
        highTemp: Double? = nil
    ) {
        self.mode = mode
        self.targetRPM = targetRPM
        self.sensorKey = sensorKey
        self.lowTemp = lowTemp
        self.highTemp = highTemp
    }
}

public struct Preset: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var subtitle: String
    public var icon: String
    public var isBuiltIn: Bool
    public var fanConfigs: [Int: FanPresetConfig] // Fan index -> config

    public init(
        id: UUID = UUID(),
        name: String,
        subtitle: String,
        icon: String,
        isBuiltIn: Bool = false,
        fanConfigs: [Int: FanPresetConfig]
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.icon = icon
        self.isBuiltIn = isBuiltIn
        self.fanConfigs = fanConfigs
    }

    public static let factoryAuto = Preset(
        name: "Factory Auto",
        subtitle: "Native macOS thermal governor",
        icon: "apple.logo",
        isBuiltIn: true,
        fanConfigs: [
            0: FanPresetConfig(mode: .auto),
            1: FanPresetConfig(mode: .auto)
        ]
    )

    public static let silent = Preset(
        name: "Silent Mode",
        subtitle: "Whisper quiet; ramps fan only above 65°C",
        icon: "speaker.slash.fill",
        isBuiltIn: true,
        fanConfigs: [
            0: FanPresetConfig(mode: .sensorCurve(sensorKey: "CPU_AVG", lowTemp: 65, highTemp: 92)),
            1: FanPresetConfig(mode: .sensorCurve(sensorKey: "CPU_AVG", lowTemp: 65, highTemp: 92))
        ]
    )

    public static let balanced = Preset(
        name: "Balanced",
        subtitle: "Optimal comfort for daily productivity",
        icon: "scale.3d",
        isBuiltIn: true,
        fanConfigs: [
            0: FanPresetConfig(mode: .sensorCurve(sensorKey: "CPU_AVG", lowTemp: 52, highTemp: 84)),
            1: FanPresetConfig(mode: .sensorCurve(sensorKey: "CPU_AVG", lowTemp: 52, highTemp: 84))
        ]
    )

    public static let performance = Preset(
        name: "Performance",
        subtitle: "Aggressive cooling for compiles, 3D & gaming",
        icon: "bolt.fill",
        isBuiltIn: true,
        fanConfigs: [
            0: FanPresetConfig(mode: .sensorCurve(sensorKey: "CPU_MAX", lowTemp: 45, highTemp: 78)),
            1: FanPresetConfig(mode: .sensorCurve(sensorKey: "CPU_MAX", lowTemp: 45, highTemp: 78))
        ]
    )

    public static let maxCooling = Preset(
        name: "Max Blast",
        subtitle: "100% full fan speed to dump heat rapidly",
        icon: "wind",
        isBuiltIn: true,
        fanConfigs: [
            0: FanPresetConfig(mode: .constant(rpm: 7800)),
            1: FanPresetConfig(mode: .constant(rpm: 7800))
        ]
    )

    public static let defaultPresets: [Preset] = [
        .factoryAuto,
        .silent,
        .balanced,
        .performance,
        .maxCooling
    ]
}
