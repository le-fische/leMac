import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, HotKeyManagerDelegate, MouseHookManagerDelegate {
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory app (menu bar extra, zero Dock clutter)
        NSApp.setActivationPolicy(.accessory)
        
        // Setup status bar icon
        StatusBarController.shared.setup()
        
        // Warm up radial window controller
        _ = RadialWindowController.shared
        
        // Register global hotkey
        let settings = ConfigManager.shared.settings
        HotKeyManager.shared.delegate = self
        HotKeyManager.shared.register(keyCode: settings.hotKeyCode, modifiers: settings.hotKeyModifiers, isModifierOnly: settings.isModifierChord)
        
        // Setup mouse monitoring
        MouseHookManager.shared.delegate = self
        MouseHookManager.shared.start()
        
        print("[leWheel] Successfully initialized and running.")
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
        MouseHookManager.shared.stop()
    }
    
    // MARK: - HotKeyManagerDelegate
    public func hotKeyPressed() {
        let settings = ConfigManager.shared.settings
        if settings.holdToPreviewReleaseToLaunch {
            RadialWindowController.shared.triggerHeld()
        } else {
            RadialWindowController.shared.toggle()
        }
    }
    
    public func hotKeyReleased() {
        let settings = ConfigManager.shared.settings
        if settings.holdToPreviewReleaseToLaunch {
            RadialWindowController.shared.triggerReleased()
        }
    }
    
    // MARK: - MouseHookManagerDelegate
    public func mouseButtonPressed(buttonNumber: Int) {
        let settings = ConfigManager.shared.settings
        if settings.holdToPreviewReleaseToLaunch {
            RadialWindowController.shared.triggerHeld()
        } else {
            RadialWindowController.shared.toggle()
        }
    }
    
    public func mouseButtonReleased(buttonNumber: Int) {
        let settings = ConfigManager.shared.settings
        if settings.holdToPreviewReleaseToLaunch {
            RadialWindowController.shared.triggerReleased()
        }
    }
}
