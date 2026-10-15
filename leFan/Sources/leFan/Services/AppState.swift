import Foundation
import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var fans: [Fan] = []
    @Published public var sensors: [Sensor] = []
    @Published public var selectedCategory: SensorCategory = .all
    @Published public var sensorSearchText: String = ""

    @Published public var presets: [Preset] = []
    @Published public var activePresetId: UUID?

    @Published public var settings: AppSettings = AppSettings()
    @Published public var helperStatus: HelperStatus = .notInstalled

    @Published public var cpuAvgTemp: Double = 35.0
    @Published public var cpuMaxTemp: Double = 35.0
    @Published public var highestTemp: Double = 35.0
    @Published public var averageRPM: Double = 0.0

    @Published public var rpmHistory: [Double] = []
    @Published public var tempHistory: [Double] = []

    @Published public var macModelName: String = "MacBook Pro (Apple Silicon)"
    @Published public var activeTab: MainTab = .fans {
        didSet {
            if oldValue != activeTab && activeTab == .sensors {
                refreshMetrics()
            }
        }
    }
    @Published public var isMainWindowVisible: Bool = true {
        didSet {
            if oldValue != isMainWindowVisible {
                startMonitoring()
                if isMainWindowVisible {
                    refreshMetrics()
                }
            }
        }
    }

    private var timer: Timer?
    private let presetsKey = "leFan_CustomPresets"
    private let settingsKey = "leFan_Settings"

    public init() {
        loadSettings()
        loadPresets()
        detectMacModel()
        refreshMetrics()
        checkHelper()

        startMonitoring()
    }

    public func startMonitoring() {
        timer?.invalidate()
        let interval: TimeInterval = isMainWindowVisible ? settings.pollingInterval : 3.0
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshMetrics()
            }
        }
    }

    public func checkHelper() {
        let status = HelperClient.shared.checkStatus()
        self.helperStatus = status
    }

    private func detectMacModel() {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let identifier = String(cString: model)

        // Friendly mapping
        if identifier.contains("Mac16") {
            macModelName = "MacBook Pro (M4 Pro / M4 Max)"
        } else if identifier.contains("Mac15") {
            macModelName = "MacBook Pro (M3)"
        } else if identifier.contains("Mac14") {
            macModelName = "MacBook Pro (M2)"
        } else if identifier.contains("MacBook") {
            macModelName = "MacBook Pro"
        } else {
            macModelName = identifier.isEmpty ? "Mac (Apple Silicon)" : identifier
        }
    }

    public var needsFullSensors: Bool {
        if isMainWindowVisible && activeTab == .sensors {
            return true
        }
        for fan in fans {
            if case .sensorCurve(let key, _, _) = fan.mode {
                if key != "CPU_AVG" && key != "CPU_MAX" {
                    return true
                }
            }
        }
        return false
    }

    public func refreshMetrics() {
        // Read fans
        let freshFans = SMCService.shared.readFans()
        if self.fans.isEmpty {
            self.fans = freshFans
        } else {
            for i in 0..<freshFans.count {
                if i < self.fans.count {
                    if abs(self.fans[i].actualRPM - freshFans[i].actualRPM) >= 1.0 {
                        self.fans[i].actualRPM = freshFans[i].actualRPM
                    }
                    if self.fans[i].minRPM != freshFans[i].minRPM {
                        self.fans[i].minRPM = freshFans[i].minRPM
                    }
                    if self.fans[i].maxRPM != freshFans[i].maxRPM {
                        self.fans[i].maxRPM = freshFans[i].maxRPM
                    }
                } else {
                    self.fans.append(freshFans[i])
                }
            }
        }

        // Targeted sensor polling: full list only when sensors tab is open or custom curve active
        if sensors.isEmpty || needsFullSensors {
            let sensorData = SMCService.shared.readSensors()
            if abs(self.cpuAvgTemp - sensorData.cpuAvg) >= 0.1 { self.cpuAvgTemp = sensorData.cpuAvg }
            if abs(self.cpuMaxTemp - sensorData.cpuMax) >= 0.1 { self.cpuMaxTemp = sensorData.cpuMax }
            if abs(self.highestTemp - sensorData.highest) >= 0.1 { self.highestTemp = sensorData.highest }

            if self.sensors.isEmpty {
                self.sensors = sensorData.sensors
            } else {
                for fresh in sensorData.sensors {
                    if let idx = self.sensors.firstIndex(where: { $0.id == fresh.id }) {
                        if abs(self.sensors[idx].temperatureC - fresh.temperatureC) >= 0.2 {
                            self.sensors[idx].updateTemperature(fresh.temperatureC)
                        }
                    } else {
                        self.sensors.append(fresh)
                    }
                }
            }
        } else {
            let quick = SMCService.shared.readQuickMetrics()
            if abs(self.cpuAvgTemp - quick.cpuAvg) >= 0.1 { self.cpuAvgTemp = quick.cpuAvg }
            if abs(self.cpuMaxTemp - quick.cpuMax) >= 0.1 { self.cpuMaxTemp = quick.cpuMax }
            if abs(self.highestTemp - quick.highest) >= 0.1 { self.highestTemp = quick.highest }
        }

        // Calculate average RPM
        if !fans.isEmpty {
            let totalRPM = fans.reduce(0.0) { $0 + $1.actualRPM }
            let avg = totalRPM / Double(fans.count)
            if abs(self.averageRPM - avg) >= 1.0 {
                self.averageRPM = avg
            }
        }

        // Telemetry history only needed when telemetry view is visible
        if isMainWindowVisible && activeTab == .telemetry {
            rpmHistory.append(averageRPM)
            if rpmHistory.count > 60 { rpmHistory.removeFirst() }

            tempHistory.append(highestTemp)
            if tempHistory.count > 60 { tempHistory.removeFirst() }
        }

        // Evaluate sensor curves
        evaluateFanCurves()

        // Periodic helper check (only if disconnected)
        if helperStatus != .connected {
            checkHelper()
        }
    }

    private func evaluateFanCurves() {
        guard helperStatus == .connected else { return }

        for (idx, fan) in fans.enumerated() {
            switch fan.mode {
            case .sensorCurve(let sensorKey, let lowTemp, let highTemp):
                let currentTemp = getTemperatureForSensorKey(sensorKey)
                var target: Double = fan.minRPM
                if currentTemp <= lowTemp {
                    target = fan.minRPM
                } else if currentTemp >= highTemp {
                    target = fan.maxRPM
                } else {
                    let ratio = (currentTemp - lowTemp) / max(highTemp - lowTemp, 1.0)
                    target = fan.minRPM + (fan.maxRPM - fan.minRPM) * ratio
                }
                // Only send to helper if target changed significantly (>= 25 RPM)
                if abs(fan.targetRPM - target) >= 25.0 {
                    fans[idx].targetRPM = target
                    _ = HelperClient.shared.setFanMode(fanIndex: fan.id, mode: fan.mode, targetRPM: target)
                }

            case .constant:
                // Already configured on mode selection; no need to repeatedly spam socket IPC
                break

            case .auto:
                break
            }
        }
    }

    public func getTemperatureForSensorKey(_ key: String) -> Double {
        if key == "CPU_AVG" {
            return cpuAvgTemp
        } else if key == "CPU_MAX" {
            return cpuMaxTemp
        }
        if let s = sensors.first(where: { $0.id == key }) {
            return s.temperatureC
        }
        return cpuAvgTemp
    }

    public func setFanMode(fanIndex: Int, mode: FanControlMode) {
        guard fanIndex < fans.count else { return }
        fans[fanIndex].mode = mode

        switch mode {
        case .auto:
            fans[fanIndex].isManual = false
            _ = HelperClient.shared.setFanMode(fanIndex: fans[fanIndex].id, mode: .auto, targetRPM: 0)
        case .constant(let rpm):
            fans[fanIndex].isManual = true
            fans[fanIndex].targetRPM = rpm
            _ = HelperClient.shared.setFanMode(fanIndex: fans[fanIndex].id, mode: mode, targetRPM: rpm)
        case .sensorCurve:
            fans[fanIndex].isManual = true
            evaluateFanCurves()
        }

        // If fans are linked, apply to all other fans
        if settings.fansLinked {
            for i in 0..<fans.count where i != fanIndex {
                fans[i].mode = mode
                fans[i].isManual = fans[fanIndex].isManual
                fans[i].targetRPM = fans[fanIndex].targetRPM
                _ = HelperClient.shared.setFanMode(fanIndex: fans[i].id, mode: mode, targetRPM: fans[i].targetRPM)
            }
        }

        activePresetId = nil
    }

    public func applyPreset(_ preset: Preset) {
        activePresetId = preset.id

        for (fanIdx, config) in preset.fanConfigs {
            guard fanIdx < fans.count else { continue }
            fans[fanIdx].mode = config.mode

            switch config.mode {
            case .auto:
                fans[fanIdx].isManual = false
                _ = HelperClient.shared.setFanMode(fanIndex: fans[fanIdx].id, mode: .auto, targetRPM: 0)
            case .constant(let rpm):
                fans[fanIdx].isManual = true
                fans[fanIdx].targetRPM = rpm
                _ = HelperClient.shared.setFanMode(fanIndex: fans[fanIdx].id, mode: config.mode, targetRPM: rpm)
            case .sensorCurve:
                fans[fanIdx].isManual = true
            }
        }

        evaluateFanCurves()
    }

    public func saveCustomPreset(name: String, subtitle: String, icon: String = "slider.horizontal.3") {
        var configs: [Int: FanPresetConfig] = [:]
        for fan in fans {
            configs[fan.id] = FanPresetConfig(mode: fan.mode, targetRPM: fan.targetRPM)
        }
        let preset = Preset(
            name: name,
            subtitle: subtitle.isEmpty ? "User custom preset" : subtitle,
            icon: icon,
            isBuiltIn: false,
            fanConfigs: configs
        )
        presets.append(preset)
        activePresetId = preset.id
        savePresets()
    }

    public func deletePreset(id: UUID) {
        presets.removeAll(where: { $0.id == id && !$0.isBuiltIn })
        if activePresetId == id {
            activePresetId = nil
        }
        savePresets()
    }

    private func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: presetsKey),
           let custom = try? JSONDecoder().decode([Preset].self, from: data) {
            presets = Preset.defaultPresets + custom
        } else {
            presets = Preset.defaultPresets
        }
    }

    private func savePresets() {
        let customOnly = presets.filter { !$0.isBuiltIn }
        if let encoded = try? JSONEncoder().encode(customOnly) {
            UserDefaults.standard.set(encoded, forKey: presetsKey)
        }
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let loaded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = loaded
        }
    }

    public func updateSettings(_ newSettings: AppSettings) {
        self.settings = newSettings
        if let encoded = try? JSONEncoder().encode(newSettings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
        startMonitoring()
    }

    public func formatTemp(_ celsius: Double) -> String {
        switch settings.temperatureUnit {
        case .celsius:
            return String(format: "%.1f°C", celsius)
        case .fahrenheit:
            let f = (celsius * 9.0 / 5.0) + 32.0
            return String(format: "%.1f°F", f)
        }
    }
}
