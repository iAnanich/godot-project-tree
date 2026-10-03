#!/usr/bin/env python3
"""Validate repository-owned Godot Asset Library media."""

from __future__ import annotations

import json
import sys
from pathlib import Path

from build_release import release_version

try:
    from PIL import Image
except ModuleNotFoundError as error:
    if error.name != "PIL":
        raise
    raise SystemExit(
        "Pillow is unavailable for this Python interpreter: "
        f"{sys.executable}\n"
        "Install development requirements with that same interpreter: "
        f"{sys.executable} -m pip install -r requirements-dev.txt"
    ) from error

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / "docs/asset_store/current"
MANIFEST = ROOT / "docs/asset_store/media_manifest.json"
MAX_BYTES = 600 * 1024
MIN_SIZE = (1280, 720)
RECOMMENDED = (1920, 1080)


def main() -> int:
    errors = []
    if not MANIFEST.is_file():
        errors.append("missing media_manifest.json")
        entries = []
    else:
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
        entries = data.get("media", [])
    roles = [e.get("role") for e in entries]
    if roles.count("thumbnail") != 1:
        errors.append("manifest must contain exactly one thumbnail")
    if not any(r == "featured" for r in roles):
        errors.append("manifest must contain featured media")
    declared = set()
    for entry in entries:
        name = str(entry.get("file", ""))
        declared.add(name)
        path = MEDIA / name
        if not path.is_file():
            errors.append(f"missing media file: {name}")
            continue
        if path.suffix.lower() != ".webp":
            errors.append(f"not WebP: {name}")
        if path.stat().st_size > MAX_BYTES:
            errors.append(f"over 600 KB: {name} ({path.stat().st_size} bytes)")
        with Image.open(path) as image:
            w, h = image.size
        if w * 9 != h * 16:
            errors.append(f"not 16:9: {name} ({w}x{h})")
        if w < MIN_SIZE[0] or h < MIN_SIZE[1]:
            errors.append(f"below 1280x720: {name} ({w}x{h})")
        if tuple(entry.get("dimensions", [])) != (w, h):
            errors.append(f"manifest dimensions mismatch: {name}")
        if entry.get("release") != release_version():
            errors.append(f"wrong release in manifest: {name}")
    actual = {p.name for p in MEDIA.glob("*.webp")}
    if actual != declared:
        errors.append(
            f"manifest/file set mismatch: declared={sorted(declared)}, actual={sorted(actual)}"
        )
    if errors:
        print("Asset-store media validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print(
        f"Asset-store media validation passed: {len(entries)} files; all 16:9, WebP, and <=600 KB."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
