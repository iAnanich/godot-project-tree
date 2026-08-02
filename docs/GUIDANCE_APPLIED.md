# Applied guidance record

Version: 0.2.2
Date: 2026-07-29

## Sources applied

- `GENERAL_PROJECT_GUIDELINES.md` v2.0.0 supplied to the project.
- `SOFTWARE_QUALITY_GUIDELINES_SINGLE_FILE.md` supplied to the project.
- `DATA_VISUALIZATION_GUIDELINES_SINGLE_FILE.md` supplied to the project.

## v0.2.2 application

- Reconstructed the requested outcomes as UI allocation, state visibility, export-only operation, control hierarchy, and development-disclosure contracts before implementation.
- Kept review findings separate from corrections and linked each finding to observable verification.
- Preserved the validated snapshot/export boundary while making GraphEdit optional; no UI preference can alter canonical relationship semantics.
- Allocated toolbar space according to task priority, made trigger state visible, and used labelled folding rather than hiding controls in deeper menus.
- Added explicit failure and migration behavior for editor-state schema v4.
- Treated AI output as proposed work and recorded actual owner direction, automated quality controls, and residual evidence limits rather than making generic supervision claims.
- Updated use cases, diagrams, design, contract, store copy, tests, and screenshots together so the same behavior does not diverge across artifacts.
- Planned rendered checks for clipping, label legibility, collapsed-state visibility, and graph-off state rather than relying on source inspection alone.

## Evidence classification

Executed parser/tests/build results are recorded as observed evidence. UI usefulness beyond the tested tasks, unfamiliar-user comprehension, formal accessibility, independent security review, and independent human line-by-line audit remain unverified and are not claimed.

---

## Prior applied-guidance record

# Guidance applied — v0.2.1

- **General baseline:** General Project and Solution Guidelines v2.0.0, 29 July 2026.
- **Software specialist baseline:** Software Quality Guidelines, evidence-reviewed edition, 27 July 2026.
- **Visualization specialist baseline:** Data Visualization Guidelines v1.1, 27 July 2026, including the AI visualization workflow for the new use-case diagrams and rendered UI evidence.
- **Project contract:** v0.2.0 source and documentation, approved v0.2.1 roadmap decisions, Godot 4.3–4.7 Linux compatibility commitment, deterministic snapshot/export boundary, and the stated non-goals.
- **Project-specific decisions:** editor synchronization remains default-on; timed rescan remains default-off; TODO extraction, general inferred call graphs, and immediate main-screen placement remain out of scope; Project Mapper remains a late consideration and is cited only for specifically adopted interaction ideas.
- **Overrides:** no specialist rule was overridden. Scope selection is intentionally a presentation projection over a full bounded project index rather than an acquisition boundary; this preserves required ancestor/dependency context at the cost of full-index scan work and full-index diagnostics.
- **Unavailable optional tools:** `gdlint` and `gdformat` were not installed in the validation environment. Godot parser/import and runtime tests remain the authoritative GDScript execution evidence.
- **Material limits:** no unfamiliar-user comprehension study, screen-reader usability study, formal WCAG conformance review, non-Linux compatibility run, Godot 4.0–4.2 run, or binary-scene analysis was performed.

This record identifies the guidance and evidence boundary; it is not itself proof that every requirement was met.
