# Script Dependency Inspector — requirements traceability

Artifact identity: `script-dependency-inspector-traceability`
Version: `0.2.1-alpha.1`
Release state at issue: Accepted for v0.3.1 implementation
Issue date: 2026-08-29


Status: proposed successor traceability baseline
Purpose: connect user outcomes, product requirements, design boundaries, and required evidence without treating planned checks as completed verification

## 1. Traceability rules

1. Use cases describe user outcomes and workflow boundaries.
2. `REQ-*` entries define product behavior.
3. `REL-*` entries define repository/release behavior.
4. `DESIGN.md` selects architecture and mechanisms.
5. Tests, checks, rendered reviews, and compatibility runs produce verification evidence.
6. A diagram is a navigation aid. It is not verification evidence.
7. A prior release result does not verify a later release after material code, configuration, documentation, schema, renderer, or environment changes.

## 2. Product use-case mapping

| Use case | User outcome | Primary requirements | Primary design boundary | Minimum required evidence |
|---|---|---|---|---|
| UC-01 Build a dependency snapshot | Deterministic structurally valid snapshot from bounded project source | `REQ-SCAN-003..007`, `REQ-MODEL-001..010`, `REQ-VALID-001..003` | `ProjectScanner`, analyzers, `GraphBuilder`, `SnapshotValidator` | scanner/analyzer/builder fixtures; malformed/boundary tests; structural-validation tests |
| UC-02 Restrict displayed project scope | Selected folder plus labelled explanatory outside context | `REQ-SCAN-001..002`, `REQ-SCOPE-001..005`, `REQ-SEC-004` | root canonicalization, `SnapshotScope` | resource-path and native-path tests; outside-project rejection; projection/context tests |
| UC-03 Inspect inheritance and dependencies | Relationship kinds and member provenance can be distinguished | `REQ-MODEL-004..009`, `REQ-GRAPH-005..006` | `GDScriptAnalyzer`, `GraphBuilder`, renderer | positive/negative static-evidence fixtures; rendered relationship decoding review |
| UC-04 Focus an inheritance path | Ancestors/optional descendants are emphasized without semantic mutation | `REQ-QUERY-002`, `REQ-MODEL-010` | `GraphQuery` | pure query tests; rendered focus state |
| UC-05 Isolate a relationship neighborhood | Unrelated nodes can be hidden without rescanning or export mutation | `REQ-QUERY-003`, `REQ-MODEL-010` | `GraphQuery`, renderer | neighborhood tests; clear/restore behavior |
| UC-06 Find a class or member | Search locates supported snapshot names/paths/members/context | `REQ-QUERY-001` | search index over accepted snapshot | search fixtures including empty query and no-match state |
| UC-07 Navigate to source or scene | Exact evidence opens exact location where available, safe fallback otherwise | `REQ-MODEL-007`, `REQ-NAV-001`, `REQ-MODEL-009` | navigation adapter | exact-location test; stale/missing-location fallback test; editor integration capture |
| UC-08 Follow editor activity | Saved changes trigger debounced non-overlapping scans; active script can focus graph | `REQ-SCAN-005`, `REQ-SYNC-001..006`, `REQ-NAV-002` | synchronization coordinator, editor adapter | debounce/non-overlap/pending tests; editor event integration; unsaved-buffer limitation documented |
| UC-09 Inspect editor context | Autoload identity and exact text-scene attachments are available | `REQ-MODEL-008..009` | autoload resolver, `SceneUsageScanner` | autoload fixtures; text-scene direct attachment positive/negative tests |
| UC-10 Export architecture evidence | JSON/Mermaid/PlantUML derive from one accepted snapshot | `REQ-VALID-001`, `REQ-EXPORT-001..003`, `REQ-EXPORT-006..008` | `ExportService`, format exporters | export fixtures; schema checks; format-capability checks; third-party message consistency |
| UC-11 Keep exports synchronized | Enabled formats update independently after completed scan | `REQ-SYNC-003..005`, `REQ-EXPORT-004..007` | scan lifecycle, export sequence | automatic-export matrix; one-format failure; self-event suppression; replacement-failure test |
| UC-12 Operate in export-only mode | Graph can be hidden while scan/summary/diagnostics/export remain | `REQ-GRAPH-001..003`, `REQ-EXPORT-*`, `REQ-DIAG-*` | graph visibility lifecycle | graph-off retention; export while hidden; graph-on rerender without rescan |
| UC-13 Configure controls efficiently | Compact action layout, trigger visibility, foldable controls | `REQ-UI-001..004`, `REQ-SYNC-006`, `REQ-STATE-*` | dock information architecture/editor state | scene/UI contracts; state round trip; tooltip presence; rendered review |

