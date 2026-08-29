#!/usr/bin/env python3
"""Build a single-file handoff of the current Git working tree.

The handoff is intentionally *not* a release artifact. It captures tracked
changes plus untracked, non-ignored files relative to an exact Git baseline,
then emits one ZIP containing:

- a complete source snapshot of the handoff target;
- a binary-capable apply-ready Git patch from the baseline;
- a machine-readable handoff manifest; and
- SHA-256 checksums for the embedded source files and patch.

The repository index, branches, commits, and worktree are not modified.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import tarfile
import tempfile
import time
import zipfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
PROJECT_ARCHIVE_ROOT = "script-dependency-inspector-godot4-project"
HANDOFF_ARCHIVE_ROOT = "script-dependency-inspector-handoff"
PLUGIN_CONFIG = Path("addons/script_dependency_inspector/plugin.cfg")
DEFAULT_ZIP_EPOCH = 315532800  # 1980-01-01, minimum ZIP date.

SENSITIVE_NAME_PATTERNS = (
    re.compile(r"(^|/)\.env($|\.)", re.IGNORECASE),
    re.compile(r"(^|/)(id_rsa|id_dsa|id_ecdsa|id_ed25519)(\.|$)", re.IGNORECASE),
    re.compile(r"\.(pem|p12|pfx|key)$", re.IGNORECASE),
    re.compile(r"(^|/)(credentials|secrets?)(\.|/|$)", re.IGNORECASE),
)


def run_git(
    arguments: list[str],
    *,
    cwd: Path = ROOT,
    binary: bool = False,
    check: bool = True,
) -> bytes | str:
    result = subprocess.run(
        ["git", *arguments],
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=not binary,
        check=False,
    )
    if check and result.returncode != 0:
        stderr = (
            result.stderr.decode("utf-8", errors="replace") if binary else result.stderr
        )
        raise RuntimeError(f"git {' '.join(arguments)} failed: {stderr.strip()}")
    return result.stdout


def verify_repository() -> None:
    if shutil.which("git") is None:
        raise RuntimeError("git is required to build a local handoff")
    top = Path(str(run_git(["rev-parse", "--show-toplevel"])).strip()).resolve()
    if top != ROOT.resolve():
        raise RuntimeError(
            f"run from the project repository rooted at {ROOT}; Git root is {top}"
        )


def verify_ref(ref: str) -> tuple[str, str]:
    commit = str(run_git(["rev-parse", "--verify", f"{ref}^{{commit}}"])).strip()
    tree = str(run_git(["rev-parse", f"{commit}^{{tree}}"])).strip()
    return commit, tree


def project_version() -> str:
    path = ROOT / PLUGIN_CONFIG
    if not path.is_file():
        return "unknown"
    match = re.search(
        r'^version="([^"]+)"$', path.read_text(encoding="utf-8"), re.MULTILINE
    )
    return match.group(1) if match else "unknown"


def git_status() -> list[str]:
    raw = str(
        run_git(["status", "--porcelain=v1", "--untracked-files=all", "--ignored=no"])
    ).splitlines()
    return [line for line in raw if line]


def selected_paths() -> list[Path]:
    raw = bytes(run_git(["ls-files", "-co", "--exclude-standard", "-z"], binary=True))
    entries = []
    seen: set[str] = set()
    for item in raw.split(b"\0"):
        if not item:
            continue
        relative = item.decode("utf-8", errors="surrogateescape")
        if relative in seen:
            continue
        seen.add(relative)
        path = ROOT / relative
        if path.exists() or path.is_symlink():
            entries.append(path)
    return sorted(entries, key=lambda value: value.relative_to(ROOT).as_posix())


def sensitive_candidates(paths: list[Path]) -> list[str]:
    flagged: list[str] = []
    for path in paths:
        relative = path.relative_to(ROOT).as_posix()
        if any(pattern.search(relative) for pattern in SENSITIVE_NAME_PATTERNS):
            flagged.append(relative)
    return flagged


def copy_entry(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if source.is_symlink():
        destination.symlink_to(os.readlink(source))
    else:
        shutil.copy2(source, destination, follow_symlinks=False)


def materialize_target(destination: Path, paths: list[Path]) -> None:
    for source in paths:
        copy_entry(source, destination / source.relative_to(ROOT))


def init_temp_repo(repository: Path) -> None:
    subprocess.run(["git", "init", "-q"], cwd=repository, check=True)
    subprocess.run(
        ["git", "config", "user.name", "Script Dependency Inspector Handoff"],
        cwd=repository,
        check=True,
    )
    subprocess.run(
        ["git", "config", "user.email", "handoff@invalid.local"],
        cwd=repository,
        check=True,
    )


def extract_baseline(base_ref: str, destination: Path) -> None:
    archive = bytes(run_git(["archive", "--format=tar", base_ref], binary=True))
    tar_path = destination.parent / "baseline.tar"
    tar_path.write_bytes(archive)
    with tarfile.open(tar_path, "r") as handle:
        for member in handle.getmembers():
            member_path = PurePosixPath(member.name)
            if member_path.is_absolute() or ".." in member_path.parts:
                raise RuntimeError(f"unsafe path in git archive: {member.name}")
        handle.extractall(destination, filter="data")


def remove_worktree_files(repository: Path) -> None:
    for path in repository.iterdir():
        if path.name == ".git":
            continue
        if path.is_dir() and not path.is_symlink():
            shutil.rmtree(path)
        else:
            path.unlink()


def commit_all(repository: Path, message: str) -> str:
    subprocess.run(["git", "add", "-A", "--", "."], cwd=repository, check=True)
    subprocess.run(
        ["git", "commit", "-q", "--allow-empty", "-m", message],
        cwd=repository,
        check=True,
    )
    return subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=repository,
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    ).stdout.strip()


def build_verified_patch(
    base_ref: str, target_paths: list[Path], temporary: Path
) -> tuple[bytes, str, str]:
    repository = temporary / "patch-repo"
    repository.mkdir()
    extract_baseline(base_ref, repository)
    init_temp_repo(repository)
    baseline_commit = commit_all(repository, "handoff baseline")

    remove_worktree_files(repository)
    materialize_target(repository, target_paths)
    target_commit = commit_all(repository, "handoff target")
    target_tree = subprocess.run(
        ["git", "rev-parse", f"{target_commit}^{{tree}}"],
        cwd=repository,
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    ).stdout.strip()

    patch = subprocess.run(
        [
            "git",
            "diff",
            "--binary",
            "--full-index",
            "--no-renames",
            baseline_commit,
            target_commit,
            "--",
            ".",
        ],
        cwd=repository,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout

    subprocess.run(
        ["git", "reset", "--hard", "-q", baseline_commit], cwd=repository, check=True
    )
    if patch:
        check = subprocess.run(
            [
                "git",
                "apply",
                "--check",
                "--index",
                "--binary",
                "--whitespace=nowarn",
                "-",
            ],
            cwd=repository,
            input=patch,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if check.returncode != 0:
            raise RuntimeError(
                f"generated handoff patch failed git apply --check: {check.stderr.decode().strip()}"
            )
        applied = subprocess.run(
            ["git", "apply", "--index", "--binary", "--whitespace=nowarn", "-"],
            cwd=repository,
            input=patch,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if applied.returncode != 0:
            raise RuntimeError(
                f"generated handoff patch failed to apply: {applied.stderr.decode().strip()}"
            )
    patched_tree = subprocess.run(
        ["git", "write-tree"],
        cwd=repository,
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    ).stdout.strip()
    if patched_tree != target_tree:
        raise RuntimeError(
            f"handoff patch reconstruction mismatch: {patched_tree} != {target_tree}"
        )
    return patch, target_tree, baseline_commit


def zip_datetime() -> tuple[int, int, int, int, int, int]:
    raw_epoch = os.environ.get("SOURCE_DATE_EPOCH", str(DEFAULT_ZIP_EPOCH))
    try:
        epoch = max(DEFAULT_ZIP_EPOCH, int(raw_epoch))
    except ValueError as error:
        raise RuntimeError(
            "SOURCE_DATE_EPOCH must be an integer Unix timestamp"
        ) from error
    value = time.gmtime(epoch)
    return (
        value.tm_year,
        value.tm_mon,
        value.tm_mday,
        value.tm_hour,
        value.tm_min,
        value.tm_sec // 2 * 2,
    )


def add_bytes(
    archive: zipfile.ZipFile, name: str, data: bytes, *, executable: bool = False
) -> None:
    info = zipfile.ZipInfo(name, date_time=zip_datetime())
    info.create_system = 3
    mode = stat.S_IFREG | (0o755 if executable else 0o644)
    info.external_attr = mode << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)


def source_record(path: Path) -> dict[str, object]:
    relative = path.relative_to(ROOT).as_posix()
    if path.is_symlink():
        data = os.readlink(path).encode("utf-8", errors="surrogateescape")
        kind = "symlink"
        executable = False
    else:
        data = path.read_bytes()
        kind = "file"
        executable = bool(path.stat().st_mode & stat.S_IXUSR)
    return {
        "path": relative,
        "kind": kind,
        "size": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "executable": executable,
    }


def build(base_ref: str, output: Path, *, allow_sensitive_looking: bool) -> Path:
    verify_repository()
    base_commit, base_tree = verify_ref(base_ref)
    paths = selected_paths()
    flagged = sensitive_candidates(paths)
    if flagged and not allow_sensitive_looking:
        joined = "\n  - ".join(flagged)
        raise RuntimeError(
            "refusing to package sensitive-looking paths; inspect them and rerun with "
            f"--allow-sensitive-looking only if intentional:\n  - {joined}"
        )

    status = git_status()
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output.mkdir(parents=True, exist_ok=True)
    destination = output / f"script-dependency-inspector-local-handoff-{timestamp}.zip"

    with tempfile.TemporaryDirectory(prefix="sdi-handoff-") as temporary_name:
        temporary = Path(temporary_name)
        patch, target_tree, _ = build_verified_patch(base_ref, paths, temporary)

    source_records = [source_record(path) for path in paths]
    patch_sha256 = hashlib.sha256(patch).hexdigest()
    manifest = {
        "schema_version": 1,
        "artifact_type": "local-working-tree-handoff",
        "project": "Script Dependency Inspector",
        "release_status": "not-a-release",
        "working_copy_version": project_version(),
        "created_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "baseline": {"ref": base_ref, "commit": base_commit, "tree": base_tree},
        "target": {"tree": target_tree, "source_file_count": len(source_records)},
        "git_status_porcelain": status,
        "sensitive_looking_paths_allowed": allow_sensitive_looking,
        "sensitive_looking_paths": flagged,
        "patch": {
            "path": "changes.patch",
            "sha256": patch_sha256,
            "bytes": len(patch),
            "apply": [
                "git apply --check --binary --whitespace=nowarn changes.patch",
                "git apply --binary --whitespace=nowarn changes.patch",
            ],
        },
        "source_files": source_records,
        "notes": [
            "This artifact captures a local working tree for synchronization; it is not a release.",
            "Tracked changes and untracked non-ignored files are included; ignored files are excluded.",
            "The patch was verified by reconstructing the target tree from the exact baseline in an isolated temporary repository.",
        ],
    }
    manifest_bytes = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode(
        "utf-8"
    )

    checksum_lines = [f"{patch_sha256}  changes.patch"]
    checksum_lines.extend(
        f"{record['sha256']}  source/{PROJECT_ARCHIVE_ROOT}/{record['path']}"
        for record in source_records
    )
    checksums = ("\n".join(checksum_lines) + "\n").encode("utf-8")

    destination.unlink(missing_ok=True)
    with zipfile.ZipFile(destination, "w") as archive:
        add_bytes(archive, f"{HANDOFF_ARCHIVE_ROOT}/HANDOFF.json", manifest_bytes)
        add_bytes(archive, f"{HANDOFF_ARCHIVE_ROOT}/SHA256SUMS.txt", checksums)
        add_bytes(archive, f"{HANDOFF_ARCHIVE_ROOT}/changes.patch", patch)
        for path, record in zip(paths, source_records, strict=True):
            relative = str(record["path"])
            archive_name = (
                f"{HANDOFF_ARCHIVE_ROOT}/source/{PROJECT_ARCHIVE_ROOT}/{relative}"
            )
            if path.is_symlink():
                # Store the link target as a Unix symlink entry.
                info = zipfile.ZipInfo(archive_name, date_time=zip_datetime())
                info.create_system = 3
                info.external_attr = (stat.S_IFLNK | 0o777) << 16
                info.compress_type = zipfile.ZIP_STORED
                archive.writestr(
                    info, os.readlink(path).encode("utf-8", errors="surrogateescape")
                )
            else:
                add_bytes(
                    archive,
                    archive_name,
                    path.read_bytes(),
                    executable=bool(record["executable"]),
                )
    return destination


def verify_handoff_archive(path: Path) -> None:
    """Verify every checksum entry against its actual member path in the handoff ZIP."""
    with zipfile.ZipFile(path, "r") as archive:
        prefix = f"{HANDOFF_ARCHIVE_ROOT}/"
        checksum_name = prefix + "SHA256SUMS.txt"
        lines = archive.read(checksum_name).decode("utf-8").splitlines()
        for line in lines:
            if not line.strip():
                continue
            expected, relative = line.split("  ", 1)
            member_name = prefix + relative
            try:
                payload = archive.read(member_name)
            except KeyError as error:
                raise RuntimeError(
                    f"handoff checksum references missing archive member: {relative}"
                ) from error
            actual = hashlib.sha256(payload).hexdigest()
            if actual != expected:
                raise RuntimeError(
                    f"handoff checksum mismatch for {relative}: {actual} != {expected}"
                )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--base-ref",
        default="HEAD",
        help="Exact Git baseline for the patch (default: HEAD)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT.parent / "script-dependency-inspector-handoff-artifacts",
        help="Output directory (default: sibling script-dependency-inspector-handoff-artifacts directory)",
    )
    parser.add_argument(
        "--allow-sensitive-looking",
        action="store_true",
        help="Package paths whose names resemble credentials/secrets after manual inspection",
    )
    arguments = parser.parse_args()
    artifact = build(
        arguments.base_ref,
        arguments.output.resolve(),
        allow_sensitive_looking=arguments.allow_sensitive_looking,
    )
    verify_handoff_archive(artifact)
    print(artifact)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
