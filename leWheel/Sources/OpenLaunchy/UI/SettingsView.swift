import SwiftUI
import AppKit
import Carbon

public enum SettingsCategory: String, CaseIterable, Identifiable {
    case wheelLauncher = "Wheel launcher"
    case general = "General"
    case about = "About"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .wheelLauncher: return "circle.circle"
        case .general: return "gearshape"
        case .about: return "info.circle"
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var config = ConfigManager.shared
    @State private var selectedCategory: SettingsCategory = .wheelLauncher
    @State private var showingAddAppSheet = false
    @State private var availableApps: [DiscoveredApp] = []
    @State private var searchText = ""
    @State private var previewHoveredIndex: Int? = 0
    @State private var isRecordingShortcut = false
    @State private var eventMonitor: Any?
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            List(selection: $selectedCategory) {
                Section("Settings") {
                    NavigationLink(value: SettingsCategory.wheelLauncher) {
                        Label("Wheel launcher", systemImage: "circle.circle")
                    }
                    NavigationLink(value: SettingsCategory.general) {
                        Label("General", systemImage: "gearshape")
                    }
                }
                
                Section("Other") {
                    NavigationLink(value: SettingsCategory.about) {
                        Label("About", systemImage: "info.circle")
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 170, maxWidth: 200)
        } detail: {
            detailView
                .frame(minWidth: 480, minHeight: 560)
        }
        .frame(width: 740, height: 600)
        .sheet(isPresented: $showingAddAppSheet) {
            addAppSheet
        }
        .onDisappear {
            stopRecording()
        }
    }
    
    @ViewBuilder
    private var detailView: some View {
        switch selectedCategory {
        case .wheelLauncher:
            wheelLauncherPane
        case .general:
            generalPane
        case .about:
            aboutPane
        }
    }
    
