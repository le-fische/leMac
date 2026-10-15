import AppKit
import ServiceManagement

public protocol MenuControllerDelegate: AnyObject {
    func didChangeStyle(_ style: GraphStyle)
    func didChangeTheme(_ theme: ColorTheme)
    func didChangeRefreshInterval(_ interval: TimeInterval)
    func didChangeMetricMode(_ mode: MetricDisplayMode)
    func didChangeTempUnit(_ unit: TemperatureUnit)
}

public class MenuController: NSObject, NSMenuDelegate {
    public weak var delegate: MenuControllerDelegate?
    public let menu = NSMenu()
    public private(set) var isMenuOpen: Bool = false
    
    // Dynamic Menu Items
    private var headerItem: NSMenuItem!
    
    // CPU items
    private var cpuHeaderItem: NSMenuItem!
    private var cpuDetailItem: NSMenuItem!
    private var cpuCoresItem: NSMenuItem!
    
    // GPU items
    private var gpuHeaderItem: NSMenuItem!
    private var gpuDetailItem: NSMenuItem!
    private var gpuMemoryItem: NSMenuItem!
    
    // RAM items
    private var ramHeaderItem: NSMenuItem!
    
    // Thermal item
    private var thermalHeaderItem: NSMenuItem!
    
    // Process items
    private var processHeaderItem: NSMenuItem!
    private var processItems: [NSMenuItem] = []
    
    // Preferences submenus
    private var styleMenuItems: [GraphStyle: NSMenuItem] = [:]
    private var themeMenuItems: [ColorTheme: NSMenuItem] = [:]
    private var intervalMenuItems: [Double: NSMenuItem] = [:]
    private var metricModeMenuItems: [MetricDisplayMode: NSMenuItem] = [:]
    private var tempUnitMenuItems: [TemperatureUnit: NSMenuItem] = [:]
    private var launchAtLoginItem: NSMenuItem!
    
    public override init() {
        super.init()
        buildMenu()
        menu.delegate = self
    }
    
    // MARK: - Menu Construction
    
