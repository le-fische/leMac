import SwiftUI

public struct PresetsView: View {
    @ObservedObject var appState: AppState
    @State private var showingCreateSheet: Bool = false
    @State private var newPresetName: String = ""
    @State private var newPresetSubtitle: String = ""
    @State private var newPresetIcon: String = "slider.horizontal.3"

    let availableIcons = ["slider.horizontal.3", "gamecontroller.fill", "hammer.fill", "music.note", "video.fill", "cube.transparent", "leaf.fill", "flame.fill", "wind"]

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Header & Add Preset button
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cooling Profiles & Presets")
                            .font(.system(size: 20, weight: .bold))
                        Text("Switch cooling behavior with one click, or create custom presets freely.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: { showingCreateSheet = true }) {
                        Label("Save Current as Preset", systemImage: "plus.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                }

                // Built-in Presets
                VStack(alignment: .leading, spacing: 12) {
                    Text("SYSTEM PROFILES")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    ForEach(appState.presets.filter { $0.isBuiltIn }) { preset in
                        PresetRowView(
                            preset: preset,
                            isActive: appState.activePresetId == preset.id,
                            onApply: { appState.applyPreset(preset) },
                            onDelete: nil
                        )
                    }
                }

                // Custom Presets
                let customPresets = appState.presets.filter { !$0.isBuiltIn }
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("CUSTOM USER PRESETS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        Text("\(customPresets.count)")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    if customPresets.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "square.dashed")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                            Text("No Custom Presets Yet")
                                .font(.system(size: 13, weight: .medium))
                            Text("Configure your fans in the Fans tab, then click 'Save Current as Preset' to save your customized profile.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    } else {
                        ForEach(customPresets) { preset in
                            PresetRowView(
                                preset: preset,
                                isActive: appState.activePresetId == preset.id,
                                onApply: { appState.applyPreset(preset) },
                                onDelete: { appState.deletePreset(id: preset.id) }
                            )
                        }
                    }
                }
            }
            .padding(22)
        }
        .sheet(isPresented: $showingCreateSheet) {
            VStack(spacing: 18) {
                Text("Create Custom Preset")
                    .font(.system(size: 16, weight: .bold))

                Text("This will save the current speed, curve, and sensor configuration of all active fans.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Preset Name")
                        .font(.system(size: 11, weight: .semibold))
                    TextField("e.g. Gaming / Rendering", text: $newPresetName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .font(.system(size: 11, weight: .semibold))
                    TextField("e.g. High cooling for Blender and Unreal Engine", text: $newPresetSubtitle)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Icon")
                        .font(.system(size: 11, weight: .semibold))
                    HStack {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button(action: { newPresetIcon = icon }) {
                                Image(systemName: icon)
                                    .font(.system(size: 14))
                                    .frame(width: 28, height: 28)
                                    .background(newPresetIcon == icon ? Color.cyan.opacity(0.3) : Color.clear)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack {
                    Button("Cancel") {
                        showingCreateSheet = false
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Save Preset") {
                        if !newPresetName.isEmpty {
                            appState.saveCustomPreset(
                                name: newPresetName,
                                subtitle: newPresetSubtitle,
                                icon: newPresetIcon
                            )
                            newPresetName = ""
                            newPresetSubtitle = ""
                            showingCreateSheet = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .disabled(newPresetName.isEmpty)
                }
                .padding(.top, 8)
            }
            .padding(20)
            .frame(width: 360)
        }
    }
}

fileprivate struct PresetRowView: View {
    let preset: Preset
    let isActive: Bool
    let onApply: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.cyan.opacity(0.2) : Color.primary.opacity(0.06))
                    .frame(width: 38, height: 38)

                Image(systemName: preset.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isActive ? .cyan : .primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(preset.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)

                    if isActive {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }

                Text(preset.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
            }

            if isActive {
                Button(action: onApply) {
                    Text("Applied")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .tint(.cyan)
                .disabled(true)
            } else {
                Button(action: onApply) {
                    Text("Apply")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.cyan.opacity(0.5) : Color.primary.opacity(0.06), lineWidth: isActive ? 1.5 : 1)
        )
    }
}
