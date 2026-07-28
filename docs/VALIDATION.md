# Validation record

## Scope and completion state

Release under test: `0.1.6`.

This record covers source integrity, runtime behavior, exporter and snapshot contracts, compatibility, deterministic output, bounded performance, rendered editor review, release reproducibility, and clean-package installation. It does not convert unexecuted platforms or manual accessibility questions into implied claims.

Overall status: **conditionally accepted as a high-quality development release**. Runtime behavior is validated on the supplied Godot 4.3–4.7 Linux builds. Public distribution remains blocked by owner governance decisions listed in `QUALITY_REVIEW.md`.

## Executed environments

| Godot release | Reported version |
|---|---|
| 4.3 | `4.3.stable.official.77dcf97d8` |
| 4.4.1 | `4.4.1.stable.official.49a5bc7b6` |
| 4.5.2 | `4.5.2.stable.official.6ce3de25a` |
| 4.6.3 | `4.6.3.stable.official.7d41c59c4` |
| 4.7 | `4.7.stable.official.5b4e0cb0f` |

Each compatibility run used a separate project copy and HOME/XDG editor state so one engine's imports could not satisfy another engine's test.

## Runtime matrix

The repository-owned `tools/run_validation.py` executed the same six gates for every supplied engine:

| Godot | Version | Static | Editor/plugin | Public suite | Showcase | Performance |
|---|---:|---:|---:|---:|---:|---:|
| 4.3 | Pass | Pass | Pass | Pass | Pass | Pass |
| 4.4.1 | Pass | Pass | Pass | Pass | Pass | Pass |
| 4.5.2 | Pass | Pass | Pass | Pass | Pass | Pass |
| 4.6.3 | Pass | Pass | Pass | Pass | Pass | Pass |
| 4.7 | Pass | Pass | Pass | Pass | Pass | Pass |

Every authoritative process exited with status `0`, and the orchestrator found no add-on parse, load, or stack-underflow signature.

The editor gate parsed/imported the project, initialized the enabled plugin, loaded the dock and GraphNode scenes, and registered global classes. The public suite printed:

```text
Script Dependency Inspector tests passed.
```

The showcase gate printed:

```text
Generated showcase representations: 25 nodes, 36 edges.
```

## Static source integrity

```sh
python tools/validate_static.py
```

Final result: **299 checks passed** in both clean and imported source trees.

The validator checks required artifacts, local documentation links, resource paths, unique scene-node contracts, GraphNode ports, plugin lifecycle, compatibility guardrails, runtime-loading policy, UI and graph invariants, snapshot schema conformance, structured error contracts, scan-root protections, exporter syntax markers, public-method documentation, and optional external linters.

Editor-generated `.godot` state is excluded, so check count and outcome no longer depend on whether Godot imported the project first.

`gdlint` and `gdformat` were unavailable in the final environment. They were reported as skipped rather than represented as passing. All five supplied Godot engines independently parsed, imported, initialized, and executed the final scripts.

## Contract and negative-case evidence

The public suite and focused quality suite cover:

- path, `class_name`, add-on, global, external, and native base resolution;
- intermediary native chains and Object/RefCounted/Node/Node2D/Node3D/Control families;
- literal loads, type annotations, and direct class-qualified member use;
- exact and partial member provenance;
- deterministic layout, actual `GraphEdit.arrange_nodes()`, adaptive sizing, member ports, and class-port fallback;
- named and unnamed script titles, unmasked child tooltips, and keyboard-focusable path copying;
- JSON lossless provenance, exact PlantUML member endpoints, and Mermaid labeled fallback relations;
- duplicate node IDs, dangling edge endpoints, invalid diagnostic severities, and contradictory member references;
- invalid snapshot rejection before serialization;
- runtime validation matches the published schema for scalar types and required node/edge collections; no schema-version, identifier, or endpoint coercion is permitted;
- negative cases cover missing node member collections, missing edge `member_links`, malformed warning/error entries, and invalid scalar types;
- exporter capability, identity, determinism, non-mutation, duplicate-registration, and empty-output behavior;
- invalid absolute, `user://`, and parent-traversal scan roots;
- visible legend and non-visual Summary construction;
- missing roots, unsupported formats, replacement-write recovery, and packaged resource paths.

## Performance regression gate

The reproducible fixture analyzes 500 typed methods and builds a 1,000-script inheritance chain. Every run produced 1,002 nodes and 1,001 edges.

