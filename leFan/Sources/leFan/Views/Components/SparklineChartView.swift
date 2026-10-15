import SwiftUI

public struct SparklineChartView: View {
    let data: [Double]
    let lineColor: Color
    let showPoints: Bool

    public init(data: [Double], lineColor: Color = .cyan, showPoints: Bool = false) {
        self.data = data
        self.lineColor = lineColor
        self.showPoints = showPoints
    }

    public var body: some View {
        GeometryReader { geo in
            if data.count >= 2 {
                let minVal = data.min() ?? 0
                let maxVal = data.max() ?? 1
                let range = max(maxVal - minVal, 1.0)
                let stepX = geo.size.width / CGFloat(data.count - 1)

                // Background gradient fill
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height))
                    for (i, val) in data.enumerated() {
                        let yRatio = (val - minVal) / range
                        let y = geo.size.height - (CGFloat(yRatio) * (geo.size.height - 8)) - 4
                        let x = CGFloat(i) * stepX
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [lineColor.opacity(0.3), lineColor.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line stroke
                Path { path in
                    for (i, val) in data.enumerated() {
                        let yRatio = (val - minVal) / range
                        let y = geo.size.height - (CGFloat(yRatio) * (geo.size.height - 8)) - 4
                        let x = CGFloat(i) * stepX
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    lineColor,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )

                if showPoints, let lastVal = data.last {
                    let yRatio = (lastVal - minVal) / range
                    let y = geo.size.height - (CGFloat(yRatio) * (geo.size.height - 8)) - 4
                    Circle()
                        .fill(lineColor)
                        .frame(width: 6, height: 6)
                        .position(x: geo.size.width, y: y)
                }
            } else {
                // Placeholder flat line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }
                .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
    }
}
