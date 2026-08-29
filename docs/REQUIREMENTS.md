# Script Dependency Inspector — product requirements

Artifact identity: `script-dependency-inspector-product-requirements`
Version: `0.2.1-alpha.1`
Release state at issue: Accepted for v0.3.1 implementation
Issue date: 2026-08-29


Status: accepted implementation requirements for v0.3.1; release-specific verification remains separate
Basis: the 2026-08-26 requirements/design revision plus the adopted Software Quality Guidelines v0.3.0-alpha.3
Implementation conformance: assessed against the synchronized v0.3.0 handoff baseline and the resulting v0.3.1 source; release-specific verification evidence is retained outside this substantive requirements artifact

## 1. Purpose and document role

This document is the normative product-behavior contract for Script Dependency Inspector. It states what the editor add-on must do, what it must not claim, and what evidence is required to accept a behavior change.

This document does not define repository packaging, GitHub release automation, Asset Library media, AI disclosure, or patch production. Those obligations belong to `RELEASE-REQUIREMENTS.md`.

Design mechanisms belong to `DESIGN.md` unless the mechanism is itself required for compatibility, safety, or observable behavior.

## 2. Normative terms

- **must**: required behavior or condition.
- **must not**: prohibited behavior or condition.
- **should**: recommended default; a justified deviation can be acceptable.
- **may**: permitted behavior.
- **can**: capability or possibility, not permission.

## 3. Terminology

| Preferred term | Definition | Important distinction |
|---|---|---|
| **full acquisition root** | The project-local root used to acquire the bounded source index. The current product contract uses `res://`. | This is not the same as the selected display/export scope. |
| **selected scope** | The project-local folder whose scripts form the primary displayed/exported subset. | The selected scope is a projection boundary, not a filesystem-read security boundary. |
| **full snapshot** | The deterministic canonical snapshot built from the bounded full acquisition index before scope projection. | It can contain scripts outside the selected scope. |
| **scoped snapshot** | A projection of the full snapshot that retains in-scope nodes plus required explanatory context. | It preserves canonical relationship semantics. |
| **context node** | A node outside the selected scope that is retained because it explains an in-scope inheritance or direct dependency relationship. | It must be identified textually, not only by color or opacity. |
| **supported static evidence** | A source construct the analyzer is designed to recognize deterministically. | Absence of supported evidence does not prove absence of a runtime dependency. |
| **structural snapshot validation** | Runtime verification that the snapshot satisfies schema and cross-record invariants before public serialization. | This is not the same as product validation for intended use. |
| **diagnostic** | A structured warning or error record about acquisition, recognition, projection, validation, navigation, or export. | A diagnostic does not automatically imply that the entire scan failed. |
| **current snapshot** | The latest structurally valid snapshot accepted from the latest successful scan. | The fate of an older valid snapshot after a later fatal scan is `OPEN-001`. |
| **graph view** | The optional in-editor GraphEdit presentation of the current scoped snapshot. | Graph state is presentation state and must not be an exporter data source. |
| **editor synchronization** | Debounced rescanning in response to saved project filesystem changes reported by the Godot Editor. | It does not analyze unsaved editor-buffer content. |
| **timed rescan** | A completion-based periodic rescan trigger. | It is independent from editor synchronization and is disabled by default. |

## 4. Product boundary and actors

### 4.1 Primary actor

The primary actor is a Godot developer who wants to inspect or export supported static GDScript structure without executing analyzed project classes.

### 4.2 Supporting systems

- Godot Editor supplies project files, project metadata, filesystem-change events, active-script context, and navigation services.
- `ClassDB` supplies native class information.
- Third-party tools may consume JSON, Mermaid, or PlantUML exports.

### 4.3 Inputs

The product can consume:

- project-local `.gd` files;
- optional project-local text `.tscn` files for supported scene attachment evidence;
- project global-class and autoload metadata;
- user-selected scan/display settings;
- graph presentation settings;
- synchronization settings;
- export format and path settings;
- project-local editor state.

### 4.4 Outputs

The product can produce:

