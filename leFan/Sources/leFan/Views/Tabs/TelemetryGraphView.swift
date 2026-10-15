import SwiftUI

public struct TelemetryGraphView: View {
    @ObservedObject var appState: AppState

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 2) {
                    Text("Live Telemetry & Diagnostics")
                        .font(.system(size: 20, weight: .bold))
                    Text("Real-time telemetry tracking fan speeds and thermal response curves.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Fan RPM Chart Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "fanblades.fill")
                                .foregroundColor(.cyan)
                            Text("FAN SPEED TELEMETRY")
                                .font(.system(size: 12, weight: .bold))
                        }

                        Spacer()

                        Text("Current: \(Int(appState.averageRPM)) RPM")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.cyan)
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.2))

                        SparklineChartView(
                            data: appState.rpmHistory,
                            lineColor: .cyan,
                            showPoints: true
                        )
                        .padding(14)
                    }
                    .frame(height: 180)

                    HStack {
                        Text("Past 60 Seconds")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        let minRPM = appState.rpmHistory.min() ?? 0
                        let maxRPM = appState.rpmHistory.max() ?? 0
                        Text("Min: \(Int(minRPM)) RPM • Max: \(Int(maxRPM)) RPM")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(18)
                .background(.ultraThinMaterial)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )

                // Temperature Chart Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("PEAK TEMPERATURE TELEMETRY")
                                .font(.system(size: 12, weight: .bold))
                        }

                        Spacer()

                        Text("Current: \(appState.formatTemp(appState.highestTemp))")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.orange)
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.2))

                        SparklineChartView(
                            data: appState.tempHistory,
                            lineColor: .orange,
                            showPoints: true
                        )
                        .padding(14)
                    }
                    .frame(height: 180)

                    HStack {
                        Text("Past 60 Seconds")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        let minT = appState.tempHistory.min() ?? 0
                        let maxT = appState.tempHistory.max() ?? 0
                        Text("Min: \(appState.formatTemp(minT)) • Max: \(appState.formatTemp(maxT))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(18)
                .background(.ultraThinMaterial)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
            }
            .padding(22)
        }
    }
}
