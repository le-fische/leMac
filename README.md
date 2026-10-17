# leMac 

A curated monorepo of lightweight native macOS utilities, tools, and mini projects designed for MacBook and Apple Silicon.

Each project in this repository is designed to be self-contained, high-performance, and deeply integrated with macOS system features (Notch, Menu Bar, Vision OCR, CoreAudio, IOBluetooth, and AppKit/SwiftUI).

---

## 📂 Projects Catalog

| Project | Description | Tech Stack | Status |
| :--- | :--- | :--- | :--- |
| [**leNotch**](leNotch/) | Dynamic Island & Notch utility with 60 FPS audio visualizer glow, smart OCR shelf, HUD replacements, and live weather. | Swift, SwiftUI, AppKit, Metal, Vision | Active |
| [**leMinibar**](leMinibar/) | 1:1 Ice-inspired zero-permission menu bar minimizer with single hairline dot control. | Swift, AppKit, Cocoa | Active |
| [**leCG**](leCG/) | Lightweight real-time CPU, GPU, RAM, and thermal monitor menu bar application for Apple Silicon. | Swift, IOKit, Metal, AppKit | Active |
| [**leFan**](leFan/) | Modern unlocked fan controller with tachometers, dynamic sensor curves, and presets. | Swift, SwiftUI, AppKit, IOKit | Active |
| [**leWheel**](leWheel/) | 100% free radial app launcher and window switcher with hold-to-navigate flick gestures. | Swift, SwiftUI, AppKit | Active |

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

## 🍸 [leMinibar](leMinibar/)

A minimalist, zero-dependency menu bar minimizer and organizer for macOS.

- **Single Dot Control (1:1 Ice UX)**: Open circle (`○`) reveals secondary apps; solid dot (`●`) hides them.
- **AirPods-Style Hairline Dot**: Ultra-sharp `0.85 pt` stroke matching Apple system icons for zero Retina blur.
- **Zero Permissions**: 0 Accessibility permissions, 0 Screen Recording permissions, 100% private and offline.
- **0.0% Battery Drain**: Pure event-driven AppKit with zero background polling and zero idle CPU usage.
- **Drag-to-Organize (`⌘ + Drag`)**: Move the dot anywhere along the menu bar to choose what hides and what stays visible.

---

## ⚡️ [leCG](leCG/)

A lightweight, native menu bar monitor for CPU, GPU, and Hardware Thermals with live stacked graphics.

- **Stacked Menu Bar Graphics**: Live rolling history waveforms, horizontal gauge bars, or compact micro-capsules unified in one icon.
- **Hardware Thermals**: Reads Apple Silicon internal die thermal sensors (CPU, GPU, SoC Peak) via IOKit HID without sudo.
- **True Apple Silicon GPU Utilization**: Live device utilization, renderer activity, tiler usage, and in-use GPU memory via `IOAccelerator`.
- **CPU Breakdown**: User, system, idle, and per-core activity across Performance (P-cores) and Efficiency (E-cores).
- **RAM & Top Processes**: Live Unified Memory metrics and top 5 CPU-consuming processes.
- **Unit & Metric Toggle**: Switch between Percentages, Temperatures (°C / °F), or Both right from the menu.
- **Ultra-Lightweight**: Native Swift, ~240 KB binary, < 0.2% CPU idle, automatic sleep/wake power conservation.

---

## 🌪️ [leFan](leFan/)

A modern, unlocked fan controller and thermal telemetry utility for macOS.

- **Dynamic Sensor Curves (Un-paywalled)**: Fine-grained temperature-to-RPM curves based on any sensor (CPU Average, Max Core, GPU, SSD, or Battery).
- **Custom Cooling Presets**: Unlimited one-click profiles (Silent, Balanced, Performance, Max Blast, or custom user profiles).
- **Interactive Tachometer Gauges**: Glowing circular dials with live RPM, min/max limits, percent of max speed, and spinning fan animations.
- **70+ Thermal Sensors**: Granular M-series core die telemetry, storage, battery, and hotspot telemetry with live sparklines.
- **Menu Bar Extra Companion**: Configurable status bar item with instant popover quick sliders and preset buttons.

---

## 🎡 [leWheel](leWheel/)

A 100% free, native macOS radial app launcher and window switcher with hold-to-navigate flick mechanics.