- a deterministic canonical snapshot;
- a selected-scope projection of that snapshot;
- structured diagnostics;
- an optional interactive graph;
- JSON, Mermaid, and PlantUML files;
- project-local editor preference state.

## 5. Acquisition and scan-root requirements

### REQ-SCAN-001 — Default acquisition and scope

The full acquisition root must be `res://`. The selected scope must default to `res://`.

**Acceptance evidence:** a fresh project state scans the full project and reports the selected scope as `res://`.

### REQ-SCAN-002 — Accepted selected-scope path forms

The selected-scope boundary must accept:

1. a canonical `res://` path; or
2. a native absolute path that resolves inside the current project.

A native absolute project-local path must be canonicalized to the equivalent `res://` path before persistence or display as the selected scope.

**Invalid behavior:** paths outside the project, `user://` paths, parent traversal that escapes the project, empty paths, and missing directories must be rejected.

**Acceptance evidence:** positive tests for both path forms and negative tests for each rejected class.

### REQ-SCAN-003 — Bounded acquisition

The scanner must enforce configured bounds for relevant file count, directory count, GDScript bytes, and text-scene bytes.

When a bound prevents further acquisition, the result must contain a diagnostic that identifies the affected bound or resource class.

### REQ-SCAN-004 — No analyzed project-script execution or resource loading

The analysis path must not instantiate scanned project classes or load analyzed project GDScript resources to discover or enrich relationships.

The scanner may use saved source text, project metadata, the project global-class registry, and `ClassDB`. The add-on may load its own required implementation scripts through checked plugin-internal dependency boundaries.

### REQ-SCAN-005 — Saved-files-only boundary

The analysis must use filesystem/project state that has been saved and made available to the scanner. The product must not claim to analyze unsaved Script Editor buffer changes.

User-facing synchronization documentation must state this limitation.

### REQ-SCAN-006 — Symbolic links

Project traversal must skip symbolic links by default unless a later explicit contract defines a safe alternative.

### REQ-SCAN-007 — Scene acquisition boundary

When text-scene analysis is enabled, `.tscn` acquisition must use separate size/failure controls from GDScript acquisition.

Binary `.scn` files must not be interpreted as equivalent text-scene evidence.

## 6. Static-analysis and canonical-model requirements

### REQ-MODEL-001 — Deterministic canonical snapshot

Equivalent accepted project inputs and equivalent scan options must produce the same canonical node/edge ordering and stable identifiers.

### REQ-MODEL-002 — Versioned public schema

The public snapshot must carry an explicit `schema_version`.

A required-field or semantic incompatibility must trigger an explicit schema-version decision. Additive fields may remain within the current schema version only when the compatibility contract permits them.

### REQ-MODEL-003 — Stable node identity

Project script node IDs must use stable project-local script identity. Native and unresolved/external nodes must use explicit stable identifiers that cannot collide with project script paths.

### REQ-MODEL-004 — Canonical relationship direction

Canonical relationship direction must be **dependent → dependency**.

A renderer may reverse visual connection direction only as a presentation mechanism. Exported canonical semantics must not change because of layout behavior.

### REQ-MODEL-005 — Supported relationship evidence

The analyzer must distinguish, at minimum, these supported evidence classes when present:

- script/native inheritance;
- literal `.gd` `load()`/`preload()` use;
- declared type use;
- direct class-qualified member use.

Relationship kinds must not be collapsed when the distinction is needed to explain why an edge exists.

### REQ-MODEL-006 — Conservative omission

The analyzer must not invent relationships for aliases, dependency injection, runtime-selected instances, reflection, virtual dispatch, arbitrary evaluated expressions, or dynamically assembled paths when supported static evidence cannot establish a unique relation.

The absence of an edge must mean only that the relation was not established by the supported evidence boundary.

### REQ-MODEL-007 — Declaration and occurrence provenance

When the analyzer claims an exact declaration or relationship occurrence, it should retain a one-based source line and column when available.

When an exact location is unavailable, the product must not fabricate one.

