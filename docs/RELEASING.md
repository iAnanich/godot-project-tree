# Release procedure

Version: 0.3.0
Issue date: 2026-08-27

This procedure implements `RELEASE-REQUIREMENTS.md` and `RELEASE-GATES.md`. A GitHub draft release is a packaging result, not evidence that every runtime release gate passed.

## 1. Prepare development tooling

```sh
python -m pip install --requirement requirements-dev.txt
pre-commit install --install-hooks
```

The local hook runs `gdformat` before `gdlint`. Formatter modifications remain visible for review and staging.

Before release, run the fail-closed gate directly:

```sh
python tools/run_gdscript_quality.py
python tools/validate_static.py
```

## 2. Run runtime release gates

Run `tools/run_validation.py` independently on every claimed Godot version. Use fresh HOME/XDG and output state. Record failures, skips, and limitations rather than retrying blindly after an unknown partial result.

## 3. Build archives twice

```sh
python tools/build_release.py --output dist-first
python tools/build_release.py --output dist-second
cmp dist-first/script-dependency-inspector-addon-v0.4.0.zip dist-second/script-dependency-inspector-addon-v0.4.0.zip
cmp dist-first/script-dependency-inspector-godot4-project-v0.4.0.zip dist-second/script-dependency-inspector-godot4-project-v0.4.0.zip
cmp dist-first/script-dependency-inspector-asset-store-media-v0.4.0.zip dist-second/script-dependency-inspector-asset-store-media-v0.4.0.zip
```

A byte-identical second build by the same operator/environment supports a same-environment repeatability claim for that artifact. Do not call it reproducible without an independent operator or independently controlled build service recreating the specified artifact from the declared source, environment, and instructions.

## 4. Verify the archives and installed add-on

```sh
python tools/verify_release_artifacts.py \
  --addon dist-first/script-dependency-inspector-addon-v0.4.0.zip \
  --project dist-first/script-dependency-inspector-godot4-project-v0.4.0.zip \
  --media dist-first/script-dependency-inspector-asset-store-media-v0.4.0.zip

python tools/verify_packaged_addon.py \
  --addon dist-first/script-dependency-inspector-addon-v0.4.0.zip \
  --godot /path/to/Godot_v4.7-stable_linux.x86_64
```

Use a supported Godot build for the package smoke check. This gate supplements, and does not replace, the full per-engine matrix.

## 5. Generate the immediate-predecessor patch

Tag the exact preceding release before generating the normal patch. Then use:

```sh
python tools/build_patch.py --base-ref v0.3.0 --target-ref HEAD --output dist-first
```

The reconstruction artifact is binary-capable. Apply it from a clean v0.2.4 checkout with:

```sh
git apply --check --binary --whitespace=nowarn script-dependency-inspector-v0.2.4-to-v0.3.0.patch
git apply --binary --whitespace=nowarn script-dependency-inspector-v0.2.4-to-v0.3.0.patch
```

The patch builder must reconstruct the target Git tree before the patch is described as complete.

## 6. GitHub release candidate

`.github/workflows/release.yml` verifies tag/version agreement, runs source gates, performs two archive builds, compares the archive bytes, verifies archive structure, and builds the immediate-predecessor patch when a prior tag exists. It creates a **draft** GitHub release using the repository-scoped `GITHUB_TOKEN` with `contents: write`.

Do not publish the draft as a verified release until all required external runtime gates and package verification are complete or the project owner records an explicit accepted exception with its lost guarantee.

## 7. Delivery evidence

Finalize the delivery manifest and SHA-256 checksum list only after every primary artifact is final. Keep per-release review and validation evidence in the delivery preservation set, not as routine repository documentation.
