# leMinibar 🍸

A lightweight, 100% private, zero-dependency menu bar minimizer and organizer for macOS.

Inspired by utilities like Ice and Bartender, **leMinibar** declutters your MacBook's menu bar by collapsing unwanted status icons behind a single, razor-sharp status dot with **ZERO system permissions required**.

---

## 📥 Download & Installation

### Quick Install (No Terminal or Xcode Needed!)

1. **Download the latest release**:
   - 💿 [**Download leMinibar.dmg**](https://github.com/le-fische/leMac/releases/latest/download/leMinibar.dmg) *(Drag & Drop Installer)*
   - 📦 [**Download leMinibar.zip**](https://github.com/le-fische/leMac/releases/latest/download/leMinibar.zip) *(Portable Archive)*
2. **Install**:
   - Open `leMinibar.dmg` and drag **leMinibar** into your **Applications** folder.
3. **Launch**:
   - Open **leMinibar** from Applications, Launchpad, or Spotlight.

> **Tip for First Launch**: Because `leMinibar` is an open-source indie utility signed ad-hoc, if macOS Gatekeeper displays an "unidentified developer" prompt on first launch, simply right-click (or Control-click) `leMinibar.app` in `/Applications` and select **Open**, then click **Open**. Alternatively, run:
> ```bash
> xattr -cr /Applications/leMinibar.app
> ```

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

## 🛠️ Building & Packaging (Developers)

`leMinibar` can be compiled in seconds using native Swift:

### Compile Standalone App
```bash
cd leMinibar
chmod +x build.sh
./build.sh
open leMinibar.app
```

### Package Release DMG and ZIP
To package the app into a drag-and-drop `.dmg` installer and `.zip` archive with SHA256 checksums:
```bash
cd leMinibar
chmod +x package_release.sh
./package_release.sh
```
This generates `leMinibar.dmg`, `leMinibar.zip`, and `checksums.txt` in `leMinibar/dist/`.

---

## 🗂️ Tech Stack

- **Language**: Swift
- **Frameworks**: Cocoa, AppKit, ServiceManagement
- **Architecture**: Native `NSStatusItem` dynamic spacer layout

---

## 📄 License

Part of the **leMac** collection. See the root [LICENSE](../LICENSE) file for details.
