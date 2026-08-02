# Dependency Inspector showcase

This example set is intentionally small but covers the main representations produced by the add-on:

- `ShowcaseCombatEntity` is a base class supplied from another add-on under `addons/example_dependency_framework`.
- `ShowcaseBaseActor` inherits that third-party class by `class_name`.
- `ShowcasePlayerActor` inherits a user class by `class_name` and has a literal `preload()` dependency.
- `ShowcaseEnemyActor` inherits by script path and has a literal `load()` dependency.
- `ShowcaseWeaponProfile` and `ShowcaseDamageService` demonstrate `Resource`, `RefCounted`, exported properties, typed parameters, return types, and static methods. `ShowcaseBaseActor.attack_power()` directly calls `ShowcaseDamageService.calculate_damage()`, providing an exact member-to-member example.
- `ShowcaseTargetingService` references `ShowcaseBaseActor` only through `Array[ShowcaseBaseActor]` and a return annotation, producing a `type_uses` edge without a literal load.
- `ShowcaseBattleController` is also registered as the `BattleCoordinator` autoload. `scenes/battle_demo.tscn` attaches it to the `BattleDemo` root node, providing exact autoload and text-scene evidence.
- `ShowcaseBattleController` and `ShowcaseBattleHud` demonstrate controller/UI classes, signals, and another script dependency.
- `ShowcaseBattlePanel` demonstrates the `Control` family.
- `ambient_marker.gd` has no `class_name`, so its node title is the filename `ambient_marker`; hover its `…` metadata affordance for the full path.
- `ShowcaseArenaAnchor3D` demonstrates the `Node3D` family.
- `ShowcaseMainLoop` extends `SceneTree`, demonstrating the `SceneTree -> MainLoop -> Object` intermediary native chain and Object-family classification.
- Existing actor/controller scripts cover general `Node`; `ambient_marker` covers `Node2D`; resource/services cover `RefCounted`.

## Try it in the editor

1. Open the project with Godot 4.
2. Select **Script Dependencies** in the right dock. Editor synchronization performs the initial/default refresh; press **Scan** for an immediate manual refresh.
3. Search for `BattleCoordinator`, `battle_demo`, a member name, or a script path. Use previous/next to focus matches.
4. Press **Open** on a script, a member row, an inner-class row, or a **References** row to navigate to its declaration or exact dependency occurrence. Press the scene row on `ShowcaseBattleController` to open `battle_demo.tscn`.
5. In **Content**, switch **Method signatures**, **Signal signatures**, and **Property types** on and off to compare compact and full representations.
6. Toggle **load/preload uses**, **Type annotation uses**, **Class member uses**, and **Native bases** independently to compare edge density.
7. Enable **Member edge anchors** to connect resolvable relationships to their visible source/target member rows. Very large scrolled nodes fall back to class-level ports.
8. Hover the title bar or member text, or use the **Copy** path action, to inspect untruncated values without a GraphNode-wide tooltip masking the child.
9. In **Appearance**, change minimum/maximum script width, native width, member overflow threshold, spacing, or depth orientation.
10. In **Colors**, change property, signal, method, inheritance-family, script-kind, or edge colors.
11. Press GraphEdit’s **Arrange** button and observe that Object/native bases precede their descendants rather than appearing in the terminal column.
12. Export JSON, Mermaid, or PlantUML from the toolbar.

The ready-made files in `representations/` were generated with Godot 4.7 from the same scanner, graph builder, and exporters used by the editor plugin. JSON uses snapshot schema v2 and contains autoload, scene-usage, declaration-location, and dependency-occurrence evidence. PlantUML uses exact member endpoints; Mermaid uses member-labeled class relationships.

Regenerate them from the project root with:

```sh
godot --headless --path . --script tests/generate_showcase_exports.gd
```
