# Local working-tree handoff

Use this procedure to send an in-progress local repository state for synchronization without turning it into a release or creating a temporary commit.

The handoff builder records the exact Git baseline, includes tracked changes and untracked non-ignored files, creates a binary-capable patch, verifies that the patch reconstructs the captured target tree, and embeds a complete source snapshot in one ZIP.

## Build a handoff

From the repository root:

```sh
python tools/build_handoff.py
```

The default patch baseline is `HEAD`. If the local work must be described relative to another exact commit or tag, name it explicitly:

```sh
python tools/build_handoff.py --base-ref v0.3.0
```

By default, the command writes one file to a sibling `script-dependency-inspector-handoff-artifacts/` directory outside the repository:

```text
script-dependency-inspector-local-handoff-YYYYMMDDTHHMMSSZ.zip
```

Upload that ZIP as the synchronization handoff. It contains:

- `HANDOFF.json` — baseline commit/tree, captured target tree, Git status, and source inventory;
- `changes.patch` — binary-capable patch from the named baseline;
- `SHA256SUMS.txt` — hashes for the patch and captured source files; and
- `source/script-dependency-inspector-godot4-project/` — complete captured source state.

## What is included

The source snapshot is based on Git's tracked files plus untracked files that are not ignored by `.gitignore` or other Git exclude rules. Deleted tracked files are represented by their absence from the source snapshot and by the deletion in `changes.patch`.

Ignored editor/cache/local-output state is not included. Review `git status --short --untracked-files=all` before building so newly created source files are intentional.

The builder refuses common credential-looking filenames such as `.env`, private-key files, and `credentials`/`secrets` paths. If such a path is genuinely intended source material, inspect it first and opt in with `--allow-sensitive-looking`.

## Handoff versus release

A handoff is an in-progress synchronization artifact. It is not a release and does not change the add-on semantic version.

Do not use `tools/build_release.py` as a substitute for a dirty-working-tree handoff: that builder intentionally names artifacts from `plugin.cfg` and is for release packaging. Use `tools/build_patch.py` for release-to-release patches between exact Git refs.
