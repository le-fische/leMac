import AppKit
import SwiftUI

public final class RadialPanel: NSPanel {
    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { true }
}

@MainActor
public final class RadialWindowController: NSObject, ObservableObject {
    public static let shared = RadialWindowController()
    
    private var window: RadialPanel?
    private var hostingView: NSHostingView<AnyView>?
    
    @Published public var isVisible: Bool = false
    @Published public var hoveredIndex: Int? = nil
    @Published public var lastPressedKey: String? = nil
    
    private var localEventMonitor: Any?
    private var globalMouseMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var isTriggerHeld: Bool = false
    private var keyBadgeTimer: Timer?
    private var spawnMouseLocation: NSPoint?
    
    private override init() {
        super.init()
        setupWindow()
    }
    
    private func setupWindow() {
        let panel = RadialPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 320),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        
        self.window = panel
        updateContentView()
    }
    
    public func updateContentView() {
        let view = RadialMenuView(
            controller: self,
            isPreview: false,
            onSelect: { [weak self] item in
                self?.executeLaunch(item: item)
            }
        )
        
        hostingView = NSHostingView(rootView: AnyView(view))
        window?.contentView = hostingView
    }
    
    // MARK: - Presentation & Positioning
    public func toggle() {
        if isVisible {
            hide()
        } else {
            show(asHoldGesture: true)
        }
    }
    
    public func show(asHoldGesture: Bool = true) {
        guard let window = window else { return }
        isTriggerHeld = asHoldGesture
        hoveredIndex = nil
        lastPressedKey = nil
        
        let settings = ConfigManager.shared.settings
        let dimension = settings.menuSize + 40
        let size = NSSize(width: dimension, height: dimension)
        window.setContentSize(size)
        
        // Spawn centered directly at mouse cursor
        let mousePoint = NSEvent.mouseLocation
        self.spawnMouseLocation = mousePoint
        
        let origin = NSPoint(
            x: mousePoint.x - (dimension / 2.0),
            y: mousePoint.y - (dimension / 2.0)
        )
        window.setFrameOrigin(origin)
        updateContentView()
        
        window.alphaValue = 0.0
        window.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.10
            window.animator().alphaValue = 1.0
        }
        
        isVisible = true
        startEventTracking()
    }
    
    public func hide() {
        guard isVisible, let window = window else { return }
        stopEventTracking()
        isTriggerHeld = false
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            window.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                window.orderOut(nil)
                self?.isVisible = false
                self?.hoveredIndex = nil
                self?.lastPressedKey = nil
            }
        })
    }
    
    // MARK: - Hold & Release Trigger Handling
    public func triggerHeld() {
        if !isVisible {
            show(asHoldGesture: true)
        }
    }
    
    public func triggerReleased() {
        guard isVisible else { return }
        isTriggerHeld = false
        
        // Re-evaluate mouse position right at the instant of release
        updateHoverAtCurrentMouse()
        
        // If an app was highlighted when the shortcut was released, launch it!
        if let item = currentHoveredItem() {
            executeLaunch(item: item)
        } else {
            // Otherwise fade away immediately
            hide()
        }
    }
    
    public func updateHoverAtCurrentMouse() {
        guard isVisible, let spawn = spawnMouseLocation else { return }
        let currentMouse = NSEvent.mouseLocation
        
        let dx = currentMouse.x - spawn.x
        let dy = -(currentMouse.y - spawn.y) // Cocoa +y is upwards, SwiftUI +y is downwards
        let distance = sqrt(dx * dx + dy * dy)
        let angle = RadialMath.clockwiseAngle(dx: dx, dy: dy)
        
        let settings = ConfigManager.shared.settings
        let total = ConfigManager.shared.activeItems.count
        guard total > 0 else { return }
        
        if distance < settings.innerRadius {
            // Inside the center hole (deadzone)
            if hoveredIndex != nil {
                hoveredIndex = nil
            }
        } else {
            // Outside the center deadzone: firmly select sector in that direction
            if let newIdx = RadialMath.sectorIndex(for: angle, count: total) {
                if hoveredIndex != newIdx {
                    hoveredIndex = newIdx
                    if settings.enableHapticFeedback {
                        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    }
                }
            }
        }
    }
    
    // MARK: - Action Execution
    private func executeLaunch(item: LaunchItem) {
        // Immediately dismiss panel and stop tracking so the target app's window takes top layer
        stopEventTracking()
        isTriggerHeld = false
        window?.orderOut(nil)
        isVisible = false
        hoveredIndex = nil
        lastPressedKey = nil
        
        AppLauncher.shared.launch(item: item)
    }
    
    private func currentHoveredItem() -> LaunchItem? {
        let items = ConfigManager.shared.activeItems
        guard let idx = hoveredIndex, idx >= 0, idx < items.count else { return nil }
        return items[idx]
    }
    
    // MARK: - Event Tracking
    private func startEventTracking() {
        stopEventTracking()
        
        // Track mouse movement and clicks locally
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseUp, .keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            self?.handleEvent(event)
            return nil
        }
        
        // Track mouse movement globally while wheel is open
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseUp]) { [weak self] event in
            self?.handleEvent(event)
        }
        
        // Track modifier key releases globally (e.g. user releases Option)
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyUp]) { [weak self] event in
            self?.handleFlagsOrKeyUp(event)
        }
    }
    
    private func stopEventTracking() {
        if let local = localEventMonitor {
            NSEvent.removeMonitor(local)
            localEventMonitor = nil
        }
        if let global = globalMouseMonitor {
            NSEvent.removeMonitor(global)
            globalMouseMonitor = nil
        }
        if let flags = globalFlagsMonitor {
            NSEvent.removeMonitor(flags)
            globalFlagsMonitor = nil
        }
    }
    
    private func handleFlagsOrKeyUp(_ event: NSEvent) {
        guard isVisible, isTriggerHeld else { return }
        
        let settings = ConfigManager.shared.settings
        
        if event.type == .flagsChanged {
            let optionDown = event.modifierFlags.contains(.option)
            let cmdDown = event.modifierFlags.contains(.command)
            let ctrlDown = event.modifierFlags.contains(.control)
            let shiftDown = event.modifierFlags.contains(.shift)
            
            if settings.isModifierChord {
                var allChordModifiersHeld = true
                if (settings.hotKeyModifiers & 2048) != 0 && !optionDown { allChordModifiersHeld = false }
                if (settings.hotKeyModifiers & 256) != 0 && !cmdDown { allChordModifiersHeld = false }
                if (settings.hotKeyModifiers & 4096) != 0 && !ctrlDown { allChordModifiersHeld = false }
                if (settings.hotKeyModifiers & 512) != 0 && !shiftDown { allChordModifiersHeld = false }
                
                // If any modifier in the dual-press chord was released, release trigger
                if !allChordModifiersHeld {
                    triggerReleased()
                }
            } else {
                var modifierStillHeld = false
                if (settings.hotKeyModifiers & 2048) != 0 && optionDown { modifierStillHeld = true }
                if (settings.hotKeyModifiers & 256) != 0 && cmdDown { modifierStillHeld = true }
                if (settings.hotKeyModifiers & 4096) != 0 && ctrlDown { modifierStillHeld = true }
                if (settings.hotKeyModifiers & 512) != 0 && shiftDown { modifierStillHeld = true }
                
                if !modifierStillHeld {
                    triggerReleased()
                }
            }
        } else if event.type == .keyUp {
            if event.keyCode == settings.hotKeyCode {
                if !event.modifierFlags.contains(.option) && !event.modifierFlags.contains(.command) {
                    triggerReleased()
                }
            }
        }
    }
    
    private func handleEvent(_ event: NSEvent) {
        guard isVisible else { return }
        
        switch event.type {
        case .mouseMoved:
            updateHoverAtCurrentMouse()
            
        case .leftMouseUp:
            updateHoverAtCurrentMouse()
            if let item = currentHoveredItem() {
                executeLaunch(item: item)
            } else {
                hide()
            }
            
        case .flagsChanged, .keyUp:
            handleFlagsOrKeyUp(event)
            
        case .keyDown:
            handleKeyDown(event: event)
            
        default:
            break
        }
    }
    
    private func handleKeyDown(event: NSEvent) {
        // Escape dismisses
        if event.keyCode == 53 {
            hide()
            return
        }
        
        // Return or Space launches
        if event.keyCode == 36 || event.keyCode == 49 {
            if let item = currentHoveredItem() {
                executeLaunch(item: item)
            }
            return
        }
        
        // Mode switch: [ or ]
        if event.charactersIgnoringModifiers == "[" || event.charactersIgnoringModifiers == "]" {
            ConfigManager.shared.toggleRunningAppsMode()
            hoveredIndex = nil
            updateContentView()
            return
        }
        
        // Arrow navigation
        if event.keyCode == 124 || event.keyCode == 125 || event.keyCode == 48 { // Right, Down, Tab
            stepHovered(forward: true)
            return
        }
        if event.keyCode == 123 || event.keyCode == 126 { // Left, Up
            stepHovered(forward: false)
            return
        }
        
        // Cmd+Q terminates application
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
            if let item = currentHoveredItem() {
                AppLauncher.shared.terminateApplication(item: item)
                ConfigManager.shared.settings.isRunningAppsMode = true
                RunningAppsManager.shared.refreshRunningApps()
                updateContentView()
            }
            return
        }
        
        // Single Keypress Selection (A–Z)
        if let char = event.charactersIgnoringModifiers?.lowercased().first, char.isLetter {
            selectByLetter(char: char)
        }
    }
    
    private func stepHovered(forward: Bool) {
        let items = ConfigManager.shared.activeItems
        let count = items.count
        guard count > 0 else { return }
        
        let current = hoveredIndex ?? -1
        let next = forward ? (current + 1) % count : (current - 1 + count) % count
        hoveredIndex = next
        
        if ConfigManager.shared.settings.enableHapticFeedback {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
    }
    
    private func selectByLetter(char: Character) {
        let items = ConfigManager.shared.activeItems
        let count = items.count
        guard count > 0 else { return }
        
        lastPressedKey = String(char)
        keyBadgeTimer?.invalidate()
        keyBadgeTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.lastPressedKey = nil
            }
        }
        
        var matchingIndices: [Int] = []
        for (idx, item) in items.enumerated() {
            if let first = item.title.lowercased().first, first == char {
                matchingIndices.append(idx)
            }
        }
        
        guard !matchingIndices.isEmpty else { return }
        
        if let current = hoveredIndex, let matchPos = matchingIndices.firstIndex(of: current) {
            let nextMatch = matchingIndices[(matchPos + 1) % matchingIndices.count]
            hoveredIndex = nextMatch
        } else {
            hoveredIndex = matchingIndices.first
        }
        
        if ConfigManager.shared.settings.enableHapticFeedback {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
    }
}
