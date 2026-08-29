@tool
extends Resource

## Serializable settings shared by scanning, graph construction, rendering,
## and export. A project can replace the default .tres resource or edit these
## fields in the Inspector without modifying implementation code.

@export_group("Scan")
@export var include_addons: bool = true
@export var use_runtime_reflection: bool = true
@export var follow_symbolic_links: bool = false
@export_range(1, 1000000, 1) var maximum_scanned_files: int = 10000
@export_range(1, 1000000, 1) var maximum_scanned_directories: int = 20000
@export_range(1024, 67108864, 1024) var maximum_script_bytes: int = 4194304
@export_range(1024, 134217728, 1024) var maximum_scene_bytes: int = 8388608
@export var include_scene_usages: bool = true
@export var excluded_path_prefixes: PackedStringArray = PackedStringArray(
	[
		"res://.godot/",
		"res://addons/script_dependency_inspector/",
	]
)

@export_group("Automation defaults")
@export var sync_on_editor_changes: bool = true
@export_range(0.25, 30.0, 0.25) var editor_change_debounce_seconds: float = 1.0
@export var follow_active_script: bool = true
@export var focus_include_descendants: bool = false
@export var graph_view_enabled: bool = true
@export var auto_rescan_enabled: bool = false
@export_range(5.0, 86400.0, 1.0) var auto_rescan_delay_seconds: float = 60.0
@export var auto_export_json: bool = false
@export var auto_export_mermaid: bool = false
@export var auto_export_plantuml: bool = false
@export var default_export_directory: String = "res://script_dependency_exports"

@export_group("Graph content")
@export var include_native_bases: bool = true
@export var include_external_bases: bool = true
@export var include_methods: bool = true
@export var include_signals: bool = true
@export var include_properties: bool = true
@export var include_resource_dependencies: bool = false
@export var include_type_dependencies: bool = true
@export var include_member_access_dependencies: bool = false
@export var show_member_dependency_edges: bool = false
@export var show_method_signatures: bool = false
@export var show_signal_signatures: bool = false
@export var show_property_types: bool = false

@export_group("Graph colors")
@export var user_script_color: Color = Color("005a8d")
@export var addon_script_color: Color = Color("8f4f79")
@export var native_class_color: Color = Color("59616d")
@export var external_class_color: Color = Color("9a6500")
@export var property_color: Color = Color("4cc9a5")
@export var signal_color: Color = Color("d78bb7")
@export var method_color: Color = Color("6ec7f2")
@export var metadata_color: Color = Color("bec4ce")
@export var inheritance_edge_color: Color = Color("e5e7eb")
@export var dependency_edge_color: Color = Color("e69f00")
@export var type_dependency_edge_color: Color = Color("56b4e9")

@export_group("Inheritance family colors")
@export var object_family_color: Color = Color("9aa0a6")
@export var ref_counted_family_color: Color = Color("e69f00")
@export var node_family_color: Color = Color("0072b2")
@export var node_2d_family_color: Color = Color("009e73")
@export var node_3d_family_color: Color = Color("cc79a7")
@export var control_family_color: Color = Color("d55e00")
@export var other_family_color: Color = Color("6f7682")

@export_group("Graph layout")
@export_range(160.0, 600.0, 10.0) var graph_node_width: float = 230.0
@export_range(180.0, 1000.0, 10.0) var graph_node_max_width: float = 420.0
@export_range(100.0, 360.0, 10.0) var native_node_width: float = 150.0
@export_range(8.0, 200.0, 4.0) var graph_sibling_spacing: float = 36.0
@export_range(24.0, 400.0, 4.0) var graph_layer_spacing: float = 80.0
@export_range(80.0, 1200.0, 10.0) var graph_max_member_height: float = 520.0
@export_range(1, 200, 1) var graph_max_members_per_section: int = 50
@export_range(12, 160, 1) var graph_title_character_limit: int = 48
@export_range(24, 320, 1) var graph_member_character_limit: int = 120
@export_range(1.0, 12.0, 0.5) var graph_connection_thickness: float = 3.0
@export var graph_minimap_enabled: bool = true
@export var graph_show_zoom_label: bool = true
@export var graph_depth_top_to_bottom: bool = true
@export var arrange_with_engine_when_available: bool = false


