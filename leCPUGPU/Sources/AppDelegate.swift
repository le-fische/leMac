import AppKit

public class AppDelegate: NSObject, NSApplicationDelegate, MenuControllerDelegate {
    private var statusItem: NSStatusItem!
    private var menuController: MenuController!
    private var refreshTimer: Timer?
    private var isSleeping: Bool = false
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize menu controller
        menuController = MenuController()
        menuController.delegate = self
        
        // Configure NSStatusItem
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = menuController.menu
        
        // Register sleep / wake observers to save power
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(macWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        nc.addObserver(self, selector: #selector(macDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        
        // Initial tick & timer setup
        startTimer()
        tick()
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        stopTimer()
    }
    
    // MARK: - Timer Management
    
    private func startTimer() {
        stopTimer()
        guard !isSleeping else { return }
        
        var interval = UserDefaults.standard.double(forKey: "leCPUGPU.RefreshInterval")
        if interval <= 0.05 {
            interval = 1.0
        }
        
        let timer = Timer(timeInterval: interval, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.refreshTimer = timer
    }
    
    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    @objc private func tick() {
        guard !isSleeping else { return }
        
        let monitor = SystemMonitor.shared
        monitor.update(includeProcesses: false)
        
        let thermal = ThermalMonitor.shared
        thermal.updateIfNeeded()
        
        let image = GraphRenderer.shared.renderImage(
            cpu: monitor.cpuTotalUsage,
            gpu: monitor.gpuUsage,
            cpuHistory: monitor.cpuHistory,
            gpuHistory: monitor.gpuHistory,
            cpuTemp: thermal.cpuTemperature,
            gpuTemp: thermal.gpuTemperature
        )
        
        if let button = statusItem.button {
            button.image = image
            let cpuT = thermal.format(celsius: thermal.cpuTemperature, short: false)
            let gpuT = thermal.format(celsius: thermal.gpuTemperature, short: false)
            let peakT = thermal.format(celsius: thermal.peakTemperature, short: false)
            button.toolTip = String(
                format: "CPU: %.1f%% (%@)  •  GPU: %.1f%% (%@)  •  RAM: %.0f%%  •  SoC Peak: %@ (%@)",
                monitor.cpuTotalUsage,
                cpuT,
                monitor.gpuUsage,
                gpuT,
                monitor.ramUsagePercentage,
                peakT,
                thermal.thermalStateString
            )
        }
        
        menuController.updateMetrics(monitor: monitor)
    }
    
    // MARK: - Power & Sleep Handling
    
    @objc private func macWillSleep() {
        isSleeping = true
        stopTimer()
    }
    
    @objc private func macDidWake() {
        isSleeping = false
        startTimer()
        tick()
    }
    
    // MARK: - MenuControllerDelegate
    
    public func didChangeStyle(_ style: GraphStyle) {
        tick()
    }
    
    public func didChangeTheme(_ theme: ColorTheme) {
        tick()
    }
    
    public func didChangeRefreshInterval(_ interval: TimeInterval) {
        startTimer()
        tick()
    }
    
    public func didChangeMetricMode(_ mode: MetricDisplayMode) {
        tick()
    }
    
    public func didChangeTempUnit(_ unit: TemperatureUnit) {
        tick()
    }
}
