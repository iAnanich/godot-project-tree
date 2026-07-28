#!/usr/bin/env python3
"""Run reproducible Script Dependency Inspector validation with one Godot binary."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import asdict, dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


@dataclass
class GateResult:
    name: str
    command: list[str]
    returncode: int
    duration_seconds: float
    log: str
    suspicious_lines: list[str]

    @property
    def ok(self) -> bool:
        return self.returncode == 0 and not self.suspicious_lines


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run static, import, public-test, showcase-export, and performance gates "
            "in an isolated project copy."
        )
    )
    parser.add_argument("--godot", required=True, type=Path, help="Godot executable")
    parser.add_argument("--project", type=Path, default=ROOT, help="Project root")
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "validation-artifacts",
        help="Directory for logs and summary.json",
    )
    parser.add_argument("--timeout", type=int, default=120, help="Seconds per gate")
    parser.add_argument("--keep-workdir", action="store_true", help="Retain isolated project copy")
    parser.add_argument("--skip-static", action="store_true", help="Skip tools/validate_static.py")
    return parser.parse_args()


def copy_project(source: Path, destination: Path) -> None:
    def ignore(_directory: str, names: list[str]) -> set[str]:
        ignored = {".godot", "validation-artifacts", "__pycache__"}
        return {name for name in names if name in ignored}

    shutil.copytree(source, destination, ignore=ignore)


def suspicious_output(text: str) -> list[str]:
    suspicious: list[str] = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if "Scan thread aborted" in stripped:
            continue
        if any(
            token in stripped
            for token in (
                "SCRIPT ERROR:",
                "Parse Error:",
                "Failed to load script",
                "Stack underflow",
            )
        ):
            suspicious.append(stripped)
    return suspicious


def run_gate(
    name: str,
    command: list[str],
    cwd: Path,
    environment: dict[str, str],
    timeout: int,
    output: Path,
) -> GateResult:
    started = time.monotonic()
    try:
        completed = subprocess.run(
            command,
            cwd=cwd,
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
        )
        returncode = completed.returncode
        log_text = completed.stdout
    except subprocess.TimeoutExpired as error:
        returncode = 124
        partial = error.stdout or ""
        if isinstance(partial, bytes):
            partial = partial.decode("utf-8", errors="replace")
        log_text = f"{partial}\nVALIDATION TIMEOUT after {timeout} seconds\n"
    duration = time.monotonic() - started
    result = GateResult(
        name=name,
        command=command,
        returncode=returncode,
        duration_seconds=round(duration, 3),
        log=str(output / f"{name}.log"),
        suspicious_lines=suspicious_output(log_text),
    )
    (output / f"{name}.log").write_text(log_text, encoding="utf-8")
    return result


def main() -> int:
    args = parse_args()
    godot = args.godot.resolve()
    project = args.project.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)

    if not godot.is_file():
        print(f"Godot executable does not exist: {godot}", file=sys.stderr)
        return 2
    if not (project / "project.godot").is_file():
        print(f"Not a Godot project: {project}", file=sys.stderr)
        return 2
    godot.chmod(godot.stat().st_mode | 0o111)

    temporary_root = Path(tempfile.mkdtemp(prefix="sdi-validation-"))
    work_project = temporary_root / "project"
    runtime_home = temporary_root / "home"
    runtime_home.mkdir()
    copy_project(project, work_project)

    environment = os.environ.copy()
    environment.update(
        {
            "HOME": str(runtime_home),
            "XDG_CONFIG_HOME": str(runtime_home / ".config"),
            "XDG_DATA_HOME": str(runtime_home / ".local" / "share"),
            "XDG_CACHE_HOME": str(runtime_home / ".cache"),
            "GODOT_SILENCE_ROOT_WARNING": "1",
        }
    )

    commands: list[tuple[str, list[str]]] = [
        ("version", [str(godot), "--version"]),
    ]
    if not args.skip_static:
        commands.append(("static", [sys.executable, "tools/validate_static.py"]))
    commands.extend(
        [
            (
                "editor_import",
                [str(godot), "--headless", "--editor", "--path", ".", "--quit-after", "5"],
            ),
            ("public_tests", [str(godot), "--headless", "--path", ".", "--script", "tests/test_runner.gd"]),
            (
                "showcase_export",
                [
                    str(godot),
                    "--headless",
                    "--path",
                    ".",
                    "--script",
                    "tests/generate_showcase_exports.gd",
                ],
            ),
            (
                "performance",
                [
                    str(godot),
                    "--headless",
                    "--path",
                    ".",
                    "--script",
                    "tests/performance_runner.gd",
                ],
            ),
        ]
    )

    results: list[GateResult] = []
    for name, command in commands:
        result = run_gate(
            name, command, work_project, environment, args.timeout, output
        )
        results.append(result)
        status = "PASS" if result.ok else "FAIL"
        print(f"{status:4} {name:16} {result.duration_seconds:8.3f}s")
        if not result.ok:
            break

    summary = {
        "ok": all(result.ok for result in results) and len(results) == len(commands),
        "godot": str(godot),
        "source_project": str(project),
        "isolated_project": str(work_project) if args.keep_workdir else "removed",
        "results": [asdict(result) | {"ok": result.ok} for result in results],
    }
    (output / "summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )

    if args.keep_workdir:
        print(f"Isolated project retained at: {work_project}")
    else:
        shutil.rmtree(temporary_root, ignore_errors=True)

    return 0 if summary["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
