# Compatibility policy

Version: 0.3.0
Issue date: 2026-08-27

The supported release claim is limited to the supplied Linux x86_64 editor builds of Godot 4.3, 4.4.1, 4.5.2, 4.6.3, and 4.7. A source-level inspection does not establish compatibility. Each release must execute the required isolated runtime gates on each claimed engine before the release is described as verified.

The implementation retains the established Godot 4 dock API and capability-checks optional editor APIs. Snapshot schema v2 and editor-state schema v4 remain the public serialized compatibility surfaces for v0.3.0.

v0.3.0 intentionally changes one analysis behavior: the scanner no longer loads analyzed project GDScript resources for reflection. The legacy `use_runtime_reflection` configuration field remains readable as a compatibility no-op. Missing metadata that cannot be resolved from source, project metadata, the global-class registry, or `ClassDB` remains unresolved rather than causing project-script execution.

Release-specific engine identifiers, gate results, failures, and limitations belong in external delivery evidence. Historical verification reports are not retained as active repository knowledge.
