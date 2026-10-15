import Foundation

public struct Palette: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID
    public var name: String
    public var iconSymbol: String
    public var items: [LaunchItem]
    public var isBuiltInRunningApps: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        iconSymbol: String = "circle.grid.2x2",
        items: [LaunchItem] = [],
        isBuiltInRunningApps: Bool = false
    ) {
        self.id = id
        self.name = name
        self.iconSymbol = iconSymbol
        self.items = items
        self.isBuiltInRunningApps = isBuiltInRunningApps
    }
}
