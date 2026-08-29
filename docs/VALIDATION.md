# Validation and verification procedure

Version: 0.3.0
Issue date: 2026-08-27

`docs/RELEASE-GATES.md` is the normative release-gate contract. This document gives the maintainer-oriented execution route. A passing command supports only the claim named by its gate.

## Required source gates

Run the pinned GDScript quality gate and static repository contract separately:

```sh
python tools/run_gdscript_quality.py
python tools/validate_static.py
```

If `gdformat` or `gdlint` is unavailable, the GDScript quality gate fails. Do not convert the unavailable result into a pass.

## Runtime compatibility

For each claimed Godot engine, run the isolated validation harness with a fresh output directory:

```sh
python tools/run_validation.py --godot /path/to/godot --project . --output /tmp/sdi-validation
```

Retain the engine identifier, command, gate result, and any skipped or unverified scope in external release evidence.

## Distributed package

Build release archives, verify their structure, then verify the actual redistributable add-on ZIP in a clean project:

```sh
python tools/build_release.py --output dist
python tools/verify_release_artifacts.py \
  --addon dist/script-dependency-inspector-addon-v0.3.0.zip \
  --project dist/script-dependency-inspector-godot4-project-v0.3.0.zip \
  --media dist/script-dependency-inspector-asset-store-media-v0.3.0.zip
python tools/verify_packaged_addon.py \
  --addon dist/script-dependency-inspector-addon-v0.3.0.zip \
  --godot /path/to/godot
```

The packaged-add-on check covers archive layout, required notices, editor plugin initialization, representative scan/build/validation/JSON export, and the non-execution static-initializer regression.

When independently checking the extracted full-project archive, verify its embedded `MANIFEST.sha256` first. Then run `python tools/validate_static.py --allow-root-manifest`. The flag is only for the extracted release archive, because the development source tree must not contain a generated root manifest.

## Reproducibility claim

A deterministic construction design is not by itself a reproducibility result. Build the claimed archives twice from the same accepted source state and environment, then compare the archive bytes. Record which artifacts matched.

## Patch reconstruction

Generate the binary-capable patch from the exact immediately preceding release. Apply it to a clean copy of that baseline and compare the reconstructed source tree with the target. The patch builder performs this check when exact Git refs are available.

## Media

Run `python tools/validate_asset_store_media.py`. When media changed or is release-owned, inspect the final rendered files. Generation success and dimension checks do not replace visual inspection.

## Evidence location

Per-release logs, compatibility matrices, review reports, delivery manifests, and checksums are delivery/provenance evidence. Keep them outside the normal source repository unless a project decision changes that retention policy.
