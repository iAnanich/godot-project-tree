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
@export var excluded_path_prefixes: PackedStringArray = PackedStringArray(
	[
		"res://.godot/",
		"res://addons/script_dependency_inspector/",
	]
)

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
@export var user_script_color: Color = Color("4f7cac")
@export var addon_script_color: Color = Color("8e6c9f")
@export var native_class_color: Color = Color("65737e")
@export var external_class_color: Color = Color("9b7653")
@export var property_color: Color = Color("98c379")
@export var signal_color: Color = Color("c678dd")
@export var method_color: Color = Color("61afef")
@export var metadata_color: Color = Color("abb2bf")
@export var inheritance_edge_color: Color = Color("d8dee9")
@export var dependency_edge_color: Color = Color("e5c07b")
@export var type_dependency_edge_color: Color = Color("56b6c2")

@export_group("Inheritance family colors")
@export var object_family_color: Color = Color("9aa0a6")
@export var ref_counted_family_color: Color = Color("c8a96b")
@export var node_family_color: Color = Color("5c9ded")
@export var node_2d_family_color: Color = Color("53c7a2")
@export var node_3d_family_color: Color = Color("b983ff")
@export var control_family_color: Color = Color("f08c78")
@export var other_family_color: Color = Color("7f8c8d")

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
