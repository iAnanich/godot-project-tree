# Snapshot schema

Version: 0.3.0

The current public model remains **snapshot v2**, formally described by [`schema/snapshot-v2.schema.json`](schema/snapshot-v2.schema.json). The v1 schema is retained for historical consumers. v0.2.1 added optional scope fields; v0.3.0 preserves `schema_version` 2 and editor-state schema v4. It narrows the analysis trust boundary by removing project-script reflection; the public snapshot schema does not change.

## Root

Required: `schema_version`, `metadata`, `nodes`, `edges`, `scene_usages`, `warnings`, and `errors`. `diagnostics` provides structured severity/code/message/context records when present.

## Source locations

`source_location` is `{ "line": positive integer, "column": positive integer }`, one-based. It can identify a script/member declaration or the exact source occurrence represented by an edge `member_link`. Absence means no exact location is claimed.

## Autoload

Script nodes may contain `autoload` with `name` and `singleton`. An empty object means no matching project autoload was found.

## Scene usage

Each record contains:

- `scene_path`;
- `node_path`;
- `script_path`;
- `line` and `column` of the script assignment in the text scene;
- `evidence`, currently `tscn_node_script_attachment`.

The root list contains records whose script nodes remain in the current snapshot projection. Matching script nodes repeat their records for local UI access. Validator invariants reject duplicate, orphaned, mismatched, or missing copies.

## Scope projection

When the dock applies a folder scope, metadata may contain:

- `index_root_path`: the full bounded acquisition root, currently `res://`;
- `root_path`: the selected display/export scope;
- `scope_active`: whether `root_path` differs from `res://`;
- `scope_summary`: required integer `in_scope_nodes` and `context_nodes` counts.

Each projected node contains:

- `scope_role`: `in_scope` or `context`;
- `scope_reason`: a stable explanatory value such as `selected_root`, `required_ancestor`, `required_dependency`, or `dependency_ancestor`.

Scope fields are additive. An older valid snapshot-v2 document without them remains valid. When scope metadata is present, runtime validation checks roles, selected-root containment for project scripts, full-index metadata, and count consistency.

JSON preserves the fields exactly. Mermaid appends `(context)` to retained context labels; PlantUML applies `<<context>>`. Diagram formats remain lossy representations and do not replace JSON for exact evidence.

## Compatibility

Snapshot v2 was an intentional schema break from v1 because required scene evidence and navigable source data were introduced in v0.2.0. Consumers must branch on `schema_version`. Editor preference state is separate and is now schema v4, accepting and migrating schemas 1, 2, and 3.
