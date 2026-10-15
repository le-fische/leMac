import SwiftUI

public struct FansDashboardView: View {
    @ObservedObject var appState: AppState
    @State private var isAuthorizing: Bool = false
    @State private var authErrorMessage: String?

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Authorization banner if helper not connected
                if appState.helperStatus != .connected {
                    HStack(spacing: 14) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fan Control Permission Required")
                                .font(.system(size: 13, weight: .bold))
                            Text("Monitoring works freely. To change fan speeds or apply curves, authorize the background helper once.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: authorizeHelper) {
                            if isAuthorizing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Enable Fan Control")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(isAuthorizing)
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                }

                // Quick Controls & Preset Bar
                HStack {
                    // Link Fans Toggle
                    Toggle(isOn: Binding(
                        get: { appState.settings.fansLinked },
                        set: {
                            var s = appState.settings
                            s.fansLinked = $0
                            appState.updateSettings(s)
                        }
                    )) {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .foregroundColor(appState.settings.fansLinked ? .cyan : .secondary)
                            Text("Synchronize Fans")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .toggleStyle(.checkbox)

                    Spacer()

                    // Quick reset all to auto
                    Button(action: {
                        if let factory = appState.presets.first(where: { $0.name == "Factory Auto" }) {
                            appState.applyPreset(factory)
                        }
                    }) {
                        Label("Reset All to Auto", systemImage: "apple.logo")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 4)

                // Fan Cards Grid
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 340), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(0..<appState.fans.count, id: \.self) { idx in
                        FanCardView(appState: appState, fanIndex: idx)
                    }
                }

                // Telemetry Highlights Bar
                HStack(spacing: 16) {
                    MetricHighlightCard(
                        title: "Average Fan RPM",
                        value: "\(Int(appState.averageRPM)) RPM",
                        icon: "fanblades",
                        color: .cyan
                    )
                    MetricHighlightCard(
                        title: "CPU Average",
                        value: appState.formatTemp(appState.cpuAvgTemp),
                        icon: "cpu",
                        color: .green
                    )
                    MetricHighlightCard(
                        title: "CPU Peak",
                        value: appState.formatTemp(appState.cpuMaxTemp),
                        icon: "flame.fill",
                        color: .orange
                    )
                    MetricHighlightCard(
                        title: "Overall Peak",
                        value: appState.formatTemp(appState.highestTemp),
                        icon: "thermometer.high",
                        color: .red
                    )
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
    }

    private func authorizeHelper() {
        isAuthorizing = true
        let scriptPath = Bundle.main.path(forResource: "install_helper", ofType: "sh")
            ?? "/Users/le/Documents/Projects/leMac/leFan/Sources/Helper/install_helper.sh"
        HelperClient.shared.installHelper(scriptPath: scriptPath) { success, err in
            isAuthorizing = false
            if success {
                appState.checkHelper()
            } else {
                authErrorMessage = err
            }
        }
    }
}

fileprivate struct MetricHighlightCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
