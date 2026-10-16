# leNotch 🪽

A sleek, modern, supercharged macOS Notch & Dynamic Island utility app written in Swift and SwiftUI.

Turn your MacBook's notch into an interactive Dynamic Island featuring a 60 FPS hardware audio visualizer, Vision-powered shelf, streamlined calendar, system HUD replacements, Bluetooth activity tracking, and live weather.

---

## ✨ Features

### 🎵 60 FPS Audio Visualizer & Ambient Glow
- **Silky Smooth Visualizer**: Calibrated 60 FPS audio spectrum visualizer running off main runloop common mode for zero-jitter rendering.
- **Color-Reactive Ambient Glow**: Color-matched audio glow pulsing behind album art in the expanded notch view.
- **Configurable in Settings**: Dedicated toggle under **Settings → Media** to easily disable ambient pulsing if preferred.

### 🗄️ Supercharged Shelf
- **Vision OCR Text Extraction**: Right-click any image or screenshot in the shelf and select **Extract Text (OCR)** to instantly copy recognized text to the clipboard.
- **1-Click Format Conversions**: Instantly convert images to PNG, JPEG, TIFF, or compile them into a PDF.
- **AirDrop Sharing**: 1-click beaming of shelf files to nearby Apple devices via native AirDrop.
- **Clipboard History**: Tracks recent copied clippings with direct 1-click pinning to the shelf.

### 📅 Streamlined, Breathable Calendar
- **Compact Date Navigation**: Replaces cramped wheel pickers with an intuitive single-line date bar (`EEE, MMM d`) with `< Today >` steppers.
- **Readable Event Cards**: Lightweight scrollable cards with calendar color indicator pills, clear time badges, and reminder completion toggles.

### 🎛️ System HUD Replacements
- **Native HUD Replacement**: Clean, non-intrusive notch HUDs for **Volume**, **Display Brightness**, and **Keyboard Backlight**.
- **Interactive Control**: Drag sliders directly inside the notch HUD to adjust levels.

### ⛅ Weather Integration
- **Live Glance in Header**: Displays current temperature and WMO weather condition icons (`☀️ 72°F` / `⛅ 18°C`) in the notch header using Open-Meteo.
- **Zero API Key Needed**: Automatically resolves city and locale unit preference (°C vs. °F) without configuration or paid accounts.
- **Quick Launch**: Click to open macOS Weather.

### ⏱️ Focus & Timer Live Activity
- **Pomodoro & Focus Timer**: Built-in 25-minute Pomodoro timer and countdown Live Activity pill in the notch.
- **Interactive Chime**: Pause, resume, and receive audio chime notifications upon completion.

### 🚀 Under-the-Hood Performance
- **Zero UI Hitching**: Completely decoupled high-frequency audio polling from root SwiftUI views, eliminating 30–60 body re-renders per second.
- **Hardware-Accelerated Color Extraction**: Sub-millisecond dominant color extraction via `CIFilter.areaAverage` with zero CPU memory spikes.
- **Memory Leak Free**: Fixed Combine retain cycles, notification observer leaks, and Quartz tap timeouts.

---

## 📥 Download & Installation

### Quick Install (No Terminal or Xcode Needed!)

1. **Download the latest release**:
   - 💿 [**Download leNotch.dmg**](https://github.com/le-fische/leMac/releases/latest/download/leNotch.dmg) *(Drag & Drop Installer)*
   - 📦 [**Download leNotch.zip**](https://github.com/le-fische/leMac/releases/latest/download/leNotch.zip) *(Portable Archive)*
2. **Install**:
   - Open `leNotch.dmg` and drag **leNotch** into your **Applications** folder.
3. **Launch**:
   - Open **leNotch** from Applications, Launchpad, or Spotlight.

> **Tip for First Launch**: Because leNotch is an open-source indie utility signed ad-hoc, if macOS Gatekeeper displays an "unidentified developer" prompt on first launch, simply right-click (or Control-click) `leNotch.app` in `/Applications` and select **Open**, then click **Open**. Alternatively, run:
> ```bash
> xattr -cr /Applications/leNotch.app
> ```

---

## 🛠️ Building from Source (Developers Only)

If you'd like to build leNotch from source or contribute changes:

- **macOS**: 14.0 Sonoma or later (Apple Silicon & Intel)
- **Xcode**: 15.0 or later

```bash
cd leNotch
./package_release.sh
```

Or open `boringNotch.xcodeproj` in Xcode and hit **Run** (`⌘R`).

---

## 🙏 Acknowledgments & Credits

**leNotch** is inspired by and built upon the open-source project [boringNotch](https://github.com/TheBoredTeam/boring.notch) by **TheBoredTeam**. 

I express my sincere gratitude and credit to the original authors, design contributors, and developers of `boringNotch` for the foundational concepts, architecture, and base files that made this project possible.

---

## 📄 License

This project is licensed under the **GNU General Public License v3.0 (GPLv3)** — see the [LICENSE](../LICENSE) file for details.
