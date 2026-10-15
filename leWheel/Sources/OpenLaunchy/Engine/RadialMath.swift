import SwiftUI
import CoreGraphics

public struct RadialMath {
    /// Clockwise angle from 12 o'clock in radians [0, 2π)
    public static func clockwiseAngle(from center: CGPoint, to point: CGPoint) -> Double {
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y) // In SwiftUI, +y is downwards
        return clockwiseAngle(dx: dx, dy: dy)
    }
    
    public static func clockwiseAngle(dx: Double, dy: Double) -> Double {
        var angle = atan2(dx, -dy)
        if angle < 0 {
            angle += 2.0 * .pi
        }
        return angle
    }
    
    /// Distance from center
    public static func distance(from center: CGPoint, to point: CGPoint) -> CGFloat {
        let dx = point.x - center.x
        let dy = point.y - center.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Sector index for a given angle and item count
    public static func sectorIndex(for angle: Double, count: Int) -> Int? {
        guard count > 0 else { return nil }
        let slice = (2.0 * .pi) / Double(count)
        let shifted = (angle + slice / 2.0).truncatingRemainder(dividingBy: 2.0 * .pi)
        let normalized = shifted < 0 ? shifted + 2.0 * .pi : shifted
        let index = Int(normalized / slice)
        return min(max(0, index), count - 1)
    }
    
    /// Sector angular span
    public static func sectorAngles(index: Int, count: Int, gapDegrees: Double = 0.0) -> (start: Double, end: Double) {
        guard count > 0 else { return (0, 0) }
        let slice = (2.0 * .pi) / Double(count)
        let gapRad = (gapDegrees * .pi) / 180.0
        
        let centerAngle = Double(index) * slice
        let start = centerAngle - (slice / 2.0) + (gapRad / 2.0)
        let end = centerAngle + (slice / 2.0) - (gapRad / 2.0)
        return (start, end)
    }
    
    /// Exact center position for placing app icons along the donut ring
    public static func itemCenter(
        center: CGPoint,
        index: Int,
        count: Int,
        innerRadius: CGFloat,
        outerRadius: CGFloat
    ) -> CGPoint {
        guard count > 0 else { return center }
        let slice = (2.0 * .pi) / Double(count)
        let angle = Double(index) * slice
        let midRadius = (innerRadius + outerRadius) / 2.0
        
        let x = center.x + midRadius * CGFloat(sin(angle))
        let y = center.y - midRadius * CGFloat(cos(angle))
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Continuous Donut / Torus Shape
public struct DonutShape: Shape {
    public var innerRadius: CGFloat
    public var outerRadius: CGFloat
    
    public init(innerRadius: CGFloat, outerRadius: CGFloat) {
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        // Outer circle
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: .zero,
            endAngle: .degrees(360),
            clockwise: false
        )
        // Inner circle cutout
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: .degrees(360),
            endAngle: .zero,
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Highlighted Sector Arc Slice
public struct RadialSectorShape: Shape {
    public var startAngleRad: Double
    public var endAngleRad: Double
    public var innerRadius: CGFloat
    public var outerRadius: CGFloat
    
    public init(
        startAngleRad: Double,
        endAngleRad: Double,
        innerRadius: CGFloat,
        outerRadius: CGFloat
    ) {
        self.startAngleRad = startAngleRad
        self.endAngleRad = endAngleRad
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        // Convert clockwise-from-12-o'clock to standard SwiftUI Angle (0 is 3 o'clock)
        let stdStart = Angle(radians: startAngleRad - (.pi / 2.0))
        let stdEnd = Angle(radians: endAngleRad - (.pi / 2.0))
        
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: stdStart,
            endAngle: stdEnd,
            clockwise: false
        )
        
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: stdEnd,
            endAngle: stdStart,
            clockwise: true
        )
        
        path.closeSubpath()
        return path
    }
}
