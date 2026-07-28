@tool
extends "res://addons/script_dependency_inspector/export/exporter.gd"


## Returns the stable format identifier used by ExportService.
func format_id() -> String:
	return "json"


## Returns the reader-facing format name used by the dock.
func display_name() -> String:
	return "JSON"


## Returns the default filename extension without a period.
func file_extension() -> String:
	return "json"


## JSON preserves the complete canonical model, including structured member links.
func capabilities() -> Dictionary:
	return {
		"colors": true,
		"class_members": true,
		"structured_member_links": true,
		"exact_member_endpoints": true,
		"member_relation_labels": true,
	}


## Serializes the validated canonical snapshot without representation loss.
func export_text(snapshot: Dictionary, _options: Dictionary = {}) -> String:
	return JSON.stringify(snapshot, "\t", true) + "\n"
