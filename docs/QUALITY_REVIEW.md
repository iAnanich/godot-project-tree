# Quality review

- Review date: 2026-07-28
- Reviewed baseline: 0.1.5
- Remediated revision: 0.1.6
- Review scope: correctness, maintainability, public API/tool usability, compatibility, test evidence, performance, security, documentation, and graph visualization
- Evidence sources: supplied project/software guidelines, supplied software-quality guidance, supplied data-visualization guidance, source inspection, rendered editor artifacts, static validation, Godot runtime tests, cross-version execution, and package verification

## Outcome

Revision 0.1.6 is a materially stronger development release. It now has a validated serialization boundary, an explicit exporter extension contract, structured operational failures, bounded project-local scanning, a visible graph legend, a non-visual summary, a reproducible performance gate, and project-level architecture/security/schema/contribution documentation.

It is suitable for continued technical evaluation and use in trusted Godot projects. It is not yet ready to claim a fully governed public marketplace release: license, publisher identity, support channel, and security contact remain owner decisions. Large synchronous core modules also remain a maintainability and responsiveness risk.

## Contract reconstructed for this review

The add-on must:

1. inspect project-local GDScript without instantiating user objects;
2. build a deterministic dependency snapshot with explicit uncertainty and stable edge semantics;
3. render the snapshot in the editor without relying on color, hover, or visual inspection alone;
4. export only snapshots that satisfy the public schema invariants;
5. allow exporter extension through a discoverable, testable contract;
6. fail with actionable and programmatically distinguishable results;
7. preserve supported Godot 4.3–4.7 behavior;
8. remain bounded and diagnosable on malformed, missing, or large inputs;
9. provide enough versioned knowledge for another developer to reproduce, evaluate, and safely change the system.

## Prioritized findings and disposition

### P0 — No validated public serialization boundary

- Status at baseline: **Observed defect**
- Location: graph snapshot to JSON/Mermaid/PlantUML export
- Problem: exporters accepted arbitrary dictionaries. Duplicate IDs, dangling edges, malformed member provenance, and incompatible schema versions could be serialized as authoritative output.
- Why it matters: all downstream formats and third-party consumers depend on the snapshot's meaning; invalid data at this boundary undermines correctness and trust.
- Evidence: baseline export service selected an exporter and serialized directly; no schema validator or machine-readable schema existed.
- Required action: define schema invariants, validate before export, and add negative tests.
- Resolution: **Resolved in 0.1.6.** `core/snapshot_validator.gd`, `docs/schema/snapshot-v1.schema.json`, runtime negative tests, and static schema validation were added. Invalid snapshots return `invalid_snapshot` and are not written.

### P0 — Runtime validation and the published schema initially disagreed

- Status during remediation: **Observed correctness defect**
- Location: `core/snapshot_validator.gd` versus `docs/schema/snapshot-v1.schema.json`
- Problem: an intermediate validator implementation coerced schema versions, node IDs, and edge endpoints to strings and treated several schema-required collections as optional. A snapshot could therefore pass the executable boundary while failing the published JSON Schema.
- Why it matters: two competing definitions of valid output make compatibility and downstream validation non-deterministic.
- Evidence: direct invariant comparison found coercion at scalar boundaries and missing required-field checks for node member collections and edge `member_links`.
- Required action: make the runtime validator strict, keep additive extension fields permissive, and add negative contract cases for every mismatch.
- Resolution: **Resolved in 0.1.6 before release packaging.** Runtime validation now rejects type coercion, enforces required node/edge fields, validates warning/error item types, and uses stable issue codes. The public suite covers string schema versions, numeric IDs/endpoints, missing member collections, missing `member_links`, and malformed message collections.

### P0 — Exporter extension promise lacked an enforceable contract