| Godot | Analyzer | Graph builder | Analyzer budget | Graph budget |
|---|---:|---:|---:|---:|
| 4.3 | 229.18 ms | 911.16 ms | 5,000 ms | 6,000 ms |
| 4.4.1 | 237.57 ms | 885.02 ms | 5,000 ms | 6,000 ms |
| 4.5.2 | 223.64 ms | 778.79 ms | 5,000 ms | 6,000 ms |
| 4.6.3 | 237.44 ms | 758.27 ms | 5,000 ms | 6,000 ms |
| 4.7 | 233.17 ms | 739.28 ms | 5,000 ms | 6,000 ms |

These are regression tripwires in the supplied environment, not portable latency promises or evidence that all large editor scans remain interactive.

## Cross-version deterministic output

Every engine generated the same 25-node, 36-edge canonical graph with zero diagnostics.

- Mermaid SHA-256: `570fda43952cbbc4523e51f22f41ff1a3dd8bc5440aeae063a02280406e4c07d`
- PlantUML SHA-256: `e114f27257d7565eb34b1710646a41299a8bce716ce533e0af3555f7af1ef99a`
- Normalized JSON SHA-256: `96e92129e9867a7897d5d617b7f9827b79cff633bfa45739f6fa231e7e38bb14`

JSON normalization removed only `metadata.engine_version` and serialized the remaining object with sorted keys and compact separators; nodes, edges, member provenance, diagnostics, options, style, schema, and other metadata were unchanged.

## Rendered editor review

Godot 4.7 was launched under Xvfb/Openbox at 1920×1200 with the actual **Script Dependencies** dock selected and automatically populated from the showcase. The captures are retained with the project:

- [Default populated dock](images/v0.1.6-default-dock.png)
- [Summary and exact-data route](images/v0.1.6-summary.png)
- [All dependency categories and member anchors](images/v0.1.6-advanced.png)

Observed results:

- default state: 25 nodes, 32 visible edges, zero warnings, zero errors;
- advanced state: 25 nodes, all 36 visible edges, zero warnings, zero errors;
- controls remain above GraphEdit in the narrow right dock;
- the visible legend decodes inheritance, literal/direct use, type use, and rendered direction;
- Summary exposes exact JSON as the route to paths, members, provenance, and diagnostics without requiring hover;
- native nodes remain compact and script nodes remain bounded;
- category meaning is available through labels and controls rather than color alone;
- no control collision, legend clipping, or disabled-state ambiguity was observed at the captured size.

The virtual machine lacked ALSA hardware and a Vulkan surface. Godot used dummy audio and OpenGL compatibility rendering; these environment messages were unrelated to the add-on. This internal review does not prove screen-reader usability, color-vision accessibility, keyboard completeness, or comprehension by an unfamiliar reviewer.

## Reproducible packaging and clean-package validation

`tools/build_release.py` owns release selection, archive layout, exclusions, manifest generation, member ordering, timestamps, and checksums. Two independent builds with the same source and `SOURCE_DATE_EPOCH` produced byte-identical add-on ZIPs, full-project ZIPs, and checksum files.

Final package properties:

- source manifest: **74/74 entries matched**;
- full-project archive: 75 files, including `MANIFEST.sha256`;
- add-on archive: 21 files;
- `.godot`, `__pycache__`, `.uid`, and operating-system metadata are absent;
- both `unzip -t` checks passed;
- clean extracted full project: static validation passed, Godot 4.7 editor/plugin initialization passed, public tests passed, showcase generation passed, and performance gate passed;
- add-on archive installed in five separate minimal projects: editor/plugin initialization and direct resource/scene/export-service smoke passed under Godot 4.3, 4.4.1, 4.5.2, 4.6.3, and 4.7.

The minimal smoke loaded all core scripts, validator, export service, built-in exporters, dock scene, and GraphNode scene; instantiated both UI scenes; and verified three registered export formats.

## Compatibility and evidence boundary

Validated runtime range: **Godot 4.3 through 4.7 on the supplied Linux builds**.

Unexecuted and therefore unclaimed:

- Godot 4.0–4.2;
- Windows, macOS, and other Linux configurations;
- custom engine builds;
- assistive-technology and independent comprehension testing;
- representative real-world projects at the configured maximum scan limits;
- cancellable or background editor execution.
