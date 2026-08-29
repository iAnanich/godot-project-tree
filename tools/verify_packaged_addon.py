#!/usr/bin/env python3
"""Verify the actual redistributable add-on ZIP in an isolated Godot project."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import tempfile
import textwrap
import zipfile
from pathlib import Path, PurePosixPath

ADDON_PREFIX = PurePosixPath("addons/script_dependency_inspector")
FORBIDDEN_PARTS = {".git", ".godot", "__pycache__", "dist", "validation-artifacts"}


def safe_members(archive: zipfile.ZipFile) -> list[zipfile.ZipInfo]:
    members = archive.infolist()
    if not members:
        raise RuntimeError("add-on archive is empty")
    for info in members:
        path = PurePosixPath(info.filename)
        if path.is_absolute() or ".." in path.parts:
            raise RuntimeError(f"unsafe archive member: {info.filename}")
        if any(part in FORBIDDEN_PARTS for part in path.parts):
            raise RuntimeError(f"forbidden archive member: {info.filename}")
        if not path.is_relative_to(ADDON_PREFIX):
            raise RuntimeError(f"unexpected add-on archive member: {info.filename}")
    required = {
        "addons/script_dependency_inspector/plugin.cfg",
        "addons/script_dependency_inspector/plugin.gd",
        "addons/script_dependency_inspector/LICENSE",
        "addons/script_dependency_inspector/NOTICE",
    }
    names = {item.filename.rstrip("/") for item in members}
    missing = sorted(required - names)
    if missing:
        raise RuntimeError(f"add-on archive is missing required files: {missing}")
    return members


def environment(root: Path) -> dict[str, str]:
    env = os.environ.copy()
    for name in ("home", "config", "data", "cache"):
        (root / name).mkdir(parents=True, exist_ok=True)
    env.update(
        {
            "HOME": str(root / "home"),
            "XDG_CONFIG_HOME": str(root / "config"),
            "XDG_DATA_HOME": str(root / "data"),
            "XDG_CACHE_HOME": str(root / "cache"),
            "GODOT_SILENCE_ROOT_WARNING": "1",
        }
    )
    return env


def run(command: list[str], *, cwd: Path, env: dict[str, str], label: str, timeout: int) -> str:
    result = subprocess.run(
        command,
        cwd=cwd,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(f"{label} failed with exit status {result.returncode}:\n{result.stdout}")
    lowered = result.stdout.lower()
    for token in ("parse error", "failed to load script", "could not resolve script"):
        if token in lowered:
            raise RuntimeError(f"{label} reported a script-load failure:\n{result.stdout}")
    return result.stdout


def write_smoke_project(project: Path) -> None:
    (project / "samples").mkdir(parents=True, exist_ok=True)
    (project / "project.godot").write_text(
        textwrap.dedent(
            """\
            [application]
            config/name="SDI packaged add-on verification"
            [editor_plugins]
            enabled=PackedStringArray("res://addons/script_dependency_inspector/plugin.cfg")
            [rendering]
            renderer/rendering_method="gl_compatibility"
            """
        ),
        encoding="utf-8",
    )
    (project / "samples" / "base.gd").write_text(
        "class_name PackagedBase\nextends RefCounted\nfunc ping() -> void:\n\tpass\n", encoding="utf-8"
    )
    (project / "samples" / "consumer.gd").write_text(
        textwrap.dedent(
            """\
            extends PackagedBase
            const BASE_SCRIPT = preload("res://samples/base.gd")
            static var marker_written: bool = _write_marker()
            static func _write_marker() -> bool:
            \tvar file := FileAccess.open("user://sdi_packaged_marker.txt", FileAccess.WRITE)
            \tif file != null:
            \t\tfile.store_string("executed")
            \t\tfile.close()
            \treturn true
            """
        ),
        encoding="utf-8",
    )
    (project / "smoke.gd").write_text(
        textwrap.dedent(
            """\
            extends SceneTree
            const ROOT := "res://addons/script_dependency_inspector/"
            func _init() -> void:
            \tvar marker := "user://sdi_packaged_marker.txt"
            \tif FileAccess.file_exists(marker):
            \t\tDirAccess.remove_absolute(ProjectSettings.globalize_path(marker))
            \tvar scanner_script := load(ROOT + "core/project_scanner.gd")
            \tvar builder_script := load(ROOT + "core/graph_builder.gd")
            \tvar validator_script := load(ROOT + "core/snapshot_validator.gd")
            \tvar exporter_script := load(ROOT + "export/export_service.gd")
            \tif scanner_script == null or builder_script == null or validator_script == null or exporter_script == null:
            \t\tpush_error("Required packaged add-on script could not be loaded.")
            \t\tquit(1)
            \t\treturn
            \tvar scanner = scanner_script.new()
            \tvar builder = builder_script.new()
            \tvar validator = validator_script.new()
            \tvar exporter = exporter_script.new()
            \tfor service in [scanner, builder, exporter]:
            \t\tif service.has_method("initialization_errors") and not service.call("initialization_errors").is_empty():
            \t\t\tpush_error("Packaged service initialization failed: %s" % [service.call("initialization_errors")])
            \t\t\tquit(1)
            \t\t\treturn
            \tvar scan: Dictionary = scanner.scan("res://samples", {"include_scene_usages": false, "use_runtime_reflection": true})
            \tif not scan.get("errors", []).is_empty() or FileAccess.file_exists(marker):
            \t\tpush_error("Packaged scan failed source-only contract: %s" % [scan.get("errors", [])])
            \t\tquit(1)
            \t\treturn
            \tvar snapshot: Dictionary = builder.build(scan)
            \tvar validation: Dictionary = validator.validate(snapshot)
            \tif not validation.get("ok", false):
            \t\tpush_error("Packaged snapshot validation failed: %s" % [validation])
            \t\tquit(1)
            \t\treturn
            \tvar destination := "user://packaged-smoke.json"
            \tvar export_result: Dictionary = exporter.export_to_file("json", destination, snapshot)
            \tif not export_result.get("ok", false) or not FileAccess.file_exists(destination):
            \t\tpush_error("Packaged JSON export failed: %s" % [export_result])
            \t\tquit(1)
            \t\treturn
            \tprint("Packaged add-on smoke verification passed.")
            \tquit(0)
            """
        ),
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--addon", type=Path, required=True)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--timeout", type=int, default=90)
    args = parser.parse_args()
    addon = args.addon.resolve()
    godot = args.godot.resolve()
    if not addon.is_file() or not godot.is_file():
        raise RuntimeError("--addon and --godot must identify existing files")
    with tempfile.TemporaryDirectory(prefix="sdi-packaged-addon-") as temporary:
        root = Path(temporary)
        project = root / "project"
        project.mkdir()
        with zipfile.ZipFile(addon) as archive:
            safe_members(archive)
            archive.extractall(project)
        write_smoke_project(project)
        env = environment(root / "env")
        import_log = run(
            [str(godot), "--headless", "--editor", "--path", str(project), "--quit-after", "2"],
            cwd=project,
            env=env,
            label="packaged add-on editor initialization",
            timeout=args.timeout,
        )
        smoke_log = run(
            [str(godot), "--headless", "--path", str(project), "--script", "smoke.gd"],
            cwd=project,
            env=env,
            label="packaged add-on smoke behavior",
            timeout=args.timeout,
        )
        if "Packaged add-on smoke verification passed." not in smoke_log:
            raise RuntimeError("packaged add-on smoke script did not emit its success marker")
        print(f"Packaged add-on verified: {addon}")
        if import_log.strip():
            print("Editor initialization completed.")
        print("Representative scan/build/validate/export behavior completed without executing the scanned static initializer.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
