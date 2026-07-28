# Script Dependency Inspector

Godot 4 editor plugin that scans GDScript source files, resolves script and native inheritance, detects literal script loads, type-annotation usage, and direct class-qualified member usage, builds a deterministic dependency graph, displays it in a customizable `GraphEdit` dock, and exports JSON, Mermaid class diagrams, or PlantUML.

Release `0.1.6` is runtime-validated with the supplied Godot 4.3, 4.4.1, 4.5.2, 4.6.3, and 4.7 Linux executables.

## Install

Copy `addons/script_dependency_inspector` into a Godot 4 project, then enable **Project > Project Settings > Plugins > Script Dependency Inspector**.

## Use

Open the **Script Dependencies** dock and press **Scan**. Scanning is manual by default so enabling the plugin does not synchronously traverse a large project. Select an export format and press **Export…** to choose a destination.

The dock is organized for a narrow right-side placement:

- **Content** controls included nodes, edge kinds, members, and compact/full member text.
- **Appearance** controls minimum and maximum script widths, compact native width, overflow thresholds, spacing, and depth orientation.
- **Colors** controls script kinds, member categories, inheritance families, and edge kinds.
- **Summary** provides a non-visual count and relationship description plus the exact-data route.
- **Log** reports warnings and failures.

Display-only changes redraw the existing snapshot without rescanning. The bundled `default_settings.tres` exposes the same defaults and additional scan limits through `@export` fields.

## Dependency kinds

- `extends`: direct inheritance, including path-based scripts, `class_name` scripts, add-ons, external scripts, and native `ClassDB` chains.
- `uses`: literal `.gd` references in `load()` or `preload()` calls.
- `type_uses`: class references found in type annotations, including properties, signals, method parameters and return types, local variables, typed loop variables, and callable/lambda declarations visible in source.
- direct class-member `uses`: optional detection of expressions such as `DamageService.calculate_damage(...)`, retaining the containing source member and the referenced target member.

Dependency provenance is stored in each class-level edge's optional `member_links` array. Literal and type dependencies retain their containing source member where known. Direct class-qualified access can retain both source and target members. This is static source analysis: it does not infer runtime receiver types, follow aliases or ordinary instance calls, evaluate expressions, or resolve dynamically constructed resource paths.

## Graph presentation

- A script with `class_name` is titled only by that custom class name. A script without `class_name` is titled by its filename without the `.gd` suffix.
- Script paths are not concatenated into titles. Hover the title bar or the compact `…` metadata affordance for the complete `res://` path.
- The GraphNode itself deliberately has no global tooltip, so member and metadata child tooltips remain reachable.
- Methods and signals default to names only; separate toggles reveal arguments and return types. Properties default to names only; a separate toggle reveals declared types.
- Properties, signals, methods, metadata, script kinds, inheritance families, and edge kinds have independent colors.
- Optional member edge anchors attach GraphEdit relationships to visible property, signal, or method rows. Very large scrolled member lists intentionally fall back to class-level ports.
- Native classes use compact title-only nodes and a separate width setting.
- Script width grows from a configurable minimum to a configurable maximum according to visible text. Height follows the visible member content and enables scrolling only after the configurable high overflow threshold is exceeded.
- The deterministic default layout groups nodes by inheritance depth. A top-to-bottom layout is used by default for a narrow dock; left-to-right depth layout remains available.
- Pressing GraphEdit’s built-in **Arrange** now places bases/dependencies before descendants/dependents. Canonical exports still retain dependent-to-dependency edge direction.
- Border/title accents distinguish `Object`, `RefCounted`, general `Node`, `Node2D`, `Node3D`, `Control`, and other inheritance families.

## Native inheritance discovery

For a script’s direct native base, the graph builder creates the native node and repeatedly calls `ClassDB.get_parent_class()` until the native root is reached. This produces intermediary chains such as:

- `SceneTree -> MainLoop -> Object`
- `CanvasLayer -> Node -> Object`
- `Control -> CanvasItem -> Node -> Object`

After inheritance edges are resolved, each script is assigned the most specific configured family using `ClassDB.is_parent_class()`: `Control`, `Node2D`, `Node3D`, `Node`, `RefCounted`, then `Object`.

## Core behavior

