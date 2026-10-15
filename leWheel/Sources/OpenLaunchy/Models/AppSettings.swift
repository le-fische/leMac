import Foundation
import CoreGraphics

public enum WheelPresetSize: String, Codable, CaseIterable, Sendable {
    case tiny = "Tiny"
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    
    public var diameter: CGFloat {
        switch self {
        case .tiny: return 180
        case .small: return 220
        case .medium: return 260
        case .large: return 300
        }
    }
    
    public var thickness: CGFloat {
        switch self {
        case .tiny: return 50
        case .small: return 60
        case .medium: return 70
        case .large: return 80
        }
    }
}

public struct AppSettings: Codable, Sendable {
    // General Settings
    public var launchAtLogin: Bool
    public var hideMenuBarIcon: Bool
    public var hotKeyModifiers: UInt32
    public var hotKeyCode: UInt32
    public var hotKeyDisplayString: String
    public var isModifierOnly: Bool?
    public var doublePressModifier: Bool
    
    public var isModifierChord: Bool {
        return (isModifierOnly == true) || (hotKeyCode == 0xFFFF)
    }
    
    // Wheel Dimensions & Appearance (1:1 with Launchy)
    public var menuSize: CGFloat           // e.g. 220 pt
    public var thickness: CGFloat          // e.g. 60 pt
    public var presetSize: WheelPresetSize
    public var maxWheelItems: Int          // e.g. 8 items (or 0 for unlimited)
    public var onlyShowIcons: Bool         // true = hide all text labels
    public var showAnimation: Bool
    public var keepMenuVisible: Bool
    public var allowSelectionByKeyboard: Bool
    public var dividersBetweenApps: Bool
    public var enableHapticFeedback: Bool
    public var appIconSize: CGFloat        // e.g. 34 pt
    public var selectionDistance: CGFloat   // e.g. 200 pt
    
    // Triggers & Navigation
    public var holdToPreviewReleaseToLaunch: Bool
    public var spawnAtCursor: Bool
    
    // Palettes & Mode
    public var palettes: [Palette]
    public var activePaletteIndex: Int
    public var isRunningAppsMode: Bool     // toggled by [ and ]
    
    public init(
        launchAtLogin: Bool = false,
        hideMenuBarIcon: Bool = false,
        hotKeyModifiers: UInt32 = 2304,   // Option (2048) + Command (256) [Launchy Standard]
        hotKeyCode: UInt32 = 0xFFFF,      // Modifier chord (dual press)
        hotKeyDisplayString: String = "⌥⌘",
        isModifierOnly: Bool? = true,
        doublePressModifier: Bool = false,
        menuSize: CGFloat = 220.0,
        thickness: CGFloat = 60.0,
        presetSize: WheelPresetSize = .small,
        maxWheelItems: Int = 8,
        onlyShowIcons: Bool = true,
        showAnimation: Bool = true,
        keepMenuVisible: Bool = false,
        allowSelectionByKeyboard: Bool = true,
        dividersBetweenApps: Bool = false,
        enableHapticFeedback: Bool = true,
        appIconSize: CGFloat = 34.0,
        selectionDistance: CGFloat = 200.0,
        holdToPreviewReleaseToLaunch: Bool = true,
        spawnAtCursor: Bool = true,
        palettes: [Palette] = [],
        activePaletteIndex: Int = 0,
        isRunningAppsMode: Bool = false
    ) {
        self.launchAtLogin = launchAtLogin
        self.hideMenuBarIcon = hideMenuBarIcon
        self.hotKeyModifiers = hotKeyModifiers
        self.hotKeyCode = hotKeyCode
        self.hotKeyDisplayString = hotKeyDisplayString
        self.isModifierOnly = isModifierOnly
        self.doublePressModifier = doublePressModifier
        self.menuSize = menuSize
        self.thickness = thickness
        self.presetSize = presetSize
        self.maxWheelItems = maxWheelItems
        self.onlyShowIcons = onlyShowIcons
        self.showAnimation = showAnimation
        self.keepMenuVisible = keepMenuVisible
        self.allowSelectionByKeyboard = allowSelectionByKeyboard
        self.dividersBetweenApps = dividersBetweenApps
        self.enableHapticFeedback = enableHapticFeedback
        self.appIconSize = appIconSize
        self.selectionDistance = selectionDistance
        self.holdToPreviewReleaseToLaunch = holdToPreviewReleaseToLaunch
        self.spawnAtCursor = spawnAtCursor
        self.palettes = palettes
        self.activePaletteIndex = activePaletteIndex
        self.isRunningAppsMode = isRunningAppsMode
    }
    
    public var outerRadius: CGFloat {
        menuSize / 2.0
    }
    
    public var innerRadius: CGFloat {
        max(20.0, outerRadius - thickness)
    }
}
