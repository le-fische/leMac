# MiniBar 🍸

A lightweight, zero-dependency menu bar organizer and collapsible divider for macOS.

MiniBar declutters your MacBook's menu bar by hiding secondary status icons behind a sleek divider toggle until you need them.

---

## ✨ Features

- **Instant Toggle**: Click the divider to hide or reveal extra menu bar icons on demand.
- **Auto-Collapse**: Optionally auto-collapses after a customizable delay to keep your menu bar tidy.
- **Zero Dependencies**: Pure native AppKit / Cocoa implementation without bloated external frameworks.
- **Ultra Lightweight**: Tiny memory footprint (~10 MB RAM) and zero background CPU usage.
- **Launch at Login**: Seamless integration with macOS `ServiceManagement` for background launch.
- **Menu Options**: Right-click to access quick toggles, preferences, and quit options.

---

## 🛠️ Building & Installation

MiniBar can be built in seconds using Swift's command-line compiler:

```bash
cd MiniBar
chmod +x build.sh
./build.sh
```

This compiles `MiniBar.app` and ad-hoc signs it automatically. You can then copy it into `/Applications`:

```bash
cp -R MiniBar.app /Applications/
open /Applications/MiniBar.app
```

---

## 📄 License

Part of the **leMac** collection. See the root [LICENSE](../LICENSE) file for details.
