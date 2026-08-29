#!/usr/bin/env python3
"""Run required GDScript formatting and lint gates.

This command fails closed when a required executable is unavailable. It is the
release/CI gate; pre-commit uses the same pinned tools for developer feedback.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXCLUDED_PARTS = {".git", ".godot", "dist", "validation-artifacts", "__pycache__"}


def gdscript_files() -> list[str]:
    return [
        str(path.relative_to(ROOT))
        for path in sorted(ROOT.rglob("*.gd"))
        if not any(part in EXCLUDED_PARTS for part in path.relative_to(ROOT).parts)
    ]


def run_required(executable_name: str, arguments: list[str], label: str) -> int:
    executable = shutil.which(executable_name)
    if executable is None:
        print(f"Required GDScript quality tool is unavailable: {executable_name}", file=sys.stderr)
        return 2
    result = subprocess.run(
        [executable, *arguments],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if result.stdout.strip():
        print(result.stdout.rstrip())
    if result.returncode != 0:
        print(f"{label} failed with exit status {result.returncode}.", file=sys.stderr)
        return result.returncode
    print(f"{label}: passed")
    return 0


def main() -> int:
    scripts = gdscript_files()
    if not scripts:
        print("No GDScript files were found.", file=sys.stderr)
        return 2
    result = run_required("gdformat", ["--check", *scripts], "gdformat --check")
    if result != 0:
        return result
    return run_required("gdlint", scripts, "gdlint")


if __name__ == "__main__":
    raise SystemExit(main())
