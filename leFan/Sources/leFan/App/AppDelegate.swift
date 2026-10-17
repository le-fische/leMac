import Cocoa
import SwiftUI
import Combine

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    public static var shared: AppDelegate?

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var mainWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    private let menuBarImage: NSImage? = {
        let img = NSImage(systemSymbolName: "fanblades.fill", accessibilityDescription: "Fan")
        img?.isTemplate = true
        return img
    }()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        _ = SoftwareUpdater.shared
        setupMenuBar()
        setupPopover()
        observeAppState()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let window = NSApplication.shared.windows.first(where: { !$0.className.contains("StatusBar") }) {
                self.mainWindow = window
                window.delegate = self
                window.isReleasedWhenClosed = false
                window.title = "leFan"
                window.subtitle = AppState.shared.macModelName
                window.minSize = NSSize(width: 850, height: 620)
                window.makeKeyAndOrderFront(self)
                NSApp.activate(ignoringOtherApps: true)
                AppState.shared.isMainWindowVisible = true
            }
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = menuBarImage
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover(_:))
            button.target = self
            updateStatusItemTitle()
        }
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 290, height: 380)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView(
                appState: AppState.shared,
                onOpenMainWindow: { [weak self] in
                    self?.openMainWindow()
                },
                onQuit: {
                    NSApplication.shared.terminate(nil)
                }
            )
        )
        self.popover = popover
    }

    private func observeAppState() {
        // Throttle menu bar updates and coalesce multiple property changes into a single redraw
        Publishers.CombineLatest3(AppState.shared.$averageRPM, AppState.shared.$highestTemp, AppState.shared.$settings)
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.updateStatusItemTitle()
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemTitle() {
        guard let button = statusItem?.button else { return }
        let state = AppState.shared

        let newTitle: String
        switch state.settings.menuBarMode {
        case .rpmAndTemp:
            let rpmStr = "\(Int(state.averageRPM)) RPM"
            let tempStr = state.formatTemp(state.highestTemp)
            newTitle = " \(rpmStr)  \(tempStr)"
        case .rpmOnly:
            let rpmStr = "\(Int(state.averageRPM)) RPM"
            newTitle = " \(rpmStr)"
        case .tempOnly:
            let tempStr = state.formatTemp(state.highestTemp)
            newTitle = " \(tempStr)"
        case .iconOnly:
            newTitle = ""
        }

        // Only update if changed to avoid unnecessary AppKit layout passes
        if button.title != newTitle {
            button.title = newTitle
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover = popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    public func openMainWindow() {
        popover?.performClose(nil)
        if let window = mainWindow {
            window.makeKeyAndOrderFront(self)
            NSApplication.shared.activate(ignoringOtherApps: true)
            AppState.shared.isMainWindowVisible = true
        } else if let window = NSApplication.shared.windows.first(where: { !$0.className.contains("StatusBar") }) {
            self.mainWindow = window
            window.delegate = self
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(self)
            NSApplication.shared.activate(ignoringOtherApps: true)
            AppState.shared.isMainWindowVisible = true
        }
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openMainWindow()
        }
        return true
    }

    public func checkForUpdates() {
        SoftwareUpdater.shared.checkForUpdates()
    }

    // MARK: - NSWindowDelegate (Window Visibility Tracking)

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        AppState.shared.isMainWindowVisible = false
        return false
    }

    public func windowWillClose(_ notification: Notification) {
        AppState.shared.isMainWindowVisible = false
    }

    public func windowDidMiniaturize(_ notification: Notification) {
        AppState.shared.isMainWindowVisible = false
    }

    public func windowDidDeminiaturize(_ notification: Notification) {
        AppState.shared.isMainWindowVisible = true
    }

    public func windowDidBecomeKey(_ notification: Notification) {
        AppState.shared.isMainWindowVisible = true
    }

    public func windowDidChangeOcclusionState(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            AppState.shared.isMainWindowVisible = window.occlusionState.contains(.visible)
        }
    }
}
