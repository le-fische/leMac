import Foundation

enum DotSize: String, CaseIterable {
    case small = "Small & Thin (5.5 pt)"
    case medium = "Medium & Crisp (6.0 pt)"
    case regular = "Classic (7.5 pt)"
    
    var diameter: Double {
        switch self {
        case .small: return 5.5
        case .medium: return 6.0
        case .regular: return 7.5
        }
    }
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
    
    private let kDotSize = "leminibar_dot_size"
    private let kAutoCollapse = "leminibar_auto_collapse"
    private let kIsCollapsed = "leminibar_is_collapsed"
    private let kHasSeenWelcome = "leminibar_has_seen_welcome"
    
    var dotSize: DotSize {
        get {
            guard let raw = defaults.string(forKey: kDotSize),
                  let size = DotSize(rawValue: raw) else {
                return .medium
            }
            return size
        }
        set {
            defaults.set(newValue.rawValue, forKey: kDotSize)
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
