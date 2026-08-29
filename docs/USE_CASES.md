# Script Dependency Inspector — user use cases

Artifact identity: `script-dependency-inspector-use-cases`
Version: `0.3.0-alpha.1`
Release state at issue: Accepted for v0.4.0 implementation
Issue date: 2026-08-29


Status: accepted user-outcome layer for v0.4.0 implementation
Authority role: intended use and workflow boundary; product obligations are normative only through referenced `REQ-*` requirements

Related acceptance model: `QUALITY-CONTRACT.md` and `RELEASE-GATES.md`.

## 1. Purpose

This catalogue describes what a Godot developer tries to accomplish with Script Dependency Inspector. It does not prove that users will discover, understand, or complete the workflows without assistance.

Use-case diagrams are navigation aids. The text catalogue is the authoritative alternative representation of the intended workflows.

## 2. Actors

- **Godot developer** — operates the add-on.
- **Godot Editor** — supplies saved filesystem events, active-script context, project metadata, and navigation services.
- **Diagram or documentation tool** — consumes Mermaid, PlantUML, or JSON outside Godot.
- **Documentation consumer** — reads or presents exported architecture evidence.

## 3. Use-case catalogue

| ID | Use case | Observable user outcome | Contract boundary | Primary requirements |
|---|---|---|---|---|
| UC-01 | Build a dependency snapshot | A deterministic structurally valid snapshot is available from bounded saved project source. Graph renders when enabled. | Invalid roots/fatal validation failures are not reported as success; unsupported runtime relations are not guessed. | `REQ-SCAN-*`, `REQ-MODEL-*`, `REQ-VALID-*` |
| UC-02 | Restrict the displayed project scope | The selected folder is shown/exported with required outside ancestors and direct dependency context labelled explicitly. | Full bounded acquisition can still read outside the selected scope. | `REQ-SCAN-002`, `REQ-SCOPE-*`, `REQ-SEC-004` |
| UC-03 | Inspect inheritance and dependencies | The developer can distinguish inheritance, literal script use, type use, and direct class-qualified member evidence. | Missing edges mean unsupported/unestablished static evidence, not proven runtime independence. | `REQ-MODEL-004..010`, `REQ-GRAPH-005..006` |
| UC-04 | Focus an inheritance path | Selecting a node emphasizes ancestry and optional descendants and can show descendant counts. | Focus changes presentation only. | `REQ-QUERY-002`, `REQ-MODEL-010` |
| UC-05 | Isolate a relationship neighborhood | The developer can hide unrelated rendered nodes around a selected relationship neighborhood. | Clearing isolation restores the scoped graph without rescanning. | `REQ-QUERY-003` |
| UC-06 | Find a class or member | Search finds supported class/path/member/autoload/scene values in the current scoped snapshot. | Search does not alter the snapshot or exports. | `REQ-QUERY-001` |
| UC-07 | Navigate to source or scene | Exact recorded evidence opens the corresponding source location when available. | Missing/stale exact locations use a safe fallback without an exact-position claim. | `REQ-MODEL-007`, `REQ-NAV-001`, `REQ-MODEL-009` |
| UC-08 | Follow saved editor activity | Saved project changes trigger one debounced non-overlapping scan by default; active Script Editor selection can focus the graph. | Unsaved buffer changes are not analyzed; timed rescan is independent and default-off. | `REQ-SCAN-005`, `REQ-SYNC-*`, `REQ-NAV-002` |
| UC-09 | Inspect editor context | Autoload identity and exact recognized text-scene node attachments are available. | Binary scenes and dynamic/transitive scene effects are excluded. | `REQ-MODEL-008..009` |
| UC-10 | Export architecture evidence | JSON, Mermaid, or PlantUML is written from the same accepted snapshot and can be consumed by external tools. | JSON is exact within the schema; diagram exports can be lossy. | `REQ-EXPORT-001..003`, `REQ-EXPORT-006..008` |
| UC-11 | Keep exports synchronized | Enabled formats are attempted independently after a completed scan. | One failed format does not block another; automatic export must not use an invalid scan result. | `REQ-SYNC-003..005`, `REQ-EXPORT-004..007` |
| UC-12 | Operate in export-only mode without the built-in graph | The developer hides GraphEdit while retaining scan, synchronization, summary, diagnostics, and exports. | Re-enabling Graph renders the retained accepted snapshot without a forced rescan. | `REQ-GRAPH-001..003` |
| UC-13 | Configure controls efficiently | The developer sees scan trigger mode and can fold semantic control groups. | Fold state and graph visibility are presentation/editor state; every interactive option remains explainable. | `REQ-UI-*`, `REQ-SYNC-006`, `REQ-STATE-*` |
| UC-14 | Inspect a graph connection on hover | Hovering a rendered line identifies the relationship, canonical dependent/dependency direction, layout-only reversed rendering, and represented static evidence occurrences. | Hover supplements visible relationship encoding; it does not make hover the only carrier of relationship kind/direction. | `REQ-UI-005`, `REQ-GRAPH-005..007`, `REQ-MODEL-004..007` |
| UC-15 | Inspect a member on hover | A compact member row exposes its full declaration/signature, exact declaration location, and incoming/outgoing static evidence counts. | Counts describe captured static evidence, not runtime call frequency. | `REQ-UI-006`, `REQ-MODEL-007`, `REQ-GRAPH-004` |
| UC-16 | Diagnose a rejected snapshot | A structural validation failure shows a stable issue code and selected root immediately, with bounded issue context in Log. | A rejected candidate is not accepted or automatically exported. | `REQ-VALID-003..006`, `REQ-DIAG-001..003` |
| UC-17 | Inspect the last valid snapshot after a failed rescan | The prior valid graph remains available with an explicit STALE marker, failed-scan reason, and last-success timestamp. | Stale data is inspection-only: it is not current and cannot be manually or automatically exported. | `REQ-VALID-003..006`, `REQ-EXPORT-004`, `REQ-DIAG-003` |

## 4. Cross-use-case limitations

- The add-on analyzes saved project source, not unsaved Script Editor buffers.
- The selected scope is a display/export projection, not a filesystem-read sandbox.
- Graph layout position and edge length do not encode dependency strength or runtime frequency.
- Missing static evidence does not prove missing runtime dependency.
- Mermaid and PlantUML are presentation exports and can omit canonical evidence that JSON preserves.
- Formal unfamiliar-user comprehension and accessibility certification are not established by these use cases or diagrams.

## 5. Resolved workflow decision

`RESOLVED-OPEN-001` adds UC-17 and refines UC-01, UC-10, UC-11, and UC-12: after a fatal rescan, the previous valid snapshot remains inspectable only as explicitly stale data until a successful rescan replaces it.
