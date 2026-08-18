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
