# Godot 4 compatibility policy

## Baseline API policy

The implementation deliberately uses APIs present in the executed Godot 4.3 baseline:

- `EditorPlugin.add_control_to_dock()` / `remove_control_from_docks()`;
- `ProjectSettings.get_global_class_list()`;
- `Script.get_base_script()` and `get_instance_base_type()`;
- `GraphEdit.clear_connections()`, four-argument `connect_node()`, and `arrange_nodes()`;
- `GraphNode.position_offset` and `set_slot()`;
- `FileAccess`, `DirAccess`, and `ClassDB.get_parent_class()` / `is_parent_class()`.

Newer or nonessential conveniences, currently `Script.get_global_name()` and `GraphNode.get_titlebar_hbox()`, are called only after capability checks. A dedicated child path action remains available when title-bar access is absent.

Member anchors use baseline `GraphNode.set_slot()`. Exact anchors are attached only to direct GraphNode children; a node using an internal `ScrollContainer` falls back to class-level ports because GraphNode cannot expose ports for grandchildren.

## Executed compatibility boundary

Release `0.1.6` passed the same isolated source gates and the final minimal-package installation gate on every supplied Linux binary:

| Godot | Commit | Editor/plugin | Public suite | Showcase | Performance | Minimal add-on |
|---|---|---:|---:|---:|---:|---:|
| 4.3 stable | `77dcf97d8` | Pass | Pass | Pass | Pass | Pass |
| 4.4.1 stable | `49a5bc7b6` | Pass | Pass | Pass | Pass | Pass |
| 4.5.2 stable | `6ce3de25a` | Pass | Pass | Pass | Pass | Pass |
| 4.6.3 stable | `7d41c59c4` | Pass | Pass | Pass | Pass | Pass |
| 4.7 stable | `5b4e0cb0f` | Pass | Pass | Pass | Pass | Pass |

All authoritative processes exited with status 0. Every version generated the same 25-node, 36-edge graph. Mermaid and PlantUML were byte-identical; normalized JSON differed only before removal of the intentionally version-specific engine metadata.

Validated runtime range: **Godot 4.3 through 4.7 on the supplied Linux builds**.

Godot 4.0–4.2 remain possible source-compatibility targets but were not executed. Other operating systems and custom engine builds are not implicitly claimed compatible.

## Internal resource-loading policy

The plugin does not bind its internal service graph through `const ... = preload(...)`. Required scripts, scenes, and resources are named by explicit `res://` path constants, checked, and loaded at the narrowest runtime boundary. One missing resource therefore produces an exact-path initialization error instead of an opaque parse-time failure chain.

The analyzer still recognizes literal `load()` and `preload()` calls in inspected user code. That evidence is independent from the add-on's internal loading policy.

## Schema and member-provenance compatibility

The class-level node/edge model remains the version-1 compatibility boundary. Optional `diagnostics` and `member_links` are additive fields; readers that follow the documented unknown-field policy can ignore them.

- JSON preserves structured member provenance losslessly.
- PlantUML renders exact member endpoints where both endpoints are known.
- Mermaid class diagrams use class endpoints and preserve member specificity in relation labels.
- GraphEdit uses exact visible member rows and falls back to class ports when an endpoint is omitted, unresolved, filtered, or nested in scrolling content.

Unsupported schema versions are rejected instead of being silently coerced.

## Degradation behavior

If reflection cannot load a script, source-only analysis proceeds with a warning. If an optional method is absent, its enrichment is omitted while source/global-class analysis remains active. Unknown annotation symbols become external nodes only when external nodes are enabled. No fallback silently changes an edge kind.

Member inference is conservative. Direct class-qualified access can identify both endpoints. Literal resource references and annotations generally identify a containing source member but not a target member. Variables, aliases, dependency injection, dynamic expressions, virtual dispatch, and runtime-created paths remain class-level or absent unless statically unambiguous.
