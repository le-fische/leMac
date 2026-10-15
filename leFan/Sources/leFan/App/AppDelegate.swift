import Cocoa
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public static var shared: AppDelegate?

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var mainWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        setupMenuBar()
        setupPopover()
        observeAppState()

        DispatchQueue.main.async { [weak self] in
            if let window = NSApplication.shared.windows.first {
                self?.mainWindow = window
                window.title = "leFan"
                window.subtitle = AppState.shared.macModelName
                window.minSize = NSSize(width: 850, height: 620)
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
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
        // Update menu bar title when telemetry changes
        AppState.shared.$averageRPM
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItemTitle()
            }
            .store(in: &cancellables)

        AppState.shared.$highestTemp
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItemTitle()
            }
            .store(in: &cancellables)

        AppState.shared.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItemTitle()
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemTitle() {
        guard let button = statusItem?.button else { return }
        let state = AppState.shared

        let rpmStr = "\(Int(state.averageRPM)) RPM"
        let tempStr = state.formatTemp(state.highestTemp)

        let image = NSImage(systemSymbolName: "fanblades.fill", accessibilityDescription: "Fan")
        button.image = image
        button.imagePosition = .imageLeading

        switch state.settings.menuBarMode {
        case .rpmAndTemp:
            button.title = " \(rpmStr)  \(tempStr)"
        case .rpmOnly:
            button.title = " \(rpmStr)"
        case .tempOnly:
            button.title = " \(tempStr)"
        case .iconOnly:
            button.title = ""
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
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        } else if let window = NSApplication.shared.windows.first {
            self.mainWindow = window
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openMainWindow()
        }
        return true
    }
}

import Combine
