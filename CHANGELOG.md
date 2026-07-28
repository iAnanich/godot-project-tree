# Changelog

This project follows semantic versioning while the public schema and add-on behavior evolve. Dates refer to completed project revisions, not marketplace publication.

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
