# Changelog

## 0.3.1 — 2026-08-29

### Fixed

- Filtered member categories no longer leave `member_links` that reference members omitted from their endpoint nodes. This fixes selected-root scans that could fail structural validation with `unknown_member_reference`.
- Snapshot-validation failures now identify the first stable issue code and selected root in the immediate status, while Log retains each issue message and bounded structured context.
- Restored the compact manual export selector width and removed accidentally captured IDE, Python-cache, and Godot `.import` state from the repository source surface.
- Local handoff checksum entries now use the actual ZIP member paths and the handoff builder verifies every checksum entry before reporting success.
- Release-archive verification now preserves tracked Godot `.uid` source sidecars while continuing to reject generated `.import` and Python-bytecode state.

### Added

- Connection-specific graph tooltips showing relationship type, canonical dependent/dependency direction, layout-only rendered direction, member/source evidence when available, and represented exact-occurrence counts.
- Member tooltips that preserve full signatures/declarations, exact declaration locations, incoming exact member-reference counts, outgoing dependency-occurrence counts, and explicit static-evidence terminology.
- Regression fixtures and behavioral checks for hidden-member selected-root validation, connection evidence tooltips, member evidence tooltips, and validator Log rendering.
- UC-14 connection inspection, UC-15 member inspection, and UC-16 rejected-snapshot diagnosis with updated requirements, design, traceability, and quality scenarios.

### Changed

- Project and packaged add-on licensing changed from Apache License 2.0 to the MIT License. Historical changelog statements remain historical.
- Tracked Godot `.uid` sidecars are treated as source artifacts; generated `.import` sidecars remain excluded.
- Asset Library copy now describes evidence-rich connection/member hover inspection and actionable validation diagnostics.
- Release documentation now distinguishes same-environment repeatability from independently demonstrated reproducibility.

### Compatibility

- Snapshot schema remains v2 and editor-state schema remains v4.
- `GraphEdit.get_closest_connection_at_point()` is used only after compatibility verification across the claimed Godot 4.3–4.7 matrix.
- `OPEN-001` remains unresolved; this release does not silently select a stale-snapshot policy.

## 0.3.0 — 2026-08-27

### Changed

- Dependency discovery is now source-only: analyzed project GDScript resources are not loaded for reflection. The legacy `use_runtime_reflection` setting remains readable but has no effect.
- Scoped snapshot candidates must pass structural validation before becoming the accepted snapshot, rendering, or triggering automatic exports.
- Scanner and graph-builder services expose transitive initialization failures consistently with the export service.
- Required `gdformat`/`gdlint` checks fail closed when tooling is unavailable; CI invokes the same pinned toolchain.
- GitHub tag automation builds a draft release candidate, performs a controlled second archive build, and does not imply the full runtime release matrix passed.
- Release manifests are generated inside project archives instead of mutating the repository root.

### Added

- Regression coverage showing dependency scanning does not execute a scanned static initializer.
- Failure-injection coverage showing a failed export replacement restores the previous destination.
- Verification tooling for the actual packaged add-on ZIP and release archive structure.
- Durable product requirements, release requirements, quality contract, release gates, and traceability documentation.
- ADR 0009 documenting the non-executing source-analysis boundary.

### Compatibility

- Snapshot schema remains v2 and editor-state schema remains v4.
- This MINOR increment is intentional during the `0.y.z` line because the legacy reflection behavior is no longer performed.
- Previously deferred signal/override/`super()` evidence features remain out of this release.


## 0.2.4 — 2026-08-04

- Added repository-owned Godot Asset Library thumbnail and seven focused featured WebP images at 1920×1080.
- Added real runtime capture scenarios for the default dock, maximum information, complex projects, exact editor navigation, export-only operation, scoped context, search, and every principal control tab.
- Added a small media-specific example project slice to avoid test/tool clutter in focused screenshots.
- Added reproducible capture, WebP build, manifest, media-validation tooling, and a deterministic Asset Library upload-media release archive.
- Added an interface gallery and release-owned media provenance notes.
- The thumbnail embeds a real runtime screenshot; no synthetic replacement graph or AI-generated diagram is used.

## 0.2.3 — 2026-08-02

### Fixed

- Folder selections returned as absolute paths by native `FileDialog` implementations are localized to canonical `res://` paths when they are inside the current project.
- The scope dialog now explicitly uses resource access; outside-project, traversal, `user://`, empty, and missing paths remain rejected.
- Release output directories are excluded from release-source enumeration, preventing stale `dist` artifacts from entering subsequent archives.

### Development and release tooling

