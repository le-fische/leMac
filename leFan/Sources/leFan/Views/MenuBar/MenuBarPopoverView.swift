import SwiftUI

public struct MenuBarPopoverView: View {
    @ObservedObject var appState: AppState
    let onOpenMainWindow: () -> Void
    let onQuit: () -> Void

    public var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "fanblades.fill")
                        .foregroundColor(.cyan)
                    Text("leFan")
                        .font(.system(size: 14, weight: .bold))
                }

                Spacer()

                Button(action: onOpenMainWindow) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Open Full Window")
            }

            // Quick Preset Switching Bar
            VStack(alignment: .leading, spacing: 6) {
                Text("QUICK PROFILES")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    ForEach(appState.presets.prefix(4)) { preset in
                        let isActive = appState.activePresetId == preset.id
                        Button(action: { appState.applyPreset(preset) }) {
                            VStack(spacing: 3) {
                                Image(systemName: preset.icon)
                                    .font(.system(size: 12))
                                Text(preset.name.replacingOccurrences(of: " Mode", with: ""))
                                    .font(.system(size: 9, weight: .medium))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(isActive ? Color.cyan.opacity(0.25) : Color.primary.opacity(0.05))
                            .foregroundColor(isActive ? .cyan : .primary)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isActive ? Color.cyan : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            // Fans Quick Sliders
            VStack(alignment: .leading, spacing: 10) {
                Text("FAN SPEEDS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)

                ForEach(0..<appState.fans.count, id: \.self) { idx in
                    let fan = appState.fans[idx]
                    VStack(spacing: 4) {
                        HStack {
                            Text(fan.name)
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text("\(Int(fan.actualRPM)) RPM")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }

                        // Mini Slider
                        Slider(
                            value: Binding(
                                get: { fan.actualRPM },
                                set: { appState.setFanMode(fanIndex: idx, mode: .constant(rpm: $0)) }
                            ),
                            in: fan.minRPM...fan.maxRPM,
                            step: 50
                        )
                        .tint(.cyan)
                    }
                    .padding(8)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)
                }
            }

            Divider()

            // Key Temperatures
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CPU AVG")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(appState.formatTemp(appState.cpuAvgTemp))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text("CPU PEAK")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(appState.formatTemp(appState.cpuMaxTemp))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text("HOTSPOT")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(appState.formatTemp(appState.highestTemp))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 4)

            Divider()

            // Footer
            HStack {
                Button(action: onOpenMainWindow) {
                    Text("Open Dashboard")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(action: {
                    SoftwareUpdater.shared.checkForUpdates()
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Check for Updates…")
                .padding(.horizontal, 4)

                Button(action: onQuit) {
                    Text("Quit")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 290)
    }
}
