import AppKit
import Foundation
import UniformTypeIdentifiers

public enum LaunchItemType: String, Codable, Sendable {
    case application
    case fileOrFolder
    case url
    case shellScript
    case runningApp
    case action
}

public struct LaunchItem: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID
    public var title: String
    public var targetPath: String
    public var itemType: LaunchItemType
    public var shortcutKey: String?
    public var customIconPath: String?
    public var arguments: [String]
    public var bundleIdentifier: String?
    
    public init(
        id: UUID = UUID(),
        title: String,
        targetPath: String,
        itemType: LaunchItemType = .application,
        shortcutKey: String? = nil,
        customIconPath: String? = nil,
        arguments: [String] = [],
        bundleIdentifier: String? = nil
    ) {
        self.id = id
        self.title = title
        self.targetPath = targetPath
        self.itemType = itemType
        self.shortcutKey = shortcutKey
        self.customIconPath = customIconPath
        self.arguments = arguments
        self.bundleIdentifier = bundleIdentifier
    }
}

// MARK: - Icon & Runtime Helpers
extension LaunchItem {
    @MainActor
    public func iconImage() -> NSImage {
        if let customPath = customIconPath,
           let customImage = NSImage(contentsOfFile: customPath) {
            return customImage
        }
        
        switch itemType {
        case .application, .fileOrFolder, .runningApp:
            if FileManager.default.fileExists(atPath: targetPath) {
                return NSWorkspace.shared.icon(forFile: targetPath)
            }
            if let bundleId = bundleIdentifier,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                return NSWorkspace.shared.icon(forFile: appURL.path)
            }
            return NSWorkspace.shared.icon(for: .application)
            
        case .url:
            return NSImage(systemSymbolName: "globe", accessibilityDescription: "Web URL") ?? NSImage()
            
        case .shellScript:
            return NSImage(systemSymbolName: "terminal", accessibilityDescription: "Shell Script") ?? NSImage()
            
        case .action:
            return NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "Action") ?? NSImage()
        }
    }
}
