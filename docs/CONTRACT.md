# Behavioral contract

## Inputs

- A project-local scan root in the `res://` namespace, normally `res://`. Absolute paths, `user://`, and parent traversal are invalid.
- GDScript source files below that root.
- Serializable scan, graph-content, presentation, style, and export options.

The scanner reads text and optionally loads scripts as `Script` resources for metadata. It never instantiates user classes.

## Output snapshot

A deterministic dictionary with:

- `schema_version`;
- metadata including engine version, root, selected options, and style;
- nodes with stable IDs, display name, custom-name status, path, direct-base metadata, resolved native base, inheritance family, and selected local members;
- directed edges with kind `extends`, `uses`, or `type_uses`;
- an optional, deterministically ordered `member_links` array on each edge, containing source member, target member, and evidence metadata when statically known;
- compatibility warning/error arrays;
- optional structured diagnostics with stable severity, code, message, and context fields.

Canonical edges point from a derived/dependent node to its base/dependency. Nodes and edges are canonically sorted. Presentation flags do not remove canonical argument/type data from JSON; they control GraphEdit and diagram rendering.

## Snapshot validity contract

`core/snapshot_validator.gd` is the executable invariant boundary before every public export. It rejects unsupported schema versions, malformed metadata, duplicate or invalid node identities, dangling or duplicate edges, invalid diagnostics, and member provenance that names a member absent from the corresponding endpoint node. Invalid snapshots are not serialized or written.

The machine-readable JSON Schema documents the interoperable shape. The runtime validator additionally enforces cross-record semantics that JSON Schema cannot express conveniently, such as endpoint existence and exact member-reference integrity. Unknown additive fields remain permitted for forward-compatible version-1 readers.

## Exporter extension contract

An exporter must expose stable lowercase `format_id`, reader-facing `display_name`, separator-free `file_extension`, a complete boolean capability dictionary, and deterministic nonempty `export_text` output without mutating the snapshot. Registration rejects malformed or duplicate implementations before they can appear in the dock.

The capability snapshot declares support for colors, class members, structured member links, exact member endpoints, and member relation labels. `tests/contracts/exporter_contract.gd` is the reusable substitutability suite for built-in and third-party exporters.

## Naming and tooltip contract

- A script declaring `class_name X` has display name `X`.
- A script without `class_name` has the filename basename as its display name.
- A script path is never concatenated into the title row.
- The complete `res://` path is exposed through the title-bar tooltip when supported and through a dedicated child metadata tooltip.
- The GraphNode root has no tooltip, preserving child-specific member and path tooltips.

## Type-use contract

The analyzer collects declared class symbols from property, signal, method-parameter, method-return, local-variable, typed-loop, and visible callable/lambda annotations. The graph builder resolves those symbols against scanned `class_name` records, project global classes, native `ClassDB` classes, or explicit external placeholders.

This is a static declaration relation, not runtime call-graph or inferred-type analysis. Built-in value/container types are filtered, while nested user types such as `Array[ProjectClass]` retain the user class reference.

## Member-dependency contract

When enabled, the analyzer recognizes explicit class-qualified accesses such as `DamageService.calculate_damage(...)`. The graph builder resolves the class symbol through the same class/global/native/external indexes used for type dependencies and records a class-level `uses` edge with a `member_links` entry. The entry identifies the containing source method/property when known and the referenced target method/property when it exists in the target node.

Literal load/preload and type-annotation edges also retain their containing source member when known. They normally target the class as a whole because the source text does not identify a target class member. This feature is not a complete call graph: instance-variable receiver types, aliases, virtual dispatch, injected dependencies, return-value chains, reflection, and dynamic expressions are not inferred.

## Native-chain and family contract

When native bases are enabled, the direct native base is expanded through repeated `ClassDB.get_parent_class()` calls until no parent remains. Every intermediary native class is represented by a node and an `extends` edge.

After inheritance resolution, each node receives one most-specific family classification in this order: `Control`, `Node2D`, `Node3D`, general `Node`, `RefCounted`, `Object`, or `other`. Family values are canonical node metadata and control editor border/title accents.

## Presentation contract

