#!/usr/bin/env python3
"""Run reproducible Script Dependency Inspector validation with one Godot binary."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import shlex
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
            "Run static, import, public-test, automation, export-matrix, showcase-export, visual-showcase, and performance gates "
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
        generated_directories = {".godot", "validation-artifacts", "__pycache__"}
        return {
            name
            for name in names
            if name in generated_directories or name.endswith(".uid")
        }

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
    log_path = output / f"{name}.log"
    timeout_command = [
        shutil.which("timeout") or "timeout",
        "--kill-after=5s",
        f"{timeout}s",
        *command,
    ]
    shell_command = (
        f"{shlex.join(timeout_command)} > {shlex.quote(str(log_path))} 2>&1"
    )
    completed = subprocess.run(
        ["bash", "-lc", shell_command],
        cwd=cwd,
        env=environment,
        text=True,
        check=False,
    )
    returncode = completed.returncode
    if returncode in {124, 137}:
        with log_path.open("a", encoding="utf-8") as log_file:
            log_file.write(f"\nVALIDATION TIMEOUT after {timeout} seconds\n")
    log_text = log_path.read_text(encoding="utf-8", errors="replace")
    duration = time.monotonic() - started
    return GateResult(
        name=name,
        command=command,
        returncode=returncode,
        duration_seconds=round(duration, 3),
        log=str(log_path),
        suspicious_lines=suspicious_output(log_text),
    )


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
    base_project = temporary_root / "prepared" / "project"
    base_home = temporary_root / "prepared" / "home"
    base_home.mkdir(parents=True)
    copy_project(project, base_project)

    def environment_for(home: Path) -> dict[str, str]:
        environment = os.environ.copy()
        environment.update(
            {
                "HOME": str(home),
                "XDG_CONFIG_HOME": str(home / ".config"),
                "XDG_DATA_HOME": str(home / ".local" / "share"),
                "XDG_CACHE_HOME": str(home / ".cache"),
                "GODOT_SILENCE_ROOT_WARNING": "1",
            }
        )
        return environment

    results: list[GateResult] = []

    def record(result: GateResult) -> bool:
        results.append(result)
        status = "PASS" if result.ok else "FAIL"
        print(f"{status:4} {result.name:16} {result.duration_seconds:8.3f}s")
        return result.ok

    if not record(
        run_gate(
            "version",
            [str(godot), "--version"],
            base_project,
            environment_for(base_home),
            args.timeout,
            output,
        )
    ):
        expected_gate_count = 1
    else:
        expected_gate_count = 9 if not args.skip_static else 8
        if not args.skip_static:
            if not record(
                run_gate(
                    "static",
                    [sys.executable, "tools/validate_static.py"],
                    base_project,
                    environment_for(base_home),
                    args.timeout,
                    output,
                )
            ):
                expected_gate_count = 2
        if len(results) == (2 if not args.skip_static else 1) and results[-1].ok:
            if not record(
                run_gate(
                    "editor_import",
                    [str(godot), "--headless", "--editor", "--path", ".", "--quit-after", "5"],
                    base_project,
                    environment_for(base_home),
                    args.timeout,
                    output,
                )
            ):
                expected_gate_count = len(results)

    prepared_gates: list[tuple[str, list[str]]] = [
        ("public_tests", [str(godot), "--headless", "--path", ".", "--script", "tests/test_runner.gd"]),
        ("automation", [str(godot), "--headless", "--path", ".", "--script", "tests/automation_runner.gd"]),
        ("export_matrix", [str(godot), "--headless", "--path", ".", "--script", "tests/export_matrix_runner.gd"]),
        ("showcase_export", [str(godot), "--headless", "--path", ".", "--script", "tests/generate_showcase_exports.gd"]),
        (
            "visual_showcase",
            [
                shutil.which("xvfb-run") or "xvfb-run", "-a", str(godot),
                "--path", ".", "--script", "tests/visual_showcase_runner.gd",
                "--", "--state=scope",
                f"--output={output / 'visual-validation.png'}",
            ],
        ),
        ("performance", [str(godot), "--headless", "--path", ".", "--script", "tests/performance_runner.gd"]),
    ]
    if results and results[-1].ok and any(result.name == "editor_import" for result in results):
        for name, command in prepared_gates:
            gate_root = temporary_root / "gates" / name
            gate_project = gate_root / "project"
            gate_home = gate_root / "home"
            gate_home.mkdir(parents=True)
            shutil.copytree(base_project, gate_project)
            if not record(
                run_gate(
                    name,
                    command,
                    gate_project,
                    environment_for(gate_home),
                    args.timeout,
                    output,
                )
            ):
                expected_gate_count = len(results)
                break


    summary = {
        "ok": all(result.ok for result in results) and len(results) == expected_gate_count,
        "godot": str(godot),
        "source_project": str(project),
        "isolated_project": str(temporary_root) if args.keep_workdir else "removed",
        "results": [asdict(result) | {"ok": result.ok} for result in results],
    }
    (output / "summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )

    if args.keep_workdir:
        print(f"Isolated validation root retained at: {temporary_root}")
    else:
        shutil.rmtree(temporary_root, ignore_errors=True)

    return 0 if summary["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