### REQ-MODEL-008 — Autoload context

When a project script is registered as an autoload, the snapshot must be able to expose the matching autoload name and singleton status.

Autoload status must not be conveyed by color alone.

### REQ-MODEL-009 — Exact text-scene attachment evidence

For supported text scenes, the scene scanner may record only direct external Script resources that are assigned to scene nodes by the recognized text form.

Each exact scene-usage record must identify the scene path, node path, script path, source location when available, and evidence kind.

The product must not infer binary-scene, dynamic-assignment, inherited-scene, instantiated-scene, or transitive-resource effects as if they were exact direct attachments.

### REQ-MODEL-010 — Model/presentation separation

Scope selection, search, graph focus, descendant emphasis, neighborhood isolation, color, layout, fold state, and graph visibility must not mutate canonical relationship semantics.

## 7. Scope projection requirements

### REQ-SCOPE-001 — Full-index resolution before projection

A selected scope must not narrow the bounded acquisition index required to resolve outside ancestors and direct dependency targets.

The product must state that selected scope controls display/export projection, not the set of project files the bounded resolver may read.

### REQ-SCOPE-002 — Required projected content

A scoped snapshot must retain:

1. scripts inside the selected scope;
2. complete visible inheritance ancestry required to explain retained scripts;
3. direct supported dependency targets of in-scope scripts; and
4. inheritance ancestry required to explain those direct dependency targets.

The projection must not recursively retain every dependency of every context node unless another retained node independently requires it.

### REQ-SCOPE-003 — Context classification

Every projected node must be classified as `in_scope` or `context`.

A context node must retain a stable explanatory reason such as selected ancestor, required dependency, or dependency ancestor.

### REQ-SCOPE-004 — Context decoding

Context status must be visible through text or another non-color-only cue in the interactive graph and supported diagram exports.

### REQ-SCOPE-005 — Deterministic non-mutating projection

Scope projection must be deterministic and must not mutate the full canonical snapshot.

## 8. Structural validation, completion, and partial-result requirements

### REQ-VALID-001 — Validate before public serialization

Every public export must consume a snapshot that has passed structural snapshot validation.

The validator must check schema requirements and material cross-record invariants, including references between nodes, edges, source locations, scene records, and scope metadata when present.

### REQ-VALID-002 — Completed scan with diagnostics

A scan may complete with warnings or non-fatal input errors when the remaining snapshot is structurally valid.

The UI and diagnostic output must distinguish this state from a fatal scan failure.

### REQ-VALID-003 — Fatal scan failure

Initialization failure, invalid selected-scope resolution that prevents the requested scan, or structural snapshot-validation failure must be reported as a failure. The product must not describe such a run as a successful current scan.

### REQ-VALID-004 — Export source state

Automatic export must run only from the structurally valid snapshot produced by the scan that triggered the automatic export sequence.

The product must not synthesize an export from renderer state.

### REQ-VALID-005 — Self-contained member provenance

A published snapshot must not retain a `source_member` or `target_member` reference to a member that was intentionally omitted from its endpoint node by the active content options.

When a member category is hidden, exact dependency evidence such as evidence kind and source occurrence may remain, but the omitted member reference must be removed rather than contradicting the endpoint node.

### OPEN-001 — Previous valid snapshot after fatal rescan

The current retrievable contract does not define the state of a previous valid snapshot after a later fatal scan.

**Recommended design for owner approval:** preserve the last valid snapshot for inspection, mark it stale with the failed-scan reason and last-success timestamp, do not run automatic exports from it, and do not present it as the current scan result.

Implementation must not begin on this behavior until the owner accepts or replaces this decision.

## 9. Graph and visualization requirements

### REQ-GRAPH-001 — Optional default-on graph

The graph view must be enabled by default and must be user-toggleable.

### REQ-GRAPH-002 — Export-only operation

When the graph is disabled, scans, structural validation, summary, diagnostics, synchronization, and manual/automatic export must remain available when their ordinary preconditions are satisfied.

### REQ-GRAPH-003 — Retained snapshot on graph hide/show

