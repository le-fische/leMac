# leMinibar 🍸

A lightweight, 100% private, zero-dependency menu bar minimizer and organizer for macOS.

Inspired by utilities like Ice and Bartender, **leMinibar** declutters your MacBook's menu bar by collapsing unwanted status icons behind a single, razor-sharp status dot with **ZERO system permissions required**.

---

## ✨ Features

- **Single Dot Control (1:1 Ice UX)**: 
  - Open circle (**`○`**) = Extra apps revealed.
  - Solid circle (**`●`**) = Secondary apps collapsed and hidden.
- **AirPods-Style Hairline Stroke (`0.85 pt`)**: An ultra-fine, pixel-aligned stroke matching Apple's native icon weight (AirPods cavity, Wi-Fi arches, and battery outline) for crystal-clear Retina sharpness without blur.
- **Zero Permissions Needed**:
  - **0** Accessibility permissions.
  - **0** Screen Recording permissions.
  - **0** Network access (100% offline).
- **0.0% Battery Drain**: Pure event-driven AppKit with zero background polling, zero event taps, and zero CPU usage when idle.
- **Drag-to-Organize (`⌘ + Drag`)**: Hold the **Command** key and drag the dot anywhere along your top bar. Everything to the left hides; everything to the right stays visible.
- **Auto-Collapse Timer**: Optionally auto-collapse after 5s, 10s, or 30s so you don't even have to click it back.
- **Dot Size Selector**: Right-click the dot to choose between **Small & Thin (5.5 pt)**, **Medium & Crisp (6.0 pt)**, or **Classic (7.5 pt)**.
- **Launch at Login**: Seamless macOS `ServiceManagement` (`SMAppService`) integration.

---

## 🛠️ Building & Running

`leMinibar` can be compiled in seconds using native Swift:

```bash
cd leMinibar
chmod +x build.sh
./build.sh
```

This compiles a standalone `leMinibar.app` bundle and signs it with an ad-hoc certificate. 

To run:
```bash
open leMinibar.app
```

To install permanently into Applications:
```bash
cp -R leMinibar.app /Applications/
open /Applications/leMinibar.app
```

---

## 🗂️ Tech Stack

- **Language**: Swift
- **Frameworks**: Cocoa, AppKit, ServiceManagement
- **Architecture**: Native `NSStatusItem` dynamic spacer layout

---

## 📄 License

Part of the **leMac** collection. See the root [LICENSE](../LICENSE) file for details.
