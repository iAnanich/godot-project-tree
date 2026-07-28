# Source and documentation research

The implementation was designed from the user-supplied archives rather than inferred from memory alone.

- Godot source archive: `godot-4.7.zip`, archive revision `c050c09b105c3715e1caa57a7109cd752047fd89`.
- Godot documentation archive: `godot-docs-4.7.zip`, archive revision `0585d03bea24497cf91f0969c81a187c892371c4`.

Key design consequences:

1. GDScript reflected method/property/signal lists may include base members, so local declarations are extracted from source and reflection is limited to naming/base enrichment.
2. `Script.get_global_name()` is newer than the early Godot 4 baseline, so it is capability-checked.
3. The GraphEdit dock uses the four-argument connection API and properties documented in Godot 4.0.
4. `GraphNode` exposes three real direct-child rows so inheritance, literal-use, and type-use relations map to valid slot/port indices.
5. Third-party bases are resolved from scanned paths/classes first, then the project global-class registry, then represented as explicit external nodes.
6. Intermediary engine inheritance is not guessed from names. `_ensure_native_chain()` repeatedly invokes `ClassDB.get_parent_class()`, producing chains such as `SceneTree -> MainLoop -> Object` and `CanvasLayer -> Node -> Object` from the running engine’s own class database.
7. In `scene/gui/graph_edit_arranger.cpp`, the arranger derives its upper/previous neighbours from incoming connections. Because the canonical model stores dependent-to-dependency edges, the editor renderer reverses only GraphEdit connection direction so bases/dependencies become earlier layout layers. Export semantics remain unchanged.
8. `GraphNode.get_titlebar_hbox()` is treated as optional and capability-checked. A dedicated child path affordance supplies the full-path tooltip independently, and the GraphNode root tooltip remains empty so child tooltips are not shadowed.

9. PlantUML class diagrams support relationship endpoints using `Class::member`, so exact member links are emitted when member-edge rendering is enabled.
10. Mermaid `classDiagram` relationships address classes rather than individual members. The Mermaid exporter therefore keeps a valid class-to-class relationship and places source/target member names in its label; canonical JSON remains the lossless representation.
11. GraphNode ports apply to direct child rows. Adaptive nodes create direct member rows while content fits; overflow content moves into a ScrollContainer and deliberately uses class-level fallback ports.
