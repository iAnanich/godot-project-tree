# Release roadmap

Status date: 2026-07-29

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

## Next release

The previously proposed v0.3.0 signal-emission/override evidence is **on hold**. The next feature set will be defined from the owner's separate improvement list before version scope or schema impact is assigned.

## Deferred or explicit non-goals

- General inferred call graph.
- Immediate main-screen editor placement.
- TODO/FIXME/HACK extraction.
- Runtime profiling and dynamic-dispatch/DI/reflection inference.
- Background/cancellable scanning until a separate lifecycle and thread-safety design is approved.
