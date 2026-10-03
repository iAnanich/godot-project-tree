# Contributing

## Change contract

Before implementation, state the user-visible behavior, non-goals, compatibility impact, failure behavior, and evidence that will establish completion. Existing code is evidence of current behavior, not automatically the intended contract.

Preserve these public invariants unless a versioned migration is approved:

- snapshot schema and canonical edge direction;
- stable node identity and ordering;
- explicit fallback diagnostics;
- Godot 4.3–4.7 compatibility on the supplied Linux builds;
- source-only dependency discovery with no analyzed project-script resource loading;
- no production `const/var = preload(...)` dependency chains.

## Development project

Open this repository as a Godot project. The add-on is enabled in `project.godot`, and `examples/showcase` exercises the main inheritance and dependency forms.

Godot must import the project once before command-line tests so global `class_name` registrations are available:

```sh
godot --headless --editor --path . --quit-after 5
godot --headless --path . --script tests/test_runner.gd
```

## Local developer workflow

Install `requirements-dev.txt`, then configure Godot paths once with `python tools/dev.py configure --godot VERSION=/path ...`. Run `python tools/dev.py doctor` to diagnose the active Python/Pillow/gdtoolkit/Godot environment. Use `python tools/dev.py quality` for formatting plus all-version checks, `python tools/dev.py assets`, `python tools/dev.py package`, and `python tools/dev.py handoff`. Use `quality --check` for non-mutating CI/review validation.

## Commit-time formatting and linting

Install the pinned development tools and Git hook once per clone:

```sh
python -m pip install --requirement requirements-dev.txt
pre-commit install --install-hooks
```

The hook runs `gdformat` and then `gdlint` for staged GDScript files. Formatting modifications stop the commit so they can be reviewed and staged. Run every hook across the repository with `pre-commit run --all-files --show-diff-on-failure`.

## Required validation

Run the narrowest focused test while iterating, then the release gates:

```sh
python tools/run_gdscript_quality.py
python tools/validate_static.py
godot --headless --editor --path . --quit-after 5
godot --headless --path . --script tests/test_runner.gd
godot --headless --path . --script tests/generate_showcase_exports.gd
godot --headless --path . --script tests/performance_runner.gd
```

`tools/run_validation.py --godot /path/to/godot` performs those gates in an isolated copy and records logs. Public behavior changes require an end-to-end assertion in `tests/test_runner.gd` or an appropriate capability suite. Exporter implementations must pass `tests/contracts/exporter_contract.gd`.

For compatibility changes, execute the same gates on every supported minor version. A source-level assumption is not runtime evidence.

## Test organization

- `tests/contracts`: reusable contracts for interchangeable implementations.
- `tests/suites`: focused capability suites.
- `tests/fixtures`: representative source inputs and negative cases.
- `tests/test_runner.gd`: legacy orchestration and broad regression coverage.

Add one coherent behavioral claim per test helper. Failure messages must identify the contract and failed condition. Do not weaken a current-version contract merely to make a historical version pass; isolate a genuine compatibility branch instead.

## Reproducible release packaging

See [`docs/RELEASING.md`](docs/RELEASING.md) for add-on-only packaging, verified patch generation, tagging, and GitHub Release automation.

Build both archives and their checksums through the repository-owned builder:

```sh
python tools/build_release.py --output dist
```

The builder derives the semantic version from `plugin.cfg`, excludes local/generated state, writes `MANIFEST.sha256` inside the project archive, sorts archive members, and uses `SOURCE_DATE_EPOCH` for stable ZIP timestamps. A reproducibility claim requires two controlled builds with byte-identical target archives.

## Documentation

Update documentation in the same change when behavior, use cases, schema, compatibility, security, or architecture changes. Consequential decisions belong in `docs/decisions`. User-facing workflow changes must update `docs/USE_CASES.md` and its traceability; diagram changes require source, rendered output, and text alternatives; release-specific review evidence belongs outside the source repository. Regenerate showcase exports after changing canonical output or exporters.

## Review priorities

Review correctness, compatibility, test evidence, security, maintainability, performance, and editor usability separately. Treat file size, lint counts, and coverage as investigation prompts rather than quality conclusions.

## Licensing and release ownership

Contributions are accepted under the MIT License. Contributors must have the right to submit their material and must review AI-assisted contributions for incompatible copying, provenance risks, correctness, and security. See `AI_USAGE_NOTICE.md`.

A marketplace release still requires the project owner to choose the final publisher identity, support channel, and security contact. Contributors must not invent those governance decisions.

## Design and marketplace knowledge

Substantial behavior or UI changes must update `docs/DESIGN.md`, `docs/USE_CASES.md`, and `docs/ASSET_STORE_DESCRIPTION.md` in the same change. Automation changes must preserve the one-shot completion-to-next-start timing contract and include the dedicated automation gate.
