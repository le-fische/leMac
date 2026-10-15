import AppKit

@MainActor
public protocol MouseHookManagerDelegate: AnyObject {
    func mouseButtonPressed(buttonNumber: Int)
    func mouseButtonReleased(buttonNumber: Int)
}

public final class MouseHookManager: @unchecked Sendable {
    public static let shared = MouseHookManager()
    
    public weak var delegate: MouseHookManagerDelegate?
    private var globalMonitorDown: Any?
    private var globalMonitorUp: Any?
    private var localMonitorDown: Any?
    private var localMonitorUp: Any?
    
    private init() {}
    
    public func start() {
        stop()
        
        // Global monitor for otherMouseDown / otherMouseUp
        globalMonitorDown = NSEvent.addGlobalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
            self?.dispatchMouseDown(buttonNumber: event.buttonNumber)
        }
        
        globalMonitorUp = NSEvent.addGlobalMonitorForEvents(matching: .otherMouseUp) { [weak self] event in
            self?.dispatchMouseUp(buttonNumber: event.buttonNumber)
        }
        
        // Local monitor when application is active
        localMonitorDown = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
            self?.dispatchMouseDown(buttonNumber: event.buttonNumber)
            return event
        }
        
        localMonitorUp = NSEvent.addLocalMonitorForEvents(matching: .otherMouseUp) { [weak self] event in
            self?.dispatchMouseUp(buttonNumber: event.buttonNumber)
            return event
        }
    }
    
    public func stop() {
        if let gDown = globalMonitorDown {
            NSEvent.removeMonitor(gDown)
            globalMonitorDown = nil
        }
        if let gUp = globalMonitorUp {
            NSEvent.removeMonitor(gUp)
            globalMonitorUp = nil
        }
        if let lDown = localMonitorDown {
            NSEvent.removeMonitor(lDown)
            localMonitorDown = nil
        }
        if let lUp = localMonitorUp {
            NSEvent.removeMonitor(lUp)
            localMonitorUp = nil
        }
    }
    
    private func dispatchMouseDown(buttonNumber: Int) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let isConfigured = (buttonNumber == 2)
            if isConfigured {
                self.delegate?.mouseButtonPressed(buttonNumber: buttonNumber)
            }
        }
    }
    
    private func dispatchMouseUp(buttonNumber: Int) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let isConfigured = (buttonNumber == 2)
            if isConfigured {
                self.delegate?.mouseButtonReleased(buttonNumber: buttonNumber)
            }
        }
    }
}
