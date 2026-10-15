import SwiftUI

public struct SensorCardView: View {
    let sensor: Sensor
    let formatTemp: (Double) -> String

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Category icon & Status Pill
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: sensor.category.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(sensor.status.color)

                    Text(sensor.category.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(sensor.status.title)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(sensor.status.color.opacity(0.15))
                    .foregroundColor(sensor.status.color)
                    .clipShape(Capsule())
            }

            // Sensor Name
            Text(sensor.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)

            // Temperature Value & Sparkline
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatTemp(sensor.temperatureC))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        Text("↓ \(formatTemp(sensor.minTempRecorded))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text("↑ \(formatTemp(sensor.maxTempRecorded))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Mini Sparkline Graph
                SparklineChartView(
                    data: sensor.history,
                    lineColor: sensor.status.color,
                    showPoints: true
                )
                .frame(width: 65, height: 28)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