    private func buildMenu() {
        menu.removeAllItems()
        
        // 1. Hardware Header (Clickable -> Opens About)
        let hw = HardwareInfo.shared
        headerItem = NSMenuItem(title: " \(hw.summaryString)", action: #selector(openAbout), keyEquivalent: "")
        headerItem.target = self
        headerItem.toolTip = "Click to view hardware specifications"
        menu.addItem(headerItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. CPU Section (Clickable -> Opens Activity Monitor CPU)
        cpuHeaderItem = NSMenuItem(title: "CPU: 0%", action: #selector(openActivityMonitor), keyEquivalent: "")
        cpuHeaderItem.target = self
        cpuHeaderItem.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "CPU")
        cpuHeaderItem.toolTip = "Click to open Activity Monitor"
        menu.addItem(cpuHeaderItem)
        
        cpuDetailItem = NSMenuItem(title: "  User: 0%  •  System: 0%  •  Idle: 100%", action: #selector(openActivityMonitor), keyEquivalent: "")
        cpuDetailItem.target = self
        menu.addItem(cpuDetailItem)
        
        cpuCoresItem = NSMenuItem(title: "  Cores: Loading...", action: #selector(openActivityMonitor), keyEquivalent: "")
        cpuCoresItem.target = self
        menu.addItem(cpuCoresItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. GPU Section (Clickable -> Opens Activity Monitor)
        gpuHeaderItem = NSMenuItem(title: "GPU: 0%", action: #selector(openActivityMonitor), keyEquivalent: "")
        gpuHeaderItem.target = self
        gpuHeaderItem.image = NSImage(systemSymbolName: "display", accessibilityDescription: "GPU")
        gpuHeaderItem.toolTip = "Click to open Activity Monitor"
        menu.addItem(gpuHeaderItem)
        
        gpuDetailItem = NSMenuItem(title: "  Renderer: 0%  •  Tiler: 0%", action: #selector(openActivityMonitor), keyEquivalent: "")
        gpuDetailItem.target = self
        menu.addItem(gpuDetailItem)
        
        gpuMemoryItem = NSMenuItem(title: "  Memory: 0 MB In-Use", action: #selector(openActivityMonitor), keyEquivalent: "")
        gpuMemoryItem.target = self
        menu.addItem(gpuMemoryItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Memory Section (Clickable -> Opens Activity Monitor)
        ramHeaderItem = NSMenuItem(title: "RAM: 0%", action: #selector(openActivityMonitor), keyEquivalent: "")
        ramHeaderItem.target = self
        ramHeaderItem.image = NSImage(systemSymbolName: "memorychip", accessibilityDescription: "RAM")
        ramHeaderItem.toolTip = "Click to open Activity Monitor"
        menu.addItem(ramHeaderItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. Thermal Section (Clickable -> Opens Activity Monitor)
        thermalHeaderItem = NSMenuItem(title: "SoC Temp: Loading...", action: #selector(openActivityMonitor), keyEquivalent: "")
        thermalHeaderItem.target = self
        thermalHeaderItem.image = NSImage(systemSymbolName: "thermometer.medium", accessibilityDescription: "Thermal")
        thermalHeaderItem.toolTip = "Click to open Activity Monitor"
        menu.addItem(thermalHeaderItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 6. Top Processes Section (Clickable -> Opens Activity Monitor)
        processHeaderItem = NSMenuItem(title: "Top CPU Processes:", action: #selector(openActivityMonitor), keyEquivalent: "")
        processHeaderItem.target = self
        processHeaderItem.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Processes")
        menu.addItem(processHeaderItem)
        
        for _ in 0..<5 {
            let item = NSMenuItem(title: "  Loading...", action: #selector(openActivityMonitor), keyEquivalent: "")
            item.target = self
            processItems.append(item)
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // 7. Activity Monitor Launcher
        let activityMonitorItem = NSMenuItem(title: "Open Activity Monitor…", action: #selector(openActivityMonitor), keyEquivalent: "")
        activityMonitorItem.target = self
        activityMonitorItem.image = NSImage(systemSymbolName: "chart.xyaxis.line", accessibilityDescription: "Activity Monitor")
        menu.addItem(activityMonitorItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 8. Settings Submenus
        buildSettingsSubmenus()
        
        menu.addItem(NSMenuItem.separator())
        
        // 9. Launch at Login
        launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        updateLaunchAtLoginState()
        menu.addItem(launchAtLoginItem)
        
        // 10. About & Quit
        let aboutItem = NSMenuItem(title: "About leCG…", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        let quitItem = NSMenuItem(title: "Quit leCG", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    private func buildSettingsSubmenus() {
        // Display Style Submenu
        let styleSubmenu = NSMenu()
        let currentStyle = GraphRenderer.shared.currentStyle
        for style in GraphStyle.allCases {
            let item = NSMenuItem(title: style.title, action: #selector(styleSelected(_:)), keyEquivalent: "")
            item.target = self
            item.tag = style.rawValue
            item.state = (style == currentStyle) ? .on : .off
            styleMenuItems[style] = item
            styleSubmenu.addItem(item)
        }
        let styleParent = NSMenuItem(title: "Display Style", action: nil, keyEquivalent: "")
        styleParent.submenu = styleSubmenu
        menu.addItem(styleParent)
        
        // Metric Display Mode (Percentages vs Temperatures vs Both)
        let metricSubmenu = NSMenu()
        let currentMetricMode = ThermalMonitor.shared.metricMode
        for mode in MetricDisplayMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(metricModeSelected(_:)), keyEquivalent: "")
            item.target = self
            item.tag = mode.rawValue
            item.state = (mode == currentMetricMode) ? .on : .off
            metricModeMenuItems[mode] = item
            metricSubmenu.addItem(item)
        }
        let metricParent = NSMenuItem(title: "Metric Display in Icon", action: nil, keyEquivalent: "")
        metricParent.submenu = metricSubmenu
        menu.addItem(metricParent)
        
        // Temperature Unit Submenu (°C vs °F)
        let unitSubmenu = NSMenu()
        let currentUnit = ThermalMonitor.shared.currentUnit
        for unit in TemperatureUnit.allCases {
            let item = NSMenuItem(title: unit.title, action: #selector(tempUnitSelected(_:)), keyEquivalent: "")
            item.target = self
            item.tag = unit.rawValue
            item.state = (unit == currentUnit) ? .on : .off
            tempUnitMenuItems[unit] = item
            unitSubmenu.addItem(item)
        }
        let unitParent = NSMenuItem(title: "Temperature Unit", action: nil, keyEquivalent: "")
        unitParent.submenu = unitSubmenu
        menu.addItem(unitParent)
        
        // Color Theme Submenu
        let themeSubmenu = NSMenu()
        let currentTheme = GraphRenderer.shared.currentTheme
        for theme in ColorTheme.allCases {
            let item = NSMenuItem(title: theme.title, action: #selector(themeSelected(_:)), keyEquivalent: "")
            item.target = self
            item.tag = theme.rawValue
            item.state = (theme == currentTheme) ? .on : .off
            themeMenuItems[theme] = item
            themeSubmenu.addItem(item)
        }
        let themeParent = NSMenuItem(title: "Color Theme", action: nil, keyEquivalent: "")
        themeParent.submenu = themeSubmenu
        menu.addItem(themeParent)
        
        // Refresh Interval Submenu
        let intervalSubmenu = NSMenu()
        let intervals: [(Double, String)] = [
            (0.5, "0.5 seconds"),
            (1.0, "1.0 second (Default)"),
            (2.0, "2.0 seconds"),
            (5.0, "5.0 seconds")
        ]
        let currentInterval = UserDefaults.standard.double(forKey: "leCG.RefreshInterval") > 0
            ? UserDefaults.standard.double(forKey: "leCG.RefreshInterval")
            : 1.0
        
        for (sec, title) in intervals {
            let item = NSMenuItem(title: title, action: #selector(intervalSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = sec
            item.state = (abs(sec - currentInterval) < 0.01) ? .on : .off
            intervalMenuItems[sec] = item
            intervalSubmenu.addItem(item)
        }
        let intervalParent = NSMenuItem(title: "Refresh Interval", action: nil, keyEquivalent: "")
        intervalParent.submenu = intervalSubmenu
        menu.addItem(intervalParent)
    }
    
    // MARK: - Live Updating
    
    public func updateMetrics(monitor: SystemMonitor) {
        let thermal = ThermalMonitor.shared
        
        // CPU
        let cpuPct = monitor.cpuTotalUsage
        let cpuBar = progressBar(percentage: cpuPct)
        let cpuTempStr = thermal.format(celsius: thermal.cpuTemperature)
        cpuHeaderItem.title = String(format: "CPU Usage: %4.1f%%    %@    %@", cpuPct, cpuBar, cpuTempStr)
        
        cpuDetailItem.title = String(format: "  User: %.1f%%  •  System: %.1f%%  •  Idle: %.1f%%",
                                    monitor.cpuUserUsage,
                                    monitor.cpuSystemUsage,
                                    monitor.cpuIdleUsage)
        
        if !monitor.perCoreUsage.isEmpty {
            let coreStrings = monitor.perCoreUsage.map { String(format: "%2.0f%%", $0) }
            let summary = coreStrings.joined(separator: " ")
            cpuCoresItem.title = "  Cores: [ \(summary) ]"
        }
        
        // GPU
        let gpuPct = monitor.gpuUsage
        let gpuBar = progressBar(percentage: gpuPct)
        let gpuTempStr = thermal.format(celsius: thermal.gpuTemperature)
        gpuHeaderItem.title = String(format: "GPU Usage: %4.1f%%    %@    %@", gpuPct, gpuBar, gpuTempStr)
        
        gpuDetailItem.title = String(format: "  Renderer: %.1f%%  •  Tiler: %.1f%%",
                                     monitor.gpuRendererUsage,
                                     monitor.gpuTilerUsage)
        
        let inUseMB = Double(monitor.gpuInUseMemoryBytes) / 1_048_576.0
        let allocMB = Double(monitor.gpuAllocatedMemoryBytes) / 1_048_576.0
        gpuMemoryItem.title = String(format: "  In-Use Memory: %.0f MB (Alloc: %.0f MB)", inUseMB, allocMB)
        
        // RAM
        let ramPct = monitor.ramUsagePercentage
        let ramUsedGB = Double(monitor.ramUsedBytes) / 1_073_741_824.0
        let ramTotalGB = Double(monitor.ramTotalBytes) / 1_073_741_824.0
        let ramBar = progressBar(percentage: ramPct)
        ramHeaderItem.title = String(format: "RAM: %.1f / %.0f GB (%2.0f%%)  %@", ramUsedGB, ramTotalGB, ramPct, ramBar)
        
        // Thermal
        let avgTempStr = thermal.format(celsius: thermal.avgTemperature)
        let peakTempStr = thermal.format(celsius: thermal.peakTemperature)
        thermalHeaderItem.title = String(format: "SoC Temp: %@  (Peak: %@  •  %@)", avgTempStr, peakTempStr, thermal.thermalStateString)
        
        // Top Processes
        let processes = monitor.topProcesses
        for (i, item) in processItems.enumerated() {
            if i < processes.count {
                let proc = processes[i]
                item.title = String(format: "  %d. %-18@ %4.1f%% (PID %d)", i + 1, proc.name, proc.cpuPercentage, proc.id)
                item.isHidden = false
            } else {
                item.isHidden = true
            }
        }
    }
    
    private func progressBar(percentage: Double, length: Int = 10) -> String {
        let clamped = max(0.0, min(100.0, percentage))
        let filled = Int(round((clamped / 100.0) * Double(length)))
        let empty = max(0, length - filled)
        return "[" + String(repeating: "■", count: filled) + String(repeating: "□", count: empty) + "]"
    }
    
    // MARK: - NSMenuDelegate
    
    public func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        SystemMonitor.shared.update(includeProcesses: true)
        ThermalMonitor.shared.updateIfNeeded(force: true)
        updateMetrics(monitor: SystemMonitor.shared)
        updateLaunchAtLoginState()
    }
    
    public func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
    }
    
    // MARK: - Actions
    
    @objc private func openActivityMonitor() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
    
    @objc private func styleSelected(_ sender: NSMenuItem) {
        guard let style = GraphStyle(rawValue: sender.tag) else { return }
        GraphRenderer.shared.currentStyle = style
        for (s, item) in styleMenuItems {
            item.state = (s == style) ? .on : .off
        }
        delegate?.didChangeStyle(style)
    }
    
    @objc private func metricModeSelected(_ sender: NSMenuItem) {
        guard let mode = MetricDisplayMode(rawValue: sender.tag) else { return }
        ThermalMonitor.shared.metricMode = mode
        for (m, item) in metricModeMenuItems {
            item.state = (m == mode) ? .on : .off
        }
        delegate?.didChangeMetricMode(mode)
    }
    
    @objc private func tempUnitSelected(_ sender: NSMenuItem) {
        guard let unit = TemperatureUnit(rawValue: sender.tag) else { return }
        ThermalMonitor.shared.currentUnit = unit
        for (u, item) in tempUnitMenuItems {
            item.state = (u == unit) ? .on : .off
        }
        delegate?.didChangeTempUnit(unit)
    }
    
    @objc private func themeSelected(_ sender: NSMenuItem) {
        guard let theme = ColorTheme(rawValue: sender.tag) else { return }
        GraphRenderer.shared.currentTheme = theme
        for (t, item) in themeMenuItems {
            item.state = (t == theme) ? .on : .off
        }
        delegate?.didChangeTheme(theme)
    }
    
    @objc private func intervalSelected(_ sender: NSMenuItem) {
        guard let sec = sender.representedObject as? Double else { return }
        UserDefaults.standard.set(sec, forKey: "leCG.RefreshInterval")
        for (s, item) in intervalMenuItems {
            item.state = (abs(s - sec) < 0.01) ? .on : .off
        }
        delegate?.didChangeRefreshInterval(sec)
    }
    
    @objc private func toggleLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                } else {
                    try SMAppService.mainApp.register()
                }
            } catch {
                NSLog("Failed to toggle launch at login: \(error)")
            }
            updateLaunchAtLoginState()
        }
    }
    
    private func updateLaunchAtLoginState() {
        if #available(macOS 13.0, *) {
            launchAtLoginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        } else {
            launchAtLoginItem.isHidden = true
        }
    }
    
    @objc private func openAbout() {
        let alert = NSAlert()
        alert.messageText = "leCG"
        alert.informativeText = """
        A lightweight native macOS menu bar monitor for CPU, GPU & Thermals with live graphics.
        
        Hardware: \(HardwareInfo.shared.summaryString)
        
        Designed for Apple Silicon & macOS Sequoia.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
