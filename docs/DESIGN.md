# Script Dependency Inspector — product design

Artifact identity: `script-dependency-inspector-product-design`
Version: `0.2.1-alpha.1`
Release state at issue: Accepted for v0.3.1 implementation
Issue date: 2026-08-29


Status: accepted implementation design for v0.3.1; release-specific verification remains separate
Requirements: `REQUIREMENTS.md`
Release process: `RELEASE-REQUIREMENTS.md`
Use-case layer: `USE_CASES.md`, with cross-artifact mapping in `TRACEABILITY.md`

## 1. Design objective

The add-on should separate evidence acquisition, static recognition, canonical model construction, scope projection, structural validation, presentation, and export so that each stage has a clear failure boundary and verification surface.

The design must preserve one central rule:

> Public graph and export semantics come from one structurally valid canonical snapshot, not from rendered GraphEdit state or unsupported inference.

## 2. System context

```text
Godot developer
    │
    ├─ controls, scan scope, export requests
    │
    ▼
DependencyDock ◄──────── Godot Editor events / active script
    │
    ├─ scan lifecycle and editor state
    │
    ▼
ProjectScanner ──► GDScriptAnalyzer
       │          SceneUsageScanner
       │                 │
       └─────────────────┘
                │
                ▼
           GraphBuilder
                │
                ▼
        full snapshot v2
                │
                ▼
          SnapshotScope
                │
                ▼
       scoped snapshot v2
                │
                ▼
       SnapshotValidator
          │           │
          │           ├────────► ExportService ─► JSON / Mermaid / PlantUML
          │           │
          └───────────► GraphQuery ─► optional GraphEdit / search / navigation
```

The selected scope is downstream of full bounded acquisition. It is not a filesystem sandbox.

## 3. Architecture boundaries

| Component | Responsibility | Inputs | Outputs | Must not do |
|---|---|---|---|---|
| `ProjectScanner` | Canonicalize/validate project-local roots; enumerate bounded project inputs; acquire source and project metadata | `res://`, scan options, project settings | acquired script/metadata records plus diagnostics | load or execute analyzed project GDScript; instantiate user classes; treat selected scope as a read-security boundary |
| `GDScriptAnalyzer` | Recognize supported declarations and static dependency evidence | script source | declarations, dependency evidence, source locations, diagnostics | claim complete AST/call-graph/runtime inference |
| `SceneUsageScanner` | Recognize exact direct text-scene node Script attachments | bounded `.tscn` text | scene-usage evidence plus diagnostics | parse binary scenes; infer dynamic/transitive resource graphs |
| `GraphBuilder` | Construct deterministic canonical nodes, edges, native chains, autoload/scene provenance | acquired analysis records | full snapshot v2 | apply display scope; apply graph layout; mutate evidence for presentation |
| `SnapshotScope` | Project the full snapshot to selected scope plus required context | full snapshot, canonical selected scope | scoped snapshot v2 | change edge kinds; infer extra dependencies; recurse without bound through context dependencies |
| `SnapshotValidator` | Perform structural snapshot validation | candidate scoped snapshot | accepted/rejected validation result | repair invalid public data silently |
| `GraphQuery` | Compute search/focus/isolation/descendant presentation sets | accepted scoped snapshot, query state | node/edge ID sets and counts | mutate canonical snapshot; own persistent editor state |
| `DependencyDock` | Coordinate UI, scan triggers, pending work, navigation, graph visibility, export sequence, editor state | controls and Godot Editor events | user-visible state transitions and delegated actions | duplicate analyzer/exporter semantics |
| `ExportService` | Validate format capability, create destinations, staged replace, invoke serializer | accepted scoped snapshot, format/options/path | explicit per-format result | consume GraphNode state; mutate canonical snapshot |
| format exporters | Serialize one accepted snapshot representation | accepted scoped snapshot | JSON/Mermaid/PlantUML text | silently add unsupported semantic evidence |

## 4. Accepted design decisions

The following decisions remain the design baseline unless a later ADR explicitly supersedes them.

