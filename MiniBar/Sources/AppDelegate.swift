import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var toggleItem: NSStatusItem!
    var separatorItem: NSStatusItem!
    var autoCollapseTimer: Timer?
    var isCollapsed: Bool = false
    
    let preferences = Preferences.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // Pure menu-bar app (no Dock icon)
        
        isCollapsed = preferences.isCollapsed
        
        setupToggleItem()
        setupSeparatorItem()
        
        updateState()
        
        if !preferences.hasSeenWelcome {
            preferences.hasSeenWelcome = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showWelcomeAlert()
            }
        }
    }
    
    // MARK: - Status Items Setup
    
    private func setupToggleItem() {
        toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = toggleItem.button else { return }
        
        button.target = self
        button.action = #selector(toggleButtonClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "MiniBar: Click to toggle. Right-click for options."
    }
    
    private func setupSeparatorItem() {
        separatorItem = NSStatusBar.system.statusItem(withLength: 14)
        guard let button = separatorItem.button else { return }
        
        button.image = makeSeparatorImage()
        button.toolTip = "MiniBar Divider: Hold ⌘ (Command) and drag this line to set which apps hide."
        button.target = self
        button.action = #selector(separatorClicked)
    }
    
    // MARK: - Actions
    
    @objc private func toggleButtonClicked() {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp ||
            (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true)
        
        if isRightClick {
            showContextMenu()
        } else {
            toggle()
        }
    }
    
    @objc private func separatorClicked() {
        let alert = NSAlert()
        alert.messageText = "MiniBar Divider"
        alert.informativeText = "Hold the ⌘ (Command) key and drag this divider left or right in your menu bar.\n\n• Icons to the LEFT of this divider will be hidden.\n• Icons to the RIGHT will stay visible."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Got it")
        alert.runModal()
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
        updateToggleIcon()
        
        if isCollapsed {
            separatorItem.length = 10000
            separatorItem.button?.image = nil
        } else {
            separatorItem.length = 14
            separatorItem.button?.image = makeSeparatorImage()
        }
    }
    
    private func updateToggleIcon() {
        guard let button = toggleItem.button else { return }
        
        let style = preferences.iconStyle
        switch style {
        case .dot:
            let symbolName = isCollapsed ? "circle" : "circle.fill"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "MiniBar Toggle")
            button.title = ""
        case .chevron:
            let symbolName = isCollapsed ? "chevron.compact.right" : "chevron.compact.left"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "MiniBar Toggle")
            button.title = ""
        case .line:
            let symbolName = isCollapsed ? "minus" : "line.3.horizontal"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "MiniBar Toggle")
            button.title = ""
        case .tray:
            let symbolName = isCollapsed ? "tray" : "tray.full.fill"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "MiniBar Toggle")
            button.title = ""
        }
        button.image?.isTemplate = true
    }
    
    // MARK: - Visual Separator
    
    private func makeSeparatorImage() -> NSImage {
        let size = NSSize(width: 14, height: 22)
        let image = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 7, y: 4))
            path.line(to: NSPoint(x: 7, y: 18))
            path.lineWidth = 1.3
            NSColor.secondaryLabelColor.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
    
    // MARK: - Context Menu
    
    private func showContextMenu() {
        guard let button = toggleItem.button else { return }
        
        let menu = NSMenu(title: "MiniBar Options")
        
        let statusTitle = isCollapsed ? "Expand Hidden Apps" : "Collapse Hidden Apps"
        let statusItem = NSMenuItem(title: statusTitle, action: #selector(toggle), keyEquivalent: "")
        statusItem.target = self
        menu.addItem(statusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Icon Style Submenu
        let styleMenu = NSMenu(title: "Icon Style")
        for style in IconStyle.allCases {
            let item = NSMenuItem(title: style.rawValue, action: #selector(changeIconStyle(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = style
            item.state = (preferences.iconStyle == style) ? .on : .off
            styleMenu.addItem(item)
        }
        let styleMenuItem = NSMenuItem(title: "Toggle Icon Style", action: nil, keyEquivalent: "")
        styleMenuItem.submenu = styleMenu
        menu.addItem(styleMenuItem)
        
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
        
        menu.addItem(NSMenuItem.separator())
        
        // Launch at Login
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(loginItem)
        
        // Instructions
        let helpItem = NSMenuItem(title: "How to Rearrange...", action: #selector(showWelcomeAlert), keyEquivalent: "")
        helpItem.target = self
        menu.addItem(helpItem)
        
        // Privacy / About
        let aboutItem = NSMenuItem(title: "Privacy & Info", action: #selector(showAboutAlert), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit MiniBar", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }
    
    @objc private func changeIconStyle(_ sender: NSMenuItem) {
        if let style = sender.representedObject as? IconStyle {
            preferences.iconStyle = style
            updateToggleIcon()
        }
    }
    
    @objc private func changeAutoCollapse(_ sender: NSMenuItem) {
        if let duration = sender.representedObject as? AutoCollapseDuration {
            preferences.autoCollapseDuration = duration
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
                alert.informativeText = "Note: To enable Launch at Login, MiniBar.app must be placed in your /Applications folder.\n\nError: \(error.localizedDescription)"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    @objc private func showWelcomeAlert() {
        let alert = NSAlert()
        alert.messageText = "How to use MiniBar"
        alert.informativeText = """
        MiniBar keeps your top bar tidy with ZERO permissions needed:

        1. Hold ⌘ (Command) and drag the divider line (|) to place it between the icons you want to HIDE and the icons you want to KEEP VISIBLE.
        2. Click the MiniBar dot (●) to collapse or reveal the hidden icons.
        3. Right-click the dot anytime to change icon style (dot, arrow, line, drawer), set an auto-collapse timer, or enable Launch at Login.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Got it!")
        alert.runModal()
    }
    
    @objc private func showAboutAlert() {
        let alert = NSAlert()
        alert.messageText = "About MiniBar"
        alert.informativeText = """
        • 100% Private & Open Source
        • ZERO Accessibility permissions
        • ZERO Screen Recording permissions
        • ZERO Network connections
        • 0.0% Battery & CPU usage when idle
        
        Built natively in Swift for macOS Sequoia.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Awesome")
        alert.runModal()
    }
    
    @objc private func quitApp() {
        separatorItem.length = 0
        NSApp.terminate(nil)
    }
}