## Returns scanner inputs in a serialization-friendly form.
func to_scan_options() -> Dictionary:
	return {
		"include_addons": include_addons,
		"use_runtime_reflection": use_runtime_reflection,
		"follow_symbolic_links": follow_symbolic_links,
		"maximum_scanned_files": maximum_scanned_files,
		"maximum_scanned_directories": maximum_scanned_directories,
		"maximum_script_bytes": maximum_script_bytes,
		"maximum_scene_bytes": maximum_scene_bytes,
		"include_scene_usages": include_scene_usages,
		"excluded_path_prefixes": excluded_path_prefixes.duplicate(),
	}


## Returns graph-content options and the current style snapshot.
func to_graph_options() -> Dictionary:
	return {
		"include_native_bases": include_native_bases,
		"include_external_bases": include_external_bases,
		"include_methods": include_methods,
		"include_signals": include_signals,
		"include_properties": include_properties,
		"include_resource_dependencies": include_resource_dependencies,
		"include_type_dependencies": include_type_dependencies,
		"include_member_access_dependencies": include_member_access_dependencies,
		"show_member_dependency_edges": show_member_dependency_edges,
		"show_method_signatures": show_method_signatures,
		"show_signal_signatures": show_signal_signatures,
		"show_property_types": show_property_types,
		"style": to_style_dictionary(),
	}


## Returns colors and layout values in deterministic serializable form.
func to_style_dictionary() -> Dictionary:
	return {
		"user_script_color": user_script_color.to_html(false),
		"addon_script_color": addon_script_color.to_html(false),
		"native_class_color": native_class_color.to_html(false),
		"external_class_color": external_class_color.to_html(false),
		"property_color": property_color.to_html(false),
		"signal_color": signal_color.to_html(false),
		"method_color": method_color.to_html(false),
		"metadata_color": metadata_color.to_html(false),
		"inheritance_edge_color": inheritance_edge_color.to_html(false),
		"dependency_edge_color": dependency_edge_color.to_html(false),
		"type_dependency_edge_color": type_dependency_edge_color.to_html(false),
		"object_family_color": object_family_color.to_html(false),
		"ref_counted_family_color": ref_counted_family_color.to_html(false),
		"node_family_color": node_family_color.to_html(false),
		"node_2d_family_color": node_2d_family_color.to_html(false),
		"node_3d_family_color": node_3d_family_color.to_html(false),
		"control_family_color": control_family_color.to_html(false),
		"other_family_color": other_family_color.to_html(false),
		"graph_node_width": graph_node_width,
		"graph_node_max_width": graph_node_max_width,
		"native_node_width": native_node_width,
		"graph_sibling_spacing": graph_sibling_spacing,
		"graph_layer_spacing": graph_layer_spacing,
		"graph_max_member_height": graph_max_member_height,
		"graph_max_members_per_section": graph_max_members_per_section,
		"graph_title_character_limit": graph_title_character_limit,
		"graph_member_character_limit": graph_member_character_limit,
		"graph_connection_thickness": graph_connection_thickness,
		"graph_minimap_enabled": graph_minimap_enabled,
		"graph_show_zoom_label": graph_show_zoom_label,
		"graph_depth_top_to_bottom": graph_depth_top_to_bottom,
	}


## Returns project-customizable defaults for persisted editor state.
func to_editor_state_defaults() -> Dictionary:
	var directory: String = default_export_directory.strip_edges().trim_suffix("/")
	if directory.is_empty():
		directory = "res://script_dependency_exports"
	return {
		"schema_version": 4,
		"scan_root": "res://",
		"recent_scan_roots": ["res://"],
		"focus_include_descendants": focus_include_descendants,
		"isolate_neighborhood": false,
		"graph_view_enabled": graph_view_enabled,
		"control_section_expanded":
		{
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
			"automation_editor": true,
			"automation_timed": false,
			"automation_export": true,
		},
		"sync_on_editor_changes": sync_on_editor_changes,
		"editor_change_debounce_seconds": editor_change_debounce_seconds,
		"follow_active_script": follow_active_script,
		"auto_rescan_enabled": auto_rescan_enabled,
		"auto_rescan_delay_seconds": auto_rescan_delay_seconds,
		"auto_export":
		{
			"json": auto_export_json,
			"mermaid": auto_export_mermaid,
			"plantuml": auto_export_plantuml,
		},
		"export_paths":
		{
			"json": directory + "/script_dependencies.json",
			"mermaid": directory + "/script_dependencies.mmd",
			"plantuml": directory + "/script_dependencies.puml",
		},
	}


## Compatibility alias for integrations written before editor state expanded beyond automation.
func to_automation_defaults() -> Dictionary:
	return to_editor_state_defaults()
