# ADR 0008 — Project-local scope paths and repository-owned release artifacts

Status: accepted for v0.2.3  
Date: 2026-08-02

## Context

Godot `FileDialog` can expose an absolute filesystem path even when the intended choice is a folder under the project. The scope boundary previously accepted only text beginning with `res://`, so a valid native-dialog selection could be rejected. Release archives and patches also need a repeatable owner-operated path rather than chat-specific reconstruction.

## Decision

1. Treat `ProjectScanner.validate_root()` as the only scope-path normalization boundary.
2. Accept `res://` directories directly.
3. Accept absolute paths only when `ProjectSettings.localize_path()` converts them to a `res://` path in the current project.
4. Store and expose only the canonical `res://` form.
5. Continue rejecting `user://`, outside-project absolute paths, parent traversal, missing directories, and empty input.
6. Keep release production in repository scripts:
   - add-on ZIP;
   - complete project ZIP and manifest;
   - complete binary-capable Git patch plus review text patch, diffstat, notes, and checksums;
   - automatic previous-tag inference for the normal local patch command.
7. Run pinned `gdformat` and `gdlint` before commits and in GitHub quality/release workflows.
8. Keep public product/design/decision/validation documentation in the repository, but do not retain internal review reports or broad comparison surveys as release-source documentation.

## Consequences

- Native folder dialogs and direct API callers share the same behavior.
- Scope state remains portable because absolute machine paths are not persisted.
- Every tagged release can publish a full bundle and a verified patch from the preceding reachable release tag.
- The first hook run requires network access to install the pinned tooling unless its pre-commit environment is already cached.
- Necessary Project Mapper attribution remains narrowly in ADR 0006 and NOTICE; no dedicated comparison document is required.
