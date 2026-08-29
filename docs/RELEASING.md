# Release packaging and patches

Version: 0.2.4

## Local prerequisites

Python 3.10 or later and Git are required. Install the pinned development tools and the commit hooks once per clone:

```sh
python -m pip install --requirement requirements-dev.txt
pre-commit install --install-hooks
```

`gdformat` runs before `gdlint` on staged GDScript files. Formatting changes stop the commit so the changed files can be reviewed and staged again. Run the same checks explicitly with:

```sh
pre-commit run --all-files --show-diff-on-failure
```

## Package only the redistributable add-on

```sh
python tools/package_addon.py --output dist
```

The output ZIP contains `addons/script_dependency_inspector/...`. A user installs it by extracting the archive at the root of a Godot project and enabling the plugin. The ZIP is deterministic for the same source tree and `SOURCE_DATE_EPOCH`.

## Build all source archives

```sh
python tools/build_release.py --output dist
```

This produces the add-on ZIP, complete development-project ZIP, their checksums, and the project manifest.

## Build an apply-ready patch

### One-time tag bootstrap

Patch generation depends on release tags. Before building the v0.2.4 patch, ensure the commit containing the exact v0.2.3 tree is tagged:

```sh
git tag -a v0.2.3 <v0.2.3-commit> -m "Script Dependency Inspector 0.2.3"
```

Do not attach the v0.2.3 tag to a v0.1.6 or v0.2.4 tree. Existing correctly named tags require no change.

### Every subsequent release

After committing the next release, generate its patch with one command:

```sh
python tools/build_patch.py
```

By default the script uses `HEAD`, finds the nearest preceding release tag, and writes to `dist`. Explicit refs remain available when needed:

```sh
python tools/build_patch.py \
  --base-ref v0.2.3 \
  --target-ref v0.2.4 \
  --output dist
```

The complete `.patch` includes binary files and is verified in a detached worktree by comparing the reconstructed Git tree with the target release. Apply it from a clean checkout of the base release:

```sh
git apply --check --binary --whitespace=nowarn script-dependency-inspector-v0.2.3-to-v0.2.4.patch
git apply --binary --whitespace=nowarn script-dependency-inspector-v0.2.3-to-v0.2.4.patch
```

A separate text patch is generated for review only.

## GitHub release automation

`.github/workflows/release.yml` runs for semantic-version tags such as `v0.2.4`. It:

1. verifies that the tag equals the version in `plugin.cfg`;
2. runs `gdformat`, `gdlint`, and repository static contracts;
3. builds the add-on and full-project archives;
4. finds the previous reachable release tag and generates a verified binary patch;
5. creates a GitHub Release and uploads every artifact from `dist`.

Recommended release sequence:

```sh
pre-commit run --all-files
git status
git commit -m "Release 0.2.4"
git tag -a v0.2.4 -m "Script Dependency Inspector 0.2.4"
git push origin main v0.2.4
```

The workflow uses the repository-provided `GITHUB_TOKEN`; no personal access token is required. Repository settings must allow GitHub Actions to create releases with `contents: write` permission.
