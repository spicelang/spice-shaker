#!/usr/bin/env python3
"""
Builds Spice Shaker to build/spice-shaker (build/spice-shaker.exe on Windows), after installing its dependencies with
bootstrap.py.

Usage: python3 build.py
Needs Python 3.11 or newer and the Spice compiler on the path.
"""

import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True  # Keep __pycache__ out of the repository
import bootstrap

BUILD_DIR = Path(__file__).resolve().parent / "build"


def main() -> int:
    # Dependencies
    if bootstrap.main() != 0:
        return 1

    # Build
    BUILD_DIR.mkdir(exist_ok=True)
    output = "spice-shaker.exe" if sys.platform == "win32" else "spice-shaker"
    command = ["spice", "build", "-m", "release", "-o", str(Path(".") / output), str(Path("..") / "src" / "main.spice")]
    try:
        returncode = subprocess.run(command, cwd=BUILD_DIR).returncode
    except FileNotFoundError:
        print("error: Could not run 'spice'. Is the Spice compiler installed?", file=sys.stderr)
        return 1
    # Spice 0.29.0 loses the executable bit when it takes the executable from its cache
    executable = BUILD_DIR / output
    if returncode == 0 and sys.platform != "win32":
        executable.chmod(executable.stat().st_mode | 0o111)
    return returncode


if __name__ == "__main__":
    sys.exit(main())
