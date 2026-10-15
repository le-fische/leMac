import AppKit
import Foundation
import ApplicationServices

@MainActor
public final class AppLauncher {
    public static let shared = AppLauncher()
    
    private init() {}
    
    /// Executes the primary launch action for a given LaunchItem
    public func launch(item: LaunchItem, hideOthers: Bool = false) {
        switch item.itemType {
        case .application, .runningApp:
            launchApplication(path: item.targetPath, bundleId: item.bundleIdentifier, arguments: item.arguments, hideOthers: hideOthers)
            
        case .fileOrFolder:
            let url = URL(fileURLWithPath: item.targetPath)
            NSWorkspace.shared.open(url)
            
        case .url:
            if let url = URL(string: item.targetPath) {
                NSWorkspace.shared.open(url)
            }
            
        case .shellScript:
            executeShellScript(command: item.targetPath, arguments: item.arguments)
            
        case .action:
            handleBuiltinAction(identifier: item.targetPath)
        }
    }
    
    /// Launches or focuses an application with modern NSWorkspace API, restoring closed windows
    public func launchApplication(path: String, bundleId: String?, arguments: [String] = [], hideOthers: Bool = false) {
        var appURL: URL?
        if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
            appURL = URL(fileURLWithPath: path)
        } else if let bundleId = bundleId {
            appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
        }
        
        if appURL == nil, let bId = bundleId {
            appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bId)
        }
        
        guard let validURL = appURL else {
            NSSound.beep()
            return
        }
        
        let targetBundleId = bundleId ?? Bundle(url: validURL)?.bundleIdentifier
        
        // Find existing running process if any
        var runningApp: NSRunningApplication?
        if let bId = targetBundleId {
            runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bId).first
        }
        if runningApp == nil {
            runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleURL == validURL })
        }
        
        if let app = runningApp {
            // 1. Unhide if hidden
            if app.isHidden {
                app.unhide()
            }
            
            // 2. Bring all windows to front and activate
            app.activate(options: .activateAllWindows)
            
            // 3. Send reopen AppleEvent (kAEReopenApplication) directly to the target process.
            // This is identical to clicking the application in the macOS Dock, causing macOS
            // to send applicationShouldHandleReopen:hasVisibleWindows: to the app delegate.
            // This restores closed windows (Cmd+W) in Terminal, Spotify, Safari, Mail, etc.,
            // and unminimizes minimized windows without requiring permission prompts.
            let targetDesc = NSAppleEventDescriptor(processIdentifier: app.processIdentifier)
            let reopenEvent = NSAppleEventDescriptor(
                eventClass: AEEventClass(kCoreEventClass),
                eventID: AEEventID(kAEReopenApplication),
                targetDescriptor: targetDesc,
                returnID: AEReturnID(kAutoGenerateReturnID),
                transactionID: AETransactionID(kAnyTransactionID)
            )
            _ = try? reopenEvent.sendEvent(options: .noReply, timeout: 0.5)
            
            // 4. Raise windows to ensure top-layer stacking via Accessibility
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var windowsRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
               let windows = windowsRef as? [AXUIElement] {
                for win in windows {
                    var isMinimized: CFTypeRef?
                    if AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &isMinimized) == .success,
                       let minVal = isMinimized as? Bool, minVal {
                        AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                    }
                    AXUIElementPerformAction(win, kAXRaiseAction as CFString)
                }
            }
            
            // 5. Special check for Finder: if Finder has no standard windows open, open user's home directory
            if targetBundleId == "com.apple.finder" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if !self.hasVisibleFinderWindows(finderPID: app.processIdentifier) {
                        NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser)
                    }
                }
            }
            
            if hideOthers {
                hideAllExcept(runningApp: app)
            }
        }
        
        // Always configure and invoke NSWorkspace.shared.openApplication
        // This ensures the window server coordinates focus, brings the app to the front,
        // or starts the process if it wasn't running.
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.hidesOthers = hideOthers
        if !arguments.isEmpty {
            config.arguments = arguments
        }
        
        NSWorkspace.shared.openApplication(at: validURL, configuration: config) { app, error in
            if let app = app {
                Task { @MainActor in
                    app.unhide()
                    app.activate(options: .activateAllWindows)
                }
            }
            if let error = error {
                print("[leWheel] Error launching app at \(validURL): \(error.localizedDescription)")
            }
        }
        
        // Also fire /usr/bin/open as secondary LaunchServices Dock guarantee
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            if let bId = targetBundleId {
                proc.arguments = ["-b", bId]
            } else {
                proc.arguments = ["-a", validURL.path]
            }
            try? proc.run()
        }
    }
    
    private func hasVisibleFinderWindows(finderPID: pid_t) -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        for win in windowList {
            if let pid = win[kCGWindowOwnerPID as String] as? Int,
               pid == Int(finderPID),
               let layer = win[kCGWindowLayer as String] as? Int,
               layer == 0 {
                if let boundsDict = win[kCGWindowBounds as String] as? [String: Any],
                   let w = boundsDict["Width"] as? Double,
                   let h = boundsDict["Height"] as? Double,
                   w > 50 && h > 50 {
                    return true
                }
            }
        }
        return false
    }
    
    /// Terminates an application (used from switcher mode via Cmd+Q)
    public func terminateApplication(item: LaunchItem, force: Bool = false) {
        guard let bundleId = item.bundleIdentifier else { return }
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        for app in runningApps {
            if force {
                app.forceTerminate()
            } else {
                app.terminate()
            }
        }
    }
    
    /// Hides all applications except the target one
    private func hideAllExcept(runningApp: NSRunningApplication) {
        for app in NSWorkspace.shared.runningApplications {
            if app != runningApp && app.activationPolicy == .regular {
                app.hide()
            }
        }
    }
    
    /// Executes a shell command or script
    private func executeShellScript(command: String, arguments: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", ([command] + arguments).joined(separator: " ")]
            do {
                try process.run()
            } catch {
                print("[OpenLaunchy] Script execution error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Built-in utility actions
    private func handleBuiltinAction(identifier: String) {
        switch identifier {
        case "open_settings":
            NotificationCenter.default.post(name: .openLaunchyPreferences, object: nil)
        case "quit":
            NSApp.terminate(nil)
        default:
            break
        }
    }
}

public extension Notification.Name {
    static let openLaunchyPreferences = Notification.Name("OpenLaunchy.OpenPreferences")
    static let toggleRadialMenu = Notification.Name("OpenLaunchy.ToggleRadialMenu")
    static let dismissRadialMenu = Notification.Name("OpenLaunchy.DismissRadialMenu")
    static let cyclePalette = Notification.Name("OpenLaunchy.CyclePalette")
}