- Added deterministic add-on-only packaging through `tools/package_addon.py`.
- Added pinned `gdformat`/`gdlint` pre-commit hooks and matching GitHub quality checks.
- Added tag-triggered GitHub Release packaging and upload workflow.
- Added verified binary-capable Git patch generation between release refs.
- Local patch generation now infers the nearest preceding release tag and defaults to `dist`, reducing the normal command to `python tools/build_patch.py`.
- Patch verification applies into the Git index and compares the reconstructed tree object, so added and deleted paths are validated as well as modified files.
- Added release setup, packaging, tagging, and patch-application instructions.

### Repository documentation policy

- Removed internal quality-review reports, rendered-review notes, and the broad related-project survey from the public repository. Product contracts, ADRs, use cases, schemas, validation evidence, and narrow required attribution remain.

## 0.2.2 — 2026-07-29

### Added

- Default-on **Graph** toggle supporting export-only operation while preserving scans, synchronization, summaries, diagnostics, and all file exports.
- Adjacent scan-mode indicator showing save synchronization, timed fallback, both, or manual operation.
- Foldable semantic groups across Content, Appearance, Colors, and Automation tabs.
- Editor-state schema v4 with persisted graph visibility and fold states, plus migration from schemas 1–3.
- UC-12 export-only and UC-13 control-configuration use cases with updated diagrams.
- Explicit AI development notice covering concrete uses, owner direction, quality controls, and residual evidence limits.

### Changed

- Manual export format selection now uses compact width; Scan and Export action groups have explicit spacing and separation.
- Store copy now explains how Mermaid, PlantUML, and JSON support third-party diagram, publication, and custom-rendering workflows beyond the constrained editor dock.
- Release construction now excludes generated Godot `.import` sidecars as well as `.uid` files, preventing editor-cache-dependent manifests.
- The previously proposed v0.3.0 behavioral-evidence work is on hold pending a separately approved improvement set.

### Compatibility

- Snapshot schema remains v2. Export semantics and static-analysis boundaries are unchanged.

## 0.2.1 — 2026-07-29

### Added

- Project-folder scope selector with recent valid roots and project-local path validation.
- Deterministic scoped projection over a bounded full-project index.
- Explicit `in_scope` and `context` node roles with retained ancestor/dependency reasons.
- Textual context labels in graph nodes, Mermaid, and PlantUML.
- Selected-node inheritance-path emphasis, optional descendant emphasis, direct/total descendant counts, and relationship-neighborhood isolation without rescanning.
- Editor-state schema v3 with migration from schemas 1 and 2.
- User use-case catalogue, three rendered use-case diagrams, text alternatives, traceability, and a rendered-review record.
- Pure `SnapshotScope` and `GraphQuery` seams with behavioral and negative validation tests.

### Fixed after v0.2.0 review

- Automatic-export filesystem-event suppression is no longer opened after scans that cannot write below `res://`.
- Display-only rerenders preserve the current graph viewport.
- Persisted state naming and messages now cover scope, focus, synchronization, timer, and export preferences rather than only automation.
- Missing remembered scope roots fall back to `res://` with a warning instead of blocking the initial scan.
- Scope roles and declared scope counts are cross-validated before serialization.
- Neighborhood isolation no longer includes inheritance descendants when **Include descendants** is disabled.
- Editor-state schema values are type-checked rather than coercing strings to integers.

### Scope decisions

- Folder scope is a display/export projection, not a trust or acquisition boundary; the full bounded project index is scanned to resolve retained context.
- TODO/FIXME/HACK extraction remains out of scope.
- General inferred call graphs and immediate main-screen placement remain non-goals.
- Project Mapper remains documented as a late consideration; selected-folder/context interaction is attributed specifically and no source code was copied.

## 0.2.0 — 2026-07-28

### Added

- Exact script, property, signal, method, and inner-class declaration locations with click-to-open actions.
- Exact dependency-occurrence locations on canonical member links, exposed as clickable **References** rows.
- Graph search, previous/next focus, nonmatch dimming, and active Script Editor following.
- Default-on debounced synchronization with editor filesystem changes.
- Autoload name/singleton metadata.
- Bounded exact `.tscn` node script-attachment scanning and scene navigation.
- Snapshot schema v2 and editor-state schema v2 with v1 state migration.
- Cross-record validation for duplicate, orphaned, mismatched, or missing scene-usage evidence.
- Roadmap, related-project provenance, and design decisions for refresh and scene evidence.

### Changed

- Timed rescanning is retained but disabled by default.
- JSON is documented as the lossless representation for source and scene evidence.
- Project Mapper is recorded as a late consideration for specific adopted interaction/context features; no source code was copied.

