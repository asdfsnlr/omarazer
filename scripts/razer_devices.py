#!/usr/bin/env python3
"""OpenRazer device scanner and management helper for Omarchy shell.

Thin CLI entry point — logic lives in:
  helpers.py   - pure utilities (no OpenRazer dependency)
  devices.py   - device status and discovery
  effects.py   - device control (brightness, poll rate, effects)
  perkey.py    - per-key LED matrix lighting
  profiles.py  - profile file management
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any

# Ensure the plugin root is on sys.path so `from scripts.xxx import ...` works
# when invoked as `python3 scripts/razer_devices.py` from the plugin directory.
_plugin_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _plugin_root not in sys.path:
    sys.path.insert(0, _plugin_root)

from scripts.helpers import normalize_effect_name
from scripts.devices import get_razer_status, print_summary
from scripts.effects import set_brightness, set_poll_rate, set_effect
from scripts.perkey import get_matrix_dims, set_per_key, set_per_key_batch
from scripts.profiles import list_profiles, save_profile, load_profile, delete_profile


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
    parser.add_argument(
        "--get-matrix-dims",
        metavar="SERIAL",
        help="Get LED matrix dimensions for a device (JSON output)",
    )
    parser.add_argument(
        "--set-per-key",
        nargs="+",
        metavar="ARG",
        help="Set per-key color: SERIAL ROW COL R G B",
    )
    parser.add_argument(
        "--set-per-key-batch",
        nargs=2,
        metavar=("SERIAL", "JSON"),
        help="Set multiple per-key colors at once: SERIAL '[ [row,col,r,g,b], ... ]'",
    )
    parser.add_argument(
        "--list-profiles",
        action="store_true",
        help="List saved profile names as JSON array",
    )
    parser.add_argument(
        "--save-profile",
        nargs=2,
        metavar=("NAME", "JSON"),
        help="Save a profile: NAME '{\"rows\":6,\"cols\":22,\"colors\":[...]}'",
    )
    parser.add_argument(
        "--load-profile",
        metavar="NAME",
        help="Load a profile by name (JSON output)",
    )
    parser.add_argument(
        "--delete-profile",
        metavar="NAME",
        help="Delete a saved profile by name",
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

    if args.get_matrix_dims:
        dims = get_matrix_dims(args.get_matrix_dims)
        print(json.dumps(dims, separators=(",", ":")))
        return 0 if "error" not in dims else 1

    if args.set_per_key:
        raw_args = args.set_per_key
        if len(raw_args) < 6:
            sys.stderr.write("Usage: --set-per-key SERIAL ROW COL R G B\n")
            return 1
        serial = raw_args[0]
        row, col = int(raw_args[1]), int(raw_args[2])
        r, g, b = int(raw_args[3]), int(raw_args[4]), int(raw_args[5])
        success = set_per_key(serial, row, col, r, g, b)
        return 0 if success else 1

    if args.set_per_key_batch:
        serial, json_str = args.set_per_key_batch
        try:
            keys = json.loads(json_str)
            if not isinstance(keys, list):
                sys.stderr.write("Error: JSON payload must be a list of [row, col, r, g, b] arrays\n")
                return 1
        except json.JSONDecodeError as e:
            sys.stderr.write(f"Error parsing JSON payload: {e}\n")
            return 1
        success = set_per_key_batch(serial, keys)
        return 0 if success else 1

    if args.list_profiles:
        names = list_profiles()
        print(json.dumps(names))
        return 0

    if args.save_profile:
        name, json_data = args.save_profile
        try:
            data = json.loads(json_data)
            if not isinstance(data, dict):
                sys.stderr.write("Error: profile data must be a JSON object\n")
                return 1
        except json.JSONDecodeError as e:
            sys.stderr.write(f"Error parsing profile JSON: {e}\n")
            return 1
        success = save_profile(name, data)
        return 0 if success else 1

    if args.load_profile:
        data = load_profile(args.load_profile)
        if data is None:
            return 1
        print(json.dumps(data, separators=(",", ":")))
        return 0

    if args.delete_profile:
        success = delete_profile(args.delete_profile)
        return 0 if success else 1

    status = get_razer_status()

    if args.summary:
        print_summary(status)
    else:
        print(json.dumps(status, separators=(",", ":")))

    return 0


if __name__ == "__main__":
    sys.exit(main())
