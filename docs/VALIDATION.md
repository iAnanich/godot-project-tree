# Validation

Version: 0.2.4

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

The final per-engine evidence is recorded in [`validation/v0.2.4-compatibility-matrix.md`](validation/v0.2.4-compatibility-matrix.md) and the consolidated [`v0.2.4 release report`](validation/v0.2.4-release-validation.md).

## v0.2.4 acceptance evidence

- `docs/asset_store/current/` contains exactly one thumbnail and seven featured media files declared by `media_manifest.json`.
- Every upload file is WebP, 16:9, 1920×1080, and at most 600 KB.
- Every featured image is derived from a real Godot runtime or editor capture. The thumbnail embeds the real default-overview capture and does not substitute a generated graph or fabricated UI.
- The focused default and maximum-information images use the small `examples/media_showcase` fixture rather than the repository-wide tools/tests/add-on tree.
- The editor-navigation image is captured from the actual Godot editor with a selected graph member and the Script Editor cursor at its source location.
- Documentation includes one real screenshot for each principal dock tab: Content, Appearance, Colors, Automation, Summary, and Log.
- Capture, transformation, manifest, and validation steps are source-controlled and reproducible through `tools/capture_asset_store_media.py`, `tools/build_asset_store_media.py`, and `tools/validate_asset_store_media.py`.
- `docs/asset_store/.gdignore` prevents Godot from importing repository-owned media; this is required for compatibility with the oldest supported editor.
- Existing scan, scope, focus, navigation, synchronization, graph-hidden operation, and exporter contracts regress unchanged.

## Visual evidence

The Asset Library upload set contains:

- `thumbnail.webp`: informational title card embedding the real default overview;
- `featured-01-default-overview.webp`: default dock with a small readable structure;
- `featured-02-maximum-information.webp`: the same structure with all supported information categories enabled;
- `featured-03-complex-project.webp`: zoomed-out complex project graph in the dock;
- `featured-04-editor-navigation.webp`: selected graph member with the actual Script Editor destination;
- `featured-05-export-workflow.webp`: graph-hidden export and synchronization workflow;
- `featured-06-scoped-context.webp`: selected scan root with retained outside context;
- `featured-07-search-and-focus.webp`: member search and focused graph result.

`docs/INTERFACE_GALLERY.md` contains the per-tab documentation set. These images establish rendered state and feature visibility; they do not prove unfamiliar-user comprehension or accessibility conformance.

## Tool qualification

Godot parser/import and runtime execution are authoritative for GDScript behavior. Optional `gdlint`/`gdformat` checks are reported as skipped when unavailable; no pass is claimed. Pillow is used only to transform approved real captures into constrained WebP upload assets and to compose the thumbnail around a real screenshot.

Build and patch validation verifies deterministic archives, SHA-256 manifests, ZIP integrity, exclusion of generated `.import`/`.uid` sidecars, and reconstruction from the exact v0.2.3 baseline.

## Completion rule

A release archive alone is insufficient. Completion requires all claimed compatibility gates, media-contract validation, deterministic build evidence, archive/manifest verification, patch reconstruction, synchronized code/design/store copy/AI notice/media, and explicit residual limitations.
