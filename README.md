# OmaRazer - OpenRazer Devices Plugin for Omarchy

An Omarchy shell bar widget and panel plugin that connects to the [OpenRazer](https://openrazer.github.io/) daemon to monitor and manage connected Razer peripherals (keyboards, mice, mousemats, headsets, and accessories).

## Features

- **Device Discovery & Status**: Automatically detects all connected Razer devices via the OpenRazer daemon.
- **Hardware Telemetry**: Displays device names, device types, serial numbers, and firmware versions.
- **Battery Monitoring**: Live battery percentage and charging state indicators with color-coded levels for wireless devices.
- **Lighting Effect Configurations**:
  - **Categorized Per-Device Effect Organization**: Grouped into logical categories (**Presets**, **Dynamic**, and **Interactive**) displaying only the lighting effects supported by each peripheral.
  - **Structured Effect Settings**: Dedicated settings card for the active effect with context-aware parameter controls:
    - Primary RGB color palette swatches with active selection indicator.
    - Secondary RGB color palette swatches for dual-color effects (Dual Breathing, Dual Starlight).
    - Wave direction selector (Left / Right).
    - Easily accessible animation & reaction speed controls with active selection highlighting (Fast / Normal / Slow / Very Slow).
    - Dedicated sub-mode switchers for Breathing (Single / Random / Dual), Ripple (Single / Random), and Starlight (Random / Single / Dual).
  - **Interactive Effect Toggles**: Collapsible per-device effect cards toggled by clicking the active effect badge.
  - **Global Quick Presets**: Quick lighting presets for all devices simultaneously (Spectrum, Wave, Razer Green, Off).
- **DPI & Polling Rate**: Displays active mouse DPI configuration and polling rate (Hz).
- **Brightness Control**: Inline brightness sliders for devices with lighting support.
- **Bar Widget**: Shows Razer status icon and connected device count on the Omarchy status bar.
- **Keyboard Navigation & Shortcuts**: Supports full keyboard navigation, `Esc` to close, and `r` to refresh.
- **Daemon Diagnostics**: Clear error reporting and one-click daemon restart if the daemon is offline.

## Requirements

- **Omarchy Linux** with Quickshell plugin architecture
- **OpenRazer Daemon & Python Client**:
  - `openrazer-daemon`
  - `python-openrazer`
- Ensure your user is in the `openrazer` group:
  ```bash
  sudo gpasswd -a "$USER" openrazer
  systemctl --user enable --now openrazer-daemon
  ```

## Installation

Add and enable the plugin directly in Omarchy:

```bash
omarchy plugin add https://github.com/slanger/omarchy-openrazer.git --enable
```

Or clone/symlink locally for development:

```bash
mkdir -p ~/.config/omarchy/plugins
cp -r "$PWD" ~/.config/omarchy/plugins/asdfsnlr.openrazer
omarchy plugin enable asdfsnlr.openrazer --section right
```

## CLI Usage

The plugin includes a standalone Python CLI scanner and management script:

```bash
# Print JSON output
python3 scripts/razer_devices.py

# Print human-readable terminal summary
python3 scripts/razer_devices.py --summary

# Set lighting effects (device serial or 'all')
python3 scripts/razer_devices.py --set-effect <serial|all> static "#00ff00"
python3 scripts/razer_devices.py --set-effect <serial|all> spectrum
python3 scripts/razer_devices.py --set-effect <serial|all> wave 1
python3 scripts/razer_devices.py --set-effect <serial|all> breath "#8000ff"
python3 scripts/razer_devices.py --set-effect <serial|all> none

# Set brightness for a specific device or all devices (0-100)
python3 scripts/razer_devices.py --set-brightness <serial|all> 75

# Set polling rate (Hz) for a device
python3 scripts/razer_devices.py --set-poll-rate <serial> 1000
```

## Running Tests

Run the test suites for Python and JavaScript components:

```bash
# Run Python unit tests
python3 -m unittest discover tests

# Run JavaScript Model tests
node tests/test_model.js

# Validate manifest schema
omarchy plugin validate .

# Lint QML syntax
qmllint -I /usr/share/omarchy/shell ./Panel.qml
```

## License

MIT License. See [LICENSE](LICENSE) for details.