- Status at baseline: **Observed design gap**
- Location: `export/exporter.gd` and `export/export_service.gd`
- Problem: built-in exporters shared method names, but registration did not validate capability shape and there was no reusable contract suite for independent implementations.
- Why it matters: a documented extension point without substitutability evidence is likely to fail late in the UI or export path.
- Evidence: registration previously accepted any object with several methods and normalized some malformed identifiers.
- Required action: declare capabilities, reject malformed implementations, and provide reusable positive/negative contract tests.
- Resolution: **Resolved in 0.1.6.** Registration validates identifiers, display names, extensions, boolean capability declarations, duplicate formats, and empty output. `tests/contracts/exporter_contract.gd` is reusable by third-party exporters.

### P1 — Graph encodings were not decoded in the initial state

- Status at baseline: **Observed visualization defect**
- Location: editor dock
- Problem: edge colors and direction carried meaning, but the graph had no visible legend. A user had to infer semantics from controls or prior documentation.
- Why it matters: the initial visual state was not self-contained, and meaning depended too heavily on color and prior knowledge.
- Evidence: baseline rendered dock showed colored relationships without an adjacent decoding key.
- Required action: provide a close, reader-facing legend and state the canonical versus rendered direction.
- Resolution: **Resolved in 0.1.6.** A visible legend decodes inheritance, literal/direct use, type use, and rendered direction. Edge categories also retain distinct labels and independent toggles rather than color-only identity.

### P1 — Essential graph information depended on vision and hover

- Status at baseline: **Observed accessibility/usability gap**
- Location: GraphEdit and script-path metadata
- Problem: exact paths were available only through hover, and there was no non-visual relationship summary.
- Why it matters: hover is unavailable to keyboard-only and non-visual users and is weak evidence for large graph comprehension.
- Evidence: baseline used a compact tooltip label; GraphEdit was the only relationship representation inside the editor.
- Required action: provide a keyboard-focusable path action and a textual summary with an exact-data route.
- Resolution: **Partially resolved in 0.1.6.** The path affordance is now a focusable button that copies the full `res://` path. A Summary tab reports node/edge counts, relationship directions, diagnostics, and JSON as the exact-data route. Screen-reader usability has not been independently tested.

### P1 — Scan trust boundary was implicit

- Status at baseline: **Observed security/operational defect**
- Location: `core/project_scanner.gd`
- Problem: callers could supply paths outside the current project namespace, and symbolic-link behavior was not explicit.
- Why it matters: editor tooling operates with user filesystem permissions; unexpected traversal increases data exposure and denial-of-service risk.
- Evidence: baseline normalized caller paths but did not explicitly reject absolute, `user://`, or parent-traversal roots.
- Required action: confine roots to `res://`, reject traversal, skip symbolic links by default, retain limits, and document reflection/trust behavior.
- Resolution: **Resolved for the default path in 0.1.6.** Invalid roots return `invalid_scan_root`; symbolic links are skipped unless explicitly enabled. `docs/SECURITY.md` records the remaining opt-in risk and the limits of editor-process trust.

### P1 — Export failures were not programmatically stable

- Status at baseline: **Observed API defect**
- Location: export service
- Problem: callers primarily received free-form error text. Failure recovery states could not be handled reliably without parsing messages.
- Why it matters: public tooling should distinguish invalid input, unsupported format, temporary write failure, commit failure, and failed restoration.
- Evidence: baseline result dictionaries did not consistently include stable codes and context.
- Required action: define structured failure codes while preserving reader-facing messages.
- Resolution: **Resolved in 0.1.6.** Export results include `ok`, `code`, `error`, `path`, and context. Replacement and recovery paths have distinct codes.

### P1 — No reproducible performance evidence

- Status at baseline: **Observed evidence gap**
- Location: analyzer and graph builder
- Problem: configurable limits existed, but there was no executable regression budget or representative scale fixture.
- Why it matters: scanning and layout are synchronous; a functional regression can still make the editor unusable.
- Evidence: existing validation covered correctness and compatibility but not elapsed time or large synthetic shapes.
- Required action: add deterministic bounded fixtures, output completeness checks, loose regression budgets, and per-version records.
- Resolution: **Resolved as a regression gate in 0.1.6.** `tests/performance_runner.gd` covers 500 typed methods and a 1,000-script inheritance chain. It is not a guarantee of editor responsiveness for all real projects.

### P1 — Documentation did not preserve system rationale or release knowledge

