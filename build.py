#!/usr/bin/env python3
"""
Builds Spice Shaker to build/spice-shaker (build/spice-shaker.exe on Windows), after installing its dependencies.

Spice Shaker cannot install its own dependencies before it is built, so an installed Spice Shaker does it: the one, that ships
with the Spice compiler, or a release from https://github.com/spicelang/spice-shaker/releases.

Usage: python3 build.py
Needs Python 3.9 or newer, and the Spice compiler and Spice Shaker on the path.
"""

import subprocess
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent
SOURCE_DIR = ROOT_DIR / "src"
BUILD_DIR = ROOT_DIR / "build"


def run(command: list[str], cwd: Path, missing_hint: str) -> int:
    try:
        return subprocess.run(command, cwd=cwd).returncode
    except FileNotFoundError:
        print(f"error: Could not run '{command[0]}'. {missing_hint}", file=sys.stderr)
        return 1


def main() -> int:
    # Dependencies, as recorded in src/spice.lock
    returncode = run(["spice-shaker", "sync"], SOURCE_DIR,
                     "Is Spice Shaker installed? It ships with the Spice compiler, or download a release from "
                     "https://github.com/spicelang/spice-shaker/releases.")
    if returncode != 0:
        return returncode

    # Build
    BUILD_DIR.mkdir(exist_ok=True)
    output = "spice-shaker.exe" if sys.platform == "win32" else "spice-shaker"
    command = ["spice", "build", "-m", "release", "-o", str(Path(".") / output), str(Path("..") / "src" / "main.spice")]
    returncode = run(command, BUILD_DIR, "Is the Spice compiler installed?")
    # Spice 0.29.0 loses the executable bit when it takes the executable from its cache
    executable = BUILD_DIR / output
    if returncode == 0 and sys.platform != "win32":
        executable.chmod(executable.stat().st_mode | 0o111)
    return returncode


if __name__ == "__main__":
    sys.exit(main())
