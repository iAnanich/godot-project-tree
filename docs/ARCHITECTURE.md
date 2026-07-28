# Architecture

## Purpose and boundary

Script Dependency Inspector is an editor-only Godot 4 add-on. It turns a project-local set of GDScript source files into a deterministic, versioned dependency snapshot, then renders or exports that snapshot.

The add-on does not execute user objects, infer runtime call graphs, or modify scanned source. Optional reflection may load script resources to improve class resolution; see [SECURITY.md](SECURITY.md).

## System flow

```text
scan options + res:// root
        │
        ▼
ProjectScanner ── reads files, optional Script reflection, resolves direct bases
        │ ScanResult
        ▼
GraphBuilder ─── expands native chains, resolves dependencies, assigns families
        │ canonical snapshot (schema v1)
        ├──────────────► SnapshotValidator ── public serialization invariant
        │
        ├──────────────► DependencyDock / GraphEdit presentation
        │
        └──────────────► ExportService ── exporter capability contract
                               ├─ JSON
                               ├─ Mermaid
                               └─ PlantUML
```

## Responsibilities

### `core/project_scanner.gd`

- Validates that the scan root is project-local (`res://`).
- Enumerates bounded `.gd` inputs and excludes configured prefixes.
- Reads source without instantiating user scripts.
- Delegates source analysis.
- Optionally enriches resolution through Godot `Script` reflection.
- Resolves each script's direct base.
- Returns warnings, errors, and structured diagnostics rather than silently changing behavior.

The scanner does not build transitive native inheritance, merge graph edges, or decide presentation.

### `core/gdscript_analyzer.gd`

A lightweight deterministic source analyzer. It recognizes the subset needed by this product: `extends`, `class_name`, methods, signals, properties, inner classes, literal `.gd` loads, type annotations, and direct class-qualified member access.

It is not a GDScript compiler front end. Unsupported or dynamic syntax must degrade to omitted evidence, not invented relationships.

### `core/graph_builder.gd`

- Converts scanner records to the canonical snapshot.
- Creates stable node IDs and canonical edge direction: dependent/derived to dependency/base.
- Merges class-level edges and member provenance deterministically.
- Expands native bases from the running engine's `ClassDB`.
- Detects inheritance cycles and assigns inheritance families.

### `core/snapshot_validator.gd`

Protects the public serialization boundary. It rejects malformed schema versions, duplicate IDs or edges, dangling endpoints, invalid members, invalid diagnostics, and inconsistent member references. Unknown additive fields are allowed so schema-v1 extensions remain forward-compatible.

### `export/export_service.gd`

Owns exporter registration, capability discovery, snapshot validation, format selection, and recoverable file replacement. Exporters are interchangeable only through the documented contract and reusable contract suite.

### `ui/dependency_dock.gd`

Coordinates editor controls, scan/build invocations, graph filtering, rendering, export selection, visible legends, and the non-visual summary. It does not redefine canonical edge direction; it reverses rendered connections only where required by Godot's built-in arranger.

### `ui/dependency_graph_node.gd`

Owns one node's adaptive presentation, member rows, child-level tooltips, style accents, and member ports.

## Canonical invariants

1. `schema_version` identifies the serialization contract.
2. Node IDs are unique and stable for equivalent inputs.
3. Every edge endpoint exists in `nodes`.
4. At most one class-level edge exists for `(kind, source, target)`; detailed evidence is merged into `member_links`.
5. Canonical edges point from dependent/derived to dependency/base.
6. Nodes, edges, and member links are canonically ordered before export.
7. Exporters do not mutate the snapshot.
8. Invalid snapshots are not exported.
9. Fallback behavior is visible through warnings, errors, or structured diagnostics.

## Failure behavior

- Missing internal resources prevent the affected component from starting and report the exact `res://` path.
- An invalid scan root returns `invalid_scan_root` and performs no traversal.
- Unreadable or over-limit scripts are skipped with diagnostics; a missing root is an error.
- Unresolved bases are represented explicitly when enabled rather than guessed.
- Invalid exporter implementations are rejected at registration.
- Export writes use a same-directory temporary file and staged backup; failures use stable result codes and retain recovery context.

## Compatibility design

The implementation uses APIs available in the supplied Godot 4.3–4.7 binaries. Optional APIs are capability-checked in `core/compat.gd`. Compatibility claims are limited to executed platforms and versions in [COMPATIBILITY.md](COMPATIBILITY.md).

## Change boundaries and current debt

The scanner, analyzer, graph builder, and dock are explicit behavioral stages, but several implementation files remain large. They should be split only around demonstrated change boundaries with characterization tests; line count alone is not a valid reason. Current priority seams are:

- source tokenization versus declaration extraction in the analyzer;
- deterministic layout versus dock orchestration;
- filesystem traversal versus class resolution in the scanner.

The editor flow is synchronous. Bounded limits protect against accidental large scans, but responsive background scanning is a future design decision requiring lifecycle, cancellation, and thread-safety contracts.
