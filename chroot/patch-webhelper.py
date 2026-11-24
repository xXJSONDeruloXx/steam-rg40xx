#!/usr/bin/env python3
"""Rewrites Valve's steamwebhelper.sh for this device, keeping its byte size.

The client's startup verification only compares file sizes, so a same-size
rewrite survives restarts; a client update replaces it and this runs again.
- drops `taskset 0x7c` (Steam Deck cores 2-6; leaves 2 of 4 cores here)
- adds --disable-hang-monitor (renderers on an A53 with software raster are
  slow enough that Steam kills them as unresponsive)
"""
import os
import sys

path = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/.local/share/Steam/steamrtarm64/steamwebhelper.sh")
marker = b"--disable-hang-monitor"
orig = open(path, "rb").read()
if marker in orig:
    sys.exit(0)
extra = os.environ.get("WEBHELPER_EXTRA_ARGS", "").encode()
new = (b'#!/bin/bash\n'
       b'cd "$(dirname -- "${BASH_SOURCE[0]}")"\n'
       b'[ -n "$DISPLAY" ] || export DISPLAY=:0\n'
       b'export LIBGL_KOPPER_DISABLE=true\n'
       b'exec $(pwd)/steamwebhelper "$@" ' + marker + (b" " + extra if extra else b"") +
       b' &> ~/.steam/steam/logs/steamwebhelper.log\n')
pad = len(orig) - len(new)
if pad < 2:
    sys.exit(f"patch-webhelper: new wrapper is {-pad} bytes too long")
new += b"#" * (pad - 1) + b"\n"
mode = os.stat(path).st_mode
open(path, "wb").write(new)
os.chmod(path, mode)
print("patch-webhelper: patched", path)
