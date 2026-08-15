#!/usr/bin/env python3
"""OpenRazer plugin CLI entrypoint."""

import sys
from scripts.razer_devices import main

if __name__ == "__main__":
    sys.exit(main())