| Decision | Status | Rationale | Review trigger |
|---|---|---|---|
| Versioned dictionary/array snapshot is the canonical boundary | accepted (ADR 0001) | deterministic JSON-compatible cross-version boundary | runtime validation/migration cost exceeds compatibility benefit |
| Static dependency discovery remains conservative and source-based and does not load analyzed project scripts | accepted (ADR 0002 as narrowed by ADR 0009) | avoid authoritative-looking guessed relationships and analysis-triggered project execution | a non-executing metadata/parser capability with equivalent evidence boundary becomes available |
| Per-project editor state lives below `.godot` with per-format export paths | accepted (ADR 0003) | keep developer workflow state out of distributed project config | stable Godot plugin-settings API or multi-destination requirements |
| Editor filesystem synchronization is default; timed rescan is default-off fallback | accepted (ADR 0004) | low unnecessary scan rate with explicit non-overlap | Godot event reliability changes or unsaved-buffer analysis is approved |
| Scene usage is a separate exact text-scene evidence stage | accepted (ADR 0005) | separate grammar/failure/size boundary | binary/resource graph support is approved |
| Scope is projection after full bounded acquisition; context is explicit | accepted (ADR 0006) | retain explanatory outside context without graph explosion | users need a true read sandbox or transitive context policy changes |
| Graph rendering is optional and controls use semantic folding | accepted (ADR 0007) | support export-only workflow and reduce dock clutter | GraphEdit is replaced or the control information architecture changes materially |
| Native project-local scope paths are canonicalized to `res://` | accepted (ADR 0008) | Godot folder dialogs can yield native absolute paths; product contract is project-local | Godot provides a stable resource-only folder selection contract across supported versions |
| Release/repository obligations are separated from runtime product requirements | accepted documentation architecture | different actors, failures, evidence, and change boundaries | separation creates duplicated or conflicting authority |
| Asset Library product screenshots are real runtime/editor captures | owner-approved release requirement | preserve truthful representation of graph/UI behavior | marketplace rules or media strategy changes |

## 5. Canonical evidence model

### 5.1 Snapshot roles

The model has two semantic stages:

1. **Full snapshot** — all accepted bounded project evidence needed for resolution.
2. **Scoped snapshot** — the user-selected projection plus required explanatory context.

Both stages retain canonical edge semantics. Scope projection changes membership and scope metadata, not relationship meaning.

### 5.2 Edge evidence

Each relationship must have an evidence kind. Member-level evidence may carry source and target member information plus an exact source occurrence when established.

Supported evidence remains:

- inheritance;
- literal script use;
- declared type use;
- direct class-qualified member use.

The design intentionally does not assign a numeric confidence score to these exact supported evidence kinds. A relation is either established by the recognized construct or omitted/diagnosed. If weaker inferred evidence is added later, it requires a separate evidence model and display contract.

### 5.3 Absence semantics

Missing edges are not negative evidence of runtime independence. User-facing documentation and exported schema notes must preserve this distinction.

### 5.4 Source locations

A claimed exact location uses one-based line/column semantics. Missing location means the analyzer does not claim exact navigation.

### 5.5 Filtered member provenance

`GraphBuilder` is responsible for making member provenance self-contained after content filtering. Before writing a member endpoint into `member_links`, it resolves that member against the already-filtered endpoint node. If the member category is hidden, the link retains its evidence kind and exact occurrence location but omits the invalid member reference. `SnapshotValidator` remains strict and does not repair this contradiction after the fact.

## 6. Scope projection design

### 6.1 Root canonicalization

The UI and public scanner boundary should normalize scan/scope input through one root-validation service.

Accepted input:

- canonical `res://...`; or
- native absolute path that `ProjectSettings.localize_path()` resolves inside the current project.

The normalized result is stored as `res://...`.

Rejected input includes:

- outside-project absolute paths;
- `user://`;
- unresolved/nonexistent directories;
- traversal that escapes the project;
- empty invalid input.

Root canonicalization belongs at the scanner boundary as well as the UI boundary so callers cannot bypass it accidentally.

### 6.2 Projection algorithm

Given selected scope `S`:

1. Mark project script nodes whose paths are inside `S` as in-scope.
2. Retain their complete resolved inheritance ancestry.
3. Retain direct supported dependency targets of in-scope scripts.
4. Retain inheritance ancestry needed to explain those direct dependency targets.
5. Mark every retained outside project node as context with a stable reason.
6. Omit unrelated outside project nodes.

Do not recursively retain dependencies of context nodes unless another retained in-scope relation independently requires them.