    // MARK: - 1. Wheel Launcher & App Customizer Pane
    private var wheelLauncherPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Top header with Export & Import
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wheel launcher")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Hold your shortcut (\(config.settings.hotKeyDisplayString)), flick cursor toward an app, and release.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: importConfig) {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .controlSize(.small)
                    Button(action: exportConfig) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .controlSize(.small)
                }
                
                // Live Interactive Donut Preview
                ZStack {
                    RadialMenuView(
                        hoveredIndex: $previewHoveredIndex,
                        onSelect: { _ in }
                    )
                    .scaleEffect(0.85)
                }
                .frame(height: 230)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
                )
                
                // ADD APPLICATION BUTTONS
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Button(action: {
                            availableApps = AppScanner.shared.scanInstalledApplications()
                            showingAddAppSheet = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("Choose from Installed Apps...")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: pickAppFromFinder) {
                            HStack {
                                Image(systemName: "folder")
                                Text("Browse in Finder...")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // APPS ON WHEEL LIST
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Applications on Wheel (\(config.currentItems.count))")
                            .font(.headline)
                        Spacer()
                    }
                    
                    if config.currentItems.isEmpty {
                        Text("No applications added. Click 'Choose from Installed Apps' above.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
                    } else {
                        VStack(spacing: 1) {
                            ForEach(Array(config.currentItems.enumerated()), id: \.element.id) { index, item in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.secondary)
                                        .frame(width: 18, alignment: .trailing)
                                    
                                    Image(nsImage: item.iconImage())
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.title)
                                            .fontWeight(.medium)
                                        Text(item.targetPath)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    // Move Up
                                    Button(action: { config.moveApp(from: index, to: max(0, index - 1)) }) {
                                        Image(systemName: "chevron.up")
                                            .foregroundColor(index > 0 ? .primary : .secondary.opacity(0.3))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(index == 0)
                                    
                                    // Move Down
                                    Button(action: { config.moveApp(from: index, to: min(config.currentItems.count - 1, index + 1)) }) {
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(index < config.currentItems.count - 1 ? .primary : .secondary.opacity(0.3))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(index == config.currentItems.count - 1)
                                    
                                    // Delete
                                    Button(action: { config.removeApp(at: index) }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red.opacity(0.85))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.leading, 6)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.06))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                // WHEEL APPEARANCE CONTROLS
                VStack(alignment: .leading, spacing: 10) {
                    Text("Wheel Appearance")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        // Max items on wheel control
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Items on wheel")
                                Text("Number of apps visible on the wheel at once")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Picker("", selection: $config.settings.maxWheelItems) {
                                Text("4 Apps").tag(4)
                                Text("6 Apps").tag(6)
                                Text("8 Apps (Recommended)").tag(8)
                                Text("10 Apps").tag(10)
                                Text("12 Apps").tag(12)
                                Text("All (Unlimited)").tag(0)
                            }
                            .frame(width: 180)
                        }
                        
                        // Preset size segmented control
                        Picker("Preset Size", selection: $config.settings.presetSize) {
                            ForEach(WheelPresetSize.allCases, id: \.self) { preset in
                                Text(preset.rawValue).tag(preset)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: config.settings.presetSize) { _, newPreset in
                            config.settings.menuSize = newPreset.diameter
                            config.settings.thickness = newPreset.thickness
                        }
                        
                        // Menu size slider
                        HStack {
                            Text("Menu size")
                            Spacer()
                            Slider(value: $config.settings.menuSize, in: 160...360, step: 2)
                                .frame(width: 200)
                            Text("\(Int(config.settings.menuSize)) pt")
                                .monospacedDigit()
                                .frame(width: 45, alignment: .trailing)
                        }
                        
                        // Thickness slider
                        HStack {
                            Text("Thickness")
                            Spacer()
                            Slider(value: $config.settings.thickness, in: 35...100, step: 2)
                                .frame(width: 200)
                            Text("\(Int(config.settings.thickness)) pt")
                                .monospacedDigit()
                                .frame(width: 45, alignment: .trailing)
                        }
                        
                        // App icon size
                        HStack {
                            Text("App icon size")
                            Spacer()
                            Slider(value: $config.settings.appIconSize, in: 24...48, step: 2)
                                .frame(width: 200)
                            Text("\(Int(config.settings.appIconSize)) pt")
                                .monospacedDigit()
                                .frame(width: 45, alignment: .trailing)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // BEHAVIOR TOGGLES
                VStack(spacing: 1) {
                    settingsToggleRow(title: "Only show icons", subtitle: "Minimalist donut without text labels", isOn: $config.settings.onlyShowIcons)
                    settingsToggleRow(title: "Enable Haptic feedback", subtitle: "Tactile click when moving between apps", isOn: $config.settings.enableHapticFeedback)
                    settingsToggleRow(title: "Show launcher with animation", isOn: $config.settings.showAnimation)
                    settingsToggleRow(title: "Dividers between apps", isOn: $config.settings.dividersBetweenApps)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Reset all button
                Button(action: { config.resetToDefaults() }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Reset to Defaults")
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.85)))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
    }
    
    // MARK: - 2. General Settings (Single Shortcut & App Lifecycle)
    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("General Settings", systemImage: "gearshape")
                .font(.title2)
                .fontWeight(.bold)
            
            // Single Global Shortcut
            VStack(alignment: .leading, spacing: 8) {
                Text("Open Shortcut")
                    .font(.headline)
                Text("Hold this shortcut while moving your mouse to navigate. Release to open, or release in the center to fade away.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    HStack {
                        HStack(spacing: 8) {
                            Text(isRecordingShortcut ? "Press keys on keyboard..." : config.settings.hotKeyDisplayString)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(isRecordingShortcut ? .accentColor : .primary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isRecordingShortcut ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isRecordingShortcut ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                )
                        )
                        
                        Button(isRecordingShortcut ? "Cancel" : "Record New Shortcut") {
                            if isRecordingShortcut {
                                stopRecording()
                            } else {
                                startRecording()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Spacer()
                        
                        Button("Default (⌥⌘)") {
                            config.updateShortcut(keyCode: 0xFFFF, modifiers: 2304, display: "⌥⌘", isModifierOnly: true)
                        }
                        .controlSize(.small)
                    }
                    
                    // Quick Presets
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Quick Presets:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            presetButton(title: "⌥⌘ (Launchy Dual Press)", code: 0xFFFF, mods: 2304, isModifierOnly: true)
                            presetButton(title: "⌥ Space", code: 49, mods: 2048, isModifierOnly: false)
                            presetButton(title: "⌃ Space", code: 49, mods: 4096, isModifierOnly: false)
                            presetButton(title: "⌘ ⌥ Space", code: 49, mods: 2304, isModifierOnly: false)
                            presetButton(title: "⌥ Tab", code: 48, mods: 2048, isModifierOnly: false)
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // App Lifecycle
            VStack(spacing: 1) {
                HStack {
                    Text("Launch at login")
                    Spacer()
                    Toggle("", isOn: $config.settings.launchAtLogin)
                        .labelsHidden()
                }
                .padding()
                .background(Color.secondary.opacity(0.08))
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hide menu bar icon")
                        Text("Runs completely silently in background via your shortcut")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $config.settings.hideMenuBarIcon)
                        .labelsHidden()
                        .onChange(of: config.settings.hideMenuBarIcon) { _, newValue in
                            StatusBarController.shared.setMenuExtraVisible(!newValue)
                        }
                }
                .padding()
                .background(Color.secondary.opacity(0.08))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Manual Quit Button
            HStack {
                Spacer()
                Button(role: .destructive, action: {
                    NSApplication.shared.terminate(nil)
                    exit(0)
                }) {
                    Label("Quit leWheel", systemImage: "power")
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .padding(24)
    }
    
    // MARK: - 3. About Pane
    private var aboutPane: some View {
        VStack(spacing: 16) {
            Image(systemName: "circle.circle")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            Text("leWheel")
                .font(.title)
                .fontWeight(.bold)
            
            Text("100% Free & Open-Source Radial Launcher")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Zero item caps: Add any number of apps to your wheel")
                Text("• Zero switch limits: No 300-switch counters or subscriptions")
                Text("• Hold-to-navigate, release-to-launch ergonomic mechanics")
                Text("• Native Swift 6 & SwiftUI architecture for macOS")
            }
            .font(.caption)
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
            
            Spacer()
        }
        .padding(24)
    }
    
    // MARK: - Add App Sheet
    private var addAppSheet: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Add Application to Wheel")
                    .font(.headline)
                Spacer()
                Button("Done") { showingAddAppSheet = false }
            }
            
            TextField("Search installed apps...", text: $searchText)
                .textFieldStyle(.roundedBorder)
            
            let filtered = availableApps.filter {
                searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
            }
            
            List(filtered) { app in
                HStack {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                        .resizable()
                        .frame(width: 26, height: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(app.name).fontWeight(.medium)
                        Text(app.path).font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    let isAdded = config.currentItems.contains {
                        $0.targetPath == app.path || ($0.bundleIdentifier != nil && $0.bundleIdentifier == app.bundleIdentifier)
                    }
                    if isAdded {
                        Button(action: {
                            if let idx = config.currentItems.firstIndex(where: {
                                $0.targetPath == app.path || ($0.bundleIdentifier != nil && $0.bundleIdentifier == app.bundleIdentifier)
                            }) {
                                config.removeApp(at: idx)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Added")
                                    .fontWeight(.medium)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button(action: {
                            let item = LaunchItem(
                                title: app.name,
                                targetPath: app.path,
                                itemType: .application,
                                shortcutKey: String(app.name.prefix(1)),
                                bundleIdentifier: app.bundleIdentifier
                            )
                            config.addApp(item: item)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Add to Wheel")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .frame(width: 500, height: 460)
    }
    
    // MARK: - Native Finder App Picker
    private func pickAppFromFinder() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.application]
        openPanel.allowsMultipleSelection = true
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        openPanel.prompt = "Add to Wheel"
        
        if openPanel.runModal() == .OK {
            for url in openPanel.urls {
                let name = url.deletingPathExtension().lastPathComponent
                let bundle = Bundle(url: url)
                let item = LaunchItem(
                    title: name,
                    targetPath: url.path,
                    itemType: .application,
                    shortcutKey: String(name.prefix(1)),
                    bundleIdentifier: bundle?.bundleIdentifier
                )
                config.addApp(item: item)
            }
        }
    }
    
    // MARK: - Shortcut Recording
    private func startRecording() {
        isRecordingShortcut = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .flagsChanged {
                let flags = event.modifierFlags.intersection([.option, .command, .control, .shift])
                var carbonMods: UInt32 = 0
                var dispParts: [String] = []
                
                if flags.contains(.control) { carbonMods |= UInt32(controlKey); dispParts.append("⌃") }
                if flags.contains(.option) { carbonMods |= UInt32(optionKey); dispParts.append("⌥") }
                if flags.contains(.shift) { carbonMods |= UInt32(shiftKey); dispParts.append("⇧") }
                if flags.contains(.command) { carbonMods |= UInt32(cmdKey); dispParts.append("⌘") }
                
                // If 2 or more modifiers are pressed together (e.g. Option + Command dual press)
                if dispParts.count >= 2 {
                    let display = dispParts.joined()
                    config.updateShortcut(keyCode: 0xFFFF, modifiers: carbonMods, display: display, isModifierOnly: true)
                    stopRecording()
                    return nil
                }
                return event
            } else if event.type == .keyDown {
                var carbonMods: UInt32 = 0
                var dispParts: [String] = []
                
                if event.modifierFlags.contains(.control) {
                    carbonMods |= UInt32(controlKey)
                    dispParts.append("⌃")
                }
                if event.modifierFlags.contains(.option) {
                    carbonMods |= UInt32(optionKey)
                    dispParts.append("⌥")
                }
                if event.modifierFlags.contains(.shift) {
                    carbonMods |= UInt32(shiftKey)
                    dispParts.append("⇧")
                }
                if event.modifierFlags.contains(.command) {
                    carbonMods |= UInt32(cmdKey)
                    dispParts.append("⌘")
                }
                
                let keyStr = keyName(for: event.keyCode, event: event)
                dispParts.append(keyStr)
                
                let display = dispParts.joined(separator: " ")
                config.updateShortcut(keyCode: UInt32(event.keyCode), modifiers: carbonMods, display: display, isModifierOnly: false)
                
                stopRecording()
                return nil
            }
            return event
        }
    }
    
    private func stopRecording() {
        isRecordingShortcut = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func keyName(for code: UInt16, event: NSEvent) -> String {
        switch code {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 53: return "Esc"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            if let chars = event.charactersIgnoringModifiers?.uppercased(), !chars.isEmpty {
                return chars
            }
            return "Key(\(code))"
        }
    }
    
    private func presetButton(title: String, code: UInt32, mods: UInt32, isModifierOnly: Bool = false) -> some View {
        Button(title) {
            config.updateShortcut(keyCode: code, modifiers: mods, display: title, isModifierOnly: isModifierOnly)
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
    }
    
    private func settingsToggleRow(title: String, subtitle: String? = nil, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let sub = subtitle {
                    Text(sub)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08))
    }
    
    private func exportConfig() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "OpenLaunchy-config.json"
        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? JSONEncoder().encode(config.settings).write(to: url)
        }
    }
    
    private func importConfig() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        if openPanel.runModal() == .OK, let url = openPanel.url, let data = try? Data(contentsOf: url) {
            if let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
                config.settings = decoded
            }
        }
    }
}
