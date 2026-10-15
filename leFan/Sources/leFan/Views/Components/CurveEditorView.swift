import SwiftUI

public struct CurveEditorView: View {
    @ObservedObject var appState: AppState
    let fan: Fan
    @Binding var selectedSensorKey: String
    @Binding var lowTemp: Double
    @Binding var highTemp: Double
    let onSave: () -> Void

    private var currentSensorTemp: Double {
        appState.getTemperatureForSensorKey(selectedSensorKey)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Sensor selector
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "thermometer.medium")
                        .foregroundColor(.cyan)
                    Text("Temperature Sensor")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("Current: \(appState.formatTemp(currentSensorTemp))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.15))
                        .clipShape(Capsule())
                }

                Picker("", selection: $selectedSensorKey) {
                    Text("⚡ CPU Average Package").tag("CPU_AVG")
                    Text("🔥 CPU Core Max").tag("CPU_MAX")
                    Divider()
                    ForEach(appState.sensors.filter { $0.id != "CPU_AVG" && $0.id != "CPU_MAX" }) { sensor in
                        Text("\(sensor.category.rawValue): \(sensor.name)").tag(sensor.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            // Interactive Curve Diagram
            VStack(alignment: .leading, spacing: 4) {
                Text("Dynamic Fan Curve Response")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.25))

                    CurveGraph(
                        minRPM: fan.minRPM,
                        maxRPM: fan.maxRPM,
                        lowTemp: lowTemp,
                        highTemp: highTemp,
                        currentTemp: currentSensorTemp
                    )
                    .padding(12)
                }
                .frame(height: 120)
            }

            // Temperature threshold steppers/sliders
            VStack(spacing: 12) {
                // Low threshold
                VStack(spacing: 4) {
                    HStack {
                        Text("Start Ramping At:")
                            .font(.system(size: 12))
                        Spacer()
                        Text(appState.formatTemp(lowTemp))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                    Slider(value: $lowTemp, in: 35...75, step: 1)
                        .tint(.blue)
                }

                // High threshold
                VStack(spacing: 4) {
                    HStack {
                        Text("Maximum Fan Speed At:")
                            .font(.system(size: 12))
                        Spacer()
                        Text(appState.formatTemp(highTemp))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                    }
                    Slider(value: $highTemp, in: max(lowTemp + 5, 60)...100, step: 1)
                        .tint(.red)
                }
            }

            // Quick curve templates
            HStack(spacing: 8) {
                Button("Whisper (65° - 90°)") {
                    lowTemp = 65
                    highTemp = 90
                    onSave()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Standard (50° - 82°)") {
                    lowTemp = 50
                    highTemp = 82
                    onSave()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Aggressive (42° - 75°)") {
                    lowTemp = 42
                    highTemp = 75
                    onSave()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Apply Button
            Button(action: onSave) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Apply Sensor Curve")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(12)
    }
}

fileprivate struct CurveGraph: View {
    let minRPM: Double
    let maxRPM: Double
    let lowTemp: Double
    let highTemp: Double
    let currentTemp: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Temp domain 30C to 100C
            let minT: Double = 30
            let maxT: Double = 100
            let tRange = maxT - minT

            let xLow = CGFloat((lowTemp - minT) / tRange) * w
            let xHigh = CGFloat((highTemp - minT) / tRange) * w
            let yMin = h - 6
            let yMax = CGFloat(6)

            // Curve path
            Path { path in
                path.move(to: CGPoint(x: 0, y: yMin))
                path.addLine(to: CGPoint(x: xLow, y: yMin))
                path.addLine(to: CGPoint(x: xHigh, y: yMax))
                path.addLine(to: CGPoint(x: w, y: yMax))
            }
            .stroke(
                LinearGradient(colors: [.blue, .cyan, .orange, .red], startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )

            // Low point
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
                .position(x: xLow, y: yMin)

            // High point
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .position(x: xHigh, y: yMax)

            // Current temperature marker
            if currentTemp >= minT && currentTemp <= maxT {
                let xCur = CGFloat((currentTemp - minT) / tRange) * w
                let yCur = calculateY(currentTemp: currentTemp, lowTemp: lowTemp, highTemp: highTemp, yMin: yMin, yMax: yMax)

                // Vertical dashed indicator
                Path { path in
                    path.move(to: CGPoint(x: xCur, y: 0))
                    path.addLine(to: CGPoint(x: xCur, y: h))
                }
                .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                // Current point pulse
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .shadow(color: .white, radius: 4)
                    .position(x: xCur, y: yCur)
            }
        }
    }

    private func calculateY(currentTemp: Double, lowTemp: Double, highTemp: Double, yMin: CGFloat, yMax: CGFloat) -> CGFloat {
        if currentTemp >= highTemp {
            return yMax
        } else if currentTemp <= lowTemp {
            return yMin
        } else {
            let ratio = (currentTemp - lowTemp) / (highTemp - lowTemp)
            return yMin - CGFloat(ratio) * (yMin - yMax)
        }
    }
}