### Out of scope

- TODO extraction, general inferred call graphs, and immediate main-screen placement.

This project follows semantic versioning while the public schema and add-on behavior evolve. Dates refer to completed project revisions, not marketplace publication.

## 0.1.8 — 2026-07-28

### Added

- Optional one-shot auto-rescan with a project-customizable 60-second default. The delay begins after scan, render, and enabled automatic exports complete.
- Independent automatic JSON, Mermaid, and PlantUML exports with remembered per-format destinations and safe default paths.
- Project-local editor automation state below `res://.godot`, with type validation and recoverable replacement.
- Parent-directory creation for manual and automatic exports.
- Explanation tooltips for every option control in the dock.
- End-to-end automation test, tooltip contract, state round-trip test, and nested-export-directory regression.
- Canonical design document, Asset Library page copy, automation ADR, and an expanded feature screenshot set.

### Changed

- A successful manual export now becomes the remembered automatic-export destination for that format.
- Validation now runs a dedicated automatic-rescan/export gate in addition to public, export-matrix, showcase, and performance gates.
- Documentation is synchronized with the implemented automation lifecycle, persistence, failure behavior, and owner-approved accessibility scope.

### Quality review

- Applied the supplied software-quality guidance to automation state, observability, determinism, failure isolation, versioned knowledge, and release evidence.
- Background/cancellable scanning remains explicitly deferred rather than being introduced without a lifecycle and thread-safety contract.

## 0.1.7 — 2026-07-28

### Fixed

- Mermaid and PlantUML full-signature exports no longer emit arbitrary GDScript default expressions such as dictionary literals into diagram member syntax.
- Export destinations now replace an existing filename extension instead of appending a second extension.

### Added

- Self-scan export matrix covering JSON, Mermaid, and PlantUML across compact/full members, all relation categories, color modes, and the all-options-enabled regression case.
- Minimal editor icon, Apache License 2.0, NOTICE, and an extensive AI-assistance/provenance disclosure.
- Color-vision-resilient default palette and automated contrast/distinguishability checks.
- Reproducible human comprehension-test protocol and feature-focused visual-review states.

### Scope decisions

- Screen-reader and exhaustive keyboard evaluation are outside the current owner-approved acceptance scope.
- Background/cancellable editor scanning remains a deferred product feature rather than a 0.1.7 release requirement.

## 0.1.6 — 2026-07-28

### Added

- Runtime canonical-snapshot validation with stable issue codes.
- Explicit exporter capability declarations and reusable exporter contract tests.
- Structured export failure codes and validation before serialization.
- Project-local scan-root validation and default symbolic-link refusal.
- Visible graph legend, rendered-direction explanation, and non-visual summary tab.
- Keyboard-focusable script-path action that copies the complete `res://` path.
- Reproducible analyzer/graph performance gate.
- Deterministic repository-owned release builder with manifest and archive checksums.
- Architecture, schema, security, contribution, decision, performance, quality-review, test, and rendered visual-review documentation.
- Local API documentation for every public add-on method, protected by static validation.

### Changed

- Exporter registration now rejects malformed identifiers, extensions, and capability declarations.
- Snapshot diagnostics are preserved in canonical output as an additive schema-v1 field.
- Runtime snapshot validation is now type-strict and aligned with the published JSON Schema; semantic fields are never coerced and all schema-required node/edge collections are enforced.
- Static validation ignores editor-generated `.godot` state, keeping its evidence count deterministic between imported and clean projects.

### Compatibility

- The release remains additive at the schema and editor-workflow boundaries. Runtime verification is recorded in `docs/VALIDATION.md` and `docs/COMPATIBILITY.md`.

## 0.1.5 — 2026-07-27

- Added member-level provenance, GraphEdit member anchors, exact PlantUML member endpoints, and labeled Mermaid fallback relations.
- Revalidated Godot 4.3–4.7 compatibility.

## 0.1.4 — 2026-07-26

- Corrected built-in arrangement direction, class/path naming, adaptive node sizing, native inheritance-chain discovery, and inheritance-family accents.

## 0.1.3 — 2026-07-25

- Added compact/full member display, independent member colors, type-annotation dependencies, deterministic depth layout, and top-oriented dock controls.

## 0.1.2 — 2026-07-24

- Executed the project with Godot 4.7, corrected runtime parse/resource defects, and added showcase examples.

## 0.1.1 — 2026-07-23

- Replaced brittle internal preload chains with explicit checked runtime resource loading.

## 0.1.0 — 2026-07-22

- Initial scanner, graph builder, GraphEdit dock, and JSON/Mermaid/PlantUML exporters.
