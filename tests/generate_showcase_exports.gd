extends SceneTree

const ADDON_ROOT: String = "res://addons/script_dependency_inspector/"
const OUTPUT_ROOT: String = "res://examples/showcase/representations/"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scanner_script = _load_script(ADDON_ROOT + "core/project_scanner.gd")
	var builder_script = _load_script(ADDON_ROOT + "core/graph_builder.gd")
	var export_service_script = _load_script(ADDON_ROOT + "export/export_service.gd")
	if scanner_script == null or builder_script == null or export_service_script == null:
		quit(1)
		return

	var scanner = scanner_script.new()
	var builder = builder_script.new()
	var export_service = export_service_script.new()
	var scan_result: Dictionary = (
		scanner
		. scan(
			"res://",
			{
				"include_addons": true,
				"use_runtime_reflection": true,
				"excluded_path_prefixes":
				PackedStringArray(
					[
						"res://.godot/",
						"res://addons/script_dependency_inspector/",
						"res://tests/",
					]
				),
			}
		)
	)
	if not scan_result["errors"].is_empty():
		push_error("Showcase scan failed: %s" % [scan_result["errors"]])
		quit(1)
		return

	var snapshot: Dictionary = (
		builder
		. build(
			scan_result,
			{
				"include_native_bases": true,
				"include_external_bases": true,
				"include_methods": true,
				"include_signals": true,
				"include_properties": true,
				"include_resource_dependencies": true,
				"include_type_dependencies": true,
				"include_member_access_dependencies": true,
				"show_member_dependency_edges": true,
				"show_method_signatures": false,
				"show_signal_signatures": false,
				"show_property_types": false,
				"style":
				{
					"user_script_color": "4f7cac",
					"addon_script_color": "8e6c9f",
					"native_class_color": "65737e",
					"external_class_color": "9b7653",
				},
			}
		)
	)
	if not snapshot["errors"].is_empty():
		push_error("Showcase graph build failed: %s" % [snapshot["errors"]])
		quit(1)
		return

	var exports = [
		["json", OUTPUT_ROOT + "showcase.json"],
		["mermaid", OUTPUT_ROOT + "showcase.mmd"],
		["plantuml", OUTPUT_ROOT + "showcase.puml"],
	]
	for export_spec in exports:
		var result: Dictionary = export_service.export_to_file(
			str(export_spec[0]), str(export_spec[1]), snapshot, {"include_colors": true}
		)
		if not result["ok"]:
			push_error("Showcase export failed: %s" % result["error"])
			quit(1)
			return

	print(
		(
			"Generated showcase representations: %s nodes, %s edges."
			% [snapshot["nodes"].size(), snapshot["edges"].size()]
		)
	)
	quit(0)


func _load_script(path: String) -> Script:
	if not FileAccess.file_exists(path):
		push_error("Required showcase generator script is missing: %s" % path)
		return null
	var resource = ResourceLoader.load(path)
	if resource == null or not resource is Script:
		push_error("Required showcase generator script could not be loaded: %s" % path)
		return null
	return resource as Script
