import Foundation

public enum TemperatureUnit: String, CaseIterable, Identifiable, Codable {
    case celsius = "°C"
    case fahrenheit = "°F"

    public var id: String { rawValue }
}

public enum MenuBarDisplayMode: String, CaseIterable, Identifiable, Codable {
    case rpmAndTemp = "RPM & Temp"
    case rpmOnly = "RPM Only"
    case tempOnly = "Temp Only"
    case iconOnly = "Icon Only"

    public var id: String { rawValue }
}

public struct AppSettings: Codable, Equatable {
    public var temperatureUnit: TemperatureUnit = .celsius
    public var fansLinked: Bool = true
    public var pollingInterval: Double = 1.0
    public var menuBarMode: MenuBarDisplayMode = .rpmAndTemp
    public var startAtLogin: Bool = false

    public init() {}
}