- **Dynamic Radial Wheel**: Seamlessly holds any number of apps with adaptive sector geometry, concentric multi-rings, and customizable wheel diameter (`140px`–`320px`).
- **Dual-Press Modifier Trigger (`⌥⌘`)**: Press and hold `Option + Command` anywhere to instantly summon the wheel at your cursor.
- **Hold-to-Navigate & Release-to-Launch**: Flick your mouse toward an app and release the shortcut to launch in under 50ms without clicking.
- **Reliable Top-Layer Window Restoration**: Uses native LaunchServices reopen events (`kAEReopenApplication`) and Accessibility elevation (`AXUIElement`) to guarantee that apps with closed (`Cmd+W`) or minimized windows always restore and pop to the top layer directly at your cursor.
- **Lowkey macOS Frosted Glass**: Sleek, distraction-free native macOS frosted vibrancy with clean gray hover highlights, transparent center deadzone, and haptic trackpad feedback.
- **Running App Switcher Mode**: Radial `Cmd+Tab` replacement displaying currently active apps with instant `Cmd+Q` termination right from the wheel.
- **100% Private & Unlimited**: Zero 5-item slot caps, zero 300-switch limits, zero paywalls, zero telemetry.

---

## 📥 Direct App Downloads (.dmg / .zip)

> **No Terminal or Xcode needed!** Download ready-to-run macOS app packages directly from [GitHub Releases](https://github.com/le-fische/leMac/releases):

| App | Direct Download | Description | Requirements |
| :--- | :--- | :--- | :--- |
| **leNotch** 🪽 | 💿 [**leNotch.dmg**](https://github.com/le-fische/leMac/releases/latest/download/leNotch.dmg) · 📦 [.zip](https://github.com/le-fische/leMac/releases/latest/download/leNotch.zip) | Notch & Dynamic Island with 60 FPS audio glow | macOS 14.0+ |
| **leMinibar** 🍸 | 💿 [**leMinibar.dmg**](https://github.com/le-fische/leMac/releases/latest/download/leMinibar.dmg) · 📦 [.zip](https://github.com/le-fische/leMac/releases/latest/download/leMinibar.zip) | 1:1 Ice replica zero-permission menu bar minimizer | macOS 13.0+ |
| **leCG** ⚡️ | 💿 [**leCG.dmg**](https://github.com/le-fische/leMac/releases/latest/download/leCG.dmg) · 📦 [.zip](https://github.com/le-fische/leMac/releases/latest/download/leCG.zip) | Real-time CPU, GPU, & thermal menu bar monitor | macOS 14.0+ |
| **leFan** 🌪️ | 💿 [**leFan.dmg**](https://github.com/le-fische/leMac/releases/latest/download/leFan.dmg) · 📦 [.zip](https://github.com/le-fische/leMac/releases/latest/download/leFan.zip) | Modern unlocked fan controller with custom curves | macOS 14.0+ |
| **leWheel** 🎡 | 💿 [**leWheel.dmg**](https://github.com/le-fische/leMac/releases/latest/download/leWheel.dmg) · 📦 [.zip](https://github.com/le-fische/leMac/releases/latest/download/leWheel.zip) | Radial app launcher & switcher with flick gestures | macOS 14.0+ |

---

## 💻 Developer Setup & Source Code

If you prefer building from source or cloning the repository:

### 1. Clone Entire Repository
Clone all `leMac` tools at once:
```bash
git clone https://github.com/le-fische/leMac.git
```
Or download the repository source directly:
- [Download leMac ZIP](https://github.com/le-fische/leMac/archive/refs/heads/main.zip)

---

### 2. Download Individual Projects (Sparse Clone)

If you only need a specific utility without downloading the full repository, you can download any project using sparse clone:

#### 🪽 [leNotch](leNotch/)
Dynamic Island & Notch utility with 60 FPS audio visualizer glow and smart shelf.
```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/le-fische/leMac.git
cd leMac && git sparse-checkout set leNotch
```
> For setup and usage details, see [leNotch/README.md](leNotch/README.md).

#### 🍸 [leMinibar](leMinibar/)
Minimalist 1:1 Ice-inspired menu bar minimizer with single hairline dot control.
```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/le-fische/leMac.git
cd leMac && git sparse-checkout set leMinibar
```
> For setup and usage details, see [leMinibar/README.md](leMinibar/README.md).

#### ⚡️ [leCG](leCG/)
Lightweight real-time CPU, GPU, RAM, and thermal monitor for Apple Silicon.
```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/le-fische/leMac.git
cd leMac && git sparse-checkout set leCG
```
> For setup and usage details, see [leCG/README.md](leCG/README.md).

#### 🌪️ [leFan](leFan/)
Modern unlocked fan controller and thermal telemetry utility.
```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/le-fische/leMac.git
cd leMac && git sparse-checkout set leFan
```
> For setup and usage details, see [leFan/README.md](leFan/README.md).

#### 🎡 [leWheel](leWheel/)
100% free radial app launcher and window switcher with hold-to-navigate flick gestures.
```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/le-fische/leMac.git
cd leMac && git sparse-checkout set leWheel
```
> For setup and usage details, see [leWheel/README.md](leWheel/README.md).

---

## 📄 License

This repository contains open-source software. Individual projects may carry specific licenses based on their origins (e.g. `leNotch` is licensed under GNU GPLv3; see [LICENSE](LICENSE)).
