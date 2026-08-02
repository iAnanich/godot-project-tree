# Test system

The suite is an evidence system, not a single pass/fail script.

## Layers

- `test_runner.gd`: public workflow and broad regression tests.
- `suites/quality_contract_suite.gd`: snapshot, scope projection, graph-query, editor-state, exporter, scan-boundary, legend, and non-visual-summary contracts.
- `contracts/exporter_contract.gd`: reusable behavioral checks for built-in and third-party exporters.
- `automation_runner.gd`: dock workflow proving default editor synchronization/debounce, bounded export-event suppression, disabled timed fallback, opt-in timed scheduling, and independent automatic exports.
- `export_matrix_runner.gd`: self-scan regression matrix covering all formats, color modes, compact/full members, every relation family, and all-options-on signatures.
- `visual_showcase_runner.gd`: Godot-rendered evidence for overview, selected scope, inheritance focus, and isolated neighborhood, plus prior visual states.
- `performance_runner.gd`: bounded analyzer and graph-builder regression gate.
- `generate_showcase_exports.gd`: real-shape end-to-end generation used by documentation and cross-version comparison.
- `fixtures`: representative positive and negative source shapes.

## Prerequisite

Run one headless editor import before tests. Godot's global `class_name` cache is project-generated state:

```sh
godot --headless --editor --path . --quit-after 5
```

A test run without that prerequisite is a harness error, not evidence that class resolution is broken.

## Evidence expectations

- New public behavior: end-to-end assertion through the public scanner/builder/export or dock boundary.
- Scope/focus behavior: pure projection/query assertions plus rendered UI state; include negative cases for omitted unrelated nodes, role/count drift, and descendants disabled.
- Corrected defect: regression assertion tied to the original cause.
- Interchangeable exporter: reusable contract plus implementation-specific output checks.
- Compatibility claim: same gate executed under each claimed Godot version in an isolated project copy.
- Visualization change: rendered capture plus semantic, clipping, legend, tooltip, text-alternative, and review-record checks.
