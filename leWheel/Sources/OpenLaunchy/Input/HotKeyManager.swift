import Carbon
import AppKit

@MainActor
public protocol HotKeyManagerDelegate: AnyObject {
    func hotKeyPressed()
    func hotKeyReleased()
}

public final class HotKeyManager: @unchecked Sendable {
    public static let shared = HotKeyManager()
    
    public weak var delegate: HotKeyManagerDelegate?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x4F504C59), id: 1) // 'OPLY'
    
    // Support for modifier-only dual press / chords (e.g. Option + Command simultaneously)
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var isModifierChordPressed: Bool = false
    private var targetModifiers: UInt32 = 0
    private var isChordMode: Bool = false
    
    private init() {}
    
    public func register(keyCode: UInt32, modifiers: UInt32, isModifierOnly: Bool = false) {
        unregister()
        
        self.targetModifiers = modifiers
        self.isChordMode = isModifierOnly || (keyCode == 0xFFFF)
        
        if isChordMode {
            setupModifierChordMonitoring()
        } else {
            setupCarbonHotKey(keyCode: keyCode, modifiers: modifiers)
        }
    }
    
    public func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        if let gFlags = globalFlagsMonitor {
            NSEvent.removeMonitor(gFlags)
            globalFlagsMonitor = nil
        }
        if let lFlags = localFlagsMonitor {
            NSEvent.removeMonitor(lFlags)
            localFlagsMonitor = nil
        }
        isModifierChordPressed = false
    }
    
    private func setupCarbonHotKey(keyCode: UInt32, modifiers: UInt32) {
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        
        let handlerProc: EventHandlerUPP = { _, event, _ -> OSStatus in
            guard let event = event else { return noErr }
            let kind = GetEventKind(event)
            
            DispatchQueue.main.async {
                if kind == UInt32(kEventHotKeyPressed) {
                    HotKeyManager.shared.delegate?.hotKeyPressed()
                } else if kind == UInt32(kEventHotKeyReleased) {
                    HotKeyManager.shared.delegate?.hotKeyReleased()
                }
            }
            return noErr
        }
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            handlerProc,
            eventTypes.count,
            &eventTypes,
            nil,
            &eventHandler
        )
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status != noErr {
            print("[OpenLaunchy] Failed to register global hotkey (status: \(status))")
        }
    }
    
    private func setupModifierChordMonitoring() {
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        guard isChordMode else { return }
        
        let optionDown = event.modifierFlags.contains(.option)
        let cmdDown = event.modifierFlags.contains(.command)
        let ctrlDown = event.modifierFlags.contains(.control)
        let shiftDown = event.modifierFlags.contains(.shift)
        
        let reqOption = (targetModifiers & 2048) != 0
        let reqCmd = (targetModifiers & 256) != 0
        let reqCtrl = (targetModifiers & 4096) != 0
        let reqShift = (targetModifiers & 512) != 0
        
        let matchOption = reqOption == optionDown
        let matchCmd = reqCmd == cmdDown
        let matchCtrl = reqCtrl == ctrlDown
        let matchShift = reqShift == shiftDown
        
        let isChordActive = matchOption && matchCmd && matchCtrl && matchShift
        
        if isChordActive && !isModifierChordPressed {
            isModifierChordPressed = true
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.hotKeyPressed()
            }
        } else if !isChordActive && isModifierChordPressed {
            isModifierChordPressed = false
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.hotKeyReleased()
            }
        }
    }
}
