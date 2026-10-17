# leFan — Modern & Unlocked Fan Controller for macOS

A modern, native macOS fan control and thermal monitoring application built with **SwiftUI** and native **IOKit / AppleSMC / IOHIDEventSystemClient**.

Designed from the ground up to replace outdated, paywalled utility apps, offering a **100% free, unrestricted feature set** inside an Apple Human Interface Guidelines (HIG)-compliant interface.

---

## 📥 Direct Download & Installation

### Quick Install (No Terminal or Xcode Needed!)

Download ready-to-run macOS packages directly from [GitHub Releases](https://github.com/le-fische/leMac/releases):

1. **Download the latest release**:
   - 💿 [**Download leFan.dmg**](https://github.com/le-fische/leMac/releases/latest/download/leFan.dmg) *(Drag & Drop Installer)*
   - 📦 [**Download leFan.zip**](https://github.com/le-fische/leMac/releases/latest/download/leFan.zip) *(Portable Archive)*
2. **Install**:
   - Open `leFan.dmg` and drag **leFan** into your **Applications** folder.
3. **Launch**:
   - Open **leFan** from Applications, Launchpad, or Spotlight (`⌘ + Space`).

> **Tip for First Launch**: Because leFan is an open-source utility signed ad-hoc, if macOS Gatekeeper displays an "unidentified developer" prompt on first launch, simply right-click (or Control-click) `leFan.app` in `/Applications` and select **Open**, then click **Open**. Alternatively, run:
> ```bash
> xattr -cr /Applications/leFan.app
> ```

---

## ✨ Features & Paywall Comparison

| Feature | Commercial Apps | **leFan (Free & Open)** |
| :--- | :---: | :---: |
| **Custom Sensor Curves** | 🔒 Paid Pro ($14.95–$29.95) | **✅ Fully Free & Interactive** |
| **Custom Cooling Presets** | 🔒 Paid Pro Only | **✅ Unlimited Custom Profiles (Save / Edit / Delete)** |
| **Menu Bar Customization** | 🔒 Paid Pro Only | **✅ Full Choice: RPM + Temp, RPM Only, Temp Only, or Icon** |
| **Modern Native UI** | ❌ Dated Qt / Windows UI | **✅ Native SwiftUI, Glass Materials, SF Symbols 6** |
| **Apple Silicon (M1–M4) Support** | Partial | **✅ Full 70+ Core Die & HID Thermal Sensor Telemetry** |
| **Animated Tachometer Gauges** | ❌ Flat text | **✅ Dynamic Glowing Circular Dials** |
| **Historical Telemetry Charts** | ❌ None | **✅ 60-Second Real-Time Sparklines** |
| **Synchronized Dual-Fan Control** | ❌ Basic | **✅ Synchronize or Independent** |
| **Idle CPU Usage** | ❌ 5%–15% | **✅ < 0.2% Idle in Menu Bar** |
| **Price** | \$14.95 – \$29.95 | **🎉 100% Free** |

---

## 🖥️ User Interface Overview

### 1. 💨 Fans & Controls Dashboard
- **Interactive Tachometer Dials**: Circular progress gauges displaying live RPM, percent of maximum, minimum and maximum thresholds, and animated spinning fan blades with speed proportional to actual hardware RPM.
- **Three Fan Modes per Fan**:
  - **Auto (System)**: Restores native macOS thermal governor.
  - **Constant RPM**: Smooth slider from hardware min to max RPM with quick-snap buttons (`Min`, `25%`, `50%`, `75%`, `Max`).
  - **Sensor Curve**: Dynamically adjust fan speed based on any selected thermal sensor.
- **Synchronize Fans Toggle**: Control Left and Right fans together in lockstep, or unlink them for asymmetric cooling.

### 2. ⚡ Cooling Profiles & Presets (Un-Paywalled)
- **Built-in System Profiles**:
  - 🍏 **Factory Auto**: Restores native Apple thermal management.
  - 🤫 **Silent Mode**: Whisper-quiet profile; keeps fans at minimum speed until high load (65°C+).
  - ⚖️ **Balanced**: Everyday optimal profile for web browsing, office tasks, and coding.
  - 🚀 **Performance**: Aggressive cooling curve designed for Xcode compiling, 3D rendering, and gaming.
  - 🌪️ **Max Blast**: Immediate 100% fan speed to rapidly cool down the machine after heavy rendering.
- **Custom User Presets**:
  - Click **"Save Current as Preset"** to capture your exact fan speeds and curves.
  - Name, describe, and assign custom icons to your profiles.
  - Unlimited profiles without restrictions.

### 3. 🌡️ Thermal Sensors Dashboard
- Reads 70+ granular hardware sensors via `IOHIDEventSystemClient` and `AppleSMC`:
  - Individual CPU Performance and Efficiency core dies (`PMU tdie1` ... `tdie14`).
  - GPU clusters.
  - Apple SSD / NAND NVMe storage temperature.
  - Battery gas gauge temperature.
  - Power Management Unit (PMU) and thermal hotspots.
- Category filters (`All`, `CPU`, `GPU`, `Battery`, `Storage`, `System`).
- Live search bar to filter sensors instantly.
- Status badges: **Cool** (< 50°C), **Optimal** (50–70°C), **Warm** (70–85°C), **Hot** (> 85°C).
- Min/Max records and real-time historical sparklines for every sensor.
- Instant switch between Celsius (**°C**) and Fahrenheit (**°F**).

### 4. 📊 Live Telemetry & Diagnostics
- 60-second real-time historical charts comparing Fan RPM vs Peak System Temperature.
- Session high, low, and average statistics.

### 5. 󰈐 Menu Bar Companion
- Resides in the macOS menu bar.
- Shows live Fan Speed (e.g. `2,450 RPM`) and Peak Temperature (e.g. `42°C`).
- Configurable display: `RPM & Temp`, `RPM Only`, `Temp Only`, or `Icon Only`.
- Clicking opens a sleek floating popover with instant preset buttons, fan sliders, and sensor readings.

---

## 🔒 Hardware Architecture & Safety

- **Read Operations (Zero Permissions Required)**:
  - Reading fan speeds and all temperature sensors uses direct native IOKit and HID events with **zero admin prompts**.
- **Write Operations (Privileged Helper)**:
  - macOS requires root privileges to write SMC registers (`F0Md`, `F0Tg`).
  - Includes a lightweight daemon (`lefan-helper`).
  - A clean, 1-click **"Enable Fan Control"** button prompts once for macOS administrator authorization and sets up the background daemon via `launchd`.
  - Once authorized, fan adjustments and dynamic curves apply continuously and instantly.

---

## 🛠️ Building & Packaging from Source

### Rebuild and Install to `/Applications/leFan.app`:
```bash
cd /Users/le/Documents/Projects/leMac/leFan
./package_app.sh
```

### Build Standalone Release Packages (`.dmg` & `.zip`):
```bash
cd /Users/le/Documents/Projects/leMac/leFan
./package_release.sh
```
This generates:
- `dist/leFan.dmg`: Standalone drag-and-drop disk image installer.
- `dist/leFan.zip`: Portable compressed application archive.
- `dist/checksums.txt`: SHA256 checksums for release verification.
