#!/usr/bin/env python3
"""Build deterministic Script Dependency Inspector release archives.

The builder excludes editor/cache/version-specific sidecars, writes the full-project
manifest inside the project archive, creates stable ZIP member order and timestamps, and emits archive checksums.
Set SOURCE_DATE_EPOCH to override the deterministic ZIP timestamp.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import stat
import time
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON_RELATIVE = Path("addons/script_dependency_inspector")
PROJECT_ARCHIVE_ROOT = "script-dependency-inspector-godot4-project"
MEDIA_ARCHIVE_ROOT = "script-dependency-inspector-asset-store-media"
MEDIA_RELATIVE = Path("docs/asset_store")
DEFAULT_ZIP_EPOCH = 315532800  # 1980-01-01, the minimum representable ZIP date.
EXCLUDED_DIRECTORY_NAMES = {
    ".git",
    ".godot",
    ".mypy_cache",
    ".pytest_cache",
    ".ruff_cache",
    "__pycache__",
    "validation-artifacts",
    "dist",
}


def release_version() -> str:
    text = (ROOT / ADDON_RELATIVE / "plugin.cfg").read_text(encoding="utf-8")
    match = re.search(r'^version="([^"]+)"$', text, re.MULTILINE)
    if match is None:
        raise RuntimeError("plugin.cfg does not declare a release version")
    version = match.group(1)
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise RuntimeError(f"unsupported release version: {version!r}")
    return version


def is_release_file(path: Path) -> bool:
    relative = path.relative_to(ROOT)
    if not path.is_file():
        return False
    if any(part in EXCLUDED_DIRECTORY_NAMES for part in relative.parts):
        return False
    if path.suffix in {".uid", ".import"} or path.name in {"MANIFEST.sha256", ".DS_Store"}:
        return False
    return True


def release_files() -> list[Path]:
    return sorted((path for path in ROOT.rglob("*") if is_release_file(path)), key=lambda path: path.as_posix())


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def manifest_bytes(files: list[Path]) -> bytes:
    lines = [
        f"{sha256_bytes(path.read_bytes())}  ./{path.relative_to(ROOT).as_posix()}"
        for path in files
    ]
    return ("\n".join(lines) + "\n").encode("utf-8")


def zip_datetime() -> tuple[int, int, int, int, int, int]:
    raw_epoch = os.environ.get("SOURCE_DATE_EPOCH", str(DEFAULT_ZIP_EPOCH))
    try:
        epoch = max(DEFAULT_ZIP_EPOCH, int(raw_epoch))
    except ValueError as error:
        raise RuntimeError("SOURCE_DATE_EPOCH must be an integer Unix timestamp") from error
    value = time.gmtime(epoch)
    # ZIP stores seconds at two-second precision.
    return (value.tm_year, value.tm_mon, value.tm_mday, value.tm_hour, value.tm_min, value.tm_sec // 2 * 2)


def add_bytes(archive: zipfile.ZipFile, archive_name: str, data: bytes, executable: bool = False) -> None:
    info = zipfile.ZipInfo(archive_name, date_time=zip_datetime())
    info.create_system = 3
    mode = stat.S_IFREG | (0o755 if executable else 0o644)
    info.external_attr = mode << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)


def write_project_archive(destination: Path, files: list[Path], manifest: bytes) -> None:
    with zipfile.ZipFile(destination, "w") as archive:
        for path in files:
            relative = path.relative_to(ROOT).as_posix()
            add_bytes(
                archive,
                f"{PROJECT_ARCHIVE_ROOT}/{relative}",
                path.read_bytes(),
                executable=bool(path.stat().st_mode & stat.S_IXUSR),
            )
        add_bytes(archive, f"{PROJECT_ARCHIVE_ROOT}/MANIFEST.sha256", manifest)


def write_addon_archive(destination: Path, files: list[Path]) -> None:
    addon_files = [path for path in files if path.is_relative_to(ROOT / ADDON_RELATIVE)]
    if not addon_files:
        raise RuntimeError("no add-on files were selected")
    with zipfile.ZipFile(destination, "w") as archive:
        for path in addon_files:
            relative = path.relative_to(ROOT).as_posix()
            add_bytes(
                archive,
                relative,
                path.read_bytes(),
                executable=bool(path.stat().st_mode & stat.S_IXUSR),
            )


def write_media_archive(destination: Path, files: list[Path]) -> None:
    media_root = ROOT / MEDIA_RELATIVE
    selected = [
        path
        for path in files
        if path in {media_root / "README.md", media_root / "media_manifest.json"}
        or path.is_relative_to(media_root / "current")
    ]
    if not selected:
        raise RuntimeError("no Asset Library media files were selected")
    with zipfile.ZipFile(destination, "w") as archive:
        for path in selected:
            relative = path.relative_to(media_root).as_posix()
            add_bytes(
                archive,
                f"{MEDIA_ARCHIVE_ROOT}/{relative}",
                path.read_bytes(),
                executable=False,
            )


def build(output_directory: Path) -> list[Path]:
    version = release_version()
    output_directory.mkdir(parents=True, exist_ok=True)
    files = release_files()
    manifest = manifest_bytes(files)
    addon = output_directory / f"script-dependency-inspector-addon-v{version}.zip"
    project = output_directory / f"script-dependency-inspector-godot4-project-v{version}.zip"
    media = output_directory / f"script-dependency-inspector-asset-store-media-v{version}.zip"
    checksums = output_directory / f"script-dependency-inspector-v{version}-SHA256SUMS.txt"
    for path in (addon, project, media, checksums):
        path.unlink(missing_ok=True)

    write_addon_archive(addon, files)
    write_project_archive(project, files, manifest)
    write_media_archive(media, files)
    checksum_lines = [
        f"{sha256_bytes(path.read_bytes())}  {path.name}"
        for path in (addon, project, media)
    ]
    checksums.write_text("\n".join(checksum_lines) + "\n", encoding="utf-8")
    return [addon, project, media, checksums]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="Directory for release artifacts")
    arguments = parser.parse_args()
    artifacts = build(arguments.output.resolve())
    for artifact in artifacts:
        print(artifact)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
