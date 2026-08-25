#!/usr/bin/env python3
"""Profile file management for OmaRazer — no OpenRazer dependency."""

from __future__ import annotations

import json
import os
import sys
from typing import Any


def get_profiles_dir() -> str:
    """Return ~/.config/omarazer/profiles/, creating it if needed."""
    profiles_dir = os.path.join(os.path.expanduser("~"), ".config", "omarazer", "profiles")
    os.makedirs(profiles_dir, exist_ok=True)
    return profiles_dir


def sanitize_profile_name(name: str) -> str:
    """Strip path separators and dangerous characters from profile names."""
    return name.replace("/", "_").replace("\\", "_").replace("..", "_").strip()


def list_profiles() -> list[str]:
    """Return sorted list of saved profile names (without .json extension)."""
    profiles_dir = get_profiles_dir()
    names = []
    for f in os.listdir(profiles_dir):
        if f.endswith(".json"):
            names.append(f[:-5])
    names.sort()
    return names


def save_profile(name: str, data: dict[str, Any]) -> bool:
    """Save a profile to ~/.config/omarazer/profiles/<name>.json."""
    safe_name = sanitize_profile_name(name)
    if not safe_name:
        sys.stderr.write("Error: empty profile name\n")
        return False
    profiles_dir = get_profiles_dir()
    path = os.path.join(profiles_dir, safe_name + ".json")
    try:
        with open(path, "w") as f:
            json.dump(data, f, indent=2)
        return True
    except Exception as e:
        sys.stderr.write(f"Failed to save profile: {e}\n")
        return False


def load_profile(name: str) -> dict[str, Any] | None:
    """Load a profile from ~/.config/omarazer/profiles/<name>.json."""
    safe_name = sanitize_profile_name(name)
    profiles_dir = get_profiles_dir()
    path = os.path.join(profiles_dir, safe_name + ".json")
    try:
        with open(path, "r") as f:
            return json.load(f)
    except FileNotFoundError:
        sys.stderr.write(f"Profile not found: {name}\n")
        return None
    except Exception as e:
        sys.stderr.write(f"Failed to load profile: {e}\n")
        return None


def delete_profile(name: str) -> bool:
    """Delete a profile file from ~/.config/omarazer/profiles/."""
    safe_name = sanitize_profile_name(name)
    profiles_dir = get_profiles_dir()
    path = os.path.join(profiles_dir, safe_name + ".json")
    try:
        os.remove(path)
        return True
    except FileNotFoundError:
        sys.stderr.write(f"Profile not found: {name}\n")
        return False
    except Exception as e:
        sys.stderr.write(f"Failed to delete profile: {e}\n")
        return False


# ── DPI Profiles ─────────────────────────────────────────────────────────────

DEFAULT_DPI_PROFILES: dict[str, dict[str, Any]] = {
    "Default": {"name": "Default", "presets": [800, 1200, 1800, 2400, 3200], "dpi": 1200},
    "FPS": {"name": "FPS", "presets": [800, 1200, 3000], "dpi": 800},
    "Gaming": {"name": "Gaming", "presets": [400, 800, 1600, 3200], "dpi": 800},
    "Office": {"name": "Office", "presets": [800, 1200, 2000], "dpi": 1200},
}


def get_dpi_profiles_dir() -> str:
    """Return ~/.config/omarazer/dpi_profiles/, creating it if needed."""
    dpi_profiles_dir = os.path.join(os.path.expanduser("~"), ".config", "omarazer", "dpi_profiles")
    os.makedirs(dpi_profiles_dir, exist_ok=True)
    return dpi_profiles_dir


def list_dpi_profiles() -> list[str]:
    """Return sorted list of saved DPI profile names (without .json extension).

    If no user profiles exist yet, seeds default profiles.
    """
    dpi_profiles_dir = get_dpi_profiles_dir()
    names = [f[:-5] for f in os.listdir(dpi_profiles_dir) if f.endswith(".json")]

    if not names:
        # Seed default profiles
        for def_name, def_data in DEFAULT_DPI_PROFILES.items():
            save_dpi_profile(def_name, def_data)
        names = list(DEFAULT_DPI_PROFILES.keys())

    names.sort()
    return names


def save_dpi_profile(name: str, data: dict[str, Any]) -> bool:
    """Save a DPI profile to ~/.config/omarazer/dpi_profiles/<name>.json."""
    safe_name = sanitize_profile_name(name)
    if not safe_name:
        sys.stderr.write("Error: empty DPI profile name\n")
        return False
    dpi_profiles_dir = get_dpi_profiles_dir()
    path = os.path.join(dpi_profiles_dir, safe_name + ".json")
    try:
        with open(path, "w") as f:
            json.dump(data, f, indent=2)
        return True
    except Exception as e:
        sys.stderr.write(f"Failed to save DPI profile: {e}\n")
        return False


def load_dpi_profile(name: str) -> dict[str, Any] | None:
    """Load a DPI profile from ~/.config/omarazer/dpi_profiles/<name>.json."""
    safe_name = sanitize_profile_name(name)
    dpi_profiles_dir = get_dpi_profiles_dir()
    path = os.path.join(dpi_profiles_dir, safe_name + ".json")
    try:
        with open(path, "r") as f:
            return json.load(f)
    except FileNotFoundError:
        if safe_name in DEFAULT_DPI_PROFILES:
            return DEFAULT_DPI_PROFILES[safe_name]
        sys.stderr.write(f"DPI profile not found: {name}\n")
        return None
    except Exception as e:
        sys.stderr.write(f"Failed to load DPI profile: {e}\n")
        return None


def delete_dpi_profile(name: str) -> bool:
    """Delete a DPI profile file from ~/.config/omarazer/dpi_profiles/."""
    safe_name = sanitize_profile_name(name)
    dpi_profiles_dir = get_dpi_profiles_dir()
    path = os.path.join(dpi_profiles_dir, safe_name + ".json")
    try:
        os.remove(path)
        return True
    except FileNotFoundError:
        sys.stderr.write(f"DPI profile not found: {name}\n")
        return False
    except Exception as e:
        sys.stderr.write(f"Failed to delete DPI profile: {e}\n")
        return False

