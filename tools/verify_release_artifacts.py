#!/usr/bin/env python3
"""Verify Script Dependency Inspector release archive structure and manifest integrity."""

from __future__ import annotations

import argparse
import hashlib
import zipfile
from pathlib import Path, PurePosixPath

PROJECT_ROOT = PurePosixPath("script-dependency-inspector-godot4-project")
MEDIA_ROOT = PurePosixPath("script-dependency-inspector-asset-store-media")
ADDON_ROOT = PurePosixPath("addons/script_dependency_inspector")
FORBIDDEN_PARTS = {".git", ".godot", "__pycache__", "dist", "validation-artifacts"}
FORBIDDEN_SUFFIXES = {".uid", ".import", ".pyc"}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def check_member(name: str) -> PurePosixPath:
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts:
        raise RuntimeError(f"unsafe archive member: {name}")
    if any(part in FORBIDDEN_PARTS for part in path.parts):
        raise RuntimeError(f"forbidden archive member: {name}")
    if path.suffix in FORBIDDEN_SUFFIXES:
        raise RuntimeError(f"forbidden generated sidecar: {name}")
    return path


def verify_project(path: Path) -> None:
    with zipfile.ZipFile(path) as archive:
        names = [
            info.filename.rstrip("/")
            for info in archive.infolist()
            if not info.is_dir()
        ]
        for name in names:
            member = check_member(name)
            if not member.is_relative_to(PROJECT_ROOT):
                raise RuntimeError(
                    f"project archive member is outside canonical root: {name}"
                )
        manifest_name = f"{PROJECT_ROOT}/MANIFEST.sha256"
        if manifest_name not in names:
            raise RuntimeError("project archive lacks MANIFEST.sha256")
        raw = archive.read(manifest_name).decode("utf-8")
        declared: dict[str, str] = {}
        for line in raw.splitlines():
            digest, relative = line.split("  ./", 1)
            declared[relative] = digest
        actual_names = {
            str(PurePosixPath(name).relative_to(PROJECT_ROOT))
            for name in names
            if name != manifest_name
        }
        if set(declared) != actual_names:
            raise RuntimeError(
                f"project manifest inventory mismatch: missing={sorted(actual_names - set(declared))}, extra={sorted(set(declared) - actual_names)}"
            )
        for relative, expected in declared.items():
            data = archive.read(f"{PROJECT_ROOT}/{relative}")
            if sha256(data) != expected:
                raise RuntimeError(f"project manifest digest mismatch: {relative}")


def verify_addon(path: Path) -> None:
    with zipfile.ZipFile(path) as archive:
        files = [
            info.filename.rstrip("/")
            for info in archive.infolist()
            if not info.is_dir()
        ]
        if not files:
            raise RuntimeError("add-on archive is empty")
        for name in files:
            member = check_member(name)
            if not member.is_relative_to(ADDON_ROOT):
                raise RuntimeError(f"unexpected add-on member: {name}")
        for required in ("plugin.cfg", "plugin.gd", "LICENSE", "NOTICE"):
            name = f"{ADDON_ROOT}/{required}"
            if name not in files:
                raise RuntimeError(f"add-on archive lacks {name}")


def verify_media(path: Path) -> None:
    with zipfile.ZipFile(path) as archive:
        files = [
            info.filename.rstrip("/")
            for info in archive.infolist()
            if not info.is_dir()
        ]
        for name in files:
            member = check_member(name)
            if not member.is_relative_to(MEDIA_ROOT):
                raise RuntimeError(
                    f"media archive member is outside canonical root: {name}"
                )
        required = {
            f"{MEDIA_ROOT}/README.md",
            f"{MEDIA_ROOT}/media_manifest.json",
            f"{MEDIA_ROOT}/current/thumbnail.webp",
        }
        missing = sorted(required - set(files))
        if missing:
            raise RuntimeError(f"media archive lacks required files: {missing}")
        if any(
            "source-captures" in PurePosixPath(name).parts
            or "documentation" in PurePosixPath(name).parts
            for name in files
        ):
            raise RuntimeError(
                "media upload archive contains source/documentation captures"
            )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--addon", type=Path, required=True)
    parser.add_argument("--media", type=Path, required=True)
    args = parser.parse_args()
    verify_project(args.project.resolve())
    verify_addon(args.addon.resolve())
    verify_media(args.media.resolve())
    print("Release archive verification passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
