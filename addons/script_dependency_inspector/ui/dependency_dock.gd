@tool
extends VBoxContainer

const ADDON_ROOT: String = "res://addons/script_dependency_inspector/"
const SETTINGS_SCRIPT_PATH: String = ADDON_ROOT + "core/settings.gd"
const DEFAULT_SETTINGS_PATH: String = ADDON_ROOT + "default_settings.tres"
const LOGGER_SCRIPT_PATH: String = ADDON_ROOT + "core/logger.gd"
const SCANNER_SCRIPT_PATH: String = ADDON_ROOT + "core/project_scanner.gd"
const GRAPH_BUILDER_SCRIPT_PATH: String = ADDON_ROOT + "core/graph_builder.gd"
const EXPORT_SERVICE_SCRIPT_PATH: String = ADDON_ROOT + "export/export_service.gd"
const COMPAT_SCRIPT_PATH: String = ADDON_ROOT + "core/compat.gd"
const GRAPH_NODE_SCRIPT_PATH: String = ADDON_ROOT + "ui/dependency_graph_node.gd"
const GRAPH_NODE_SCENE_PATH: String = ADDON_ROOT + "ui/dependency_graph_node.tscn"

@export var settings: Resource
@export var auto_scan_on_open: bool = false

var _editor_interface: EditorInterface
var _logger
var _scanner
var _builder
var _export_service
var _compat_script: Script
var _graph_node_scene: PackedScene
var _initialization_errors: Array[String] = []
var _snapshot: Dictionary = {}
var _graph_nodes: Array = []
var _id_to_graph_name: Dictionary = {}
var _suppress_control_events: bool = false

@onready var scan_button: Button = %ScanButton
@onready var export_button: Button = %ExportButton
@onready var format_option: OptionButton = %FormatOption
@onready var status_label: Label = %StatusLabel
@onready var legend_view: RichTextLabel = %LegendView
@onready var summary_view: RichTextLabel = %SummaryView
@onready var graph_edit: GraphEdit = %GraphEdit
@onready var file_dialog: FileDialog = %FileDialog
@onready var include_addons_check: CheckBox = %IncludeAddons
@onready var include_native_check: CheckBox = %IncludeNative
@onready var include_external_check: CheckBox = %IncludeExternal
@onready var include_methods_check: CheckBox = %IncludeMethods
@onready var include_signals_check: CheckBox = %IncludeSignals
@onready var include_properties_check: CheckBox = %IncludeProperties
@onready var include_dependencies_check: CheckBox = %IncludeDependencies
@onready var include_type_dependencies_check: CheckBox = %IncludeTypeDependencies
@onready var include_member_access_dependencies_check: CheckBox = %IncludeMemberAccessDependencies
@onready var show_member_dependency_edges_check: CheckBox = %ShowMemberDependencyEdges
@onready var method_signatures_check: CheckBox = %MethodSignatures
@onready var signal_signatures_check: CheckBox = %SignalSignatures
@onready var property_types_check: CheckBox = %PropertyTypes
@onready var export_colors_check: CheckBox = %ExportColors
@onready var graph_node_width_spin: SpinBox = %GraphNodeWidth
@onready var graph_node_max_width_spin: SpinBox = %GraphNodeMaxWidth
@onready var native_node_width_spin: SpinBox = %NativeNodeWidth
@onready var max_members_spin: SpinBox = %MaxMembers
@onready var max_member_height_spin: SpinBox = %MaxMemberHeight
@onready var sibling_spacing_spin: SpinBox = %SiblingSpacing
@onready var layer_spacing_spin: SpinBox = %LayerSpacing
@onready var depth_top_to_bottom_check: CheckBox = %DepthTopToBottom
@onready var user_color_picker: ColorPickerButton = %UserColor
@onready var addon_color_picker: ColorPickerButton = %AddonColor
@onready var native_color_picker: ColorPickerButton = %NativeColor
@onready var external_color_picker: ColorPickerButton = %ExternalColor
@onready var property_color_picker: ColorPickerButton = %PropertyColor
@onready var signal_color_picker: ColorPickerButton = %SignalColor
@onready var method_color_picker: ColorPickerButton = %MethodColor
@onready var metadata_color_picker: ColorPickerButton = %MetadataColor
@onready var inheritance_color_picker: ColorPickerButton = %InheritanceColor
@onready var dependency_color_picker: ColorPickerButton = %DependencyColor
@onready var type_dependency_color_picker: ColorPickerButton = %TypeDependencyColor
@onready var object_family_color_picker: ColorPickerButton = %ObjectFamilyColor
@onready var ref_counted_family_color_picker: ColorPickerButton = %RefCountedFamilyColor
@onready var node_family_color_picker: ColorPickerButton = %NodeFamilyColor
@onready var node_2d_family_color_picker: ColorPickerButton = %Node2DFamilyColor
@onready var node_3d_family_color_picker: ColorPickerButton = %Node3DFamilyColor
@onready var control_family_color_picker: ColorPickerButton = %ControlFamilyColor
@onready var other_family_color_picker: ColorPickerButton = %OtherFamilyColor
@onready var log_view: RichTextLabel = %LogView


