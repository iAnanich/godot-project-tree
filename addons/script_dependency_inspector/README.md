# Script Dependency Inspector 0.4.0

Editor-only Godot 4 add-on that scans GDScript and exact text-scene script attachments, builds a validated dependency snapshot, optionally renders an interactive searchable graph, and exports JSON, Mermaid, or PlantUML.

The **Graph** toggle is enabled by default. Disable it for export-only operation: scans, editor-save synchronization, summaries, diagnostics, and manual/automatic file exports remain active. Re-enable it to render the retained snapshot without rescanning. The compact toolbar shows whether automatic scans are save-synchronized, timed, both, or manual.

Exported Mermaid and PlantUML files can be opened in dedicated diagram applications for larger canvases, alternate layout engines, themes, or presentation workflows. JSON is the lossless machine-readable representation for automation and custom renderers.

Graph connections expose relationship-specific hover evidence, including canonical dependency direction and represented source occurrences. Member rows expose full declaration/signature details and static incoming/outgoing evidence counts while keeping the visible graph compact.

Folder scopes accept either `res://` selections or absolute paths returned by native dialogs, normalize project-local paths to `res://`, and retain required outside ancestors and direct dependency targets as labelled **Context**. Search, focus, source navigation, autoload metadata, and exact text-scene attachments remain available when the graph is shown.

Generative AI was used extensively under owner-directed scope and documented automated quality controls. See `AI_USAGE_NOTICE.md` for uses, supervision, executed checks, and residual evidence limits.

Static-analysis limits are deliberate: no general inferred call graph, runtime profiling, dynamic-path evaluation, project-class instantiation, binary-scene inference, or TODO extraction.

## Analysis trust boundary

Dependency discovery reads saved project source and metadata. It does not load analyzed project GDScript resources for reflection or execute analyzed project classes. Missing unsupported relationships are omitted or diagnosed rather than inferred.
