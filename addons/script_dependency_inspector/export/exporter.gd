@tool
extends RefCounted

## Behavioral contract for deterministic dependency graph exporters.
## Implementations must be stateless for a single export call and must not
## mutate the supplied canonical snapshot.


## Returns the stable lowercase format identifier used by the export service.
func format_id() -> String:
	push_error("Exporter.format_id() must be overridden.")
	return "unknown"


## Returns the human-readable format name used by the editor dock.
func display_name() -> String:
	return format_id().capitalize()


## Returns the filename extension without a leading period.
func file_extension() -> String:
	push_error("Exporter.file_extension() must be overridden.")
	return "txt"


## Declares optional representation capabilities before an export is attempted.
## Unknown capability keys are allowed for forward-compatible exporters.
func capabilities() -> Dictionary:
	return {
		"colors": false,
		"class_members": true,
		"structured_member_links": false,
		"exact_member_endpoints": false,
		"member_relation_labels": false,
	}


## Returns a deterministic textual representation of snapshot.
func export_text(_snapshot: Dictionary, _options: Dictionary = {}) -> String:
	push_error("Exporter.export_text() must be overridden.")
	return ""
