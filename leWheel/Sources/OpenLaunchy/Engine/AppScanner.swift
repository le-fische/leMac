import AppKit
import Foundation

public struct DiscoveredApp: Identifiable, Sendable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let bundleIdentifier: String?
}

public final class AppScanner: @unchecked Sendable {
    public static let shared = AppScanner()
    
    private let searchDirectories: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: "/System/Applications/Utilities"),
        URL(fileURLWithPath: "/System/Library/CoreServices/Applications"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    ]
    
    public init() {}
    
    public func scanInstalledApplications() -> [DiscoveredApp] {
        var results: [DiscoveredApp] = []
        var seenPaths = Set<String>()
        
        // 1. Always explicitly include Finder (which resides in /System/Library/CoreServices/)
        let finderPath = "/System/Library/CoreServices/Finder.app"
        if FileManager.default.fileExists(atPath: finderPath) {
            seenPaths.insert(finderPath)
            results.append(DiscoveredApp(
                name: "Finder",
                path: finderPath,
                bundleIdentifier: "com.apple.finder"
            ))
        }
        
        // 2. Scan standard application folders
        for dir in searchDirectories {
            guard let enumerator = FileManager.default.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isApplicationKey, .localizedNameKey],
                options: [.skipsPackageDescendants, .skipsHiddenFiles]
            ) else { continue }
            
            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "app" else { continue }
                let path = fileURL.path
                if seenPaths.contains(path) { continue }
                seenPaths.insert(path)
                
                let bundle = Bundle(url: fileURL)
                let bundleId = bundle?.bundleIdentifier
                let name = fileURL.deletingPathExtension().lastPathComponent
                
                results.append(DiscoveredApp(
                    name: name,
                    path: path,
                    bundleIdentifier: bundleId
                ))
            }
        }
        
        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    public func generateDefaultFavorites() -> [LaunchItem] {
        let appCandidates: [(name: String, bundleId: String, path: String, key: String)] = [
            ("Finder", "com.apple.finder", "/System/Library/CoreServices/Finder.app", "F"),
            ("Safari", "com.apple.Safari", "/Applications/Safari.app", "S"),
            ("Terminal", "com.apple.Terminal", "/System/Applications/Utilities/Terminal.app", "T"),
            ("System Settings", "com.apple.systempreferences", "/System/Applications/System Settings.app", ","),
            ("Notes", "com.apple.Notes", "/System/Applications/Notes.app", "N"),
            ("Activity Monitor", "com.apple.ActivityMonitor", "/System/Applications/Utilities/Activity Monitor.app", "A"),
            ("Calculator", "com.apple.calculator", "/System/Applications/Calculator.app", "C"),
            ("Mail", "com.apple.mail", "/System/Applications/Mail.app", "M")
        ]
        
        var items: [LaunchItem] = []
        
        for candidate in appCandidates {
            var validPath: String?
            if FileManager.default.fileExists(atPath: candidate.path) {
                validPath = candidate.path
            } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: candidate.bundleId) {
                validPath = appURL.path
            }
            
            if let target = validPath {
                items.append(LaunchItem(
                    title: candidate.name,
                    targetPath: target,
                    itemType: .application,
                    shortcutKey: candidate.key,
                    bundleIdentifier: candidate.bundleId
                ))
            }
        }
        
        return items
    }
}
