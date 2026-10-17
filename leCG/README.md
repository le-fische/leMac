# leCG 

A lightweight, native macOS menu bar app for monitoring **CPU**, **GPU**, and **Hardware Thermals** in real time with live graphics, built specifically for Apple Silicon (M1/M2/M3/M4) and macOS Sonoma / Sequoia.

![leCG](https://img.shields.io/badge/macOS-14.0%2B-blue)
![Architecture](https://img.shields.io/badge/Arch-Apple%20Silicon%20(arm64)-orange)
![Binary Size](https://img.shields.io/badge/Binary%20Size-~240KB-success)

---

## Highlights

- **Live Menu Bar Graphics**: Crisp, Retina-rendered mini sparkline history waveforms, vertical gauge bars, or compact micro-capsules right in your menu bar.
- **Hardware Temperature Monitoring**: Reads Apple Silicon internal die thermal sensors in real-time via IOKit HID (`0xFF00:5`) to report CPU temperature, GPU temperature, and peak SoC hot-spot temperature without `sudo`.
- **True Apple Silicon GPU Monitoring**: Uses native macOS IOKit (`IOAccelerator`) to read live GPU device utilization, renderer activity, tiler usage, and allocated GPU memory without `sudo`.
- **Detailed CPU Breakdown**: Computes overall CPU load, User / System / Idle percentages, and per-core activity across both **Performance (P-cores)** and **Efficiency (E-cores)**.
- **Unified Memory (RAM) Monitor**: Shows active, wired, compressed, and total memory usage.
- **Top 5 Processes**: Instant view of the top CPU-consuming apps and processes in the dropdown menu.
- **Flexible Units & Display**:
  - Show **Percentages**, **Temperatures**, or **Both** in the menu bar icon.
  - Switch between **Celsius (°C)** and **Fahrenheit (°F)**.
- **Ultra-Lightweight & Battery Efficient**:
  - Written in native Swift with zero third-party dependencies.
  - Binary size is only **~240 KB** (no Electron, no Python, no heavy runtime).
  - Idles at **< 0.2% CPU**.
  - Automatically pauses polling when your Mac goes to sleep and resumes on wake.
- **Customizable**:
  - **5 Graphic Styles**: Dual Sparklines (Waveform), Sparklines + %, Vertical Bars + %, Compact Dual Gauges, Numbers Only.
  - **3 Color Themes**: Vibrant (Electric Cyan CPU / Tangerine GPU), Adaptive Monochrome (matches system theme), Dynamic Alert (Green → Orange → Red).
  - **Configurable Refresh Intervals**: 0.5s, 1.0s, 2.0s, or 5.0s.
  - **Launch at Login**: Native toggle via Apple's `SMAppService`.

---

## Visual Styles

All styles are unified into **one single icon capsule** with CPU on top and GPU on bottom:

| Style | Description | Layout in One Icon |
|---|---|---|
| **Stacked Sparklines + %** *(Default)* | CPU waveform on top, GPU waveform on bottom, each with live % or temp in one single pill. | `┌ C ∿∿ 14% ┐`<br>`└ G ∿_  5% ┘` |
| **Stacked Waveforms** | Pure dual waveforms (CPU top, GPU bottom) with a subtle hairline separator. | `┌ C ∿∿∿∿∿ ┐`<br>`└ G ∿____ ┘` |
| **Stacked Horizontal Bars + %** | CPU horizontal gauge bar on top, GPU horizontal bar on bottom with live %. | `┌ C [██░░] 14% ┐`<br>`└ G [█░░░]  5% ┘` |
| **Stacked Horizontal Bars (Compact)** | Micro-capsule (24 pt wide) with two stacked horizontal gauge bars. | `┌ [████░░] ┐`<br>`└ [██░░░░] ┘` |
| **Stacked Numbers** | Clean two-row numeric text: CPU on top row, GPU on bottom row. | `┌ C: 14% ┐`<br>`└ G:  5% ┘` |
| **Side-by-Side Dual Sparklines** | Side-by-side mode (preserved as an option). | `[ C ∿∿ ] [ G ∿_ ]` |

## 📥 Download & Installation

### Quick Install (No Terminal or Xcode Needed!)

1. **Download the latest release**:
   - 💿 [**Download leCG.dmg**](https://github.com/le-fische/leMac/releases/latest/download/leCG.dmg) *(Drag & Drop Installer)*
   - 📦 [**Download leCG.zip**](https://github.com/le-fische/leMac/releases/latest/download/leCG.zip) *(Portable Archive)*
2. **Install**:
   - Open `leCG.dmg` and drag **leCG** into your **Applications** folder.
3. **Launch**:
   - Open **leCG** from Applications, Launchpad, or Spotlight.

> **Tip for First Launch**: Because leCG is an open-source indie utility signed ad-hoc, if macOS Gatekeeper displays an "unidentified developer" prompt on first launch, simply right-click (or Control-click) `leCG.app` in `/Applications` and select **Open**, then click **Open**. Alternatively, run:
> ```bash
> xattr -cr /Applications/leCG.app
> ```

---

## Quick Start

### 1. Build and Run Immediately

```bash
cd leCG
make run
```

Or manually:

```bash
./build_app.sh
open leCG.app
```

The app will appear instantly in your top-right menu bar. Click the icon to open the detailed monitor panel.

### 2. Install to Applications

```bash
make install
```

This copies `leCG.app` into `/Applications` so you can launch it anytime from Spotlight, Launchpad, or Finder.

---

## Architecture & Code Structure

```
leCG/
├── Sources/
│   ├── HardwareInfo.swift    # Queries chip model (e.g. M4 Pro), P/E core counts, GPU cores via sysctl & IORegistry
│   ├── SystemMonitor.swift   # Polls Mach kernel CPU stats, per-core load, IOKit GPU statistics, and RAM
│   ├── ThermalMonitor.swift  # Reads Apple Silicon IOHID temperature sensors (CPU, GPU, SoC Peak)
│   ├── GraphRenderer.swift   # Renders crisp NSImage graphics for the menu bar with CoreGraphics
│   ├── MenuController.swift  # Manages the dropdown NSMenu, live statistics, submenus, and actions
│   ├── AppDelegate.swift     # Manages NSStatusItem, sleep/wake power conservation, and update loop
│   └── main.swift            # Configures NSApplication in accessory mode (no Dock icon)
├── Info.plist                # Bundle configuration with LSUIElement = true
├── build_app.sh              # Script compiling Swift code into leCG.app bundle
├── Makefile                  # make, make run, make install, make clean
└── AppIcon.icns              # Retina macOS squircle app icon
```

---

## License

MIT License. Free to use and modify.
