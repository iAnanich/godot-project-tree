# ADR 0003: project-local automation state and per-format export paths

Status: accepted

Version: 0.1.8

## Context

Auto-rescan and automatic export need to survive editor restarts without modifying `project.godot`, rewriting the distributed default settings resource, or forcing one developer's local export destinations into version control.

A single shared export path is also insufficient because JSON, Mermaid, and PlantUML are commonly consumed by different tools and directories.

## Decision

- Persist editor-only automation state in `res://.godot/script_dependency_inspector/editor_state.json`.
- Use a versioned, type-checked state dictionary.
- Keep independent enable flags and paths for JSON, Mermaid, and PlantUML.
- Let a successful manual export update the remembered path for that format.
- Supply project-customizable default paths through `default_settings.tres`.
- Start the auto-rescan one-shot timer only after scan, render, and all enabled automatic exports complete.
- Attempt automatic formats independently and log per-format failures.
- Create missing parent directories when possible.

## Alternatives considered

### Store automation in `project.godot`

Rejected because it creates project-wide diffs for per-developer workflow state and requires ProjectSettings mutation.

### Rewrite `default_settings.tres`

Rejected because the add-on's distributed resource should remain a versioned default, not mutable editor state.

### Use global `EditorSettings`

Rejected because export destinations and cadence are project-specific. Namespacing by project path would also make moved or cloned projects harder to reason about.

### Use one destination directory only

Rejected because it prevents established per-format workflows and cannot remember a manual destination exactly.

## Consequences

- `.godot` remains excluded from release archives and normal source control.
- Automation state is local to a project checkout.
- Invalid or old state can be discarded safely in favor of defaults.
- The dock remains responsible for the synchronous automation lifecycle; background execution remains a separate future design.

## Review triggers

Revisit this decision if Godot introduces a stable project-local editor-plugin settings API, if automatic exports need templates or multiple destinations per format, or if scanning moves off the editor thread.
