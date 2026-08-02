# Quality review — v0.2.1 baseline and v0.2.2 correction

Review date: 2026-07-29
Baseline: v0.2.1 source bundle
Guidance: see [GUIDANCE_APPLIED.md](GUIDANCE_APPLIED.md)

## Outcome

The v0.2.1 analysis/export model remained valid, but the dock allocated space poorly for manual export, concealed scan-trigger state, made GraphEdit mandatory, used flat high-density option lists, and provided an AI notice too generic for meaningful development disclosure. The findings below were corrected without changing snapshot schema or dependency semantics.

## Findings and resolutions

| ID | Severity / confidence | Type | Finding and impact | Resolution | Verification |
|---|---|---|---|---|---|
| SDI-REV-022-01 | Medium / high | Observed | The export format selector used flexible horizontal expansion, occupying disproportionate space compared with the action it qualifies. | Constrain the selector to compact intrinsic width and reserve flexible space for separation. | Static scene contract and rendered toolbar review. |
| SDI-REV-022-02 | Medium / high | Observed | The toolbar did not identify whether automatic scans came from editor saves, the timer, both, or neither. | Add a derived state indicator beside **Scan** with detailed timing in its tooltip. | Default/combined-mode tests and automation screenshot. |
| SDI-REV-022-03 | Low / high | Observed | **Scan** and **Export** read as one crowded action cluster. | Add a fixed gap and separator between the task groups. | Rendered toolbar inspection. |
| SDI-REV-022-04 | Medium / high | Observed design gap | GraphEdit was always rendered even for users whose goal is only file export, consuming space and rendering work. | Add a default-on persisted **Graph** toggle; graph-off retains snapshot, summary, diagnostics, synchronization, and export; graph-on rerenders without rescanning. | Behavioral UI contract and export-only screenshot. |
| SDI-REV-022-05 | Medium / high | Observed | Content, Appearance, Colors, and Automation tabs contained long flat control lists with weak hierarchy. | Introduce labelled, tooltip-equipped foldable semantic groups and persist their expanded state. | Fold-state round-trip, tooltip contract, and folded-controls screenshot. |
| SDI-REV-022-06 | High / high | Observed documentation gap | The AI notice named broad activities but did not state concrete supervision, executed quality controls, or residual evidence limits. | Expand the repository/add-on notice and summarize it in marketplace copy without claiming an independent human audit. | Documentation static contract and review. |
| SDI-REV-022-07 | Medium / high | Observed product-communication gap | Store copy listed file formats but did not explain why external files matter relative to the constrained dock. | Explain larger-canvas, alternate-layout, theming, publication, and custom-analysis workflows in dedicated third-party tools. | Store-copy contract review. |
| SDI-REV-022-08 | Medium / high | Observed traceability gap | Existing use cases assumed a graph-first workflow and did not represent export-only operation or control configuration. | Add UC-12/UC-13 and update all three source-controlled diagrams and text alternatives. | Diagram render review and use-case traceability checks. |

| SDI-REV-022-09 | Medium / high | Observed during release reconstruction | Generated Godot `.import` sidecars were ignored by Git but still selected by the release builder, so a manifest could depend on local editor cache state and patch reconstruction could not reproduce it. | Exclude `.import` and `.uid` sidecars independently in release-file selection and enforce the rule in static validation. | Two byte-identical clean builds, forbidden-entry inspection, manifest verification, and patch reconstruction. |

## Acceptance status

All v0.2.2 corrections are implemented. Final completion depends on the executed compatibility matrix, deterministic build, patch reconstruction, and rendered-artifact checks recorded in `VALIDATION.md`.

---

## Historical v0.2.0 → v0.2.1 review

# Quality review — v0.2.0 baseline and v0.2.1 correction

Review date: 2026-07-29
Baseline: v0.2.0 source bundle
Guidance: see [GUIDANCE_APPLIED.md](GUIDANCE_APPLIED.md)

## Outcome

The baseline was suitable for extension but contained several correctness, maintainability, and evidence gaps at the new scope/focus boundary. The findings below were addressed in the v0.2.1 worktree. The corrected release passed the executed matrix in [VALIDATION.md](VALIDATION.md).

## Findings and resolutions

