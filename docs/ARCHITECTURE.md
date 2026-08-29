# Architecture

Version: 0.3.0

## Boundaries

The add-on separates acquisition, recognition, model construction, scoped projection, validation, presentation queries, rendering, and export. A selected folder changes the displayed/exported snapshot but does not narrow the full bounded acquisition index needed to resolve outside ancestors and dependencies.

## Components

| Component | Responsibility | Must not do |
|---|---|---|
| `ProjectScanner` | Validate project roots; enumerate bounded project files; acquire source; resolve autoload/base inputs from source/project metadata/ClassDB | Load or execute analyzed project GDScript, instantiate user classes, or treat a selected display scope as a trust boundary |
| `GDScriptAnalyzer` | Recognize the supported declaration/dependency subset and source locations | Claim general AST, call-graph, or runtime inference |
| `SceneUsageScanner` | Record exact direct text-scene node script attachments | Parse binary scenes or infer transitive resource graphs |
| `GraphBuilder` | Build deterministic snapshot-v2 nodes, edges, native chains, and provenance | Apply display scope or mutate data for layout |
| `SnapshotScope` | Project full snapshot to selected folder and required context | Change relationship kinds or invent missing context |
| `SnapshotValidator` | Enforce structural, referential, scene, source-location, and scope invariants | Repair invalid public data silently |
| `GraphQuery` | Compute descendants, inheritance focus, and bounded neighborhoods | Mutate the snapshot or own UI state |
| `DependencyDock` | Coordinate controls, fold/graph state, scans, synchronization, optional rendering, and export | Reimplement source recognition or exporter semantics |
| Export service/exporters | Validate and serialize the same snapshot; staged file replacement | Mutate the snapshot or hide format limitations |

## Data flow

```text
res:// bounded index
  ├─ GDScript analysis
  └─ text-scene attachment evidence
          ↓
    full snapshot v2
          ↓ SnapshotScope(selected root)
    scoped snapshot v2
       ├─ SnapshotValidator → JSON/Mermaid/PlantUML
       ├─ GraphQuery → focus/isolation state
       └─ optional renderer/search/navigation
```

## State and invariants

- Canonical edge direction is dependent → dependency.
- Rendered GraphEdit direction may reverse for layout only.
- Scope projection is deterministic and deep-copies input.
- Presentation queries return ID sets/counts only.
- Editor state is project-local under `.godot`, schema-versioned (v4), and excluded from releases.
- Graph rendering is optional; exporters consume validated snapshots and never GraphNode state.
- Scans and export sequences are synchronous and non-overlapping; one pending refresh is coalesced.

## v0.3.0 trust-boundary refinement

ADR 0009 narrows ADR 0002: dependency discovery no longer loads analyzed project scripts as `Script` resources. Required add-on implementation scripts remain checked plugin-internal dependencies. Candidate scoped snapshots are structurally validated before they become the accepted snapshot or trigger automatic export.
