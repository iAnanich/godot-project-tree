# Behavioral contract

Version: 0.2.4

## Inputs

- A selected project-local `res://` display scope, default `res://`.
- A bounded full-project index of `.gd` and optional text `.tscn` files.
- Project global-class and autoload settings.
- Content, display, synchronization, focus, graph-visibility, fold-state, and export settings.

## Outputs

- A deterministic snapshot-v2 dictionary projected to the selected display scope.
- An optional interactive graph derived from that snapshot.
- Optional validated JSON, Mermaid, or PlantUML files suitable for dedicated third-party tools.
- Structured diagnostics and explicit partial/failure status.

## Invariants

- Scanned project scripts are not instantiated to discover relationships.
- Stable node IDs are script paths or explicit native/external identifiers.
- Canonical edges point dependent → dependency; renderer reversal is presentation-only.
- Scope projection retains in-scope scripts, complete visible inheritance chains, direct dependency targets, and ancestry required to explain those targets.
- Every scoped node is labelled `in_scope` or `context`; context meaning is textual as well as visual.
- Scope, search, focus, descendant emphasis, neighborhood isolation, control folding, and graph visibility do not mutate canonical semantics.
- Hiding GraphEdit does not discard the latest validated snapshot, diagnostics, summary, or export capability.
- Re-enabling GraphEdit renders the current snapshot without forcing a rescan.
- The toolbar identifies active scan triggers as save sync, timed fallback, both, or manual.
- Timed rescanning is disabled by default; editor-change synchronization is enabled by default.
- Automatic exports consume the same completed snapshot and are attempted independently.
- Validation precedes every public serialization.


### Project-folder scope path normalization

The public scope boundary accepts either a `res://` directory or an absolute directory returned by a native `FileDialog`. An absolute selection is accepted only when `ProjectSettings.localize_path()` resolves it inside the current project; the stored, displayed, scanned, and exported root is the normalized `res://` form. Empty paths, `user://`, parent traversal, nonexistent directories, and absolute paths outside the project fail explicitly and do not replace the current scope.

## Failure behavior

- Invalid selected folders are rejected. Unavailable remembered folders fall back to `res://` with a warning.
- Invalid roots, unreadable required resources, invalid snapshots, and failed file commits are explicit failures.
- Unsupported static cases produce diagnostics or omissions, never guessed relationships.
- Navigation without an exact location opens a safe fallback where possible.
- A failed automatic export does not block other formats.
- Hiding the graph while no snapshot exists leaves export unavailable rather than exporting stale or invented data.

## Acceptance criteria

- The manual export format selector uses compact intrinsic width and does not consume the toolbar's flexible remainder.
- **Scan** and **Export** are visually separated; a visible adjacent indicator states the active automatic scan modes and exposes detailed timing in its tooltip.
- **Graph** is enabled by default and can be disabled for export-only operation while scans, summaries, diagnostics, synchronization, and file export remain functional.
- Re-enabling **Graph** renders the retained snapshot without another scan.
- Content, Appearance, Colors, and Automation controls use labelled foldable semantic groups whose expanded states persist project-locally.
- Every interactive option and fold header has an explanatory tooltip.
- Existing scope, focus, navigation, synchronization, scene/autoload context, and export contracts remain satisfied.
- The AI notice identifies uses, human direction, quality controls, and residual evidence limits; the store copy summarizes that disclosure.
- Store copy explicitly explains that Mermaid, PlantUML, and JSON files support larger-canvas or more presentation-oriented third-party workflows than the dock.
- All release gates pass under each claimed Godot version.

## Release media contract

- The repository contains the exact current Asset Library thumbnail and featured media.
- Final upload media is WebP, 16:9, at least 1280×720, no more than 600 KB, and targets 1920×1080.
- Featured graph/UI images derive from actual Godot-rendered states.
- The thumbnail may compose text and branding around a real screenshot; it must not substitute a fabricated graph.
- Each principal dock tab has a current documentation screenshot.
- Media files and their source scenarios are traceable through the manifest and capture notes.
