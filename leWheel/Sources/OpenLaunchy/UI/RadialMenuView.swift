import SwiftUI
import AppKit

public struct RadialMenuView: View {
    @ObservedObject var config = ConfigManager.shared
    @ObservedObject var controller: RadialWindowController
    
    public var previewHoveredIndex: Int? = nil
    public var isPreview: Bool = false
    public var onSelect: (LaunchItem) -> Void
    
    public init(
        controller: RadialWindowController? = nil,
        previewHoveredIndex: Int? = nil,
        isPreview: Bool = false,
        onSelect: @escaping (LaunchItem) -> Void
    ) {
        self.controller = controller ?? RadialWindowController.shared
        self.previewHoveredIndex = previewHoveredIndex
        self.isPreview = isPreview
        self.onSelect = onSelect
    }
    
    // Convenience initializer for settings previews or bindings
    public init(
        controller: RadialWindowController? = nil,
        hoveredIndex: Binding<Int?>? = nil,
        lastPressedKey: Binding<String?>? = nil,
        onSelect: @escaping (LaunchItem) -> Void
    ) {
        self.controller = controller ?? RadialWindowController.shared
        self.previewHoveredIndex = hoveredIndex?.wrappedValue
        self.isPreview = (hoveredIndex != nil)
        self.onSelect = onSelect
    }
    
    private var activeHoveredIndex: Int? {
        isPreview ? previewHoveredIndex : controller.hoveredIndex
    }
    
    private var activeLastPressedKey: String? {
        isPreview ? nil : controller.lastPressedKey
    }
    
    public var body: some View {
        let settings = config.settings
        let items = config.activeItems
        let total = items.count
        let menuSize = settings.menuSize
        let outerR = settings.outerRadius
        let innerR = settings.innerRadius
        
        ZStack {
            // 1. Continuous Frosted Glass Donut Ring
            DonutShape(innerRadius: innerR, outerRadius: outerR)
                .fill(Color.clear)
                .background(
                    VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                        .clipShape(DonutShape(innerRadius: innerR, outerRadius: outerR))
                )
                .overlay(
                    // Glass edge rings
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1.2)
                            .frame(width: outerR * 2, height: outerR * 2)
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1.0)
                            .frame(width: innerR * 2, height: innerR * 2)
                    }
                )
                .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
            
            // 2. Dividers between apps (if enabled in settings)
            if settings.dividersBetweenApps && total > 1 {
                GeometryReader { proxy in
                    let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    let slice = (2.0 * .pi) / Double(total)
                    Path { path in
                        for i in 0..<total {
                            let angle = Double(i) * slice - (slice / 2.0)
                            let pInner = CGPoint(
                                x: center.x + innerR * CGFloat(sin(angle)),
                                y: center.y - innerR * CGFloat(cos(angle))
                            )
                            let pOuter = CGPoint(
                                x: center.x + outerR * CGFloat(sin(angle)),
                                y: center.y - outerR * CGFloat(cos(angle))
                            )
                            path.move(to: pInner)
                            path.addLine(to: pOuter)
                        }
                    }
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                }
            }
            
            // 3. Lowkey macOS-Style Frosted Gray Highlighted Sector Slice
            if let activeIdx = activeHoveredIndex, activeIdx >= 0, activeIdx < total {
                let angles = RadialMath.sectorAngles(index: activeIdx, count: total)
                RadialSectorShape(
                    startAngleRad: angles.start,
                    endAngleRad: angles.end,
                    innerRadius: innerR,
                    outerRadius: outerR
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.24),
                            Color.white.opacity(0.16)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RadialSectorShape(
                        startAngleRad: angles.start,
                        endAngleRad: angles.end,
                        innerRadius: innerR,
                        outerRadius: outerR
                    )
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.0)
                )
                .animation(.spring(response: 0.16, dampingFraction: 0.8), value: activeHoveredIndex)
            }
            
            // 5. App Icons on the Donut Ring
            GeometryReader { proxy in
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let pos = RadialMath.itemCenter(
                        center: center,
                        index: index,
                        count: total,
                        innerRadius: innerR,
                        outerRadius: outerR
                    )
                    let isHovered = (activeHoveredIndex == index)
                    
                    VStack(spacing: 2) {
                        Image(nsImage: item.iconImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: settings.appIconSize, height: settings.appIconSize)
                            .scaleEffect(isHovered ? 1.14 : 1.0)
                            .opacity(activeHoveredIndex == nil || isHovered ? 1.0 : 0.82)
                            .shadow(color: isHovered ? Color.white.opacity(0.35) : Color.black.opacity(0.2), radius: isHovered ? 4 : 2, y: 1)
                            .animation(.spring(response: 0.18, dampingFraction: 0.75), value: isHovered)
                        
                        // Optional text label
                        if !settings.onlyShowIcons {
                            Text(item.title)
                                .font(.system(size: 9, weight: isHovered ? .bold : .medium, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .frame(maxWidth: 55)
                                .scaleEffect(isHovered ? 1.1 : 1.0)
                        }
                    }
                    .position(pos)
                }
            }
            
            // 6. Active Key Display Badge (e.g. [ S ])
            if let key = activeLastPressedKey, !key.isEmpty {
                HStack {
                    Text(key.uppercased())
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.85))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.3), lineWidth: 1))
                        )
                        .shadow(color: Color.black.opacity(0.5), radius: 10)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: menuSize + 30, height: menuSize + 30)
    }
}
