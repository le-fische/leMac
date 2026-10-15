import Foundation

enum IconStyle: String, CaseIterable {
    case dot = "Minimal Dot (●)"
    case chevron = "Chevron Arrow (‹ ›)"
    case line = "Line (—)"
    case tray = "Folder / Drawer"
}

enum AutoCollapseDuration: Int, CaseIterable {
    case never = 0
    case fiveSeconds = 5
    case tenSeconds = 10
    case fifteenSeconds = 15
    case thirtySeconds = 30
    
    var title: String {
        switch self {
        case .never: return "Never (Manual toggle)"
        case .fiveSeconds: return "After 5 seconds"
        case .tenSeconds: return "After 10 seconds"
        case .fifteenSeconds: return "After 15 seconds"
        case .thirtySeconds: return "After 30 seconds"
        }
    }
}

class Preferences {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard
    
    private let kIconStyle = "minibar_icon_style"
    private let kAutoCollapse = "minibar_auto_collapse"
    private let kIsCollapsed = "minibar_is_collapsed"
    private let kHasSeenWelcome = "minibar_has_seen_welcome"
    
    var iconStyle: IconStyle {
        get {
            guard let raw = defaults.string(forKey: kIconStyle),
                  let style = IconStyle(rawValue: raw) else {
                return .dot
            }
            return style
        }
        set {
            defaults.set(newValue.rawValue, forKey: kIconStyle)
        }
    }
    
    var autoCollapseDuration: AutoCollapseDuration {
        get {
            let val = defaults.integer(forKey: kAutoCollapse)
            return AutoCollapseDuration(rawValue: val) ?? .never
        }
        set {
            defaults.set(newValue.rawValue, forKey: kAutoCollapse)
        }
    }
    
    var isCollapsed: Bool {
        get {
            return defaults.bool(forKey: kIsCollapsed)
        }
        set {
            defaults.set(newValue, forKey: kIsCollapsed)
        }
    }
    
    var hasSeenWelcome: Bool {
        get { defaults.bool(forKey: kHasSeenWelcome) }
        set { defaults.set(newValue, forKey: kHasSeenWelcome) }
    }
}
