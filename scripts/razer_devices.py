#!/usr/bin/env python3
"""OpenRazer device scanner and management helper for Omarchy shell."""

from __future__ import annotations

import argparse
import json
import sys
from typing import Any


def safe_get(obj: Any, attr: str, default: Any = None) -> Any:
    """Safely get an attribute or property, handling NotImplementedError and exceptions."""
    try:
        val = getattr(obj, attr, default)
        return default if val is None else val
    except (NotImplementedError, AttributeError, Exception):
        return default


def normalize_effect_name(name: str) -> str:
    """Normalize effect name from daemon/CLI to standard lowercase identifier."""
    n = str(name or "").strip().lower().replace("-", "_")
    if n in ("none", "off"):
        return "none"
    if n in ("static",):
        return "static"
    if n in ("spectrum", "spectrumcycling", "spectrum_cycling"):
        return "spectrum"
    if n in ("wave",):
        return "wave"
    if n in ("breathsingle", "breath_single", "breath", "breathing"):
        return "breath_single"
    if n in ("breathrandom", "breath_random"):
        return "breath_random"
    if n in ("breathdual", "breath_dual"):
        return "breath_dual"
    if n in ("reactive",):
        return "reactive"
    if n in ("ripple",):
        return "ripple"
    if n in ("ripplerandom", "ripple_random"):
        return "ripple_random"
    if n in ("starlightrandom", "starlight_random", "starlight"):
        return "starlight_random"
    if n in ("starlight_single", "starlight_single"):
        return "starlight_single"
    return n


def classify_device_type(raw_type: str, name: str) -> str:
    """Classify device type, refining generic types based on device name when appropriate."""
    t = str(raw_type or "").strip().lower()
    n = str(name or "").strip().lower()

    if t in ("keyboard", "keyboards"):
        return "keyboard"
    if t in ("keypad", "keypads"):
        return "keypad"
    if t in ("mouse", "mice"):
        return "mouse"
    if t in ("mousemat", "mousemats", "mouse_mat", "mat", "pad"):
        return "mousemat"
    if t in ("headset", "headsets", "headphone", "headphones"):
        return "headset"
    if t in ("speaker", "speakers", "soundbar"):
        return "speaker"

    # Name-based classification for accessories or generic audio/device
    if any(k in n for k in ("nommo", "speaker", "leviathan", "ferox")):
        return "speaker"
    if any(k in n for k in ("kraken", "nari", "blackshark", "barracuda", "kaira", "opus", "hammerhead", "thresher", "electra", "headset", "headphone", "earphone", "earbud")):
        return "headset"
    if any(k in n for k in ("seiren", "microphone", " mic ")):
        return "headset"
    if any(k in n for k in ("firefly", "goliathus", "strider", "mouse mat", "mousemat")):
        return "mousemat"
    if any(k in n for k in ("tartarus", "orbweaver", "nostromo")):
        return "keypad"
    if any(k in n for k in ("keyboard", "blackwidow", "huntsman", "cynosa", "deathstalker", "ornata")):
        return "keyboard"
    if any(k in n for k in ("mouse", "deathadder", "viper", "basilisk", "naga", "cobra", "orochi", "mamba", "abyssus", "lancehead")):
        return "mouse"

    return t or "accessory"


def parse_speed(val: Any, default: int = 2) -> int:
    """Parse speed/reaction time parameter (1=fast, 2=normal, 3=slow, 4=very_slow)."""
    if val is None:
        return default
    s = str(val).strip().lower()
    if s in ("1", "fast", "speed_fast"):
        return 1
    if s in ("2", "normal", "medium", "med", "speed_medium"):
        return 2
    if s in ("3", "slow", "speed_slow"):
        return 3
    if s in ("4", "very_slow"):
        return 4
    try:
        n = int(s)
        return n if 1 <= n <= 4 else default
    except ValueError:
        return default


def parse_direction(val: Any, default: int = 1) -> int:
    """Parse wave direction (1=right, 2=left)."""
    if val is None:
        return default
    s = str(val).strip().lower()
    if s in ("2", "left", "wave_left"):
        return 2
    if s in ("1", "right", "wave_right"):
        return 1
    try:
        n = int(s)
        return n if n in (1, 2) else default
    except ValueError:
        return default


