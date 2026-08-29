#!/usr/bin/env python3
"""Create the deterministic redistributable add-on ZIP only.

The archive contains ``addons/script_dependency_inspector`` at its installable
project-relative location. It shares release filtering and ZIP metadata rules
with ``tools/build_release.py``.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from build_release import (
    release_files,
    release_version,
    sha256_bytes,
    write_addon_archive,
)


def package(destination: Path) -> Path:
    version = release_version()
    if destination.suffix.lower() == ".zip":
        archive = destination
        archive.parent.mkdir(parents=True, exist_ok=True)
    else:
        destination.mkdir(parents=True, exist_ok=True)
        archive = destination / f"script-dependency-inspector-addon-v{version}.zip"
    archive.unlink(missing_ok=True)
    write_addon_archive(archive, release_files())
    checksum = sha256_bytes(archive.read_bytes())
    print(f"{checksum}  {archive.name}")
    return archive


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("dist"),
        help="Destination ZIP path or output directory (default: dist)",
    )
    arguments = parser.parse_args()
    archive = package(arguments.output.resolve())
    print(archive)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