- Methods and signals can render as names only or as full signatures.
- Properties can render as names only or with declared types.
- Script/member/metadata/family/edge colors are independently configurable where the target representation supports them.
- Native nodes are title-only and use a separate compact width.
- Script width is estimated from displayed text and clamped between configured minimum and maximum widths.
- Script height follows displayed content until the configured maximum member-area height; only content beyond that threshold scrolls.
- Member counts and title/member text lengths remain bounded; omitted or truncated text remains discoverable through child tooltips or canonical exports.
- Default layout groups by inheritance depth and orders each group deterministically by kind, name, and stable ID.
- Canonical edges remain dependent-to-dependency. GraphEdit connections are rendered in reverse solely because Godot’s built-in arranger interprets incoming nodes as earlier layers; this places bases and dependencies before descendants when **Arrange** is pressed.
- When member-edge anchors are enabled, visible direct member rows expose dedicated use/type-use ports. Scrolled overflow nodes fall back to class-level ports because GraphNode cannot attach ports to grandchildren inside a `ScrollContainer`.
- JSON preserves structured member links. PlantUML emits exact `Class::member` endpoints. Mermaid class diagrams retain member specificity in relationship labels because Mermaid does not provide class-member relationship endpoints.

## Visualization decoding and alternative-output contract

The populated initial dock identifies every edge category in a visible legend and explains that rendered GraphEdit direction is reversed from canonical export direction for layout. Category checkboxes and relation labels preserve meaning beyond color alone.

The Summary tab provides node, inheritance-family, edge-kind, direction, and diagnostic counts plus a visible route to JSON for exact paths, members, provenance, and diagnostics. Script paths are available through a keyboard-focusable copy action as well as hover. These measures reduce dependence on vision and hover; they do not constitute an independently verified screen-reader or color-vision-accessibility claim.

## Failure behavior

- An invalid or unreadable scan root returns an `invalid_scan_root` diagnostic and stops the scan.
- Unreadable subdirectories or files are warnings; readable results remain available.
- Scan/file safety limits produce warnings and partial results.
- Unresolved bases and type symbols are represented explicitly when external nodes are enabled.
- Snapshot validation failures return `invalid_snapshot`; unsupported formats, empty destinations, empty exporter output, temporary-write failures, commit failures, and restoration failures have distinct stable result codes and contextual paths.
- Snapshot validation never coerces schema versions, identifiers, endpoints, collection types, or diagnostic text. Required fields follow `docs/schema/snapshot-v1.schema.json`; unknown additive fields remain allowed.
- File replacement uses operation-unique same-directory temporary and backup files, restores an existing destination after a failed commit when possible, and does not claim transactional filesystem semantics. `commit_and_restore_failed` requires manual recovery using the returned backup path.
- Structured codes are the programmatic contract; reader-facing text may improve without requiring callers to parse it.

## Acceptance criteria

1. Path and `class_name` inheritance resolve in representative fixtures.
2. Native base chains include intermediary classes and render compactly.
3. Local methods, signals, and properties can be independently included or omitted.
4. Compact/full signature and property-type switches alter presentation without rescanning or discarding canonical data.
5. Literal `.gd` `load`/`preload` dependencies are optional and do not match text inside strings/comments.
6. Annotation-only dependencies are emitted as `type_uses`, separate from literal resource dependencies.
7. JSON, Mermaid, and PlantUML output is deterministic for an identical snapshot.
8. Default positions increase by inheritance depth and are deterministic within each layer.
9. Built-in GraphEdit arrangement places base/dependency nodes before descendants/dependents.
10. Named and unnamed scripts follow the naming contract, and full paths remain available through unmasked child/title tooltips.
11. Family classification distinguishes Object, RefCounted, Node, Node2D, Node3D, and Control branches.
12. Ordinary classes grow naturally and do not scroll until the configured overflow threshold is exceeded.
13. Missing roots, unsupported formats, and write failures are explicit.
14. Direct class-qualified member use retains exact source/target member provenance.
15. GraphEdit and PlantUML can render exact member endpoints; Mermaid degrades explicitly to a labeled class relationship without losing provenance from JSON.
16. Invalid snapshots cannot reach any exporter or destination file.
17. Exporters are registered only after capability and identity validation and pass the reusable exporter contract.
18. Scan roots are project-local by default and symbolic links are skipped unless explicitly enabled.
19. The populated initial view visibly decodes relation categories and rendered direction, and the Summary tab exposes a non-visual overview and exact JSON route.
20. Public add-on methods carry local API documentation, and release validation is reproducible from an isolated project copy.