Disabling the graph must release presentation objects without discarding the latest valid scoped snapshot solely because graph rendering is hidden.

Re-enabling the graph must render the retained snapshot without forcing a new scan.

### REQ-GRAPH-004 — Layout has no semantic metric

Graph node position, geometric distance, and edge length must be treated as layout artifacts. The product must not imply that they represent quantitative dependency strength, runtime frequency, certainty, or importance.

### REQ-GRAPH-005 — Decodable relationship encodings

Each meaningful relationship kind and node role shown in the initial graph state must be decodable through labels, legend entries, line roles, symbols, or other visible cues.

Essential relationship meaning must not depend only on hover, pointer precision, color, or animation.

### REQ-GRAPH-006 — Color redundancy

Color may reinforce script kinds, inheritance families, relation kinds, focus, or context state, but color must not be the sole carrier of those meanings.

### REQ-GRAPH-007 — Graph accessibility boundary

The product must provide text-based summary/diagnostic/export routes that do not require interpretation of the graph alone.

Formal screen-reader certification remains outside the current acceptance claim unless a separate validation plan is approved and executed.

## 10. Search, focus, and navigation requirements

### REQ-QUERY-001 — Search

When graph view is enabled, search must be able to match supported class/display names, project paths, member names, autoload names, scene paths, and scene-node paths that are present in the current scoped snapshot.

Search must affect presentation only.

### REQ-QUERY-002 — Inheritance focus

Selecting a node may emphasize its ancestors and optional descendants. Direct and transitive descendant counts may be shown.

Focus must not change exported snapshot semantics.

### REQ-QUERY-003 — Neighborhood isolation

Neighborhood isolation may hide unrelated rendered nodes while retaining the selected node, required inheritance context, and defined direct dependency neighborhood.

Clearing isolation must restore the current scoped graph without rescanning.

### REQ-NAV-001 — Exact source navigation

When an exact source location is recorded, navigation must request that file and location from the Godot Editor.

When the location is unavailable or stale, navigation may open the source file without claiming exact positioning.

### REQ-NAV-002 — Active-script following

The product may follow the active Script Editor file and select the matching graph node. This behavior must be independently user-configurable and enabled by default under the current product intent.

When graph view is hidden, active-script following may become presentation-dormant without changing scan/export behavior.

## 11. Synchronization and scan-lifecycle requirements

### REQ-SYNC-001 — Default editor synchronization

Editor filesystem synchronization must be enabled by default.

It must respond to saved project filesystem changes reported through the supported Godot Editor interface.

### REQ-SYNC-002 — Debounce

Editor-change bursts must be debounced by a configurable quiet period so one burst does not start an unbounded number of scans.

### REQ-SYNC-003 — Non-overlap and pending work

A new scan must not start while another scan/export sequence is active.

If a qualifying editor change occurs while a scan is active, the system must retain at most one pending follow-up scan request for that synchronization source.

### REQ-SYNC-004 — Timed fallback

Timed rescanning must remain independent from editor synchronization and disabled by default.

When enabled, the timer interval must be measured from completion of the prior scan and enabled automatic-export sequence to initiation of the next timed scan.

### REQ-SYNC-005 — Self-generated filesystem events

Filesystem-event suppression used to avoid export loops must activate only when the add-on is expected to write a configured export into the project resource filesystem.

Suppression must be bounded. It must not create a general blind period after scans that perform no relevant write.

### REQ-SYNC-006 — Trigger visibility

The toolbar must identify whether automatic scanning is currently configured as editor synchronization, timed fallback, both, or manual-only.

Detailed timing semantics must be available through nearby explanatory text or tooltip.

## 12. Export requirements

### REQ-EXPORT-001 — Supported formats

The product must support manual export to:

- JSON;
- Mermaid;
- PlantUML.

### REQ-EXPORT-002 — Exact and representational formats

JSON must preserve the canonical public snapshot fields defined by the active schema and is the exact machine-readable export.

Mermaid and PlantUML are diagram representations. They may omit canonical evidence that the target syntax does not express. Documentation must not describe them as lossless substitutes for JSON.