- Scans `.gd` files recursively without instantiating user scripts.
- Uses source parsing for local methods, signals, properties, inner classes, literal dependencies, and declared type references.
- Uses optional `Script` reflection and `ProjectSettings.get_global_class_list()` to improve base and type resolution.
- Uses stable IDs and canonical ordering so repeated exports are deterministic.
- Reports unreadable files, unresolved bases, size/scan limits, unsupported exporters, and write failures through structured log entries and the editor dock.
- Loads internal scripts, scenes, and settings through explicit resource-path checks instead of `const ... = preload(...)` chains.

## Showcase project

The development project includes `examples/showcase`, plus a small third-party-style base class under `addons/example_dependency_framework`. It covers native/add-on/user inheritance, named and unnamed scripts, all inheritance-family colors, compact and full member representations, exported properties, signals, static methods, literal resource dependencies, and annotation-only dependencies.

Member specificity differs by export format:

- JSON preserves structured `member_links`.
- PlantUML uses exact `Class::member` relationship endpoints.
- Mermaid class diagrams do not expose member endpoints, so member provenance is retained in the class-to-class relationship label.

Ready-made representations are included at:

- `examples/showcase/representations/showcase.json`
- `examples/showcase/representations/showcase.mmd`
- `examples/showcase/representations/showcase.puml`

Regenerate them with:

```sh
godot --headless --path . --script tests/generate_showcase_exports.gd
```

See `examples/showcase/README.md` for the editor workflow and what each script demonstrates.

## Known limitations

- The source analyzer is deliberately lightweight rather than a compiler AST. It handles common declarations, multiline strings, comments, generic/container type expressions, and literal `.gd` resource references, but it does not evaluate dynamic paths or conditional code.
- Inner classes are captured as metadata on their containing script; they are not emitted as independent graph nodes.
- Direct member-use detection currently recognizes explicit class-qualified access. It is not a complete call graph and does not resolve instance variables, aliases, dependency injection, virtual dispatch, or dynamically selected members.
- Mermaid `classDiagram` syntax cannot anchor relationships to individual member rows; labeled class relationships are used instead. PlantUML and GraphEdit support exact member endpoints.
- Full third-party script chains are most reliable when add-on scanning is enabled. With add-ons excluded, resolution is limited to project global-class metadata and native `ClassDB` information visible to the running editor.
- Dense projects can still produce crossing edges. Edge kinds and native/external chains can be disabled independently to reduce visual density.
- Godot’s built-in arranger uses a horizontal dependency layout and may place deep descendants beyond the initially visible width of a narrow dock; minimap and panning remain available.
- Scanning and layout run on the editor thread. File, directory, script-size, node-size, and member limits are configurable.

## Validation

Run the complete isolated gate set with a Godot executable:

```sh
python tools/run_validation.py --godot /path/to/godot --output validation-results
```

The orchestrator records version, static integrity, editor/plugin initialization, public tests, showcase export, and bounded performance evidence. Individual gates remain available for focused development:

```sh
python tools/validate_static.py
godot --headless --path . --script tests/test_runner.gd
godot --headless --path . --script tests/performance_runner.gd
```

See `docs/VALIDATION.md` for executed evidence and `docs/COMPATIBILITY.md` for the cross-version and resource-loading policy. Deterministic release archives are built with `python tools/build_release.py --output dist`.

## Quality status

Release 0.1.6 adds executable snapshot invariants, exporter capability contracts, structured failures, project-local scan boundaries, deterministic validation, public-method documentation checks, a reproducible performance gate, visible relation decoding, a textual graph summary, and versioned architecture/schema/security/decision records. The detailed review distinguishes resolved defects from remaining design work.

Current unresolved boundaries are synchronous editor-thread scanning/layout, concentrated large modules and legacy test orchestration, compiler-incomplete source analysis by design, untested Godot 4.0–4.2 and non-Linux platforms, independent assistive-technology/comprehension review, and public-release governance.

## Project documentation

- [Architecture and component boundaries](docs/ARCHITECTURE.md)
- [Canonical snapshot schema](docs/SCHEMA.md)
- [Security and trust boundaries](docs/SECURITY.md)
- [Compatibility policy](docs/COMPATIBILITY.md)
- [Performance contract](docs/PERFORMANCE.md)
- [Validation evidence](docs/VALIDATION.md)
- [Quality review and remaining gaps](docs/QUALITY_REVIEW.md)
- [Contribution and release gates](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)

The project has not yet selected a distribution license, final publisher identity, support channel, or security contact. Those governance decisions remain owner actions before a public marketplace release.
