import SwiftUI

public struct ThermalSensorsView: View {
    @ObservedObject var appState: AppState

    private var filteredSensors: [Sensor] {
        var list = appState.sensors

        if appState.selectedCategory != .all {
            list = list.filter { $0.category == appState.selectedCategory }
        }

        if !appState.sensorSearchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(appState.sensorSearchText) ||
                $0.id.localizedCaseInsensitiveContains(appState.sensorSearchText)
            }
        }

        return list
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Filter & Search Header
            VStack(spacing: 12) {
                HStack {
                    // Category Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SensorCategory.allCases) { cat in
                                Button(action: { appState.selectedCategory = cat }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: cat.icon)
                                            .font(.system(size: 11))
                                        Text(cat.rawValue)
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(appState.selectedCategory == cat ? Color.cyan : Color.primary.opacity(0.06))
                                    .foregroundColor(appState.selectedCategory == cat ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer()

                    // Temperature Unit Toggle
                    Picker("Unit", selection: Binding(
                        get: { appState.settings.temperatureUnit },
                        set: {
                            var s = appState.settings
                            s.temperatureUnit = $0
                            appState.updateSettings(s)
                        }
                    )) {
                        Text("°C").tag(TemperatureUnit.celsius)
                        Text("°F").tag(TemperatureUnit.fahrenheit)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                }

                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search thermal sensors...", text: $appState.sensorSearchText)
                        .textFieldStyle(.plain)

                    if !appState.sensorSearchText.isEmpty {
                        Button(action: { appState.sensorSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.regularMaterial)

            Divider()

            // Sensor Grid
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("MONITORED SENSORS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        Text("\(filteredSensors.count)")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.15))
                            .foregroundColor(.cyan)
                            .clipShape(Capsule())

                        Spacer()
                    }

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 200), spacing: 14)],
                        spacing: 14
                    ) {
                        ForEach(filteredSensors) { sensor in
                            SensorCardView(
                                sensor: sensor,
                                formatTemp: { appState.formatTemp($0) }
                            )
                        }
                    }
                }
                .padding(20)
            }
        }
    }
}