### 6.3 Trust implication

The scanner still reads the bounded full acquisition root. The selected scope is not privacy isolation. This fact must be visible in requirements and user documentation, not only in security notes.

## 7. Scan and synchronization state model

### 7.1 Current trigger model

Independent triggers:

- manual Scan;
- debounced saved-filesystem change;
- completion-based timed rescan when enabled;
- scan-affecting option change only if the approved UI contract explicitly triggers a rescan.

Presentation-only options must rerender/query without rescanning.

### 7.2 Operation states

Use separate scan-operation state and snapshot-validity state. This avoids treating "not currently scanning" as proof that current data are valid.

#### Scan operation state

```text
Idle
  ├─ manual/editor/timer trigger
  ▼
Scanning
  ├─ acquire and analyze
  ├─ build full snapshot
  ├─ project selected scope
  ├─ structural snapshot validation
  ▼
PostScan
  ├─ optional graph render
  ├─ enabled automatic exports
  ▼
Idle
```

A second scan must not start while `Scanning` or the associated automatic-export sequence is active. A qualifying editor event during that interval sets one pending follow-up flag.

#### Snapshot state

At minimum the design must distinguish:

- `none` — no structurally valid snapshot has been produced in this editor session;
- `current` — snapshot comes from the most recent successful scan;
- `current_with_diagnostics` — structurally valid snapshot contains non-fatal diagnostics.

`stale` remains proposed under `OPEN-001`.

### 7.3 Saved-files-only semantics

Filesystem synchronization follows saved/imported project state. It does not read unsaved Script Editor buffers. Active-script following is a navigation/presentation feature and does not change analyzed source content.

### 7.4 Self-generated export events

The dock may suppress filesystem events only around a known project-local export write that can feed back into editor-change notifications. The suppression window must be bounded and must not open after a scan that performs no qualifying write.

## 8. Failure and partial-result design

### 8.1 Failure classes

| Class | Example | Required outcome |
|---|---|---|
| Initialization failure | required internal script/scene cannot load | disable affected operations; identify missing component; no success claim |
| Root validation failure | selected path outside project or missing | reject requested scan/scope; retain clear user correction path |
| Non-fatal acquisition/recognition diagnostic | optional file unreadable; unsupported dynamic construct | retain structurally valid evidence that remains; diagnose omission |
| Structural snapshot validation failure | broken node/edge/scope/scene invariant | reject public serialization; no current-success claim |
| Navigation degradation | exact source location missing/stale | open source safely when possible; do not claim exact positioning |
| One-format export failure | directory/write/format failure | report format result; continue other enabled formats |
| Replacement commit failure | final file replacement fails | preserve/restore prior destination where possible; report final state |

### 8.2 Validator failure diagnostics

A rejected candidate remains rejected. The dock reports the first stable issue code and selected scan root in immediate status, then writes every validator issue to Log with its code, root, issue index, and a sorted bounded subset of structured context. Log rendering exposes structured context instead of discarding it.

### 8.2 Partial-result rule

A snapshot with diagnostics is publishable only when `SnapshotValidator` accepts its structural invariants. The validator is not a repair engine.

The status layer should state that diagnostics mean some evidence can be missing. It should not equate zero structural-validation errors with complete runtime dependency coverage.

### 8.3 Open stale-snapshot decision

`OPEN-001` remains unresolved.

Recommended behavior:

1. Keep the last structurally valid snapshot after a fatal new scan.
2. Mark it `stale` with the failure reason and last-successful-scan timestamp.
3. Allow inspection with a visible stale-state marker.
4. Do not start automatic exports from stale data.
5. Require a successful rescan before the snapshot returns to `current`.

Whether manual export should be disabled or require explicit confirmation is a secondary decision that should be made together with `OPEN-001`.

## 9. Graph visualization contract

The interactive graph is an exploratory structure view for Godot developers. It is not a quantitative network metric visualization.

### 9.1 Reader task

The graph should support these tasks:

- identify inheritance ancestry;
- identify supported dependency kinds;
- inspect class/member metadata;
- find a class/member/scene/autoload;
- focus on one inheritance/dependency neighborhood;
- navigate from evidence to source;
- distinguish in-scope nodes from retained context.

### 9.2 Semantic encodings

The initial graph state must make the following decodable without requiring hover:

