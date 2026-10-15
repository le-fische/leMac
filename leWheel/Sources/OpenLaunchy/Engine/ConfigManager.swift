import Foundation
import Combine

@MainActor
public final class ConfigManager: ObservableObject {
    public static let shared = ConfigManager()
    
    @Published public var settings: AppSettings {
        didSet {
            save()
        }
    }
    
    private let fileManager = FileManager.default
    private var configURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("OpenLaunchy", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("config.json")
    }
    
    private init() {
        let loaded = ConfigManager.loadFromDisk()
        self.settings = loaded ?? ConfigManager.makeDefaultSettings()
        if loaded == nil {
            save()
        }
    }
    
    public func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: configURL, options: .atomic)
        } catch {
            print("[OpenLaunchy] Error saving configuration: \(error.localizedDescription)")
        }
    }
    
    private static func loadFromDisk() -> AppSettings? {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = appSupport.appendingPathComponent("OpenLaunchy/config.json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            print("[OpenLaunchy] Failed to parse existing config, falling back to defaults: \(error)")
            return nil
        }
    }
    
    public static func makeDefaultSettings() -> AppSettings {
        let defaultFavorites = AppScanner.shared.generateDefaultFavorites()
        
        let favoritesPalette = Palette(
            name: "Favorites",
            iconSymbol: "star.fill",
            items: defaultFavorites
        )
        
        return AppSettings(palettes: [favoritesPalette])
    }
    
    public func resetToDefaults() {
        self.settings = ConfigManager.makeDefaultSettings()
        save()
    }
    
    public func toggleRunningAppsMode() {
        settings.isRunningAppsMode.toggle()
        if settings.isRunningAppsMode {
            RunningAppsManager.shared.refreshRunningApps()
        }
    }
    
    public var activeItems: [LaunchItem] {
        let rawList: [LaunchItem]
        if settings.isRunningAppsMode {
            rawList = RunningAppsManager.shared.runningApps
        } else {
            rawList = currentItems
        }
        
        if settings.maxWheelItems > 0 && rawList.count > settings.maxWheelItems {
            return Array(rawList.prefix(settings.maxWheelItems))
        }
        return rawList
    }
    
    public var currentItems: [LaunchItem] {
        if settings.palettes.isEmpty {
            return []
        }
        let idx = min(max(0, settings.activePaletteIndex), settings.palettes.count - 1)
        return settings.palettes[idx].items
    }
    
    // MARK: - Direct, Bug-Free Item Modification
    public func addApp(item: LaunchItem) {
        if settings.palettes.isEmpty {
            settings.palettes = [Palette(name: "Favorites", items: [item])]
            save()
            return
        }
        let idx = min(max(0, settings.activePaletteIndex), settings.palettes.count - 1)
        
        // Prevent duplicates
        let alreadyExists = settings.palettes[idx].items.contains { existing in
            existing.targetPath == item.targetPath ||
            (existing.bundleIdentifier != nil && existing.bundleIdentifier == item.bundleIdentifier)
        }
        guard !alreadyExists else { return }
        
        settings.palettes[idx].items.append(item)
        save()
    }
    
    public func removeApp(at index: Int) {
        guard !settings.palettes.isEmpty else { return }
        let idx = min(max(0, settings.activePaletteIndex), settings.palettes.count - 1)
        guard index >= 0 && index < settings.palettes[idx].items.count else { return }
        settings.palettes[idx].items.remove(at: index)
        save()
    }
    
    public func moveApp(from sourceIndex: Int, to destinationIndex: Int) {
        guard !settings.palettes.isEmpty else { return }
        let idx = min(max(0, settings.activePaletteIndex), settings.palettes.count - 1)
        let count = settings.palettes[idx].items.count
        guard sourceIndex >= 0 && sourceIndex < count,
              destinationIndex >= 0 && destinationIndex < count else { return }
        
        let item = settings.palettes[idx].items.remove(at: sourceIndex)
        settings.palettes[idx].items.insert(item, at: destinationIndex)
        save()
    }
    
    public func setMaxWheelItems(_ count: Int) {
        settings.maxWheelItems = count
        save()
    }
    
    public func updateShortcut(keyCode: UInt32, modifiers: UInt32, display: String, isModifierOnly: Bool = false) {
        settings.hotKeyCode = keyCode
        settings.hotKeyModifiers = modifiers
        settings.hotKeyDisplayString = display
        settings.isModifierOnly = isModifierOnly || (keyCode == 0xFFFF)
        save()
        HotKeyManager.shared.register(keyCode: keyCode, modifiers: modifiers, isModifierOnly: settings.isModifierChord)
    }
}
