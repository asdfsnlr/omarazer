#!/usr/bin/env python3
"""Per-key LED matrix lighting for OmaRazer."""

from __future__ import annotations

import sys
from typing import Any

from scripts.helpers import safe_get


def _connect():
    """Connect to the OpenRazer daemon and return DeviceManager."""
    import openrazer.client

    return openrazer.client.DeviceManager()


def get_matrix_dims(serial: str) -> dict[str, Any]:
    """Get LED matrix dimensions for a device by serial number."""
    try:
        dm = _connect()
    except Exception as e:
        return {"error": f"Error connecting to OpenRazer daemon: {e}"}

    for dev in dm.devices:
        dev_serial = str(safe_get(dev, "serial", ""))
        if dev_serial.lower() == serial.lower():
            fx = safe_get(dev, "fx", None)
            advanced = safe_get(fx, "advanced", None) if fx else None
            if advanced is None:
                return {"rows": 0, "cols": 0, "has_per_key": False}
            try:
                rows = int(safe_get(advanced, "rows", 0) or 0)
                cols = int(safe_get(advanced, "cols", 0) or 0)
                return {"rows": rows, "cols": cols, "has_per_key": True}
            except Exception:
                return {"rows": 0, "cols": 0, "has_per_key": False}

    return {"error": f"Device not found: {serial}"}


def set_per_key(serial: str, row: int, col: int, r: int, g: int, b: int) -> bool:
    """Set a single key color in the LED matrix."""
    try:
        dm = _connect()
    except Exception as e:
        sys.stderr.write(f"Error connecting to OpenRazer daemon: {e}\n")
        return False

    r = max(0, min(255, int(r)))
    g = max(0, min(255, int(g)))
    b = max(0, min(255, int(b)))

    for dev in dm.devices:
        dev_serial = str(safe_get(dev, "serial", ""))
        if dev_serial.lower() == serial.lower():
            fx = safe_get(dev, "fx", None)
            advanced = safe_get(fx, "advanced", None) if fx else None
            if advanced is None:
                sys.stderr.write(f"Device does not support per-key lighting: {dev.name}\n")
                return False
            try:
                advanced.matrix[row, col] = (r, g, b)
                advanced.draw()
                return True
            except Exception as e:
                sys.stderr.write(f"Failed to set per-key color on {dev.name}: {e}\n")
                return False

    sys.stderr.write(f"Device not found: {serial}\n")
    return False


def set_per_key_batch(serial: str, keys: list[list[int]]) -> bool:
    """Set multiple key colors in one batch, then draw once.

    keys: list of [row, col, r, g, b] tuples.
    """
    try:
        dm = _connect()
    except Exception as e:
        sys.stderr.write(f"Error connecting to OpenRazer daemon: {e}\n")
        return False

    for dev in dm.devices:
        dev_serial = str(safe_get(dev, "serial", ""))
        if dev_serial.lower() == serial.lower():
            fx = safe_get(dev, "fx", None)
            advanced = safe_get(fx, "advanced", None) if fx else None
            if advanced is None:
                sys.stderr.write(f"Device does not support per-key lighting: {dev.name}\n")
                return False
            try:
                for entry in keys:
                    if len(entry) < 5:
                        continue
                    row, col, r, g, b = entry[0], entry[1], entry[2], entry[3], entry[4]
                    advanced.matrix[int(row), int(col)] = (
                        max(0, min(255, int(r))),
                        max(0, min(255, int(g))),
                        max(0, min(255, int(b))),
                    )
                advanced.draw()
                return True
            except Exception as e:
                sys.stderr.write(f"Failed to set per-key colors on {dev.name}: {e}\n")
                return False

    sys.stderr.write(f"Device not found: {serial}\n")
    return False