- node identity;
- node role/kind when material;
- relationship kind;
- scope/context role;
- direction semantics where arrows/ports are visible.

Color may reinforce these roles but must not be the only cue.

### 9.3 Non-semantic layout dimensions

Graph position, Euclidean distance, route length, crossing count, and node area do not encode dependency strength or runtime frequency unless a later explicit feature defines such a metric.

Layout exists to improve readability and grouping only.

### 9.4 Interaction

Search, focus, isolation, zoom, arrange, and fold/overflow behavior should support named tasks. Interaction must not change the canonical snapshot.

Important meaning must remain available through labels, summary, diagnostics, or exports when the graph is hidden or too zoomed out for details.

Connection hover is implemented by a dedicated `GraphEdit` subclass. The dock registers canonical edge/member occurrence evidence against each rendered `from_node/from_port/to_node/to_port` connection. The subclass resolves the nearest connection at pointer position and formats a bounded tooltip. Duplicate canonical occurrences that collapse onto one rendered line are aggregated rather than replaced arbitrarily.

Member-row hover is built from canonical member declarations plus a dock-derived static evidence index keyed by endpoint member. Compact visible labels do not control tooltip detail; full stored signatures/declarations remain available even when the row displays only the member name.

### 9.5 External renderers

Mermaid and PlantUML may use different layout algorithms, themes, and canvases. Those renderings can improve presentation but cannot restore canonical fields that the diagram export omitted. JSON remains the exact machine-readable snapshot representation.

## 10. Graph visibility lifecycle

When Graph is disabled:

- release GraphNode/rendering objects;
- hide or disable graph-only search/focus/legend controls;
- retain the accepted scoped snapshot, summary, diagnostics, synchronization settings, and exporter capability;
- do not rescan solely because graph visibility changed.

When Graph is enabled:

- render the retained accepted snapshot if one exists;
- reapply applicable presentation state;
- do not force a rescan solely because graph visibility changed.

This behavior keeps export-only operation independent from the GraphEdit lifecycle.

## 11. Search, focus, and navigation design

### Search

Build an in-memory search index from the accepted scoped snapshot. Searchable values can include class/display names, script paths, members, autoload names, scene paths, and scene-node paths.

Search returns presentation matches only.

### Focus and isolation

`GraphQuery` computes IDs/counts over the accepted snapshot. It should remain a pure query component so focus behavior can be tested independently from Godot UI state.

### Navigation

Navigation uses recorded provenance:

- exact declaration/occurrence: open script at the recorded line/column;
- no exact location: open script without exact-position claim;
- scene usage: open the recorded scene or corresponding resource path when the editor API supports it.

The navigation service must treat stored locations as evidence that can become stale after project edits.

## 12. Export architecture

### 12.1 Common contract

Each exporter receives the same accepted scoped snapshot and format options. Exporters may transform presentation syntax but must not mutate shared input.

### 12.2 JSON

JSON is the exact public serialization of the canonical snapshot schema.

### 12.3 Mermaid and PlantUML

Diagram formats are intentionally representational. Each exporter should document capability limits such as member-endpoint support, color support, or metadata omission.

### 12.4 File commit

Export to file should use:

1. normalized destination path;
2. parent-directory creation when required and permitted;
3. same-directory temporary file;
4. backup of prior destination when required by the replacement strategy;
5. commit/rename;
6. rollback or preservation attempt on failure;
7. explicit result containing final destination state.

Do not treat a serializer success as proof that the destination file was committed.

## 13. Editor-state architecture

Editor state is project-local developer workflow state and is not release configuration.

It can contain:

- selected and recent scopes;
- editor-sync and timed-rescan settings;
- auto-export enablement and destinations;
- graph visibility;
- fold states;
- active-script-follow option;
- other presentation preferences approved by the product contract.

Editor-state schema must remain separate from public snapshot schema.

Unknown additive fields can be ignored. Known fields require type checks. Old supported schema versions merge/migrate into current defaults. Malformed state falls back with a diagnostic when intent is lost.

## 14. Security and trust boundaries

### Project source

Project `.gd` and `.tscn` content is untrusted input. The analyzer reads syntax/evidence. It must not execute embedded project behavior to infer dependencies.

### Filesystem