def parse_color(c: str) -> tuple[int, int, int]:
    """Parse hex or comma-separated string to RGB tuple (0-255)."""
    if not c:
        return (0, 255, 0)
    cleaned = c.strip().lstrip("#")
    if "," in cleaned:
        parts = [int(p.strip()) for p in cleaned.split(",") if p.strip()]
        if len(parts) >= 3:
            return (
                max(0, min(255, parts[0])),
                max(0, min(255, parts[1])),
                max(0, min(255, parts[2])),
            )
    if len(cleaned) == 6:
        return (
            int(cleaned[0:2], 16),
            int(cleaned[2:4], 16),
            int(cleaned[4:6], 16),
        )
    if len(cleaned) == 3:
        return (
            int(cleaned[0] * 2, 16),
            int(cleaned[1] * 2, 16),
            int(cleaned[2] * 2, 16),
        )
    raise ValueError(f"Invalid color representation: {c}")


def get_device_info(device: Any, daemon_version: str = "") -> dict[str, Any]:
    """Extract full status and capabilities from a single OpenRazer device."""
    caps: dict[str, Any] = safe_get(device, "capabilities", {}) or {}

    # Battery
    has_battery = bool(caps.get("battery", False))
    battery_level: int | None = None
    is_charging: bool | None = None
    if has_battery:
        try:
            b = device.battery_level
            battery_level = int(b) if b is not None else None
        except (NotImplementedError, Exception):
            battery_level = None
        try:
            c = device.is_charging
            is_charging = bool(c) if c is not None else None
        except (NotImplementedError, Exception):
            is_charging = None

    # Brightness (0 - 100)
    brightness: float | None = None
    has_brightness = bool(caps.get("brightness", False))
    if has_brightness:
        try:
            br = device.brightness
            brightness = round(float(br), 1) if br is not None else None
        except (NotImplementedError, Exception):
            brightness = None

    # DPI
    dpi: list[int] | None = None
    max_dpi: int | None = None
    has_dpi = bool(caps.get("dpi", False))
    if has_dpi:
        try:
            dpi_val = device.dpi
            if isinstance(dpi_val, (tuple, list)):
                dpi = [int(x) for x in dpi_val]
            elif dpi_val is not None:
                dpi = [int(dpi_val), int(dpi_val)]
        except (NotImplementedError, Exception):
            dpi = None
        try:
            m = device.max_dpi
            max_dpi = int(m) if m is not None else None
        except (NotImplementedError, Exception):
            max_dpi = None

    # Poll Rate (Hz)
    poll_rate: int | None = None
    has_poll_rate = bool(caps.get("poll_rate", False))
    if has_poll_rate:
        try:
            pr = device.poll_rate
            poll_rate = int(pr) if pr is not None else None
        except (NotImplementedError, Exception):
            poll_rate = None

    # Supported poll rates
    supported_poll_rates: list[int] = []
    if has_poll_rate:
        try:
            rates = safe_get(device, "supported_poll_rates", [])
            if isinstance(rates, (list, tuple)):
                supported_poll_rates = [int(r) for r in rates]
        except (NotImplementedError, Exception):
            supported_poll_rates = []

    # Lighting / FX
    fx = safe_get(device, "fx", None)
    has_lighting = bool(caps.get("lighting", False) or fx is not None)
    current_effect: str | None = None
    colors: list[str] = []
    supported_effects: list[str] = []

    if has_lighting and fx is not None:
        try:
            eff = safe_get(fx, "effect", None)
            if eff:
                current_effect = normalize_effect_name(str(eff))
        except Exception:
            current_effect = None

        try:
            raw_colors = safe_get(fx, "colors", None)
            if isinstance(raw_colors, (bytes, bytearray)):
                for i in range(0, len(raw_colors), 3):
                    chunk = raw_colors[i : i + 3]
                    if len(chunk) == 3:
                        colors.append(f"#{chunk[0]:02x}{chunk[1]:02x}{chunk[2]:02x}")
        except Exception:
            colors = []

        candidate_effects = [
            "none",
            "static",
            "spectrum",
            "wave",
            "breath_single",
            "breath_random",
            "breath_dual",
            "breath_triple",
            "reactive",
            "ripple",
            "ripple_random",
            "starlight_random",
            "starlight_single",
            "starlight_dual",
            "wheel",
        ]
        for e in candidate_effects:
            try:
                if hasattr(fx, "has") and fx.has(e):
                    supported_effects.append(e)
                elif caps.get(f"lighting_{e}", False):
                    supported_effects.append(e)
            except Exception:
                pass

    raw_type = str(safe_get(device, "type", "accessory")).lower()
    name = str(safe_get(device, "name", "Unknown Razer Device"))
    dev_type = classify_device_type(raw_type, name)
    serial = str(safe_get(device, "serial", ""))
    firmware_version = str(safe_get(device, "firmware_version", ""))
    driver_version = str(safe_get(device, "driver_version", daemon_version))

    return {
        "name": name,
        "type": dev_type,
        "serial": serial,
        "firmware_version": firmware_version,
        "driver_version": driver_version,
        "has_battery": has_battery,
        "battery_level": battery_level,
        "is_charging": is_charging,
        "has_brightness": has_brightness,
        "brightness": brightness,
        "has_dpi": has_dpi,
        "dpi": dpi,
        "max_dpi": max_dpi,
        "has_poll_rate": has_poll_rate,
        "poll_rate": poll_rate,
        "supported_poll_rates": supported_poll_rates,
        "has_lighting": has_lighting,
        "current_effect": current_effect,
        "colors": colors,
        "primary_color": colors[0] if colors else "#00ff00",
        "supported_effects": supported_effects,
        "capabilities": {
            "battery": has_battery,
            "brightness": has_brightness,
            "dpi": has_dpi,
            "poll_rate": has_poll_rate,
            "lighting": has_lighting,
        },
    }