## 3. Cross-cutting quality mapping

| Quality claim | Requirements | Evidence class | Important limitation |
|---|---|---|---|
| Project source is not executed for dependency discovery | `REQ-SCAN-004`, `REQ-SEC-001` | code review plus behavior/security fixture | Godot may still parse/load Script resources as documented; this is not project-class instantiation |
| Scope is not a read sandbox | `REQ-SCOPE-001`, `REQ-SEC-004` | root/scope tests plus documentation check | selecting a folder can still require reading other project files |
| Graph is not a quantitative dependency-strength visualization | `REQ-GRAPH-004..007` | rendered review plus legend/static contracts | layout changes across Godot or external renderers are presentation changes |
| Compatibility with claimed Godot versions | `REQ-COMPAT-001..003` | isolated per-engine execution | evidence does not generalize to untested OS/version combinations |
| Performance remains bounded | `REQ-PERF-001..003` | configured-bound tests and fresh regression benchmark | synthetic budgets are not universal project latency SLAs |
| Exports do not silently destroy prior destination on failed replacement | `REQ-EXPORT-007` | failure-injection filesystem test | underlying filesystem guarantees remain platform-dependent |

## 4. Product requirement to component index

| Requirement family | Primary components/documents |
|---|---|
| `REQ-SCAN-*` | `ProjectScanner`, settings, editor root selector |
| `REQ-MODEL-*` | `GDScriptAnalyzer`, `SceneUsageScanner`, `GraphBuilder`, snapshot schema |
| `REQ-SCOPE-*` | `SnapshotScope`, scope metadata/labels |
| `REQ-VALID-*` | `SnapshotValidator`, operation-status layer |
| `REQ-GRAPH-*` | renderer, legend, graph visibility lifecycle, summary/export alternatives |
| `REQ-QUERY-*` | `GraphQuery`, search/presentation controller |
| `REQ-NAV-*` | Godot Editor navigation adapter |
| `REQ-SYNC-*` | `DependencyDock` scan coordinator, timers, filesystem-event adapter |
| `REQ-EXPORT-*` | `ExportService`, JSON/Mermaid/PlantUML exporters |
| `REQ-STATE-*` | editor-state store and defaults |
| `REQ-UI-*` | dock scene/controller |
| `REQ-DIAG-*` | logger/status/operation result models |
| `REQ-SEC-*` | scanner/export boundaries, security documentation |
| `REQ-COMPAT-*` | capability checks, compatibility harness |
| `REQ-PERF-*` | acquisition limits, performance fixture/harness |

## 5. Release/repository requirement mapping

