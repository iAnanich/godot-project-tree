#!/usr/bin/env python3
"""Capture real Script Dependency Inspector media and rebuild Asset Library WebP files."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from build_release import release_version

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / f"docs/asset_store/source-captures/v{release_version()}/raw"
STATES = {
    "overview": "media_overview",
    "max_info": "media_max_info",
    "complex": "media_complex",
    "tab_content": "media_tab_content",
    "tab_appearance": "media_tab_appearance",
    "tab_colors": "media_tab_colors",
    "tab_automation": "media_tab_automation",
    "tab_summary": "media_tab_summary",
    "tab_log": "media_tab_log",
    "scope": "media_scope",
    "search": "media_search",
    "export_only": "media_export_only",
    "member_tooltip": "media_member_tooltip",
    "connection_tooltip": "media_connection_tooltip",
    "stale_snapshot": "media_stale",
}


def run(
    command: list[str],
    *,
    cwd: Path = ROOT,
    env: dict[str, str] | None = None,
    timeout: int = 120,
) -> None:
    result = subprocess.run(
        command,
        cwd=cwd,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        timeout=timeout,
    )
    if result.returncode:
        raise RuntimeError(
            f"Command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}"
        )


def enable_capture_plugin(project: Path) -> None:
    cfg = project / "project.godot"
    text = cfg.read_text(encoding="utf-8")
    needle = 'enabled=PackedStringArray("res://addons/script_dependency_inspector/plugin.cfg")'
    replacement = 'enabled=PackedStringArray("res://addons/script_dependency_inspector/plugin.cfg", "res://tools/media_capture/plugin.cfg")'
    if needle not in text:
        raise RuntimeError("Unexpected editor_plugins configuration")
    cfg.write_text(text.replace(needle, replacement), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--skip-editor-navigation", action="store_true")
    args = parser.parse_args()
    godot = args.godot.resolve()
    if not godot.is_file():
        raise SystemExit(f"Godot executable not found: {godot}")
    xvfb = shutil.which("xvfb-run")
    if xvfb is None:
        raise SystemExit("xvfb-run is required for deterministic Linux captures")
    RAW.mkdir(parents=True, exist_ok=True)
    run(
        [str(godot), "--headless", "--editor", "--path", str(ROOT), "--quit-after", "5"]
    )
    for output, state in STATES.items():
        run(
            [
                xvfb,
                "-a",
                str(godot),
                "--path",
                str(ROOT),
                "--script",
                str(ROOT / "tests/visual_showcase_runner.gd"),
                "--",
                f"--state={state}",
                "--width=1920",
                "--height=1080",
                f"--output={RAW / (output + '.png')}",
            ]
        )
    if not args.skip_editor_navigation:
        with tempfile.TemporaryDirectory(prefix="sdi-media-editor-") as temporary:
            project = Path(temporary) / "project"
            shutil.copytree(
                ROOT,
                project,
                ignore=shutil.ignore_patterns(
                    ".git", ".godot", ".sdi-dev.json", "dist", "validation-artifacts", "__pycache__"
                ),
            )
            enable_capture_plugin(project)
            run(
                [
                    str(godot),
                    "--headless",
                    "--editor",
                    "--path",
                    str(project),
                    "--quit-after",
                    "5",
                ],
                cwd=project,
            )
            env = os.environ.copy()
            env["SDI_MEDIA_CAPTURE_STATE"] = "navigation"
            env["SDI_MEDIA_CAPTURE_OUTPUT"] = str(RAW / "editor-navigation.png")
            run(
                [
                    xvfb,
                    "-a",
                    "-s",
                    "-screen 0 1920x1080x24",
                    str(godot),
                    "--editor",
                    "--path",
                    str(project),
                    "--resolution",
                    "1920x1080",
                ],
                cwd=project,
                env=env,
                timeout=180,
            )
    documentation = ROOT / "docs/asset_store/documentation"
    documentation.mkdir(parents=True, exist_ok=True)
    for name in ("content", "appearance", "colors", "automation", "summary", "log"):
        shutil.copy2(RAW / f"tab_{name}.png", documentation / f"tab_{name}.png")
    run(
        [
            sys.executable,
            str(ROOT / "tools/build_asset_store_media.py"),
        ]
    )
    run(
        [
            sys.executable,
            str(ROOT / "tools/validate_asset_store_media.py"),
        ]
    )
    print(
        f"Asset-store media captured in {RAW} and built in {ROOT / 'docs/asset_store/current'}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
