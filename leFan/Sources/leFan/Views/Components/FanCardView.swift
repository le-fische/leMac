import SwiftUI

public struct FanCardView: View {
    @ObservedObject var appState: AppState
    let fanIndex: Int

    @State private var selectedTab: Int = 0 // 0: Auto, 1: Constant, 2: Curve
    @State private var sliderRPM: Double = 3000
    @State private var curveSensorKey: String = "CPU_AVG"
    @State private var curveLowTemp: Double = 50
    @State private var curveHighTemp: Double = 82

    private var fan: Fan? {
        guard fanIndex < appState.fans.count else { return nil }
        return appState.fans[fanIndex]
    }

    public var body: some View {
        if let currentFan = fan {
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentFan.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)

                        Text("Fan #\(currentFan.id + 1)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Quick Auto Restore Pill
                    if currentFan.isManual {
                        Button(action: {
                            selectedTab = 0
                            appState.setFanMode(fanIndex: fanIndex, mode: .auto)
                        }) {
                            Label("Reset to Auto", systemImage: "arrow.counterclockwise")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                // Tachometer Dial
                TachometerDial(
                    actualRPM: currentFan.actualRPM,
                    minRPM: currentFan.minRPM,
                    maxRPM: currentFan.maxRPM,
                    targetRPM: currentFan.targetRPM,
                    isManual: currentFan.isManual,
                    modeTitle: currentFan.mode.title
                )
                .padding(.vertical, 4)

                // Mode Selector
                Picker("Fan Mode", selection: $selectedTab) {
                    Text("Auto").tag(0)
                    Text("Constant").tag(1)
                    Text("Sensor Curve").tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedTab) { _, newTab in
                    applyTabChange(newTab)
                }

                // Mode Controls Area
                Group {
                    if selectedTab == 0 {
                        // Auto Mode Info
                        VStack(spacing: 6) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                            Text("Automatic Mode Active")
                                .font(.system(size: 13, weight: .medium))
                            Text("macOS dynamically adjusts fan speed based on thermal pressure.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .padding(.horizontal)
                    } else if selectedTab == 1 {
                        // Constant RPM Controls
                        VStack(spacing: 12) {
                            HStack {
                                Text("Target Speed:")
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text("\(Int(sliderRPM)) RPM")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyan)
                            }

                            Slider(
                                value: $sliderRPM,
                                in: currentFan.minRPM...currentFan.maxRPM,
                                step: 50
                            ) { _ in
                                appState.setFanMode(fanIndex: fanIndex, mode: .constant(rpm: sliderRPM))
                            }
                            .tint(.cyan)

                            // Quick preset buttons
                            HStack(spacing: 6) {
                                Button("Min") { setQuickRPM(currentFan.minRPM) }
                                Button("25%") { setQuickPercent(0.25, fan: currentFan) }
                                Button("50%") { setQuickPercent(0.50, fan: currentFan) }
                                Button("75%") { setQuickPercent(0.75, fan: currentFan) }
                                Button("Max") { setQuickRPM(currentFan.maxRPM) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(10)
                        .frame(minHeight: 120)
                    } else {
                        // Sensor Curve Controls
                        CurveEditorView(
                            appState: appState,
                            fan: currentFan,
                            selectedSensorKey: $curveSensorKey,
                            lowTemp: $curveLowTemp,
                            highTemp: $curveHighTemp,
                            onSave: {
                                appState.setFanMode(
                                    fanIndex: fanIndex,
                                    mode: .sensorCurve(
                                        sensorKey: curveSensorKey,
                                        lowTemp: curveLowTemp,
                                        highTemp: curveHighTemp
                                    )
                                )
                            }
                        )
                    }
                }
            }
            .padding(18)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .onAppear {
                syncWithCurrentFan(currentFan)
            }
        }
    }

    private func syncWithCurrentFan(_ fan: Fan) {
        switch fan.mode {
        case .auto:
            selectedTab = 0
        case .constant(let rpm):
            selectedTab = 1
            sliderRPM = rpm
        case .sensorCurve(let key, let low, let high):
            selectedTab = 2
            curveSensorKey = key
            curveLowTemp = low
            curveHighTemp = high
        }
    }

    private func applyTabChange(_ tab: Int) {
        guard let currentFan = fan else { return }
        switch tab {
        case 0:
            appState.setFanMode(fanIndex: fanIndex, mode: .auto)
        case 1:
            sliderRPM = max(currentFan.actualRPM, currentFan.minRPM)
            appState.setFanMode(fanIndex: fanIndex, mode: .constant(rpm: sliderRPM))
        case 2:
            appState.setFanMode(
                fanIndex: fanIndex,
                mode: .sensorCurve(
                    sensorKey: curveSensorKey,
                    lowTemp: curveLowTemp,
                    highTemp: curveHighTemp
                )
            )
        default:
            break
        }
    }

    private func setQuickRPM(_ rpm: Double) {
        sliderRPM = rpm
        appState.setFanMode(fanIndex: fanIndex, mode: .constant(rpm: rpm))
    }

    private func setQuickPercent(_ pct: Double, fan: Fan) {
        let rpm = fan.minRPM + (fan.maxRPM - fan.minRPM) * pct
        setQuickRPM(rpm)
    }
}
