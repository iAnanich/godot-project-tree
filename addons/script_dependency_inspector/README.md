# Script Dependency Inspector add-on

Copy this directory to `res://addons/script_dependency_inspector`, then enable **Script Dependency Inspector** under **Project > Project Settings > Plugins**.

The right-side editor dock scans GDScript inheritance, literal script loads, and type-annotation and direct class-member usage; renders the result through `GraphEdit`; and exports JSON, Mermaid, or PlantUML.

The dock provides:

- custom class names as titles, or the script filename when `class_name` is absent;
- full `res://` paths through title-bar and child metadata tooltips rather than title/path concatenation;
- method/signal name-only or full-signature display;
- property name-only or typed display;
- independent colors for properties, signals, methods, metadata, script kinds, inheritance families, and edge kinds;
- compact native nodes;
- adaptive script width and height, with member scrolling only after a high configurable overflow threshold;
- deterministic inheritance-depth layout;
- corrected built-in GraphEdit arrangement direction, with bases/dependencies before their dependents;
- optional member-row edge anchors in GraphEdit;
- JSON member provenance, exact PlantUML `Class::member` endpoints, and labeled Mermaid class relationships.

Native intermediary bases are expanded with `ClassDB.get_parent_class()`. Family accents distinguish Object, RefCounted, Node, Node2D, Node3D, Control, and other branches.

Internal dependencies are loaded through explicit checked paths rather than parse-time preload chains. The full development package contains a runnable showcase under `examples/showcase` and headless validation scripts under `tests`.


Public exports are checked by the canonical snapshot validator. Exporters declare capabilities and must satisfy the reusable contract documented in the full development project. Scan roots are confined to `res://`; symbolic links are skipped by default.


The populated dock includes a visible relation legend and a Summary tab with node/family/edge counts, direction semantics, diagnostics, and a route to lossless JSON. Script paths are available through a focusable copy action, not only hover.

Exports are accepted only after canonical snapshot validation. Exporters declare representation capabilities and return stable failure codes; custom exporters should be verified with the reusable contract suite from the full development project.