### REQ-EXPORT-003 — Same-snapshot export

All formats generated from one completed scan must consume the same scoped snapshot semantics.

No exporter may mutate the snapshot for another exporter.

### REQ-EXPORT-004 — Independent automatic formats

Automatic export enablement must be independent for JSON, Mermaid, and PlantUML.

A failure in one automatic format must not prevent an attempt of another enabled format.

### REQ-EXPORT-005 — Manual destination memory

A successful manual export should update the remembered destination for that format.

Remembered paths must remain project-local editor state rather than release-controlled defaults.

### REQ-EXPORT-006 — Defaults and parent directories

Each format must have a deterministic default path. Missing destination parent directories may be created when possible.

A directory-creation failure must produce an explicit export failure rather than silently redirecting output.

### REQ-EXPORT-007 — Recoverable file replacement

When replacing an existing export, the writer must use a recoverable same-directory staged replacement strategy so a failed commit does not intentionally destroy the prior destination.

The export result must report whether the requested destination was written.

### REQ-EXPORT-008 — External-tool use

Product documentation may state that Mermaid, PlantUML, and JSON exports can be consumed by third-party tools for alternative layout, larger canvases, documentation, presentation, or machine processing.

The product must not claim that a third-party renderer preserves evidence that the exported format itself omitted.

## 13. Editor-state requirements

### REQ-STATE-001 — Project-local editor state

Per-developer scan scope, recent roots, graph visibility, fold state, synchronization settings, and export destinations must be stored as editor-local project state rather than distributed project configuration.

### REQ-STATE-002 — Versioned state

Editor state must carry a schema version. Known historical schemas that remain supported must migrate or merge with current defaults deterministically.

Unknown fields should be ignored unless they conflict with a required invariant. Known fields must be type-checked.

### REQ-STATE-003 — Malformed-state recovery

Malformed or unsupported editor state must not prevent the add-on from loading when safe defaults can restore operation.

Fallback must produce a diagnostic when user intent may have been discarded.

## 14. UI organization and diagnostics requirements

### REQ-UI-001 — Toolbar task priority

The manual export format selector must use compact intrinsic width rather than consuming the toolbar's flexible remainder.

Scan and Export action groups must have visible separation.

### REQ-UI-002 — Graph visibility control

A visible Graph control must expose whether the graph presentation is enabled.

### REQ-UI-003 — Foldable semantic groups

Long control surfaces must use labelled semantic fold groups within the existing task-oriented tabs.

Fold state may persist project-locally and must not change canonical analysis semantics.

### REQ-UI-004 — Explanatory tooltips

Every interactive option and fold header must provide an explanatory tooltip or equivalent nearby explanation.

### REQ-UI-005 — Connection-specific graph tooltips

Hovering sufficiently close to a rendered graph connection must expose relationship-specific information for that rendered connection, including relationship kind, canonical dependent and dependency, canonical versus layout-only rendered direction, and the number of exact evidence occurrences represented.

When member/source-location evidence exists, the tooltip should expose a bounded representative set without presenting static evidence as runtime frequency.

### REQ-UI-006 — Member evidence tooltips

A member row tooltip must preserve the full captured declaration or signature independently of compact visible-row settings. It must expose the declaration location when known and bounded static-evidence counts for incoming exact member references and outgoing dependency occurrences.

The UI must describe these counts as static source evidence, not runtime call/use counts.

### REQ-DIAG-001 — Structured diagnostics

Material scan/export problems must produce stable structured diagnostics with at least severity, code, human-readable message, and relevant context when safe to expose.

### REQ-DIAG-002 — Observable operation status

The UI must distinguish, at minimum:

- scanning/in progress;
- completed with a structurally valid snapshot;
- completed with diagnostics;
- initialization or fatal scan failure;
- per-format export failure.

The UI must not report success before the corresponding operation has reached its defined completion state.

### REQ-DIAG-003 — Actionable snapshot-validation failure