## Supplies the editor interface after scene instantiation.
func setup(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


func _ready() -> void:
	if not _initialize_dependencies():
		_present_initialization_failure()
		return
	_scanner.logger = _logger
	_builder.logger = _logger
	_export_service.logger = _logger
	_logger.entry_added.connect(_on_log_entry)
	scan_button.pressed.connect(scan_project)
	export_button.pressed.connect(_open_export_dialog)
	file_dialog.file_selected.connect(_on_export_path_selected)
	format_option.item_selected.connect(_on_export_format_selected)
	_populate_formats()
	_load_settings_into_controls()
	_connect_option_controls()
	_apply_graph_settings()
	export_button.disabled = true
	if auto_scan_on_open:
		call_deferred("scan_project")


func _initialize_dependencies() -> bool:
	var settings_script = _load_required_script(SETTINGS_SCRIPT_PATH, "settings")
	var default_settings = _load_required_resource(DEFAULT_SETTINGS_PATH, "default settings")
	var logger_script = _load_required_script(LOGGER_SCRIPT_PATH, "logger")
	var scanner_script = _load_required_script(SCANNER_SCRIPT_PATH, "project scanner")
	var builder_script = _load_required_script(GRAPH_BUILDER_SCRIPT_PATH, "graph builder")
	var export_service_script = _load_required_script(EXPORT_SERVICE_SCRIPT_PATH, "export service")
	_compat_script = _load_required_script(COMPAT_SCRIPT_PATH, "compatibility shim")
	_load_required_script(GRAPH_NODE_SCRIPT_PATH, "graph node")
	_graph_node_scene = _load_required_scene(GRAPH_NODE_SCENE_PATH, "graph node")
	if not _initialization_errors.is_empty():
		return false

	_logger = logger_script.new()
	_scanner = scanner_script.new()
	_builder = builder_script.new()
	_export_service = export_service_script.new()
	if _logger == null or _scanner == null or _builder == null or _export_service == null:
		_record_initialization_error("Could not instantiate one or more required plugin services.")
		return false
	if settings == null:
		settings = default_settings.duplicate(true)
		if settings == null and settings_script != null:
			settings = settings_script.new()
	else:
		settings = settings.duplicate(true)
	if settings == null:
		_record_initialization_error("Could not create dependency inspector settings resource.")
		return false
	for required_method in ["to_scan_options", "to_graph_options", "to_style_dictionary"]:
		if not settings.has_method(required_method):
			_record_initialization_error(
				"Settings resource is missing required method '%s': %s"
				% [required_method, DEFAULT_SETTINGS_PATH]
			)
	if _export_service.has_method("initialization_errors"):
		for error_value in _export_service.call("initialization_errors"):
			_record_initialization_error(str(error_value))
	return _initialization_errors.is_empty()


func _load_required_resource(path: String, role: String) -> Resource:
	if not FileAccess.file_exists(path):
		_record_initialization_error("Missing %s resource: %s" % [role, path])
		return null
	var resource = ResourceLoader.load(path)
	if resource == null:
		_record_initialization_error("Could not load %s resource: %s" % [role, path])
		return null
	return resource


func _load_required_script(path: String, role: String) -> Script:
	if not FileAccess.file_exists(path):
		_record_initialization_error("Missing %s script: %s" % [role, path])
		return null
	var resource = ResourceLoader.load(path)
	if resource == null or not resource is Script:
		_record_initialization_error("Could not load %s script: %s" % [role, path])
		return null
	return resource as Script


func _load_required_scene(path: String, role: String) -> PackedScene:
	if not FileAccess.file_exists(path):
		_record_initialization_error("Missing %s scene: %s" % [role, path])
		return null
	var resource = ResourceLoader.load(path)
	if resource == null or not resource is PackedScene:
		_record_initialization_error("Could not load %s scene: %s" % [role, path])
		return null
	return resource as PackedScene


func _record_initialization_error(message: String) -> void:
	if not _initialization_errors.has(message):
		_initialization_errors.append(message)
	push_error(message)


func _present_initialization_failure() -> void:
	scan_button.disabled = true
	export_button.disabled = true
	status_label.text = "Plugin initialization failed; see the Log tab."
	log_view.clear()
	for message in _initialization_errors:
		log_view.append_text("[ERROR] %s\n" % message)


## Scans the project, rebuilds the canonical snapshot, and redraws the graph.
func scan_project() -> void:
	if not _initialization_errors.is_empty():
		_present_initialization_failure()
		return
	_capture_controls_into_settings()
	scan_button.disabled = true
	export_button.disabled = true
	status_label.text = "Scanning…"
	_logger.clear()
	log_view.clear()
	var scan_result: Dictionary = _scanner.scan("res://", settings.call("to_scan_options"))
	_snapshot = _builder.build(scan_result, settings.call("to_graph_options"))
	_render_snapshot()
	scan_button.disabled = false
	export_button.disabled = _snapshot.get("nodes", []).is_empty()
	status_label.text = (
		"%s nodes · %s edges · %s warnings · %s errors"
		% [
			_snapshot.get("nodes", []).size(),
			_snapshot.get("edges", []).size(),
			_snapshot.get("warnings", []).size(),
			_snapshot.get("errors", []).size(),
		]
	)
	for warning_value in _snapshot.get("warnings", []):
		_logger.warning(str(warning_value))
	for error_value in _snapshot.get("errors", []):
		_logger.error(str(error_value))


func _connect_option_controls() -> void:
	for control in [
		include_addons_check,
		include_native_check,
		include_external_check,
		include_methods_check,
		include_signals_check,
		include_properties_check,
		include_dependencies_check,
		include_type_dependencies_check,
		include_member_access_dependencies_check,
	]:
		control.toggled.connect(_on_scan_option_changed)
	for control in [
		method_signatures_check,
		signal_signatures_check,
		property_types_check,
		show_member_dependency_edges_check,
	]:
		control.toggled.connect(_on_display_option_changed)
	depth_top_to_bottom_check.toggled.connect(_on_appearance_changed)
	for spin in [
		graph_node_width_spin,
		graph_node_max_width_spin,
		native_node_width_spin,
		max_members_spin,
		max_member_height_spin,
		sibling_spacing_spin,
		layer_spacing_spin,
	]:
		spin.value_changed.connect(_on_appearance_value_changed)
	for picker in [
		user_color_picker,
		addon_color_picker,
		native_color_picker,
		external_color_picker,
		property_color_picker,
		signal_color_picker,
		method_color_picker,
		metadata_color_picker,
		inheritance_color_picker,
		dependency_color_picker,
		type_dependency_color_picker,
		object_family_color_picker,
		ref_counted_family_color_picker,
		node_family_color_picker,
		node_2d_family_color_picker,
		node_3d_family_color_picker,
		control_family_color_picker,
		other_family_color_picker,
	]:
		picker.color_changed.connect(_on_color_changed)


func _populate_formats() -> void:
	format_option.clear()
	for descriptor_value in _export_service.format_descriptors():
		var descriptor: Dictionary = descriptor_value
		format_option.add_item(str(descriptor["name"]))
		format_option.set_item_metadata(format_option.item_count - 1, str(descriptor["id"]))
	if format_option.item_count > 0:
		format_option.select(0)
		_on_export_format_selected(0)


func _load_settings_into_controls() -> void:
	_suppress_control_events = true
	include_addons_check.button_pressed = bool(settings.get("include_addons"))
	include_native_check.button_pressed = bool(settings.get("include_native_bases"))
	include_external_check.button_pressed = bool(settings.get("include_external_bases"))
	include_methods_check.button_pressed = bool(settings.get("include_methods"))
	include_signals_check.button_pressed = bool(settings.get("include_signals"))
	include_properties_check.button_pressed = bool(settings.get("include_properties"))
	include_dependencies_check.button_pressed = bool(settings.get("include_resource_dependencies"))
	include_type_dependencies_check.button_pressed = bool(settings.get("include_type_dependencies"))
	include_member_access_dependencies_check.button_pressed = bool(
		settings.get("include_member_access_dependencies")
	)
	show_member_dependency_edges_check.button_pressed = bool(
		settings.get("show_member_dependency_edges")
	)
	method_signatures_check.button_pressed = bool(settings.get("show_method_signatures"))
	signal_signatures_check.button_pressed = bool(settings.get("show_signal_signatures"))
	property_types_check.button_pressed = bool(settings.get("show_property_types"))
	graph_node_width_spin.value = float(settings.get("graph_node_width"))
	graph_node_max_width_spin.value = float(settings.get("graph_node_max_width"))
	native_node_width_spin.value = float(settings.get("native_node_width"))
	max_members_spin.value = float(settings.get("graph_max_members_per_section"))
	max_member_height_spin.value = float(settings.get("graph_max_member_height"))
	sibling_spacing_spin.value = float(settings.get("graph_sibling_spacing"))
	layer_spacing_spin.value = float(settings.get("graph_layer_spacing"))
	depth_top_to_bottom_check.button_pressed = bool(settings.get("graph_depth_top_to_bottom"))
	user_color_picker.color = settings.get("user_script_color")
	addon_color_picker.color = settings.get("addon_script_color")
	native_color_picker.color = settings.get("native_class_color")
	external_color_picker.color = settings.get("external_class_color")
	property_color_picker.color = settings.get("property_color")
	signal_color_picker.color = settings.get("signal_color")
	method_color_picker.color = settings.get("method_color")
	metadata_color_picker.color = settings.get("metadata_color")
	inheritance_color_picker.color = settings.get("inheritance_edge_color")
	dependency_color_picker.color = settings.get("dependency_edge_color")
	type_dependency_color_picker.color = settings.get("type_dependency_edge_color")
	object_family_color_picker.color = settings.get("object_family_color")
	ref_counted_family_color_picker.color = settings.get("ref_counted_family_color")
	node_family_color_picker.color = settings.get("node_family_color")
	node_2d_family_color_picker.color = settings.get("node_2d_family_color")
	node_3d_family_color_picker.color = settings.get("node_3d_family_color")
	control_family_color_picker.color = settings.get("control_family_color")
	other_family_color_picker.color = settings.get("other_family_color")
	_suppress_control_events = false


func _capture_controls_into_settings() -> void:
	settings.set("include_addons", include_addons_check.button_pressed)
	settings.set("include_native_bases", include_native_check.button_pressed)
	settings.set("include_external_bases", include_external_check.button_pressed)
	settings.set("include_methods", include_methods_check.button_pressed)
	settings.set("include_signals", include_signals_check.button_pressed)
	settings.set("include_properties", include_properties_check.button_pressed)
	settings.set("include_resource_dependencies", include_dependencies_check.button_pressed)
	settings.set("include_type_dependencies", include_type_dependencies_check.button_pressed)
	settings.set(
		"include_member_access_dependencies",
		include_member_access_dependencies_check.button_pressed
	)
	settings.set("show_member_dependency_edges", show_member_dependency_edges_check.button_pressed)
	settings.set("show_method_signatures", method_signatures_check.button_pressed)
	settings.set("show_signal_signatures", signal_signatures_check.button_pressed)
	settings.set("show_property_types", property_types_check.button_pressed)
	settings.set("graph_node_width", graph_node_width_spin.value)
	settings.set("graph_node_max_width", maxf(graph_node_width_spin.value, graph_node_max_width_spin.value))
	settings.set("native_node_width", native_node_width_spin.value)
	settings.set("graph_max_members_per_section", int(max_members_spin.value))
	settings.set("graph_max_member_height", max_member_height_spin.value)
	settings.set("graph_sibling_spacing", sibling_spacing_spin.value)
	settings.set("graph_layer_spacing", layer_spacing_spin.value)
	settings.set("graph_depth_top_to_bottom", depth_top_to_bottom_check.button_pressed)
	settings.set("user_script_color", user_color_picker.color)
	settings.set("addon_script_color", addon_color_picker.color)
	settings.set("native_class_color", native_color_picker.color)
	settings.set("external_class_color", external_color_picker.color)
	settings.set("property_color", property_color_picker.color)
	settings.set("signal_color", signal_color_picker.color)
	settings.set("method_color", method_color_picker.color)
	settings.set("metadata_color", metadata_color_picker.color)
	settings.set("inheritance_edge_color", inheritance_color_picker.color)
	settings.set("dependency_edge_color", dependency_color_picker.color)
	settings.set("type_dependency_edge_color", type_dependency_color_picker.color)
	settings.set("object_family_color", object_family_color_picker.color)
	settings.set("ref_counted_family_color", ref_counted_family_color_picker.color)
	settings.set("node_family_color", node_family_color_picker.color)
	settings.set("node_2d_family_color", node_2d_family_color_picker.color)
	settings.set("node_3d_family_color", node_3d_family_color_picker.color)
	settings.set("control_family_color", control_family_color_picker.color)
	settings.set("other_family_color", other_family_color_picker.color)


func _apply_graph_settings() -> void:
	graph_edit.minimap_enabled = bool(settings.get("graph_minimap_enabled"))
	graph_edit.show_zoom_label = bool(settings.get("graph_show_zoom_label"))
	graph_edit.connection_lines_thickness = float(settings.get("graph_connection_thickness"))
	_update_legend()


func _update_legend() -> void:
	if legend_view == null or settings == null:
		return
	var inheritance_color = str(settings.call("to_style_dictionary").get("inheritance_edge_color", "d8dee9"))
	var dependency_color = str(settings.call("to_style_dictionary").get("dependency_edge_color", "e5c07b"))
	var type_color = str(settings.call("to_style_dictionary").get("type_dependency_edge_color", "56b6c2"))
	legend_view.text = (
		"[color=#%s]Inheritance[/color]  ·  [color=#%s]load/preload or class-member use[/color]\n"
		+ "[color=#%s]Type-annotation use[/color]\n"
		+ "Rendered direction: base or dependency → derived or dependent"
	) % [inheritance_color, dependency_color, type_color]


func _update_summary() -> void:
	if summary_view == null:
		return
	if _snapshot.is_empty():
		summary_view.text = "Scan the project to populate this non-visual graph summary."
		return
	var node_kind_counts: Dictionary = {}
	var family_counts: Dictionary = {}
	var edge_kind_counts: Dictionary = {}
	for node_value in _snapshot.get("nodes", []):
		var node: Dictionary = node_value
		var kind = str(node.get("kind", "unknown"))
		var family = str(node.get("inheritance_family", "other"))
		node_kind_counts[kind] = int(node_kind_counts.get(kind, 0)) + 1
		family_counts[family] = int(family_counts.get(family, 0)) + 1
	for edge_value in _snapshot.get("edges", []):
		var edge: Dictionary = edge_value
		var kind = str(edge.get("kind", "unknown"))
		edge_kind_counts[kind] = int(edge_kind_counts.get(kind, 0)) + 1
	var metadata: Dictionary = _snapshot.get("metadata", {})
	var lines: Array[String] = [
		"[b]Dependency graph summary[/b]",
		"Root: %s" % str(metadata.get("root_path", "res://")),
		"Engine: %s" % str(metadata.get("engine_version", "unknown")),
		"Exact data: choose JSON, then Export, for paths, members, provenance, and diagnostics.",
		"Nodes: %s (%s)" % [_snapshot.get("nodes", []).size(), _count_summary(node_kind_counts)],
		"Inheritance families: %s" % _count_summary(family_counts),
		"Edges: %s (%s)" % [_snapshot.get("edges", []).size(), _count_summary(edge_kind_counts)],
		"Canonical export direction: dependent → dependency.",
		"Rendered GraphEdit direction: dependency → dependent, for layout.",
		"Warnings: %s; errors: %s." % [_snapshot.get("warnings", []).size(), _snapshot.get("errors", []).size()],
	]
	summary_view.text = "\n".join(lines)


func _count_summary(counts: Dictionary) -> String:
	var keys: Array = counts.keys()
	keys.sort()
	var values: Array[String] = []
	for key_value in keys:
		values.append("%s %s" % [str(key_value).replace("_", " "), counts[key_value]])
	return ", ".join(values) if not values.is_empty() else "none"


func _on_export_format_selected(_index: int) -> void:
	if _export_service == null:
		return
	var format_id = _selected_format_id()
	var capabilities: Dictionary = _export_service.capabilities_for(format_id)
	export_colors_check.disabled = not bool(capabilities.get("colors", false))
	if export_colors_check.disabled:
		export_colors_check.button_pressed = false
	format_option.tooltip_text = _format_capability_tooltip(format_id, capabilities)


func _format_capability_tooltip(format_id: String, capabilities: Dictionary) -> String:
	var endpoint_text = (
		"exact member endpoints"
		if bool(capabilities.get("exact_member_endpoints", false))
		else "class-level endpoints"
	)
	return "%s export: %s; colors: %s; structured member links: %s" % [
		format_id.to_upper(),
		endpoint_text,
		"yes" if bool(capabilities.get("colors", false)) else "no",
		"yes" if bool(capabilities.get("structured_member_links", false)) else "no",
	]


func _on_scan_option_changed(_pressed: bool) -> void:
	if not _suppress_control_events and is_node_ready():
		scan_project()


func _on_display_option_changed(_pressed: bool) -> void:
	_refresh_display_without_scan()


func _on_appearance_changed(_pressed: bool) -> void:
	_refresh_display_without_scan()


func _on_appearance_value_changed(_value: float) -> void:
	_refresh_display_without_scan()


func _on_color_changed(_color: Color) -> void:
	_refresh_display_without_scan()


func _refresh_display_without_scan() -> void:
	if _suppress_control_events or not is_node_ready():
		return
	_capture_controls_into_settings()
	_apply_graph_settings()
	if not _snapshot.is_empty():
		_snapshot["metadata"]["style"] = settings.call("to_style_dictionary")
		_snapshot["metadata"]["options"] = _display_options()
		_render_snapshot()


func _display_options() -> Dictionary:
	var graph_options: Dictionary = settings.call("to_graph_options")
	graph_options.erase("style")
	return graph_options


func _render_snapshot() -> void:
	graph_edit.clear_connections()
	for graph_node in _graph_nodes:
		if is_instance_valid(graph_node):
			if graph_node.get_parent() == graph_edit:
				graph_edit.remove_child(graph_node)
			graph_node.queue_free()
	_graph_nodes.clear()
	_id_to_graph_name.clear()
	if _snapshot.is_empty():
		_update_summary()
		return

	var style: Dictionary = settings.call("to_style_dictionary")
	var display_options = _display_options()
	var member_port_usage_by_node = _member_port_usage_by_node(_snapshot)
	var size_by_id: Dictionary = {}
	for index in range(_snapshot.get("nodes", []).size()):
		var node_data: Dictionary = _snapshot["nodes"][index]
		var graph_node = _graph_node_scene.instantiate()
		var graph_name = "DependencyNode_%s" % index
		graph_node.name = graph_name
		graph_edit.add_child(graph_node)
		var node_display_options: Dictionary = display_options.duplicate(true)
		node_display_options["member_port_usage"] = member_port_usage_by_node.get(
			str(node_data.get("id", "")), {}
		)
		graph_node.call("configure", node_data, style, node_display_options)
		if graph_node.has_method("layout_size"):
			size_by_id[str(node_data["id"])] = graph_node.call("layout_size")
		_graph_nodes.append(graph_node)
		_id_to_graph_name[str(node_data["id"])] = graph_name

	var positions = _layout_positions(_snapshot, size_by_id)
	for index in range(_snapshot.get("nodes", []).size()):
		var node_data: Dictionary = _snapshot["nodes"][index]
		var graph_node = _graph_nodes[index]
		graph_node.position_offset = positions.get(node_data["id"], Vector2.ZERO)

	var rendered_connections: Dictionary = {}
	for edge_value in _snapshot.get("edges", []):
		var edge: Dictionary = edge_value
		_render_edge(edge, rendered_connections)

	if bool(settings.get("arrange_with_engine_when_available")):
		_compat_script.call("arrange_graph", graph_edit)
	_update_summary()
	graph_edit.set_deferred("scroll_offset", Vector2.ZERO)


func _member_port_usage_by_node(snapshot: Dictionary) -> Dictionary:
	var usage_by_node: Dictionary = {}
	if not bool(settings.get("show_member_dependency_edges")):
		return usage_by_node
	for edge_value in snapshot.get("edges", []):
		var edge: Dictionary = edge_value
		var relation_kind = str(edge.get("kind", "uses"))
		if relation_kind == "extends":
			continue
		for link_value in edge.get("member_links", []):
			var link: Dictionary = link_value
			_register_member_port_usage(
				usage_by_node, str(edge.get("source", "")), link.get("source_member", {}), relation_kind
			)
			_register_member_port_usage(
				usage_by_node, str(edge.get("target", "")), link.get("target_member", {}), relation_kind
			)
	return usage_by_node


func _register_member_port_usage(
	usage_by_node: Dictionary, node_id: String, member_value, relation_kind: String
) -> void:
	if node_id.is_empty() or not member_value is Dictionary:
		return
	var member: Dictionary = member_value
	var member_kind = str(member.get("kind", ""))
	var member_name = str(member.get("name", ""))
	if member_kind.is_empty() or member_name.is_empty():
		return
	var node_usage: Dictionary = usage_by_node.get(node_id, {})
	var key = member_kind + ":" + member_name
	var relation_kinds: Array = node_usage.get(key, [])
	if not relation_kinds.has(relation_kind):
		relation_kinds.append(relation_kind)
		relation_kinds.sort()
	node_usage[key] = relation_kinds
	usage_by_node[node_id] = node_usage


func _render_edge(edge: Dictionary, rendered_connections: Dictionary) -> void:
	if not _id_to_graph_name.has(edge["source"]) or not _id_to_graph_name.has(edge["target"]):
		return
	var edge_kind = str(edge.get("kind", "uses"))
	var fallback_port = _port_for_edge(edge_kind)
	var member_links: Array = edge.get("member_links", [])
	if not bool(settings.get("show_member_dependency_edges")) or member_links.is_empty():
		_connect_rendered_edge(edge, fallback_port, fallback_port, rendered_connections)
		return
	for link_value in member_links:
		var link: Dictionary = link_value
		var dependency_node = graph_edit.get_node_or_null(
			NodePath(str(_id_to_graph_name[edge["target"]]))
		)
		var dependent_node = graph_edit.get_node_or_null(
			NodePath(str(_id_to_graph_name[edge["source"]]))
		)
		var from_port = fallback_port
		var to_port = fallback_port
		if dependency_node != null and dependency_node.has_method("port_for_member"):
			from_port = int(
				dependency_node.call(
					"port_for_member", link.get("target_member", {}), edge_kind, fallback_port
				)
			)
		if dependent_node != null and dependent_node.has_method("port_for_member"):
			to_port = int(
				dependent_node.call(
					"port_for_member", link.get("source_member", {}), edge_kind, fallback_port
				)
			)
		_connect_rendered_edge(edge, from_port, to_port, rendered_connections)


func _connect_rendered_edge(
	edge: Dictionary, from_port: int, to_port: int, rendered_connections: Dictionary
) -> void:
	# Canonical edges point dependent -> dependency. GraphEdit's arranger interprets
	# incoming nodes as the previous layer, so render dependency -> dependent to
	# place Object/base classes before their descendants when Arrange is pressed.
	var from_name = str(_id_to_graph_name[edge["target"]])
	var to_name = str(_id_to_graph_name[edge["source"]])
	var connection_key = "%s|%s|%s|%s" % [from_name, from_port, to_name, to_port]
	if rendered_connections.has(connection_key):
		return
	rendered_connections[connection_key] = true
	var connection_error = graph_edit.connect_node(from_name, from_port, to_name, to_port)
	if connection_error != OK and connection_error != ERR_ALREADY_EXISTS:
		var context = edge.duplicate(true)
		context["from_port"] = from_port
		context["to_port"] = to_port
		_logger.warning("Could not render graph connection.", context)


func _port_for_edge(edge_kind: String) -> int:
	match edge_kind:
		"extends":
			return 0
		"type_uses":
			return 2
		_:
			return 1


func _layout_positions(snapshot: Dictionary, size_by_id: Dictionary = {}) -> Dictionary:
	var parent_by_child: Dictionary = {}
	var node_by_id: Dictionary = {}
	for node_value in snapshot.get("nodes", []):
		var node: Dictionary = node_value
		node_by_id[str(node["id"])] = node
	for edge_value in snapshot.get("edges", []):
		var edge: Dictionary = edge_value
		if edge["kind"] == "extends":
			parent_by_child[str(edge["source"])] = str(edge["target"])

	var depths: Dictionary = {}
	for node_id_value in node_by_id.keys():
		_depth_for(str(node_id_value), parent_by_child, depths, {})
	var ids_by_depth: Dictionary = {}
	for node_id_value in node_by_id.keys():
		var node_id = str(node_id_value)
		var depth = int(depths.get(node_id, 0))
		if not ids_by_depth.has(depth):
			ids_by_depth[depth] = []
		ids_by_depth[depth].append(node_id)

	var depth_keys: Array = ids_by_depth.keys()
	depth_keys.sort()
	for depth_value in depth_keys:
		var ids: Array = ids_by_depth[depth_value]
		ids.sort_custom(
			func(left: String, right: String) -> bool:
				return _layout_sort_key(node_by_id[left]) < _layout_sort_key(node_by_id[right])
		)

	if bool(settings.get("graph_depth_top_to_bottom")):
		return _layout_top_to_bottom(depth_keys, ids_by_depth, node_by_id, size_by_id)
	return _layout_left_to_right(depth_keys, ids_by_depth, node_by_id, size_by_id)


func _layout_top_to_bottom(
	depth_keys: Array,
	ids_by_depth: Dictionary,
	node_by_id: Dictionary,
	size_by_id: Dictionary
) -> Dictionary:
	var style: Dictionary = settings.call("to_style_dictionary")
	var sibling_gap = float(style["graph_sibling_spacing"])
	var layer_gap = float(style["graph_layer_spacing"])
	var available_width = maxf(
		500.0, graph_edit.size.x / graph_edit.zoom - 32.0
	)
	var positions: Dictionary = {}
	var layer_y = 70.0
	for depth_value in depth_keys:
		var ids: Array = ids_by_depth[depth_value]
		var cursor_x = 20.0
		var cursor_y = layer_y
		var row_height = 0.0
		var layer_bottom = layer_y
		for node_id_value in ids:
			var node_id = str(node_id_value)
			var size = _node_layout_size(node_id, node_by_id[node_id], style, size_by_id)
			if cursor_x > 20.0 and cursor_x + size.x > 20.0 + available_width:
				cursor_x = 20.0
				cursor_y += row_height + sibling_gap
				row_height = 0.0
			positions[node_id] = Vector2(cursor_x, cursor_y)
			cursor_x += size.x + sibling_gap
			row_height = maxf(row_height, size.y)
			layer_bottom = maxf(layer_bottom, cursor_y + size.y)
		layer_y = layer_bottom + layer_gap
	return positions


func _layout_left_to_right(
	depth_keys: Array,
	ids_by_depth: Dictionary,
	node_by_id: Dictionary,
	size_by_id: Dictionary
) -> Dictionary:
	var style: Dictionary = settings.call("to_style_dictionary")
	var sibling_gap = float(style["graph_sibling_spacing"])
	var layer_gap = float(style["graph_layer_spacing"])
	var layer_heights: Dictionary = {}
	var maximum_height = 0.0
	for depth_value in depth_keys:
		var height = 0.0
		var ids: Array = ids_by_depth[depth_value]
		for index in range(ids.size()):
			height += _node_layout_size(str(ids[index]), node_by_id[ids[index]], style, size_by_id).y
			if index + 1 < ids.size():
				height += sibling_gap
		layer_heights[depth_value] = height
		maximum_height = maxf(maximum_height, height)

	var positions: Dictionary = {}
	var cursor_x = 20.0
	for depth_value in depth_keys:
		var ids: Array = ids_by_depth[depth_value]
		var cursor_y = 70.0 + (maximum_height - float(layer_heights[depth_value])) * 0.5
		var maximum_width = 0.0
		for node_id_value in ids:
			var node_id = str(node_id_value)
			var size = _node_layout_size(node_id, node_by_id[node_id], style, size_by_id)
			positions[node_id] = Vector2(cursor_x, cursor_y)
			cursor_y += size.y + sibling_gap
			maximum_width = maxf(maximum_width, size.x)
		cursor_x += maximum_width + layer_gap
	return positions


func _node_layout_size(
	node_id: String, node_data: Dictionary, style: Dictionary, size_by_id: Dictionary
) -> Vector2:
	if size_by_id.has(node_id) and size_by_id[node_id] is Vector2:
		return size_by_id[node_id]
	var kind = str(node_data.get("kind", "external"))
	var width = (
		float(style["native_node_width"])
		if kind == "native"
		else float(style["graph_node_width"])
	)
	if kind == "native":
		return Vector2(width, 37.0)
	var member_rows = _estimated_member_rows(node_data, int(style["graph_max_members_per_section"]))
	var member_height = minf(float(style["graph_max_member_height"]), member_rows * 22.0 + 6.0)
	return Vector2(width, 65.0 + member_height)


func _estimated_member_rows(node_data: Dictionary, maximum_per_section: int) -> float:
	var rows = 0
	for key in ["properties", "signals", "methods"]:
		var members: Array = node_data.get(key, [])
		if members.is_empty():
			continue
		rows += 1 + mini(members.size(), maximum_per_section)
		if members.size() > maximum_per_section:
			rows += 1
	return float(rows)


func _layout_sort_key(node_data: Dictionary) -> String:
	var kind_order = {"native": "0", "addon": "1", "user": "2", "external": "3"}
	var kind = str(node_data.get("kind", "external"))
	return "%s|%s|%s" % [
		str(kind_order.get(kind, "9")),
		str(node_data.get("name", "")).to_lower(),
		str(node_data.get("id", "")),
	]


func _depth_for(
	node_id: String, parent_by_child: Dictionary, cache: Dictionary, visiting: Dictionary
) -> int:
	if cache.has(node_id):
		return int(cache[node_id])
	if visiting.has(node_id):
		cache[node_id] = 0
		return 0
	visiting[node_id] = true
	var depth = 0
	if parent_by_child.has(node_id):
		depth = _depth_for(str(parent_by_child[node_id]), parent_by_child, cache, visiting) + 1
	visiting.erase(node_id)
	cache[node_id] = depth
	return depth


func _open_export_dialog() -> void:
	if _snapshot.is_empty():
		return
	var format_id = _selected_format_id()
	var extension = _export_service.extension_for(format_id)
	file_dialog.clear_filters()
	file_dialog.add_filter("*.%s ; %s" % [extension, format_id.to_upper()])
	file_dialog.current_file = "script_dependencies.%s" % extension
	file_dialog.popup_centered_ratio(0.75)


func _on_export_path_selected(path: String) -> void:
	_capture_controls_into_settings()
	var result = _export_service.export_to_file(
		_selected_format_id(),
		path,
		_snapshot,
		{"include_colors": export_colors_check.button_pressed}
	)
	if result["ok"]:
		status_label.text = "Exported: %s" % result["path"]
		if _editor_interface != null and str(result["path"]).begins_with("res://"):
			_editor_interface.get_resource_filesystem().scan()
	else:
		status_label.text = "Export failed: %s" % result.get("error", "unknown error")


func _selected_format_id() -> String:
	if format_option.selected < 0:
		return "json"
	return str(format_option.get_item_metadata(format_option.selected))


func _on_log_entry(entry: Dictionary) -> void:
	log_view.append_text(
		"[%s] %s\n" % [str(entry.get("level", "info")).to_upper(), str(entry.get("message", ""))]
	)
