import SwiftUI

public enum MainTab: String, CaseIterable, Identifiable {
    case fans = "Fans"
    case presets = "Profiles"
    case sensors = "Sensors"
    case telemetry = "Telemetry"
    case settings = "Settings"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .fans: return "fanblades.fill"
        case .presets: return "slider.horizontal.3"
        case .sensors: return "thermometer.medium"
        case .telemetry: return "chart.xyaxis.line"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct MainWindowView: View {
    @ObservedObject var appState: AppState
    @State private var selectedTab: MainTab = .fans

    public var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 6) {
                // App Branding Header
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)

                        Image(systemName: "fanblades.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("leFan")
                            .font(.system(size: 15, weight: .bold))
                        Text(appState.macModelName)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Divider()
                    .padding(.bottom, 4)

                // Navigation Items
                ForEach(MainTab.allCases) { tab in
                    Button(action: { selectedTab = tab }) {
                        HStack(spacing: 10) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 20)
                                .foregroundColor(selectedTab == tab ? .white : .secondary)

                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))

                            Spacer()

                            if tab == .sensors {
                                Text("\(appState.sensors.count)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(selectedTab == tab ? Color.cyan : Color.clear)
                        .foregroundColor(selectedTab == tab ? .white : .primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Bottom Status Pill
                HStack(spacing: 8) {
                    Circle()
                        .fill(appState.helperStatus == .connected ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)

                    Text(appState.helperStatus == .connected ? "Control Engine Active" : "Monitoring Only")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding(10)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(8)
                .padding(.bottom, 4)
            }
            .padding(10)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            // Main Content Area
            ZStack {
                switch selectedTab {
                case .fans:
                    FansDashboardView(appState: appState)
                case .presets:
                    PresetsView(appState: appState)
                case .sensors:
                    ThermalSensorsView(appState: appState)
                case .telemetry:
                    TelemetryGraphView(appState: appState)
                case .settings:
                    SettingsView(appState: appState)
                }
            }
            .navigationTitle(selectedTab.rawValue)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // Quick Preset Selector in Toolbar
                    Menu {
                        ForEach(appState.presets) { preset in
                            Button(action: { appState.applyPreset(preset) }) {
                                HStack {
                                    Image(systemName: preset.icon)
                                    Text(preset.name)
                                    if appState.activePresetId == preset.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                            let current = appState.presets.first(where: { $0.id == appState.activePresetId })
                            Text(current?.name ?? "Custom Profile")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }

                    // Refresh Button
                    Button(action: { appState.refreshMetrics() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh metrics now")
                }
            }
        }
        .frame(minWidth: 850, minHeight: 620)
    }
}
