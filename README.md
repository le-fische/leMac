# leMac 

A curated monorepo of lightweight native macOS utilities, tools, and mini projects designed for MacBook and Apple Silicon.

Each project in this repository is designed to be self-contained, high-performance, and deeply integrated with macOS system features (Notch, Menu Bar, Vision OCR, CoreAudio, IOBluetooth, and AppKit/SwiftUI).

---

## 📂 Projects Catalog

| Project | Description | Tech Stack | Status |
| :--- | :--- | :--- | :--- |
| [**leNotch**](leNotch/) | Dynamic Island & Notch utility with 60 FPS audio visualizer glow, smart OCR shelf, HUD replacements, and live weather. | Swift, SwiftUI, AppKit, Metal, Vision | Active |
| [**MiniBar**](MiniBar/) | Minimalist collapsible menu bar organizer to declutter MacBook status icons with zero dependencies. | Swift, AppKit, Cocoa | Active |
| [**leCPUGPU**](leCPUGPU/) | Lightweight real-time CPU, GPU, RAM, and thermal monitor menu bar application for Apple Silicon. | Swift, IOKit, Metal, AppKit | Active |

---

## 🪽 [leNotch](leNotch/)

An interactive Dynamic Island and MacBook Notch enhancement utility.

- **60 FPS Hardware Audio Visualizer**: Main-runloop calibrated audio spectrum visualizer with decoupled render tree for stutter-free 60 FPS performance.
- **Color-Reactive Ambient Glow**: Ambient background glow pulsing behind album art in expanded mode, with user toggle in Settings.
- **Supercharged Shelf**: Drag-and-drop workspace with Apple Vision OCR text extraction, 1-click format conversion (PNG/JPEG/TIFF/PDF), AirDrop sharing, and clipboard history.
- **Breathable Calendar**: Streamlined single-line `< Today >` date navigation with clean, non-cramped event cards.
- **System HUD Replacements**: Modern notch popups replacing standard macOS Volume, Display Brightness, and Keyboard Backlight HUDs.
- **Bluetooth Live Activity**: Real-time peripheral connect/disconnect pills with live battery percentages for AirPods, keyboards, mice, and headphones.
- **Live Weather**: Instant temperature and condition glance in the notch header powered by Open-Meteo.
- **Focus Timer**: Integrated Pomodoro timer countdown Live Activity.

> *Credits: Inspired by and built upon [boringNotch](https://github.com/TheBoredTeam/boring.notch) by TheBoredTeam.*

---

## 🍸 [MiniBar](MiniBar/)

A minimalist, zero-dependency menu bar manager for macOS.

- **Collapsible Status Items**: Click to collapse or expand secondary status bar icons.
- **Auto-Collapse**: Automatically hides icons after an idle period.
- **Zero Overhead**: Pure AppKit with minimal memory (< 10 MB RAM) and zero background CPU usage.
- **Instant Compilation**: Single command build script (`./build.sh`).

---

## ⚡️ [leCPUGPU](leCPUGPU/)

A lightweight, native menu bar monitor for CPU, GPU, and Hardware Thermals with live stacked graphics.

- **Stacked Menu Bar Graphics**: Live rolling history waveforms, horizontal gauge bars, or compact micro-capsules unified in one icon.
- **Hardware Thermals**: Reads Apple Silicon internal die thermal sensors (CPU, GPU, SoC Peak) via IOKit HID without sudo.
- **True Apple Silicon GPU Utilization**: Live device utilization, renderer activity, tiler usage, and in-use GPU memory via `IOAccelerator`.
- **CPU Breakdown**: User, system, idle, and per-core activity across Performance (P-cores) and Efficiency (E-cores).
- **RAM & Top Processes**: Live Unified Memory metrics and top 5 CPU-consuming processes.
- **Unit & Metric Toggle**: Switch between Percentages, Temperatures (°C / °F), or Both right from the menu.
- **Ultra-Lightweight**: Native Swift, ~240 KB binary, < 0.2% CPU idle, automatic sleep/wake power conservation.

---

## 🚀 How to Add New Mini Projects

> For full migration steps from outside directories, see [**MONOREPO_GUIDE.md**](MONOREPO_GUIDE.md).

Adding a new MacBook mini project to this monorepo is straightforward:

1. **Create a project folder** in the root:
   ```bash
   mkdir MyMacProject
   ```

2. **Add your source code & build configuration**:
   - For Xcode projects: save `MyMacProject.xcodeproj` inside `MyMacProject/`
   - For Swift script / CLI / single-file apps: include a `build.sh` or `Package.swift`

3. **Add a `README.md`** inside `MyMacProject/` describing its purpose, features, and build steps.

4. **Add an entry to the Projects Catalog** in this root `README.md`.

5. **Commit and push**:
   ```bash
   git add MyMacProject README.md
   git commit -m "Add MyMacProject"
   git push origin main
   ```

---

## 🛠️ Building Projects

### Build leNotch
```bash
cd leNotch
xcodebuild -scheme boringNotch -configuration Release build CODE_SIGNING_ALLOWED=NO
```

### Build MiniBar
```bash
cd MiniBar
chmod +x build.sh
./build.sh
```

### Build leCPUGPU
```bash
cd leCPUGPU
make build
# or run directly
make run
```

---

## 📄 License

This repository contains open-source software. Individual projects may carry specific licenses based on their origins (e.g. `leNotch` is licensed under GNU GPLv3; see [LICENSE](LICENSE)).
