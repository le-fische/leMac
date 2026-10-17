import AppKit
import SwiftUI

@MainActor
public final class StatusBarController: NSObject, NSMenuDelegate {
    public static let shared = StatusBarController()
    
    private var statusItem: NSStatusItem?
    private var preferencesWindow: NSWindow?
    
    private override init() {
        super.init()
    }
    
    public func setup() {
        // Initialize Sparkle auto-updater controller
        _ = SparkleUpdater.shared
        
        if ConfigManager.shared.settings.hideMenuBarIcon {
            return
        }
        createStatusItem()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openPreferences),
            name: .openLaunchyPreferences,
            object: nil
        )
    }
    
    private func createStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            button.image = NSImage(systemSymbolName: "circle.circle", accessibilityDescription: "OpenLaunchy")?.withSymbolConfiguration(config)
        }
        
        // Directly assigning menu ensures clicking the button ONLY opens the options menu!
        item.menu = buildOptionsMenu()
        self.statusItem = item
    }
    
    public func setMenuExtraVisible(_ visible: Bool) {
        if visible {
            createStatusItem()
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }
    
    public func refreshMenu() {
        statusItem?.menu = buildOptionsMenu()
    }
    
    private func buildOptionsMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        
        let settings = ConfigManager.shared.settings
        
        // 1. Settings...
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openPreferences), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // 2. Check for Updates...
        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. Shortcut configuration submenu
        let shortcutSubmenu = NSMenu()
        let presets: [(name: String, code: UInt32, mods: UInt32, disp: String)] = [
            ("Option + Command (⌥⌘) [Dual Press]", 0xFFFF, 2304, "⌥⌘"),
            ("Option + Space (⌥ Space)", 49, 2048, "⌥ Space"),
            ("Control + Space (⌃ Space)", 49, 4096, "⌃ Space"),
            ("Command + Option + Space (⌘ ⌥ Space)", 49, 2304, "⌘ ⌥ Space"),
            ("Option + Tab (⌥ Tab)", 48, 2048, "⌥ Tab")
        ]
        
        for preset in presets {
            let pItem = NSMenuItem(title: preset.name, action: #selector(selectShortcutPreset(_:)), keyEquivalent: "")
            pItem.target = self
            pItem.representedObject = preset
            pItem.state = (settings.hotKeyCode == preset.code && settings.hotKeyModifiers == preset.mods) ? .on : .off
            shortcutSubmenu.addItem(pItem)
        }
        shortcutSubmenu.addItem(NSMenuItem.separator())
        let customizeItem = NSMenuItem(title: "Configure in Settings...", action: #selector(openPreferences), keyEquivalent: "")
        customizeItem.target = self
        shortcutSubmenu.addItem(customizeItem)
        
        let shortcutParent = NSMenuItem(title: "Shortcut: \(settings.hotKeyDisplayString)", action: nil, keyEquivalent: "")
        shortcutParent.submenu = shortcutSubmenu
        menu.addItem(shortcutParent)
        
        // 3. Max Items on Wheel Submenu
        let itemsSubmenu = NSMenu()
        let itemCounts = [4, 6, 8, 10, 12, 0] // 0 means All/Unlimited
        for count in itemCounts {
            let title = count == 0 ? "All Apps (Unlimited)" : "\(count) Apps" + (count == 8 ? " (Default)" : "")
            let countItem = NSMenuItem(title: title, action: #selector(selectItemCount(_:)), keyEquivalent: "")
            countItem.target = self
            countItem.tag = count
            countItem.state = settings.maxWheelItems == count ? .on : .off
            itemsSubmenu.addItem(countItem)
        }
        let itemsParent = NSMenuItem(title: "Items on Wheel: \(settings.maxWheelItems == 0 ? "Unlimited" : "\(settings.maxWheelItems)")", action: nil, keyEquivalent: "")
        itemsParent.submenu = itemsSubmenu
        menu.addItem(itemsParent)
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Mode Switcher (Running vs User Apps)
        let modeItem = NSMenuItem(
            title: settings.isRunningAppsMode ? "Switch to User Palette ([ or ])" : "Switch to Running Apps ([ or ])",
            action: #selector(toggleMode),
            keyEquivalent: ""
        )
        modeItem.target = self
        menu.addItem(modeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. Quit leWheel
        let quitItem = NSMenuItem(title: "Quit leWheel", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        return menu
    }
    
    // MARK: - Menu Actions
    @objc private func selectShortcutPreset(_ sender: NSMenuItem) {
        if let preset = sender.representedObject as? (name: String, code: UInt32, mods: UInt32, disp: String) {
            ConfigManager.shared.updateShortcut(keyCode: preset.code, modifiers: preset.mods, display: preset.disp)
            refreshMenu()
        }
    }
    
    @objc private func selectItemCount(_ sender: NSMenuItem) {
        ConfigManager.shared.setMaxWheelItems(sender.tag)
        refreshMenu()
        RadialWindowController.shared.updateContentView()
    }
    
    @objc private func toggleMode() {
        ConfigManager.shared.toggleRunningAppsMode()
        refreshMenu()
        RadialWindowController.shared.updateContentView()
    }
    
    @objc public func openPreferences() {
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "leWheel Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.isReleasedWhenClosed = false
        
        self.preferencesWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func checkForUpdates() {
        SparkleUpdater.shared.checkForUpdates()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
        exit(0)
    }
    
    // MARK: - NSMenuDelegate
    public func menuWillOpen(_ menu: NSMenu) {
        // Refresh checkmarks dynamically before menu displays
        statusItem?.menu = buildOptionsMenu()
    }
}
