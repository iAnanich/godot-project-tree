# Security and operational safety

## Trust model

This add-on runs inside the Godot editor with the editor process's filesystem permissions. It is not a sandbox. Projects, installed add-ons, custom exporters, and destination paths must be treated according to the trust granted to the editor process.

## Source scanning

The source analyzer reads `.gd` files as text and does not instantiate user classes. Scan roots are restricted to the current project's `res://` namespace. Parent traversal, absolute paths, and `user://` roots are rejected.

Symbolic links are skipped by default. Enabling `follow_symbolic_links` is an explicit trust decision; traversal remains bounded by maximum file and directory counts, but the add-on does not claim to confine a followed operating-system link to the project directory.

Per-script byte limits, total file limits, and directory limits reduce accidental denial-of-service from very large projects or cyclic directory structures.

## Optional runtime reflection

`use_runtime_reflection` loads script resources through Godot to improve global-name and base resolution. The add-on still does not instantiate user scripts, but resource loading invokes Godot's parser/compiler and is not equivalent to treating input as inert text. Disable runtime reflection when inspecting source that should not be trusted by the current editor process.

The plugin cannot make opening an untrusted Godot project safe: the editor may import resources and enable other project tooling independently of this add-on.

## Exports

Exports are written only after an explicit user destination is selected or a caller invokes the export API. The service validates the snapshot, writes a temporary file in the destination directory, stages an existing destination to an operation-unique backup, and restores that backup when commit fails where possible.

Failure results contain stable codes and recovery context. A `commit_and_restore_failed` result is an operational incident: the returned backup path must be preserved for manual recovery.

## Extension boundary

Custom exporters run with the same authority as the editor. The exporter method contract and contract tests provide behavioral compatibility, not isolation. Do not register untrusted exporter code.

## Reporting a vulnerability

This package does not yet declare a public security contact or disclosure channel. That must be resolved by the project owner before public distribution. Until then, do not include secrets or private project data in public issue reports.