def get_razer_status() -> dict[str, Any]:
    """Connect to OpenRazer daemon and collect status for all connected devices."""
    try:
        import openrazer.client
    except ImportError as e:
        return {
            "daemon_running": False,
            "version": "",
            "sync_effects": False,
            "error": "openrazer Python library is not installed",
            "device_count": 0,
            "devices": [],
        }

    try:
        dm = openrazer.client.DeviceManager()
    except openrazer.client.DaemonNotFound:
        return {
            "daemon_running": False,
            "version": "",
            "sync_effects": False,
            "error": "OpenRazer daemon is not running (DaemonNotFound)",
            "device_count": 0,
            "devices": [],
        }
    except Exception as e:
        return {
            "daemon_running": False,
            "version": "",
            "sync_effects": False,
            "error": f"Failed to connect to OpenRazer daemon: {e}",
            "device_count": 0,
            "devices": [],
        }

    daemon_version = str(safe_get(dm, "version", ""))
    sync_effects = bool(safe_get(dm, "sync_effects", False))

    device_list: list[dict[str, Any]] = []
    try:
        raw_devices = dm.devices
    except Exception as e:
        return {
            "daemon_running": True,
            "version": daemon_version,
            "sync_effects": sync_effects,
            "error": f"Error querying devices: {e}",
            "device_count": 0,
            "devices": [],
        }

    for dev in raw_devices:
        try:
            device_list.append(get_device_info(dev, daemon_version))
        except Exception:
            continue

    return {
        "daemon_running": True,
        "version": daemon_version,
        "sync_effects": sync_effects,
        "device_count": len(device_list),
        "devices": device_list,
        "error": None,
    }


def set_brightness(serial: str, value: float) -> bool:
    """Set brightness (0-100) for a device by serial number or 'all'."""
    try:
        import openrazer.client

        dm = openrazer.client.DeviceManager()
    except Exception as e:
        sys.stderr.write(f"Error connecting to OpenRazer daemon: {e}\n")
        return False

    value = max(0.0, min(100.0, float(value)))
    found = False
    for dev in dm.devices:
        dev_serial = str(safe_get(dev, "serial", ""))
        if serial.lower() == "all" or dev_serial.lower() == serial.lower():
            try:
                dev.brightness = value
                found = True
            except Exception as e:
                sys.stderr.write(f"Failed to set brightness on {dev.name}: {e}\n")

    return found


def set_poll_rate(serial: str, rate: int) -> bool:
    """Set poll rate for a device by serial number."""
    try:
        import openrazer.client

        dm = openrazer.client.DeviceManager()
    except Exception as e:
        sys.stderr.write(f"Error connecting to OpenRazer daemon: {e}\n")
        return False

    found = False
    for dev in dm.devices:
        dev_serial = str(safe_get(dev, "serial", ""))
        if dev_serial.lower() == serial.lower():
            try:
                dev.poll_rate = int(rate)
                found = True
            except Exception as e:
                sys.stderr.write(f"Failed to set poll rate on {dev.name}: {e}\n")

    return found


