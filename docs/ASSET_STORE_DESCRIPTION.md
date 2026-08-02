# Asset Library page copy

## Name

Script Dependency Inspector

## One-line summary

Inspect GDScript inheritance and dependencies in Godot, or export the validated graph to JSON, Mermaid, and PlantUML for dedicated diagram tools.

## Short description

Script Dependency Inspector builds a deterministic static dependency snapshot from your Godot project. Explore it in an interactive, searchable graph—or hide the graph and run export-only. Scope large projects, navigate exact source and scene evidence, follow editor saves, and produce JSON, Mermaid, or PlantUML files for larger-canvas rendering and presentation in third-party applications.

## Full description

Script Dependency Inspector scans GDScript source without instantiating project classes, validates one canonical dependency snapshot, and makes that evidence available both inside Godot and as portable files.

### Inspect inside Godot

- Visualize path-based, `class_name`, native, add-on, and unresolved inheritance.
- Distinguish literal `load()`/`preload()`, type-annotation, and statically resolvable class-qualified member dependencies.
- Search classes, paths, members, autoloads, scenes, and scene-node paths.
- Navigate to exact supported declarations, dependency occurrences, and text-scene attachments.
- Select project-folder scopes while retaining required outside context.
- Focus inheritance paths, include descendants, or isolate a bounded relationship neighborhood.
- Use grouped foldable controls rather than one long flat option list.

### Export for dedicated diagram and documentation tools

The built-in GraphEdit is optimized for inspection inside an editor dock. It is not the only viewing surface. Export the same validated snapshot as:

- **JSON** — lossless structured data for automation, custom analysis, or custom renderers;
- **Mermaid** — portable text diagrams for documentation systems and Mermaid-compatible editors/renderers;
- **PlantUML** — class diagrams for PlantUML tools with precise member endpoints where supported.

Dedicated third-party applications can provide a larger canvas, different layout engines, renderer-specific themes, publication workflows, or presentation controls that are impractical in a constrained editor dock. The graph can therefore be hidden entirely while scans, synchronization, summaries, diagnostics, and manual or automatic exports continue to operate.

### Stay synchronized

Save/import synchronization is enabled by default and debounced after editor activity becomes quiet. The toolbar shows whether scanning is save-synchronized, timed, both, or manual. Timed rescanning remains an independent disabled-by-default fallback. JSON, Mermaid, and PlantUML destinations can be updated independently after each completed scan.

### Reliability boundary

- Deterministic ordering and versioned snapshot schema
- Validation before every serialization
- Bounded files, directories, scripts, and text scenes
- Recoverable staged writes and independent per-format failures
- Explicit diagnostics instead of guessed dynamic relationships
- Automated behavioral, negative, export, visual, performance, and compatibility tests

### Compatibility

Runtime-tested against the supplied Linux builds of Godot 4.3, 4.4.1, 4.5.2, 4.6.3, and 4.7. Consult the included compatibility matrix for the exact executed evidence.

### Static-analysis limits

This is not a runtime profiler or complete call graph. It does not infer aliases, dependency injection, virtual dispatch, reflection, dynamic paths, runtime-selected receiver types, binary-scene contents, or transitive scene/resource behavior. Missing evidence is omitted or diagnosed rather than guessed.

### AI-assisted development disclosure

Generative AI was used extensively for requirements synthesis, code and refactoring drafts, tests, documentation, diagrams, review suggestions, and release support. The project owner directed scope and feature decisions. AI output was treated as proposed work and checked through documented contracts, review, Godot parser/import and runtime tests across the claimed engine matrix, negative and boundary tests, deterministic builds, checksums, patch reconstruction, and rendered-artifact inspection. This does not claim an independent human line-by-line audit or independent accessibility/security certification. Full details and provenance limits are in `AI_USAGE_NOTICE.md`.

Licensed under Apache License 2.0. Project Mapper is documented as a late consideration for individually attributed interaction features; no source code was copied.
