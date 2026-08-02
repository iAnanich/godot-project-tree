# Validation

Version: 0.2.2

## Release gates

Each claimed Godot version is validated in an isolated copied project with these gates:

1. engine version identification;
2. static repository and documentation contracts;
3. editor import/parser check;
4. public behavioral tests;
5. synchronization/automation lifecycle tests;
6. export matrix;
7. showcase export generation;
8. rendered visual showcase;
9. bounded performance fixtures.

The final per-engine evidence is recorded in [`validation/v0.2.2-compatibility-matrix.md`](validation/v0.2.2-compatibility-matrix.md) and the consolidated [`v0.2.2 release report`](validation/v0.2.2-release-validation.md).

## v0.2.2 acceptance evidence

- Manual export format selection remains compact and Scan/Export groups remain separated.
- The scan indicator reports default save synchronization and the combined save/timed state.
- Graph-off operation clears rendered nodes but retains the validated snapshot, summary, diagnostics, synchronization, and exporter availability.
- Graph-on operation rerenders the retained snapshot without rescanning.
- Fold headers expose semantic grouping, persist state, and retain tooltips.
- Editor-state schemas 1–3 migrate to schema-4 defaults; malformed types are rejected or defaulted.
- Existing scope, focus, navigation, autoload/scene evidence, synchronization, and exporter contracts regress unchanged.
- AI and store disclosures satisfy their documented content contract.

## Visual evidence

The v0.2.2 screenshot set contains:

- `v0.2.2-overview.png`: compact toolbar, default save-sync indicator, grouped controls, and graph;
- `v0.2.2-export-only.png`: Graph hidden while summary, Automation controls, and automatic export destinations remain;
- `v0.2.2-folded-controls.png`: visible semantic groups with secondary categories folded;
- `v0.2.2-automation.png`: editor synchronization, timed fallback, independent file exports, and combined trigger indicator.

The manual record is [`images/v0.2.2-REVIEW.md`](images/v0.2.2-REVIEW.md). Screenshots establish rendering and state visibility, not unfamiliar-user comprehension.

## Tool qualification

Godot parser/import and runtime execution are authoritative for GDScript behavior. Optional `gdlint`/`gdformat` checks are reported as skipped when unavailable; no pass is claimed. Build and patch validation verifies deterministic archives, SHA-256 manifests, ZIP integrity, exclusion of generated `.import`/`.uid` sidecars, and reconstruction from the exact v0.2.1 baseline.

## Completion rule

A release archive alone is insufficient. Completion requires all claimed compatibility gates, deterministic build evidence, archive/manifest verification, patch reconstruction, synchronized code/use cases/design/store copy/AI notice/screenshots, and explicit residual limitations.