def set_effect(
    serial: str,
    effect: str,
    color: str | None = None,
    color2: str | None = None,
    param: str | None = None,
) -> bool:
    """Set lighting effect on a device by serial number or 'all'."""
    try:
        import openrazer.client

        dm = openrazer.client.DeviceManager()
    except Exception as e:
        sys.stderr.write(f"Error connecting to OpenRazer daemon: {e}\n")
        return False

    eff = normalize_effect_name(effect)

    # Resolve colors
    rgb = (0, 255, 0)
    if color and color.lower() != "random":
        try:
            rgb = parse_color(color)
        except Exception:
            rgb = (0, 255, 0)

    rgb2 = None
    if color2 and color2.lower() != "random":
        try:
            rgb2 = parse_color(color2)
        except Exception:
            rgb2 = None

    found = False
    for dev in dm.devices:
        dev_serial = str(safe_get(dev, "serial", ""))
        if serial.lower() == "all" or dev_serial.lower() == serial.lower():
            fx = safe_get(dev, "fx", None)
            if not fx:
                continue
            try:
                if eff == "none":
                    if hasattr(fx, "none"):
                        fx.none()
                        found = True
                elif eff == "static":
                    if hasattr(fx, "static"):
                        fx.static(*rgb)
                        found = True
                elif eff == "spectrum":
                    if hasattr(fx, "spectrum"):
                        fx.spectrum()
                        found = True
                elif eff == "wave":
                    direction = parse_direction(param or color2 or color, 1)
                    if hasattr(fx, "wave"):
                        fx.wave(direction)
                        found = True
                elif eff == "breath_random":
                    if hasattr(fx, "breath_random"):
                        fx.breath_random()
                        found = True
                    elif hasattr(fx, "breath_single"):
                        fx.breath_single(*rgb)
                        found = True
                elif eff in ("breath_single", "breath"):
                    if color and color.lower() == "random" and hasattr(fx, "breath_random"):
                        fx.breath_random()
                        found = True
                    elif rgb2 and hasattr(fx, "breath_dual"):
                        fx.breath_dual(rgb[0], rgb[1], rgb[2], rgb2[0], rgb2[1], rgb2[2])
                        found = True
                    elif hasattr(fx, "breath_single"):
                        fx.breath_single(*rgb)
                        found = True
                    elif hasattr(fx, "breath_random"):
                        fx.breath_random()
                        found = True
                elif eff == "breath_dual":
                    if rgb2 and hasattr(fx, "breath_dual"):
                        fx.breath_dual(rgb[0], rgb[1], rgb[2], rgb2[0], rgb2[1], rgb2[2])
                        found = True
                    elif hasattr(fx, "breath_single"):
                        fx.breath_single(*rgb)
                        found = True
                elif eff == "reactive":
                    speed = parse_speed(param or color2, 2)
                    if hasattr(fx, "reactive"):
                        fx.reactive(rgb[0], rgb[1], rgb[2], speed)
                        found = True
                elif eff in ("ripple_random", "ripple"):
                    speed = parse_speed(param or color2 or (color if eff == "ripple_random" else None), 2)
                    rate_map = {1: 0.025, 2: 0.05, 3: 0.1, 4: 0.15}
                    refreshrate = rate_map.get(speed, 0.05)
                    if eff == "ripple" and hasattr(fx, "ripple") and color and color.lower() != "random":
                        try:
                            fx.ripple(rgb[0], rgb[1], rgb[2], refreshrate=refreshrate)
                            found = True
                        except TypeError:
                            fx.ripple(*rgb)
                            found = True
                    elif hasattr(fx, "ripple_random"):
                        try:
                            fx.ripple_random(refreshrate=refreshrate)
                            found = True
                        except TypeError:
                            fx.ripple_random()
                            found = True
                    elif hasattr(fx, "ripple"):
                        try:
                            fx.ripple(rgb[0], rgb[1], rgb[2], refreshrate=refreshrate)
                            found = True
                        except TypeError:
                            fx.ripple(*rgb)
                            found = True
                elif eff == "starlight_random":
                    speed = min(3, max(1, parse_speed(param or color2 or color, 2)))
                    if hasattr(fx, "starlight_random"):
                        fx.starlight_random(speed)
                        found = True
                elif eff == "starlight_single":
                    speed = min(3, max(1, parse_speed(param or color2, 2)))
                    if hasattr(fx, "starlight_single"):
                        fx.starlight_single(rgb[0], rgb[1], rgb[2], speed)
                        found = True
                elif eff == "starlight_dual":
                    speed = min(3, max(1, parse_speed(param, 2)))
                    r2, g2, b2 = rgb2 if rgb2 else (0, 229, 255)
                    if hasattr(fx, "starlight_dual"):
                        fx.starlight_dual(rgb[0], rgb[1], rgb[2], r2, g2, b2, speed)
                        found = True
                else:
                    # Generic fallback if method exists directly on fx
                    if hasattr(fx, eff) and callable(getattr(fx, eff)):
                        fn = getattr(fx, eff)
                        try:
                            fn(*rgb)
                            found = True
                        except TypeError:
                            try:
                                fn()
                                found = True
                            except Exception:
                                pass
            except Exception as e:
                sys.stderr.write(f"Failed to set effect {eff} on {dev.name}: {e}\n")

    return found


