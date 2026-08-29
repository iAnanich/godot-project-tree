# Release roadmap

Status date: 2026-08-27

## v0.3.0 — source-only trust boundary and release assurance

Status: implementation complete; release verification remains blocked by unresolved required gates.

- Removed analyzed-project `Script` reflection from dependency discovery.
- Validate scoped snapshot candidates before acceptance and automatic export.
- Expose transitive initialization failures from scanner and graph-builder services.
- Add failure-injection coverage for export replacement recovery.
- Add fail-closed GDScript quality, packaged-add-on, archive, reproducibility, and patch reconstruction gates.
- Integrate requirements, quality contract, release gates, and traceability as durable repository knowledge.


## v0.2.4 — Asset Library media refresh

Delivered repository-owned, validated Asset Library media and real-runtime interface documentation without changing snapshot semantics.

## v0.2.3 — scope-path correction and release automation

Status: implemented.

- Normalize absolute native-dialog folder selections to canonical `res://` roots when they are inside the project.
- Reject absolute paths outside the project, `user://`, parent traversal, missing directories, and empty selections.
- Add deterministic add-on-only packaging and documented installation shape.
- Add pinned pre-commit `gdformat` and `gdlint` checks plus matching GitHub quality checks.
- Add tag-triggered GitHub Release packaging.
- Add verified binary-capable release patches generated from Git refs.
- Remove internal review documents and broad related-project survey material from the public source tree while preserving necessary narrow attribution.

## v0.2.2 — export-oriented UI and development disclosure

Status: implemented; validation evidence is recorded in `VALIDATION.md`.

- Compact manual export-format selector and separated Scan/Export action groups.
- Visible scan-mode indicator for save synchronization, timed fallback, both, or manual operation.
- Default-on Graph toggle and export-only workflow retaining snapshot, summaries, diagnostics, synchronization, and exports.
- Foldable semantic groupings across Content, Appearance, Colors, and Automation tabs.
- Editor-state schema v4 with graph visibility and fold-state persistence; migration from schemas 1–3.
- Expanded AI usage notice covering actual uses, owner direction/supervision, quality controls, and residual limits.
- Marketplace copy emphasizing third-party Mermaid/PlantUML/JSON workflows and summarizing AI-assisted development.
- UC-12 export-only and UC-13 control-configuration use cases with updated diagrams.

## Deferred product work

The previously proposed v0.3.0 signal-emission/override evidence is **on hold**. The next feature set will be defined from the owner's separate improvement list before version scope or schema impact is assigned.

## Deferred or explicit non-goals

- General inferred call graph.
- Immediate main-screen editor placement.
- TODO/FIXME/HACK extraction.
- Runtime profiling and dynamic-dispatch/DI/reflection inference.
- Background/cancellable scanning until a separate lifecycle and thread-safety design is approved.