| Requirement family | Responsible artifact/tool | Required evidence |
|---|---|---|
| `REL-REPO-*` | repository layout, ADR/NOTICE policy | repository inventory/static check |
| `REL-AI-*` | `AI_USAGE_NOTICE.md`, Asset Library copy | documentation consistency review |
| `REL-DEV-*` | `requirements-dev.txt`, pre-commit config, CI | local/CI command execution where available; version check |
| `REL-PKG-*` | package/release builder | clean build, archive inventory, extraction and manifest checks |
| `REL-PATCH-*` | patch builder | apply to exact baseline and compare resulting Git tree |
| `REL-GH-*` | GitHub Actions release workflow | workflow syntax/static review and an actual tag run before claiming hosted success |
| `REL-MEDIA-*` | `docs/asset_store`, media build/validation scripts | final-file dimension/size/format checks plus rendered review |
| `REL-STORE-*` | Asset Library description | source-analysis/compatibility/export-message consistency check |
| `REL-VERIFY-*` | validation harness and release evidence | fresh release-specific execution with environment and limitation record |

| `REQ-VALID-005` | filtered endpoint-member provenance | UC-01, UC-02, UC-16 | `GraphBuilder`, `SnapshotValidator` | hidden-member selected-root regression; baseline sensitivity demonstration |
| `REQ-UI-005` | connection-specific evidence tooltip | UC-14 | `DependencyGraphEdit`, dock rendered-edge evidence registry | connection evidence aggregation/tooltip behavioral test; rendered inspection |
| `REQ-UI-006` | full member/evidence tooltip | UC-15 | `DependencyGraphNode`, dock member evidence index | compact-row/full-tooltip behavioral test |
| `REQ-DIAG-003` | actionable validator rejection | UC-16 | dock validation/status/Log rendering | stable code/root/context UI log test |
| `REL-PKG-006` | MIT license consistency | release/package surfaces | root/add-on licenses, current notices/store copy | static license consistency; packaged add-on inspection |

## 6. Quality-scenario mapping

| Quality scenario | Primary requirements | Primary assessment |
|---|---|---|
| `QS-FS-01` deterministic supported analysis | `REQ-SCAN-*`, `REQ-MODEL-*`, `REQ-VALID-*` | contract-linked fixtures and structural-validation tests |
| `QS-REL-01` partial-result preservation | `REQ-VALID-*`, `REQ-DIAG-*` | failure-path tests with explicit partial/fatal outcomes |
| `QS-REL-02` export replacement recovery | `REQ-EXPORT-007` | filesystem failure injection and prior-file state check |
| `QS-COMP-01` claimed Godot compatibility | `REQ-COMPAT-*`, `REL-VERIFY-002` | isolated per-engine plugin and behavior runs |
| `QS-INT-01` graph meaning is decodable | `REQ-GRAPH-*`, `REQ-UI-*` | rendered review plus static semantic checks |
| `QS-PERF-01` bounded synchronous work | `REQ-PERF-*` | measured regression fixture with declared environment and budget |
| `QS-MAINT-01` change boundaries remain localizable | design boundaries plus `REL-VERIFY-003` | requirement-to-component review and targeted maintenance-task inspection |
| `QS-PKG-01` distributed add-on is usable | `REL-PKG-001`, `REL-PKG-005` | clean extracted-package smoke test |

## 7. Release-gate mapping

`RELEASE-GATES.md` defines the decision gates. Its gate IDs map to the release requirements and must be satisfied or explicitly excepted before a release is described as verified.

## 8. Requirement status model

Do not encode implementation status into the requirement text itself. Track status separately with one of:

- `planned`;
- `implemented_unverified`;
- `verified_for_release_<version>`;
- `conditionally_accepted`;
- `blocked`;
- `superseded`.

A status entry must identify the evidence artifact or run that supports it.

Release-specific verification status is recorded in external delivery evidence rather than in these durable requirements/design artifacts.

## 9. Open decision traceability

| Decision | Affected requirements | Affected use cases | Required evidence after approval |
|---|---|---|---|
| `OPEN-001` previous valid snapshot after fatal rescan | `REQ-VALID-003..004`, possibly `REQ-EXPORT-004`, `REQ-DIAG-002` | UC-01, UC-10, UC-11, UC-12 | lifecycle state tests; stale/current UI rendering; automatic-export negative test; manual-export policy test |