def print_summary(status: dict[str, Any]) -> None:
    """Print human-readable summary to stdout."""
    if not status.get("daemon_running"):
        print(f"OpenRazer Daemon: NOT RUNNING ({status.get('error', 'Unknown error')})")
        print("Hint: Start with 'systemctl --user start openrazer-daemon'")
        return

    print(f"OpenRazer Daemon v{status.get('version', 'unknown')} - {status.get('device_count', 0)} devices connected")
    print("-" * 60)
    for i, dev in enumerate(status.get("devices", []), 1):
        print(f"[{i}] {dev['name']} ({dev['type'].title()})")
        print(f"    Serial:   {dev['serial'] or 'N/A'}")
        print(f"    Firmware: {dev['firmware_version'] or 'N/A'}")
        if dev.get("has_battery"):
            chg = " (Charging)" if dev.get("is_charging") else ""
            print(f"    Battery:  {dev.get('battery_level', 'N/A')}%{chg}")
        if dev.get("has_brightness") and dev.get("brightness") is not None:
            print(f"    Brightness: {dev.get('brightness')}%")
        if dev.get("has_lighting"):
            eff_str = dev.get("current_effect", "N/A")
            colors_str = ", ".join(dev.get("colors", [])) or "N/A"
            print(f"    Lighting:   Effect: {eff_str} | Colors: {colors_str}")
            if dev.get("supported_effects"):
                print(f"    Supported:  {', '.join(dev['supported_effects'])}")
        if dev.get("has_dpi") and dev.get("dpi") is not None:
            dpi_str = " x ".join(str(x) for x in dev["dpi"])
            max_str = f" (Max: {dev['max_dpi']})" if dev.get("max_dpi") else ""
            print(f"    DPI:      {dpi_str}{max_str}")
        if dev.get("has_poll_rate") and dev.get("poll_rate") is not None:
            print(f"    Poll Rate: {dev.get('poll_rate')} Hz")
        print()


def main() -> int:
    parser = argparse.ArgumentParser(description="OpenRazer device query and control for Omarchy shell")
    parser.add_argument("--json", action="store_true", default=True, help="Output status as JSON (default)")
    parser.add_argument("--summary", action="store_true", help="Print human-readable summary")
    parser.add_argument(
        "--set-brightness",
        nargs=2,
        metavar=("SERIAL", "VALUE"),
        help="Set brightness (0-100) for device serial or 'all'",
    )
    parser.add_argument(
        "--set-poll-rate",
        nargs=2,
        metavar=("SERIAL", "RATE"),
        help="Set polling rate (Hz) for device serial",
    )
    parser.add_argument(
        "--set-effect",
        nargs="+",
        metavar="ARG",
        help="Set lighting effect: SERIAL EFFECT [COLOR] [COLOR2_OR_PARAM] [PARAM]",
    )

    args = parser.parse_args()

    if args.set_brightness:
        serial, val = args.set_brightness
        success = set_brightness(serial, float(val))
        return 0 if success else 1

    if args.set_poll_rate:
        serial, rate = args.set_poll_rate
        success = set_poll_rate(serial, int(rate))
        return 0 if success else 1

    if args.set_effect:
        raw_args = args.set_effect
        serial = raw_args[0]
        effect = raw_args[1] if len(raw_args) > 1 else "static"
        color = raw_args[2] if len(raw_args) > 2 else None
        color2 = raw_args[3] if len(raw_args) > 3 else None
        param = raw_args[4] if len(raw_args) > 4 else None

        # Check if color2 is a parameter like "1", "2", "left", "right" for wave
        if normalize_effect_name(effect) == "wave" and color and not param:
            param = color
            color = None

        success = set_effect(serial, effect, color, color2, param)
        return 0 if success else 1

    status = get_razer_status()

    if args.summary:
        print_summary(status)
    else:
        print(json.dumps(status, separators=(",", ":")))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