The add-on has the Godot editor process's filesystem permissions. Selected scope does not reduce those permissions. Export writes are restricted by explicit configured/requested destinations, not by a security sandbox.

### Network and external processes

Core analysis, graph, and export do not require network access or external processes. Third-party diagram tools are outside the add-on runtime boundary.

### Diagnostics

Consumer-facing diagnostics should identify operation, target, observed condition, resulting state, and safe next action when known. They should not expose secrets or unrelated sensitive content.

## 15. Performance design

The current synchronous design is acceptable only under explicit resource bounds and regression evidence.

- Full acquisition cost depends on accepted source bytes and project index size.
- Narrow selected scope does not imply narrow acquisition cost.
- Scope projection and graph queries operate in memory after scan.
- Descendant aggregation can become expensive on long inheritance chains and remains a measured optimization candidate.
- Synthetic timing gates are regression controls, not user-project SLAs.

Background work and cancellation require a separate lifecycle/thread-safety design and remain outside the current accepted architecture.

## 16. Compatibility design

The current supported execution evidence is bounded to the supplied Linux Godot 4.3, 4.4.1, 4.5.2, 4.6.3, and 4.7 editor builds.

Compatibility mechanisms should:

- prefer APIs present across the supported range;
- capability-check optional editor APIs;
- keep snapshot schema/version explicit;
- keep editor preference schema separate;
- test plugin initialization and behavior in isolated project copies per engine.

Do not infer compatibility with other operating systems or Godot versions from source similarity alone.

## 17. Knowledge and documentation boundaries

Product requirements, design, use cases, schema, ADRs, security, performance, setup, and release procedures are durable repository knowledge.

Routine review reports and generated critique are not design authority. Durable findings must be absorbed into requirements, design, ADRs, issues, or tests.

Release validation records are evidence for one release. They must not become an implicit requirement source for later releases.

`RELEASE-REQUIREMENTS.md` governs packaging, patches, Asset Library media, AI disclosure, CI, and repository-retention policy.

## 18. Verification design

Tests and checks should map to stable requirements through `TRACEABILITY.md`.

Evidence must be proportional to the claim:

- pure model transformations: focused deterministic tests;
- parser boundaries: positive, boundary, malformed, and unsupported cases;
- lifecycle/synchronization: deterministic state tests plus editor integration;
- file commits: failure injection and prior-file preservation checks;
- compatibility: per-engine execution;
- graph meaning: rendered artifact review plus static semantic checks;
- release media: final-file automated checks plus visual review.

A generated test that passes is not independent evidence by itself. Use executable behavior, primary Godot documentation, static tools, and owner/human review where each has a different failure mode.

## 19. Quality-assurance architecture

`QUALITY-CONTRACT.md` selects the quality characteristics that materially affect Script Dependency Inspector. `RELEASE-GATES.md` maps release claims to required evidence. These documents constrain acceptance; they do not replace runtime requirements.

### 19.1 Evidence separation

The implementation and release workflow keep these claims separate:

- a source-tree test completed;
- a packaged add-on initialized and performed representative behavior;
- a compatibility run passed on one claimed Godot version;
- all required release gates passed;
- a second controlled same-environment build repeated a specified archive;
- an independent operator or build service reproduced a specified archive;
- a checksum matched a final artifact.

No one claim implies the others.

### 19.2 Regression sensitivity

When a defect is corrected, the new regression test should be exercised against the faulty baseline before the fix when that baseline is available and safe to run. If the exact faulty baseline cannot be run, the verification record must state the alternate sensitivity method.

### 19.3 Packaged-artifact verification

The release workflow verifies the add-on from the redistributable ZIP in an isolated project. This path detects package-content, path, notice, and discovery failures that source-tree tests can miss.

### 19.4 Quality exceptions

A required release gate can be waived only by an explicit owner decision. The exception record identifies the missing evidence, lost guarantee, scope, rationale, and review trigger. The absence of a gate result is not converted into a pass.

## 20. Design decisions still open

### OPEN-001 — Prior snapshot after fatal rescan

See `REQUIREMENTS.md`. This is the only material product decision introduced by this review.

### Deferred, not currently open for implementation

- signal-emission evidence;
- override/`super()` evidence;
- background/cancellable scanning;
- general inferred call graph;
- main-screen editor placement.

These items require new owner scope before design work continues.
