import SwiftUI

public struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var updater = SoftwareUpdater.shared
    @State private var isAuthorizing: Bool = false
    @State private var statusMessage: String?

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Header
                VStack(alignment: .leading, spacing: 2) {
                    Text("Settings & Preferences")
                        .font(.system(size: 20, weight: .bold))
                    Text("Configure monitoring preferences, menu bar format, and hardware control helper.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // General Preferences Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("GENERAL PREFERENCES")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    // Temperature Unit
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Temperature Unit")
                                .font(.system(size: 13, weight: .medium))
                            Text("Display temperatures in Celsius or Fahrenheit")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: Binding(
                            get: { appState.settings.temperatureUnit },
                            set: {
                                var s = appState.settings
                                s.temperatureUnit = $0
                                appState.updateSettings(s)
                            }
                        )) {
                            Text("Celsius (°C)").tag(TemperatureUnit.celsius)
                            Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit)
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }

                    Divider()

                    // Refresh Interval
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sensor Refresh Interval")
                                .font(.system(size: 13, weight: .medium))
                            Text("Frequency of SMC fan and thermal polling")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: Binding(
                            get: { appState.settings.pollingInterval },
                            set: {
                                var s = appState.settings
                                s.pollingInterval = $0
                                appState.updateSettings(s)
                            }
                        )) {
                            Text("0.5 Seconds (Fast)").tag(0.5)
                            Text("1.0 Second (Normal)").tag(1.0)
                            Text("2.0 Seconds (Eco)").tag(2.0)
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }

                    Divider()

                    // Synchronize Fans
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Synchronize Fans")
                                .font(.system(size: 13, weight: .medium))
                            Text("Keep Left and Right fans at matching speeds and curve modes")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { appState.settings.fansLinked },
                            set: {
                                var s = appState.settings
                                s.fansLinked = $0
                                appState.updateSettings(s)
                            }
                        ))
                        .labelsHidden()
                    }
                }
                .padding(18)
                .background(.ultraThinMaterial)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )

                // Menu Bar Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("MENU BAR COMPANION")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Menu Bar Item Content")
                                .font(.system(size: 13, weight: .medium))
                            Text("Choose what information is visible in your Mac menu bar")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: Binding(
                            get: { appState.settings.menuBarMode },
                            set: {
                                var s = appState.settings
                                s.menuBarMode = $0
                                appState.updateSettings(s)
                            }
                        )) {
                            ForEach(MenuBarDisplayMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                }
                .padding(18)
                .background(.ultraThinMaterial)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )

                // Hardware Control Helper Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("PRIVILEGED HARDWARE HELPER")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Image(systemName: appState.helperStatus == .connected ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(appState.helperStatus == .connected ? .green : .orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.helperStatus.title)
                                .font(.system(size: 14, weight: .bold))
                            Text(appState.helperStatus == .connected
                                 ? "Background daemon is running with SMC write privileges."
                                 : "Authorize the helper to enable direct fan speed and curve controls.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: installOrReinstallHelper) {
                            if isAuthorizing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text(appState.helperStatus == .connected ? "Reinstall Helper" : "Authorize Helper")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(appState.helperStatus == .connected ? .cyan : .orange)
                        .disabled(isAuthorizing)
                    }

                    if let msg = statusMessage {
                        Text(msg)
                            .font(.system(size: 11))
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

                // Software Updates Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("SOFTWARE UPDATES")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Automatic Updates")
                                .font(.system(size: 13, weight: .medium))
                            Text("Automatically check for and notify of new updates")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { updater.automaticallyChecksForUpdates },
                            set: { updater.automaticallyChecksForUpdates = $0 }
                        ))
                        .labelsHidden()
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Automatic Downloads")
                                .font(.system(size: 13, weight: .medium))
                            Text("Download new releases automatically in the background")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { updater.automaticallyDownloadsUpdates },
                            set: { updater.automaticallyDownloadsUpdates = $0 }
                        ))
                        .disabled(!updater.automaticallyChecksForUpdates)
                        .labelsHidden()
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Version")
                                .font(.system(size: 13, weight: .medium))
                            let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                            let bld = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                            Text("leFan v\(ver) (Build \(bld))")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            updater.checkForUpdates()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Check for Updates…")
                            }
                            .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                    }
                }
                .padding(18)
                .background(.ultraThinMaterial)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )

                // Hardware Info Card
                VStack(alignment: .leading, spacing: 10) {
                    Text("HARDWARE DETAILS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack {
                        Text("Model:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(appState.macModelName)
                            .font(.system(size: 12, weight: .semibold))
                    }

                    HStack {
                        Text("Fans Detected:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(appState.fans.count)")
                            .font(.system(size: 12, weight: .semibold))
                    }

                    HStack {
                        Text("Thermal Sensors:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(appState.sensors.count) Active Sensors")
                            .font(.system(size: 12, weight: .semibold))
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

    private func installOrReinstallHelper() {
        isAuthorizing = true
        statusMessage = "Requesting authorization from macOS..."
        let scriptPath = Bundle.main.path(forResource: "install_helper", ofType: "sh")
            ?? "/Users/le/Documents/Projects/leMac/leFan/Sources/Helper/install_helper.sh"
        HelperClient.shared.installHelper(scriptPath: scriptPath) { success, err in
            isAuthorizing = false
            if success {
                appState.checkHelper()
                statusMessage = "Helper installed successfully!"
            } else {
                statusMessage = "Authorization failed: \(err ?? "Unknown")"
            }
        }
    }
}
