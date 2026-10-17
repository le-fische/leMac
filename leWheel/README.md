# leWheel 🎡

> **A 100% Free, Native macOS Radial App Launcher & Window Switcher for Apple Silicon.**  
> Part of the [`leMac`](../README.md) suite of native utilities (`leNotch`, `leMinibar`, `leCG`, `leFan`).

[![macOS](https://img.shields.io/badge/macOS-14.0%2B%20%28Sonoma%20%7C%20Sequoia%29-blue.svg)](https://apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 🚀 Overview

**leWheel** is an ultra-fast, zero-friction radial (pie-menu) application launcher and switcher inspired by Launchy, built completely natively with **Swift 6**, **SwiftUI**, and **AppKit**.

Unlike proprietary launchers that impose 5-item slot limits, 300-switch trial paywalls, or locked customization, **leWheel is 100% free, unlimited, and private forever**.

### Key Features
* 🎡 **Dynamic Radial Wheel**: Seamlessly holds any number of apps with adaptive sector geometry, concentric multi-rings, and customizable wheel diameter (`140px`–`320px`).
* ⚡️ **Dual-Press Modifier Trigger (`⌥⌘`)**: Press and hold `Option + Command` anywhere to instantly summon the wheel at your cursor.
* 🎯 **Hold-to-Navigate & Release-to-Launch**: Flick your mouse toward an app and release the keys to launch in under 50ms without clicking.
* 🪟 **Reliable Top-Layer Window Restoration**: Uses native LaunchServices reopen events (`kAEReopenApplication`) and Accessibility elevation (`AXUIElement`) to guarantee that apps with closed (`Cmd+W`) or minimized windows always restore and pop to the top layer directly at your cursor.
* 🎛️ **Lowkey macOS Frosted Glass**: Sleek, distraction-free native macOS frosted vibrancy with clean gray hover highlights, transparent center deadzone, and haptic trackpad feedback.
* 🔄 **Running App Switcher Mode**: Radial `Cmd+Tab` replacement displaying currently active apps with instant `Cmd+Q` termination right from the wheel.
* 🔒 **100% Private & Offline**: Zero network calls, zero analytics, zero telemetry. Configuration saved in local human-readable JSON.

---

## 📊 Comparison Matrix

| Feature | Proprietary Free Tier | Proprietary Paid Tier | **leWheel (FOSS)** |
| :--- | :---: | :---: | :---: |
| **Pinned Item Slots** | Capped at ~5 apps | Unlimited | **Unlimited** |
| **Usage / Switch Limit** | 300 switches cap | Unlimited | **Unlimited Forever** |
| **Custom Palettes** | 1 palette | Multiple | **Unlimited Palettes** |
| **Reopen Closed Windows** | Unreliable | Partial | **100% Native LaunchServices Reopen** |
| **Hold-to-Navigate Gesture**| Limited | Enabled | **Fully Enabled** |
| **Direct A–Z Keyboard Jump** | Partial | Enabled | **Fully Enabled** |
| **Custom Sizing & Aesthetics**| Locked | Available | **Fully Customizable** |
| **Data Privacy** | Closed Source | Closed Source | **MIT Licensed, 0 Telemetry** |

---

## 📥 Download & Installation

### Quick Install (No Terminal or Xcode Needed!)

1. **Download the latest release**:
   - 💿 [**Download leWheel.dmg**](https://github.com/le-fische/leMac/releases/latest/download/leWheel.dmg) *(Drag & Drop Installer)*
   - 📦 [**Download leWheel.zip**](https://github.com/le-fische/leMac/releases/latest/download/leWheel.zip) *(Portable Archive)*
2. **Install**:
   - Open `leWheel.dmg` and drag **leWheel** into your **Applications** folder.
3. **Launch**:
   - Open **leWheel** from Applications, Launchpad, or Spotlight.

> **Tip for First Launch**: Because `leWheel` is an open-source indie utility signed ad-hoc, if macOS Gatekeeper displays an "unidentified developer" prompt on first launch, simply right-click (or Control-click) `leWheel.app` in `/Applications` and select **Open**, then click **Open**. Alternatively, run:
> ```bash
> xattr -cr /Applications/leWheel.app
> ```

---

## 🛠️ Build from Source & Packaging

### Requirements
* macOS 14.0+ (Sonoma, Sequoia, or later)
* Apple Silicon (M1/M2/M3/M4) or Intel
* Xcode 15+ / Swift 5.10+ command line tools

### 1. Package DMG & ZIP Release Bundles
To compile and package drag-and-drop `.dmg` and `.zip` releases with SHA256 checksums:
```bash
cd /Users/le/Documents/Projects/leMac/leWheel
./package_release.sh
```
Output files will be generated in `leWheel/dist/`:
- `leWheel.dmg` (drag-and-drop installer with `/Applications` symlink)
- `leWheel.zip` (portable archive)
- `leWheel-checksums.txt` (SHA256 checksums)

### 2. Build and Install Directly via Script
From the `leWheel` project directory:
```bash
cd /Users/le/Documents/Projects/leMac/leWheel

# Build release binary, package into leWheel.app, code-sign, and install to /Applications/
./scripts/bundle.sh

# Launch the app
open /Applications/leWheel.app
```

### 3. Build via Swift Package Manager
```bash
cd /Users/le/Documents/Projects/leMac/leWheel
swift build -c release
```

---

## 🎮 How to Use

* **Summon the Wheel**: Hold `Option + Command` (`⌥⌘`). The wheel spawns centered at your mouse cursor.
* **Launch an Item**: Move your cursor towards the desired app and release `⌥⌘`.
* **Cancel**: Move cursor to center hole or press `Escape`.
* **Menu Bar Options**: Click the `leWheel` menu bar icon to access Settings, edit palettes, customize shortcuts, or quit.
* **App Switcher Mode**: Press `[` or `]` while the wheel is open to toggle between your pinned Favorites and active Running Apps.

---

## 📂 Codebase Structure

```
leWheel/
├── Package.swift                  # Swift package manifest
├── Resources/
│   └── Info.plist                 # Bundle identity (com.le.leWheel)
├── scripts/
│   └── bundle.sh                  # Release compilation, codesigning & installation script
└── Sources/OpenLaunchy/
    ├── App/
    │   ├── OpenLaunchyApp.swift   # Main application entry
    │   ├── AppDelegate.swift      # Lifecycle & warmup
    │   └── StatusBarController.swift # Menu bar extra & context menu
    ├── Engine/
    │   ├── AppLauncher.swift      # LaunchServices, kAEReopenApplication & window elevation
    │   ├── AppScanner.swift       # Applications folder crawler
    │   ├── ConfigManager.swift    # JSON persistence (~/Library/Application Support/OpenLaunchy)
    │   ├── RadialMath.swift       # Trigonometry, angles & dynamic sectors
    │   └── RunningAppsManager.swift # Running applications tracker
    ├── Input/
    │   ├── HotKeyManager.swift    # Carbon global hotkeys & dual-modifier chord monitoring
    │   └── MouseHookManager.swift # Auxiliary mouse button hooks
    ├── Models/
    │   ├── AppSettings.swift      # Geometry, styling, triggers & behavior settings
    │   ├── LaunchItem.swift       # Wheel item model
    │   └── Palette.swift          # Custom radial wheel collections
    └── UI/
        ├── LiquidGlassBackground.swift # Frosted glass visual effects
        ├── RadialMenuView.swift   # Radial wheel Canvas & sector rendering
        ├── RadialWindowController.swift # Non-activating overlay & mouse gesture engine
        └── SettingsView.swift     # SwiftUI Preferences & Palette Editor
```

---

## 📄 License

This project is open-source software licensed under the [MIT License](LICENSE).
