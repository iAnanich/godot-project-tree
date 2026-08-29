# Script Dependency Inspector — design document

Version: 0.2.4
Status: implemented; release evidence recorded in `VALIDATION.md`

## 1. Product purpose

Script Dependency Inspector is an editor-only Godot 4 add-on for understanding and exporting the static structure of a GDScript project. It builds one deterministic validated snapshot, supports scoped/focused inspection and source navigation, and exports JSON, Mermaid, or PlantUML. GraphEdit is an optional interactive presentation surface rather than a prerequisite for scanning or export.

The intended user outcomes are defined in [USE_CASES.md](USE_CASES.md).

## 2. Scope and non-goals

Included: GDScript/native inheritance, supported dependency evidence, declarations and locations, autoload/text-scene context, scoped projections, search/focus/navigation, editor synchronization, optional timed fallback, optional graph rendering, and validated file exports.

Excluded: project-script execution as analysis; general inferred call graphs; runtime profiling; alias/DI/reflection/dynamic-path inference; binary-scene interpretation; TODO extraction; immediate main-screen placement; background/cancellable scanning; and the deferred v0.3.0 behavioral-evidence proposal until a later scope is approved.

## 3. User workflows

### Interactive inspection

1. Scan manually or through default editor-save synchronization.
2. Optionally select a project-folder scope.
3. Keep **Graph** enabled to search, focus, isolate, and navigate evidence.
4. Use foldable control groups to expose only the relevant semantic or presentation options.

### Export-only operation

1. Disable **Graph** in the toolbar.
2. Scan and validate normally; summary, diagnostics, and synchronization remain active.
3. Export JSON, Mermaid, or PlantUML manually or automatically.
4. Open diagram files in dedicated tools for larger canvases, renderer-specific layout, themes, or presentation workflows.
5. Re-enable **Graph** to render the retained snapshot without rescanning.

### Scan trigger visibility

The indicator next to **Scan** derives from the two independent settings:

- editor save/import synchronization, default on;
- timed fallback, default off.

It displays `Save sync`, `Timed`, `Save + timed`, or `Manual`; the tooltip contains actual quiet-period and delay values.

## 4. Architecture

```text
Editor/file-system signals ─► debounce/pending coordinator ─┐
Controls + editor state ────────────────────────────────────┤
                                                          ▼
ProjectScanner(full bounded index) ─► analyzers ─► GraphBuilder
                                                   │
                                                   ▼
                                           full snapshot v2
                                                   │
                                           SnapshotScope
                                                   │
                                        scoped snapshot v2
                        ┌──────────────────────────┼──────────────────────┐
                        ▼                          ▼                      ▼
               SnapshotValidator              GraphQuery           ExportService
                        │                          │                 JSON/MMD/PUML
                        │                    optional renderer
                        └─ summary/diagnostics     │
                                                   ▼
                                                GraphEdit
```

Graph rendering is downstream of validation and independently switchable. Exporters never depend on GraphNode state.

## 5. UI hierarchy

The toolbar uses task priority rather than equal expansion:

- immediate scan action;
- adjacent scan-mode state;
- explicit action gap/separator;
- manual export action and compact format choice;
- flexible remainder;
- default-on Graph visibility toggle.

Control tabs retain their semantic domains but use foldable subsections:

- **Content:** scripts/classes, members/signatures, relationship evidence, diagram export styling;
- **Appearance:** sizing, density/overflow, layout;
- **Colors:** node roles, member text, relations, inheritance families;
- **Automation:** editor synchronization, timed fallback, automatic file exports.

The headings are controls with visible expanded/collapsed state and tooltips. Folding alters only layout.

## 6. Persisted editor state

Editor-state schema v4 adds:

```json
{
  "schema_version": 4,
  "graph_view_enabled": true,
  "control_section_expanded": {
    "content_sources": true,
    "content_members": true,
    "content_relations": true,
    "content_export": false,
    "appearance_sizing": true,
    "appearance_density": false,
    "appearance_layout": true,
    "colors_nodes": true,
    "colors_members": false,
    "colors_relations": false,
    "colors_families": false,
    "automation_sync": true,
    "automation_timed": false,
    "automation_exports": true
  }
}
```

Schemas 1–3 are accepted and merged with v4 defaults. Unknown fold keys are ignored. Malformed state degrades to defaults.

## 7. Graph visibility lifecycle

- Disabling the graph hides graph-only search/focus/legend surfaces and releases rendered GraphNodes.
- The latest scoped snapshot, summary, diagnostics, and exporter availability remain.
- Active-script following and search presentation are dormant while hidden.
- Enabling the graph rerenders the retained snapshot and reapplies relevant presentation state.
- No scan is initiated solely by toggling graph visibility.

## 8. Validation contract

Required evidence includes compact-toolbar scene contracts; default and combined indicator states; graph-off retention and graph-on rerender tests; state schema v4 round-trip and schema 1–3 migration; tooltip presence for all option/fold controls; rendered overview, export-only, folded-control, and automation states; parser/import and all existing behavioral/export/performance gates under Godot 4.3–4.7; and documentation/AI-disclosure consistency checks.

## 9. Project-local scope normalization

The scope chooser is configured for resource access, but native dialogs may still report an absolute filesystem path on some editor/platform combinations. `ProjectScanner.validate_root()` is the single normalization boundary: it rejects parent traversal first, localizes absolute paths through `ProjectSettings.localize_path()`, requires the result to be `res://`-local, verifies directory existence, and returns only the canonical project path. The scan method uses the same boundary, so UI and programmatic callers cannot diverge.

## 10. Repository and release tooling

The public repository retains product documentation, contracts, ADRs, use cases, schemas, security/performance guidance, compatibility evidence, and release instructions. Internal quality-review reports, rendered-review notes, and broad related-project surveys are not release-source documents. Necessary third-party consideration/provenance is retained narrowly in the relevant ADR and NOTICE.

Redistribution and upgrades are repository-owned operations:

- `tools/package_addon.py` creates the installable add-on ZIP;
- `tools/build_release.py` creates deterministic add-on, full-project, and Asset Library upload-media archives;
- `tools/build_patch.py` creates and verifies a binary-capable Git patch between release refs;
- pre-commit runs pinned `gdformat` and `gdlint`;
- tag-triggered GitHub Actions verify, package, patch, and attach artifacts to a GitHub Release.

## 11. Provenance

Project Mapper remains a late consideration for the interaction features attributed in ADR 0006 and NOTICE. No Project Mapper source was copied.

## Asset Library media pipeline

Release media is a source-controlled documentation subsystem. A deliberately small `examples/media_showcase` slice produces focused dock captures, while the existing showcase provides the complex-project view. The editor-navigation state is captured from the actual Godot Script Editor through a temporary, disabled-by-default helper plugin. Approved PNG captures are transformed to 1920×1080 WebP files, declared in `docs/asset_store/media_manifest.json`, and rejected when they are not 16:9, fall below 1280×720, exceed 600 KB, or diverge from the manifest.

The thumbnail may add titles and callouts, but must embed a real runtime screenshot. Synthetic or AI-generated replacement graphs are outside the media contract.
