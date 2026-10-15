import AppKit
import Combine

@MainActor
public final class RunningAppsManager: ObservableObject {
    public static let shared = RunningAppsManager()
    
    @Published public private(set) var runningApps: [LaunchItem] = []
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        refreshRunningApps()
        setupWorkspaceNotifications()
    }
    
    public func refreshRunningApps() {
        let activeApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
        
        var items: [LaunchItem] = []
        for (index, app) in activeApps.enumerated() {
            let name = app.localizedName ?? "Application"
            let path = app.bundleURL?.path ?? ""
            let bundleId = app.bundleIdentifier
            let shortcutKey = index < 9 ? "\(index + 1)" : nil
            
            items.append(LaunchItem(
                title: name,
                targetPath: path,
                itemType: .runningApp,
                shortcutKey: shortcutKey,
                bundleIdentifier: bundleId
            ))
        }
        
        self.runningApps = items
    }
    
    private func setupWorkspaceNotifications() {
        let center = NSWorkspace.shared.notificationCenter
        
        center.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshRunningApps() }
            .store(in: &cancellables)
            
        center.publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshRunningApps() }
            .store(in: &cancellables)
            
        center.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshRunningApps() }
            .store(in: &cancellables)
    }
}