When structural snapshot validation rejects a selected-root result, the immediate status must identify the first stable validator issue code and selected scan root. The Log must retain each issue message, stable code, selected root, issue index, and available bounded structured context.

A generic `snapshot validator failed` message without the stable issue identity is insufficient.

## 15. Security and trust-boundary requirements

### REQ-SEC-001 — No analysis-triggered project execution

Project source must be treated as untrusted analysis input. Dependency discovery must not execute analyzed project GDScript, including static initializers triggered by loading a script resource. Source text must not redefine scan policy, export destinations, permissions, or other control flow except through explicitly parsed data fields defined by the product.

### REQ-SEC-002 — No network requirement

Core scan, graph, and export behavior must not require network access.

### REQ-SEC-003 — No external-process requirement

Core analysis must not require execution of external processes.

Third-party rendering of exported files is outside the add-on's runtime trust boundary.

### REQ-SEC-004 — Selected scope is not a sandbox

The product must not present selected scope as a privacy or security sandbox. Full bounded project acquisition can read outside the selected scope to resolve required context.

## 16. Compatibility requirements

### REQ-COMPAT-001 — Supported Godot range

The current compatibility claim is Godot 4.3, 4.4.1, 4.5.2, 4.6.3, and 4.7 on the supplied Linux editor executables.

A release must not broaden this claim without direct compatibility evidence for the added environment.

### REQ-COMPAT-002 — Public snapshot compatibility

Consumers must be able to branch on `schema_version`.

A schema-breaking change requires explicit migration/compatibility documentation and a version decision before implementation.

### REQ-COMPAT-003 — Editor-state compatibility

Editor preference schema changes must define which earlier state versions are accepted and what fallback occurs for unsupported or malformed state.

## 17. Performance and resource requirements

### REQ-PERF-001 — Bounded synchronous work

Scanning and graph construction may remain synchronous in the current product, but the work must remain bounded by explicit acquisition limits and reproducible regression fixtures.

### REQ-PERF-002 — Scope does not imply lower scan cost

Selecting a narrower display/export scope must not be documented as a guarantee of lower acquisition cost while the full bounded index is still required for context resolution.

### REQ-PERF-003 — No unsupported latency SLA

Synthetic performance thresholds may be used as regression gates. They must not be presented as universal user-project latency guarantees without representative workload evidence and an owner-approved threshold.

## 18. Product quality contract

`QUALITY-CONTRACT.md` defines the selected quality characteristics, quality scenarios, acceptance methods, evidence limits, exception authority, and unverified areas for this product.

The quality contract is normative for release acceptance where it maps to a `REQ-*` or `REL-*` obligation. A quality scenario is not a verification result. Release-specific results belong in delivery evidence.

The product requirements remain the authority for observable runtime behavior. `QUALITY-CONTRACT.md` must not invent runtime behavior that is absent from this document.

## 19. Explicit non-goals

Unless a later owner decision changes scope, the product must not claim:

- complete compiler AST coverage;
- a general inferred call graph;
- runtime profiling;
- receiver inference through aliases, dependency injection, reflection, virtual dispatch, or dynamic paths;
- complete resource-graph analysis;
- binary `.scn` interpretation as direct text-scene evidence;
- TODO/FIXME/HACK task extraction;
- immediate main-screen editor placement;
- background or cancellable scanning;
- formal accessibility certification;
- unfamiliar-user comprehension validation;
- automatic correctness judgments about signal use or override behavior before that feature set is separately approved.

## 20. Deferred feature work

The previously discussed signal-emission and override/`super()` evidence work remains deferred. The owner explicitly paused that planned feature set in favor of other improvements.

A future release may reconsider it only through a new contract/design decision with explicit evidence boundaries and test oracles.

## 21. Open decisions

| ID | Decision | Why material | Required owner action |
|---|---|---|---|
| OPEN-001 | State and export behavior of the previous valid snapshot after a later fatal rescan | A stale snapshot can mislead; discarding it removes useful context | Accept the recommended stale-state design or select another behavior before implementation |

No other new material product decision is introduced by this documentation revision.