- Status at baseline: **Observed maintainability gap**
- Location: repository documentation
- Problem: README/contract/validation material described features, but architecture boundaries, schema evolution, security assumptions, contribution gates, decision rationale, and release history were absent.
- Why it matters: a future maintainer would need to reconstruct consequential decisions from code and conversation history.
- Evidence: no architecture document, machine-readable schema, security document, contributing guide, changelog, or decision records.
- Required action: add concise versioned documentation close to the affected subsystem and validate local links.
- Resolution: **Resolved in 0.1.6.** Architecture, schema, security, performance, contribution, changelog, test-system, and two ADR documents were added. Static validation checks required documents and local links.

### P2 — Diagnostics had two representations without a migration statement

- Status at baseline: **Observed design gap**
- Location: scanner and canonical snapshot
- Problem: warnings/errors were free-form arrays; new structured diagnostics were not part of the canonical output contract.
- Why it matters: UI, exporters, and future automation need stable codes, while existing consumers may still rely on string arrays.
- Required action: preserve legacy arrays, add structured diagnostics additively, and document the evolution policy.
- Resolution: **Resolved in 0.1.6.** Snapshots include optional `diagnostics`; legacy arrays remain. The schema explicitly permits additive fields and documents migration rules.

### P2 — Test discovery and diagnosis were concentrated in one runner

- Status at baseline: **Observed maintainability risk**
- Location: `tests/test_runner.gd`
- Problem: more than one thousand lines of broad tests make ownership and failure localization harder.
- Why it matters: change cost rises when unrelated capability setup and assertions share one orchestration file.
- Required action: move new behavior into capability suites and reusable contracts; split legacy tests only with characterization coverage.
- Resolution: **Partially resolved.** New quality tests live in `tests/suites`, exporter checks in `tests/contracts`, performance has a separate runner, and `tests/README.md` defines organization. The legacy runner remains large and should be decomposed incrementally rather than mechanically.

### P2 — Large core modules concentrate unrelated change knowledge

- Status at baseline: **Observed maintainability risk**
- Location: analyzer, dock, graph builder, scanner
- Problem: several files are 450–900 lines and combine sub-responsibilities that may evolve independently.
- Why it matters: modifications require recovering large mental models and increase regression blast radius.
- Evidence: source analysis combines sanitization, declaration parsing, type extraction, and member-access recognition; dock combines orchestration, rendering, layout, summary, and export UI.
- Required action: identify volatile seams using real changes and tests before extraction.
- Resolution: **Open.** This review did not split files solely to reduce line count. Candidate seams are recorded in `ARCHITECTURE.md`. Refactoring should follow characterization and delta-focused review.

### P2 — Synchronous scan/layout can block the editor

- Status at baseline: **Observed architectural limitation**
- Location: editor workflow
- Problem: traversal, analysis, graph construction, and rendering run on the editor thread.
- Why it matters: limits cap work but do not provide cancellation or responsive progress for a large valid project.
- Required action: define lifecycle, cancellation, progress, immutable plan, and thread-safety semantics before moving work off-thread.
- Resolution: **Open.** Manual scan, size limits, and performance evidence bound current behavior. Background execution is a future design decision, not a safe local patch.

### P2 — Static source analysis remains incomplete by design

- Status at baseline: **Known limitation**
- Location: GDScript analyzer
- Problem: ordinary instance calls, aliases, virtual dispatch, dependency injection, conditional execution, and dynamic resource paths are not resolved.
- Why it matters: users may otherwise interpret the graph as a complete runtime call graph.
- Required action: state the evidence boundary prominently and avoid invented certainty.
- Resolution: **Accepted limitation.** ADR 0002 and user documentation clarify that absence of an edge means unsupported or unobserved static evidence, not proof of no runtime dependency.

### P2 — Public-release governance is incomplete

- Status at baseline: **Observed release blocker**
- Location: repository/project metadata
- Problem: no selected license, final publisher identity, support policy, or security contact exists.
- Why it matters: users cannot determine redistribution rights or a responsible disclosure/support path.
- Required action: project owner decision.
- Resolution: **Open; not safely inferable.** Documentation now surfaces the gap rather than inventing governance metadata.

