#!/usr/bin/env python3
"""Build and verify apply-ready Git patches between two repository refs.

The complete patch uses ``git diff --binary --full-index`` and is the
reconstruction artifact. A separate text-oriented patch and diffstat are
provided for review. The script verifies the complete patch in a detached
worktree before publishing it.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLUGIN_CONFIG = "addons/script_dependency_inspector/plugin.cfg"


def run_git(
    arguments: list[str], *, cwd: Path = ROOT, binary: bool = False
) -> bytes | str:
    result = subprocess.run(
        ["git", *arguments],
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        text=not binary,
    )
    if result.returncode != 0:
        stderr = (
            result.stderr.decode("utf-8", errors="replace") if binary else result.stderr
        )
        raise RuntimeError(f"git {' '.join(arguments)} failed: {stderr.strip()}")
    return result.stdout


def verify_ref(ref: str) -> str:
    return str(run_git(["rev-parse", "--verify", f"{ref}^{{commit}}"])).strip()


def version_at(ref: str) -> str:
    text = str(run_git(["show", f"{ref}:{PLUGIN_CONFIG}"]))
    match = re.search(r'^version="([^"]+)"$', text, re.MULTILINE)
    if match is None:
        raise RuntimeError(f"{ref} does not contain a versioned {PLUGIN_CONFIG}")
    version = match.group(1)
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise RuntimeError(f"unsupported release version at {ref}: {version!r}")
    return version


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def infer_base_ref(target_ref: str) -> str:
    target_commit = verify_ref(target_ref)
    result = subprocess.run(
        ["git", "describe", "--tags", "--abbrev=0", f"{target_commit}^"],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        text=True,
    )
    if result.returncode != 0 or not result.stdout.strip():
        raise RuntimeError(
            "could not infer a previous release tag; pass --base-ref explicitly "
            "after tagging the preceding release"
        )
    return result.stdout.strip()


def verify_patch(base_ref: str, target_ref: str, patch: Path) -> None:
    # Resolve the target before creating a detached base worktree. In that
    # worktree, a symbolic target such as HEAD would otherwise mean the base.
    expected_target_tree = str(run_git(["rev-parse", f"{target_ref}^{{tree}}"])).strip()
    with tempfile.TemporaryDirectory(prefix="sdi-patch-verify-") as temporary:
        worktree = Path(temporary) / "worktree"
        run_git(["worktree", "add", "--detach", str(worktree), base_ref])
        try:
            # Apply to both the worktree and index so additions and deletions are
            # represented in the reconstructed tree, not left as untracked files.
            run_git(
                [
                    "apply",
                    "--check",
                    "--index",
                    "--binary",
                    "--whitespace=nowarn",
                    str(patch),
                ],
                cwd=worktree,
            )
            run_git(
                [
                    "apply",
                    "--index",
                    "--binary",
                    "--whitespace=nowarn",
                    str(patch),
                ],
                cwd=worktree,
            )
            patched_tree = str(run_git(["write-tree"], cwd=worktree)).strip()
            if patched_tree != expected_target_tree:
                raise RuntimeError(
                    "patched tree differs from target ref "
                    f"({patched_tree} != {expected_target_tree})"
                )
        finally:
            run_git(["worktree", "remove", "--force", str(worktree)])


def build(base_ref: str, target_ref: str, output: Path) -> list[Path]:
    base_commit = verify_ref(base_ref)
    target_commit = verify_ref(target_ref)
    base_version = version_at(base_ref)
    target_version = version_at(target_ref)
    if base_commit == target_commit:
        raise RuntimeError("base and target resolve to the same commit")

    output.mkdir(parents=True, exist_ok=True)
    stem = f"script-dependency-inspector-v{base_version}-to-v{target_version}"
    complete = output / f"{stem}.patch"
    text_patch = output / f"{stem}-text.patch"
    diffstat = output / f"{stem}-DIFFSTAT.txt"
    notes = output / f"{stem}-PATCH-NOTES.md"
    checksums = output / f"{stem}-SHA256SUMS.txt"

    complete.write_bytes(
        bytes(
            run_git(
                [
                    "diff",
                    "--binary",
                    "--full-index",
                    "--no-renames",
                    base_ref,
                    target_ref,
                    "--",
                    ".",
                ],
                binary=True,
            )
        )
    )
    text_patch.write_text(
        str(
            run_git(
                [
                    "diff",
                    "--no-ext-diff",
                    "--no-renames",
                    "--src-prefix=a/",
                    "--dst-prefix=b/",
                    base_ref,
                    target_ref,
                    "--",
                    ".",
                ]
            )
        ),
        encoding="utf-8",
    )
    diffstat.write_text(
        str(run_git(["diff", "--stat", "--summary", base_ref, target_ref, "--", "."])),
        encoding="utf-8",
    )
    if complete.stat().st_size == 0:
        raise RuntimeError("complete patch is empty")
    verify_patch(base_ref, target_ref, complete)

    notes.write_text(
        f"""# Patch notes: v{base_version} to v{target_version}

- Base ref: `{base_ref}` (`{base_commit}`)
- Target ref: `{target_ref}` (`{target_commit}`)
- Authoritative artifact: `{complete.name}`
- Review-only artifact: `{text_patch.name}`

The complete patch includes binary files and was verified by applying it to a detached worktree at the base ref and comparing the result with the target ref.

## Apply

From a clean checkout of v{base_version}:

```sh
git apply --check --binary --whitespace=nowarn {complete.name}
git apply --binary --whitespace=nowarn {complete.name}
```

The text patch is intended for review and may omit reconstructable binary content. Do not use it as the authoritative upgrade artifact.
""",
        encoding="utf-8",
    )
    checksum_paths = [complete, text_patch, diffstat, notes]
    checksums.write_text(
        "\n".join(f"{sha256(path)}  {path.name}" for path in checksum_paths) + "\n",
        encoding="utf-8",
    )
    return [*checksum_paths, checksums]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--base-ref",
        help="Previous release tag or commit; defaults to the nearest tag before target",
    )
    parser.add_argument(
        "--target-ref", default="HEAD", help="Target release tag or commit"
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("dist"),
        help="Output directory (default: dist)",
    )
    arguments = parser.parse_args()
    if shutil.which("git") is None:
        raise RuntimeError("git is required to build release patches")
    base_ref = arguments.base_ref or infer_base_ref(arguments.target_ref)
    if arguments.base_ref is None:
        print(f"Inferred base ref: {base_ref}")
    for artifact in build(base_ref, arguments.target_ref, arguments.output.resolve()):
        print(artifact)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
