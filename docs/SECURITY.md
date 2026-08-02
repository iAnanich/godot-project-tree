# Security and trust boundary

Version: 0.2.2

The add-on runs inside the Godot editor with the editor process's filesystem permissions. It does not provide network access, execute external processes, or instantiate scanned project classes as part of analysis.

## Untrusted project input

GDScript and `.tscn` text are treated as bounded input. Traversal rejects roots outside `res://`, skips symbolic links by default, honors file/directory/byte limits, and records read failures. The scene scanner recognizes only direct textual constructs and does not evaluate resource expressions. Binary `.scn` files are outside scope.

Optional Script resource loading for reflection can trigger Godot parsing, but not project-class instantiation. Source-only analysis remains available.

## Scope is not a trust boundary

A selected folder is a display/export projection. The scanner still acquires the bounded full `res://` index so ancestors and direct dependency targets outside the folder can be resolved. Users must not treat folder scope as preventing the add-on from reading other project files. The selected root is validated as an existing project-local directory, but it does not grant or revoke filesystem authority.

## Writes

Exports write only to user-selected or configured paths. Missing directories may be created. Existing files use same-directory temporary and backup paths with rollback attempts. Editor preferences are stored below `res://.godot` and excluded from release archives.

Editor synchronization suppresses filesystem notifications only around configured project-local export writes to avoid loops. This is a control-flow safeguard, not a security sandbox. Timed rescanning is disabled by default.
