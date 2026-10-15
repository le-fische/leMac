import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var dotItem: NSStatusItem!
    private var spacerItem: NSStatusItem!
    private var autoCollapseTimer: Timer?
    private var isCollapsed: Bool = false
    
    private let dotAutosaveName = "leMinibar_Dot"
    private let spacerAutosaveName = "leMinibar_Spacer"
    
    let preferences = Preferences.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // Pure menu-bar accessory app (no Dock icon)
        
        setupInitialPositions()
        setupStatusItems()
        
        // Start in open state (or saved state, defaulting to false on first launch so user sees the dot)
        isCollapsed = preferences.isCollapsed
        updateState()
        
        // Show brief instruction tip on first launch
        if !preferences.hasSeenWelcome {
            preferences.hasSeenWelcome = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.showWelcomeAlert()
            }
        }
    }
    
    // MARK: - Position Anchoring (1:1 Ice layout logic)
    
    private func setupInitialPositions() {
        let defaults = UserDefaults.standard
        let dotKey = "NSStatusItem Preferred Position \(dotAutosaveName)"
        let spacerKey = "NSStatusItem Preferred Position \(spacerAutosaveName)"
        
        let existingDotPos = defaults.double(forKey: dotKey)
        let dotPos = existingDotPos > 0 ? existingDotPos : 340.0
        defaults.set(dotPos, forKey: dotKey)
        defaults.set(dotPos + 1.0, forKey: spacerKey)
    }
    
    private func setupStatusItems() {
        // 1. The Single Dot Button (Visible control)
        dotItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        dotItem.autosaveName = dotAutosaveName
        
        if let button = dotItem.button {
            button.target = self
            button.action = #selector(dotButtonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "leMinibar: Click to hide/show apps. Right-click for options."
        }
        
        // 2. The Spacer (100% invisible delimiter)
        spacerItem = NSStatusBar.system.statusItem(withLength: 0)
        spacerItem.autosaveName = spacerAutosaveName
        spacerItem.button?.cell?.isEnabled = false
    }
    
    // MARK: - Actions
    
    @objc private func dotButtonClicked() {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp ||
            (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true)
        
        if isRightClick {
            showContextMenu()
        } else {
            toggle()
        }
    }
    
    @objc func toggle() {
        isCollapsed.toggle()
        preferences.isCollapsed = isCollapsed
        updateState()
        
        // Handle Auto-collapse timer
        autoCollapseTimer?.invalidate()
        autoCollapseTimer = nil
        
        if !isCollapsed && preferences.autoCollapseDuration != .never {
            let delay = Double(preferences.autoCollapseDuration.rawValue)
            autoCollapseTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                guard let self = self, !self.isCollapsed else { return }
                self.isCollapsed = true
                self.preferences.isCollapsed = true
                self.updateState()
            }
        }
    }
    
    private func updateState() {
        updateDotIcon()
        
        // Keep spacer position synchronized next to dot
        let dotPos = UserDefaults.standard.double(forKey: "NSStatusItem Preferred Position \(dotAutosaveName)")
        if dotPos > 0 {
            UserDefaults.standard.set(dotPos + 1.0, forKey: "NSStatusItem Preferred Position \(spacerAutosaveName)")
        }
        
        if isCollapsed {
            spacerItem.length = 10000
        } else {
            spacerItem.length = 0
        }
    }
    
    private func updateDotIcon() {
        guard let button = dotItem.button else { return }
        // Ice 1:1 behavior:
        // Closed / Collapsed (apps hidden): FULL circle (●)
        // Open / Expanded (apps shown): OPEN circle (○)
        button.image = makeDotImage(filled: isCollapsed)
        button.image?.isTemplate = true
        button.title = ""
    }
    
    // MARK: - Native Dot Image (Pixel-perfect & Razor-Sharp)
    
    private func makeDotImage(filled: Bool) -> NSImage {
        let canvasSize: CGFloat = 16.0
        let diameter: CGFloat = CGFloat(preferences.dotSize.diameter)
        let origin = round((canvasSize - diameter) / 2.0 * 2.0) / 2.0
        
        let size = NSSize(width: canvasSize, height: canvasSize)
        let image = NSImage(size: size, flipped: false) { rect in
            if filled {
                let circleRect = NSRect(x: origin, y: origin, width: diameter, height: diameter)
                let path = NSBezierPath(ovalIn: circleRect)
                NSColor.labelColor.setFill()
                path.fill()
            } else {
                // Ultra-fine Apple hairline stroke (0.85 pt) matching AirPods & Control Center icons
                let lineWidth: CGFloat = 0.85
                let inset = lineWidth / 2.0
                let circleRect = NSRect(
                    x: origin + inset,
                    y: origin + inset,
                    width: diameter - lineWidth,
                    height: diameter - lineWidth
                )
                let path = NSBezierPath(ovalIn: circleRect)
                path.lineWidth = lineWidth
                NSColor.labelColor.setStroke()
                path.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
    
    // MARK: - Context Menu
    
    private func showContextMenu() {
        guard let button = dotItem.button else { return }
        
        let menu = NSMenu(title: "leMinibar")
        
        let statusTitle = isCollapsed ? "Expand Hidden Apps" : "Collapse Hidden Apps"
        let statusItem = NSMenuItem(title: statusTitle, action: #selector(toggle), keyEquivalent: "")
        statusItem.target = self
        menu.addItem(statusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Auto-collapse Submenu
        let timerMenu = NSMenu(title: "Auto-Collapse")
        for duration in AutoCollapseDuration.allCases {
            let item = NSMenuItem(title: duration.title, action: #selector(changeAutoCollapse(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = duration
            item.state = (preferences.autoCollapseDuration == duration) ? .on : .off
            timerMenu.addItem(item)
        }
        let timerMenuItem = NSMenuItem(title: "Auto-Collapse Timer", action: nil, keyEquivalent: "")
        timerMenuItem.submenu = timerMenu
        menu.addItem(timerMenuItem)
        
        // Dot Size Submenu
        let sizeMenu = NSMenu(title: "Dot Size")
        for size in DotSize.allCases {
            let item = NSMenuItem(title: size.rawValue, action: #selector(changeDotSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = size
            item.state = (preferences.dotSize == size) ? .on : .off
            sizeMenu.addItem(item)
        }
        let sizeMenuItem = NSMenuItem(title: "Dot Size", action: nil, keyEquivalent: "")
        sizeMenuItem.submenu = sizeMenu
        menu.addItem(sizeMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Launch at Login
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(loginItem)
        
        // How to use
        let helpItem = NSMenuItem(title: "How to Organize...", action: #selector(showWelcomeAlert), keyEquivalent: "")
        helpItem.target = self
        menu.addItem(helpItem)
        
        // Privacy / Info
        let aboutItem = NSMenuItem(title: "Privacy & Info", action: #selector(showAboutAlert), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit leMinibar", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }
    
    @objc private func changeAutoCollapse(_ sender: NSMenuItem) {
        if let duration = sender.representedObject as? AutoCollapseDuration {
            preferences.autoCollapseDuration = duration
        }
    }
    
    @objc private func changeDotSize(_ sender: NSMenuItem) {
        if let size = sender.representedObject as? DotSize {
            preferences.dotSize = size
            updateDotIcon()
        }
    }
    
    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let current = isLaunchAtLoginEnabled()
        setLaunchAtLogin(!current)
    }
    
    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
    
    private func setLaunchAtLogin(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                let alert = NSAlert()
                alert.messageText = "Launch at Login"
                alert.informativeText = "Note: To enable Launch at Login, leMinibar.app must be placed in your /Applications folder.\n\nError: \(error.localizedDescription)"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    @objc private func showWelcomeAlert() {
        let alert = NSAlert()
        alert.messageText = "How to use leMinibar"
        alert.informativeText = """
        leMinibar is 1:1 like Ice, with ZERO permissions needed:

        1. Single Dot Button:
           • Full circle (●) = Closed (apps hidden).
           • Open circle (○) = Open (apps shown).

        2. Organizing your apps:
           • Hold the ⌘ (Command) key and drag the Dot anywhere in your menu bar.
           • Apps to the LEFT of the Dot will be hidden when closed.
           • Apps to the RIGHT of the Dot stay visible at all times.

        3. Options:
           • Right-click the Dot for options (auto-collapse timer, launch at login).
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Got it!")
        alert.runModal()
    }
    
    @objc private func showAboutAlert() {
        let alert = NSAlert()
        alert.messageText = "About leMinibar"
        alert.informativeText = """
        • 1:1 Ice Replica
        • 100% Private (0 permissions required)
        • Zero background battery or CPU drain
        • Single clean dot control
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Close")
        alert.runModal()
    }
    
    @objc private func quitApp() {
        spacerItem.length = 0
        NSApp.terminate(nil)
    }
}