### P1 — Static evidence depended on editor cache state

- Status at baseline: **Observed reproducibility defect**
- Location: `tools/validate_static.py`
- Problem: resource-reference checks traversed `.godot` editor metadata, so the reported check count differed between an imported working tree and a clean release copy.
- Why it matters: validation evidence must describe source artifacts, not incidental cache contents.
- Required action: exclude generated editor state and prove the same check count before and after import.
- Resolution: **Resolved in 0.1.6.** `.godot` is excluded from source validation. Clean and imported trees now execute the same 299 source checks once the three rendered-review images are included.

### P1 — Release assembly was not an executable project contract

- Status at baseline: **Observed reproducibility gap**
- Location: release workflow
- Problem: archive exclusions, root layout, timestamps, manifest creation, and checksums were performed outside the repository.
- Why it matters: a future maintainer could produce a materially different package despite passing source tests.
- Required action: add a deterministic repository-owned builder and validate its outputs rather than only the working tree.
- Resolution: **Resolved in 0.1.6.** `tools/build_release.py` derives the version, excludes generated state, writes the manifest, fixes member order/timestamps, and emits archive checksums. Two builds were byte-identical; clean extracted and minimal add-on installations were executed.

### P2 — Public method knowledge was uneven

- Status at baseline: **Observed maintainability gap**
- Location: logger and concrete exporters
- Problem: several public methods relied on names or base-class implication rather than local API documentation.
- Why it matters: extension and operational surfaces should be understandable where maintainers encounter them.
- Required action: document every non-private add-on method locally and prevent regression.
- Resolution: **Resolved in 0.1.6.** Public methods now have GDScript documentation comments, and static validation enforces the rule across the add-on.

### P2 — Independent accessibility and comprehension evidence is absent

- Status at baseline: **Observed evidence gap**
- Location: rendered editor graph
- Problem: automated construction and internal visual inspection do not prove screen-reader usability, color-vision accessibility, keyboard workflow completeness, or comprehension by a developer unfamiliar with the project.
- Why it matters: accessibility and decoding claims require representative users or assistive technology, not implementation intent alone.
- Required action: run keyboard-only, assistive-technology, color-vision, and independent comprehension review before making stronger accessibility claims.
- Resolution: **Open.** The visible legend, category controls, focusable path action, Summary tab, and JSON route reduce risk, but the project makes no stronger accessibility claim.

## Test and evidence improvements

Revision 0.1.6 adds or strengthens evidence for:

- valid and invalid snapshot contracts;
- strict parity between the runtime snapshot validator and published JSON Schema, including scalar-type and required-field negative cases;
- duplicate IDs, dangling edges, invalid diagnostics, and contradictory member provenance;
- exporter capability declarations, deterministic output, non-mutation, registration rejection, and empty-output failure;
- invalid scan roots;
- visible legend and non-visual summary construction;
- analyzer and graph-builder scale regression;
- JSON Schema validity and showcase conformance;
- documentation-link and required-knowledge checks;
- isolated validation orchestration through `tools/run_validation.py`.

## Visualization review contract

The editor graph is considered releasable only when:

1. the initial populated state visibly explains edge encodings and direction;
2. identity does not depend on color alone—titles, family text, relation category, position, and toggles remain available;
3. essential path and relationship information is available without hover;
4. the Summary tab and JSON export provide non-visual and exact-data alternatives;
5. the densest showcase is rendered and inspected for clipping, collision, legend wrapping, disabled-state ambiguity, and control availability;
6. the review record links the actual screenshots and engine version.

Automated scene construction verifies presence and text contracts. It does not establish assistive-technology usability or independent comprehension; those remain manual evidence requirements.

## Completion status

**Conditionally accepted as a high-quality development release.** Core correctness, extension, failure, documentation, and visualization-decoding gaps identified in this review have executable protections. Public-release governance, large-module maintainability, editor-thread responsiveness, Godot 4.0–4.2, non-Linux platforms, and independent accessibility testing remain explicit unresolved boundaries.