| ID | Severity / confidence | Type | Finding and impact | Resolution | Verification |
|---|---|---|---|---|---|
| SDI-REV-021-01 | High / high | Observed | v0.2.0 opened a filesystem-event suppression window after every scan, including scans with no project-local automatic writes. A real editor change during that window could be ignored. | Suppression is opened only when an enabled automatic export targets `res://`; scans without such writes leave synchronization fully active. | Automation lifecycle regression and code inspection. |
| SDI-REV-021-02 | Medium / high | Observed | Display-only rerenders reset `GraphEdit` scroll position, disrupting inspection. | Preserve the prior viewport when rerendering without a new focus target. | Render-state regression and visual review. |
| SDI-REV-021-03 | Medium / high | Observed | Persisted state and messages were named as “automation” although they now also contain synchronization, scope, and focus state, increasing maintenance ambiguity. | Introduce editor-state schema v3 and generalized names/messages; retain schema-1/2 migration. | Round-trip/migration tests and static contract. |
| SDI-REV-021-04 | Medium / high | Inferred from executed path validation | A remembered scope folder can be deleted or renamed between sessions; accepting it unconditionally could block the initial scan. | Validate stored recent roots at load, discard stale entries, and fall back to `res://` with a warning. | Root-boundary tests plus dock initialization review. |
| SDI-REV-021-05 | High / high | Observed design gap | Additive scope roles and summary counts could drift without cross-record validation, causing misleading JSON/diagram output. | Validate role values, required roles in active scope, project-script containment, full-index metadata, and declared counts before export. | Positive projection test and negative `scope_summary_mismatch` test. |
| SDI-REV-021-06 | Medium / high | Observed usability/evidence risk | Outside context could be encoded only through opacity/color and disappear in diagram exports. | Add textual **Context** metadata/reasons to graph nodes, `(context)` in Mermaid, and `<<context>>` in PlantUML. | Export assertions and rendered screenshot review. |
| SDI-REV-021-07 | Medium / high | Observed maintainability gap | Scope/focus behavior placed directly in orchestration would be difficult to test independently and risk canonical-data mutation. | Add pure `SnapshotScope` and `GraphQuery` components; keep orchestration and presentation state in the dock. | Focused behavioral tests and architecture review. |
| SDI-REV-021-08 | Medium / high | Observed documentation gap | Requirements/design did not provide a user-outcome layer connecting product workflows to contracts and evidence. | Add UC-01–UC-11, three source-controlled diagrams, text alternatives, traceability, and rendered-review notes. | Static documentation checks and `docs/diagrams/REVIEW.md`. |
| SDI-REV-021-09 | Medium / high | Observed during v0.2.1 test review | Neighborhood isolation treated inheritance edges as generic neighbors, so direct children appeared even when **Include descendants** was disabled. | Exclude `extends` edges from direct-neighbor expansion; inheritance descendants are controlled only by the explicit option. | Positive and negative `GraphQuery` tests. |
| SDI-REV-021-10 | Medium / high | Observed | Editor-state loading coerced `schema_version` with `int(...)`, allowing a string value to cross a type boundary. | Require an integer schema value and degrade malformed state to defaults with a warning. | Invalid-schema regression test. |
| SDI-REV-021-11 | Low / high | Observed | The v0.2.0 development tree tracked Python bytecode caches and had no ignore contract for Godot/Python-generated files, creating noisy, non-reproducible review deltas. | Remove tracked caches and add a repository `.gitignore` for Godot import state, UID sidecars, Python bytecode, and local validation outputs. Release packaging continues to enforce its own independent exclusion rules. | Clean-tree inspection, static required-file check, and release archive forbidden-entry verification. |

## Design implications

- Folder selection is a **projection boundary**, not an acquisition/security boundary. The full bounded index is still scanned to resolve required outside context.
- Focus and isolation are presentation queries. They never mutate the scoped snapshot or exporter input.
- Snapshot schema remains v2 with additive optional scope fields. Persisted editor state becomes schema v3.
- A general inferred call graph, TODO extraction, and immediate main-screen placement remain non-goals.

## Evidence limits

The diagrams and screenshots are reviewed representations, not proof of unfamiliar-user comprehension or accessibility conformance. No screen-reader study, formal WCAG review, non-Linux run, Godot 4.0–4.2 run, or binary-scene analysis is claimed.
