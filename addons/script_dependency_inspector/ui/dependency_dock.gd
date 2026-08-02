@tool
extends VBoxContainer

const ADDON_ROOT: String = "res://addons/script_dependency_inspector/"
const SETTINGS_SCRIPT_PATH: String = ADDON_ROOT + "core/settings.gd"
const DEFAULT_SETTINGS_PATH: String = ADDON_ROOT + "default_settings.tres"
const LOGGER_SCRIPT_PATH: String = ADDON_ROOT + "core/logger.gd"
const SCANNER_SCRIPT_PATH: String = ADDON_ROOT + "core/project_scanner.gd"
const GRAPH_BUILDER_SCRIPT_PATH: String = ADDON_ROOT + "core/graph_builder.gd"
const SNAPSHOT_SCOPE_SCRIPT_PATH: String = ADDON_ROOT + "core/snapshot_scope.gd"
const GRAPH_QUERY_SCRIPT_PATH: String = ADDON_ROOT + "core/graph_query.gd"
const EDITOR_STATE_STORE_SCRIPT_PATH: String = ADDON_ROOT + "core/editor_state_store.gd"
const EDITOR_STATE_PATH: String = "res://.godot/script_dependency_inspector/editor_state.json"
const EXPORT_SERVICE_SCRIPT_PATH: String = ADDON_ROOT + "export/export_service.gd"
const COMPAT_SCRIPT_PATH: String = ADDON_ROOT + "core/compat.gd"
const GRAPH_NODE_SCRIPT_PATH: String = ADDON_ROOT + "ui/dependency_graph_node.gd"
const GRAPH_NODE_SCENE_PATH: String = ADDON_ROOT + "ui/dependency_graph_node.tscn"

const CONTROL_SECTION_CONFIG: Dictionary = {
	"content_sources": ["ContentSourcesHeader", "ContentSourcesBody", "Scripts and classes"],
	"content_members": ["ContentMembersHeader", "ContentMembersBody", "Members and signatures"],
	"content_relations": ["ContentRelationsHeader", "ContentRelationsBody", "Relationship evidence"],
	"content_export": ["ContentExportHeader", "ContentExportBody", "Diagram export styling"],
	"appearance_sizing": ["AppearanceSizingHeader", "AppearanceSizingBody", "Node sizing"],
	"appearance_density": ["AppearanceDensityHeader", "AppearanceDensityBody", "Member density and overflow"],
	"appearance_layout": ["AppearanceLayoutHeader", "AppearanceLayoutBody", "Layout and spacing"],
	"colors_nodes": ["ColorsNodesHeader", "ColorsNodesBody", "Node roles"],
	"colors_members": ["ColorsMembersHeader", "ColorsMembersBody", "Member and metadata text"],
	"colors_relations": ["ColorsRelationsHeader", "ColorsRelationsBody", "Relationship lines"],
	"colors_families": ["ColorsFamiliesHeader", "ColorsFamiliesBody", "Inheritance-family borders"],
	"automation_editor": ["AutomationEditorHeader", "AutomationEditorBody", "Editor synchronization"],
	"automation_timed": ["AutomationTimedHeader", "AutomationTimedBody", "Timed fallback"],
	"automation_export": ["AutomationExportHeader", "AutomationExportBody", "Automatic file exports"],
}

@export var settings: Resource
@export var auto_scan_on_open: bool = false

var _editor_interface: EditorInterface
var _logger
var _scanner
var _builder
var _scope_projector
var _graph_query
var _export_service
var _state_store
var _editor_state: Dictionary = {}
var _scan_in_progress: bool = false
var _pending_path_format: String = ""
var _pending_manual_export: bool = false
var _compat_script: Script
var _graph_node_scene: PackedScene
var _initialization_errors: Array[String] = []
var _snapshot: Dictionary = {}
var _graph_nodes: Array = []
var _id_to_graph_name: Dictionary = {}
var _id_to_graph_node: Dictionary = {}
var _node_data_by_id: Dictionary = {}
var _search_match_ids: Array[String] = []
var _search_index: int = -1
var _suppress_control_events: bool = false
var _editor_change_pending: bool = false
var _ignore_filesystem_events_until_msec: int = 0
var _editor_signals_connected: bool = false
var _scan_root: String = "res://"
var _recent_scan_roots: Array[String] = ["res://"]
var _focused_node_id: String = ""
var _focus_related_ids: Dictionary = {}
var _focus_visible_ids: Dictionary = {}
var _suppress_graph_selection_events: bool = false
var _fold_sections: Dictionary = {}

@onready var scan_button: Button = %ScanButton
@onready var scan_mode_indicator: Label = %ScanModeIndicator
@onready var show_graph_check: CheckButton = %ShowGraph
@onready var export_button: Button = %ExportButton
@onready var format_option: OptionButton = %FormatOption
@onready var status_label: Label = %StatusLabel
@onready var scope_option: OptionButton = %ScopeOption
@onready var choose_scope_button: Button = %ChooseScope
@onready var scope_dialog: FileDialog = %ScopeDialog
@onready var search_bar: HBoxContainer = %SearchBar
@onready var search_input: LineEdit = %SearchInput
@onready var previous_match_button: Button = %PreviousMatch
@onready var next_match_button: Button = %NextMatch
@onready var search_status: Label = %SearchStatus
@onready var focus_bar: HBoxContainer = %FocusBar
@onready var include_descendants_check: CheckBox = %IncludeDescendants
@onready var isolate_neighborhood_check: CheckBox = %IsolateNeighborhood
@onready var clear_focus_button: Button = %ClearFocus
@onready var focus_status: Label = %FocusStatus
@onready var legend_panel: PanelContainer = %LegendPanel
@onready var legend_view: RichTextLabel = %LegendView
@onready var summary_view: RichTextLabel = %SummaryView
@onready var main_split: VSplitContainer = %MainSplit
@onready var controls_tabs: TabContainer = %ControlsTabs
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
@onready var sync_on_editor_changes_check: CheckBox = %SyncOnEditorChanges
@onready var editor_sync_debounce_spin: SpinBox = %EditorSyncDebounce
@onready var follow_active_script_check: CheckBox = %FollowActiveScript
@onready var editor_sync_status: Label = %EditorSyncStatus
@onready var auto_rescan_check: CheckBox = %AutoRescan
@onready var auto_rescan_delay_spin: SpinBox = %AutoRescanDelay
@onready var auto_rescan_status: Label = %AutoRescanStatus
@onready var auto_export_json_check: CheckBox = %AutoExportJson
@onready var auto_export_mermaid_check: CheckBox = %AutoExportMermaid
@onready var auto_export_plantuml_check: CheckBox = %AutoExportPlantUML
@onready var auto_export_json_path: LineEdit = %AutoExportJsonPath
@onready var auto_export_mermaid_path: LineEdit = %AutoExportMermaidPath
@onready var auto_export_plantuml_path: LineEdit = %AutoExportPlantUMLPath
@onready var browse_auto_export_json: Button = %BrowseAutoExportJson
@onready var browse_auto_export_mermaid: Button = %BrowseAutoExportMermaid
@onready var browse_auto_export_plantuml: Button = %BrowseAutoExportPlantUML
@onready var auto_rescan_timer: Timer = %AutoRescanTimer
@onready var editor_change_timer: Timer = %EditorChangeTimer
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
	file_dialog.canceled.connect(_on_export_dialog_canceled)
	scope_dialog.dir_selected.connect(_on_scope_selected)
	choose_scope_button.pressed.connect(_open_scope_dialog)
	scope_option.item_selected.connect(_on_scope_option_selected)
	format_option.item_selected.connect(_on_export_format_selected)
	show_graph_check.toggled.connect(_on_graph_view_toggled)
	auto_rescan_timer.timeout.connect(_on_auto_rescan_timeout)
	editor_change_timer.timeout.connect(_on_editor_change_timeout)
	search_input.text_changed.connect(_on_search_query_changed)
	previous_match_button.pressed.connect(_focus_previous_match)
	next_match_button.pressed.connect(_focus_next_match)
	include_descendants_check.toggled.connect(_on_focus_option_changed)
	isolate_neighborhood_check.toggled.connect(_on_focus_option_changed)
	clear_focus_button.pressed.connect(_clear_relationship_focus)
	graph_edit.node_selected.connect(_on_graph_node_selected)
	graph_edit.node_deselected.connect(_on_graph_node_deselected)
	_populate_formats()
	_load_settings_into_controls()
	_setup_fold_sections()
	_load_editor_state()
	_apply_graph_view_visibility(false)
	_connect_option_controls()
	_apply_graph_settings()
	export_button.disabled = true
	_connect_editor_signals()
	_update_refresh_schedules()
	if auto_scan_on_open or (
		_editor_interface != null and sync_on_editor_changes_check.button_pressed
	):
		call_deferred("scan_project")


func _initialize_dependencies() -> bool:
	var settings_script = _load_required_script(SETTINGS_SCRIPT_PATH, "settings")
	var default_settings = _load_required_resource(DEFAULT_SETTINGS_PATH, "default settings")
	var logger_script = _load_required_script(LOGGER_SCRIPT_PATH, "logger")
	var scanner_script = _load_required_script(SCANNER_SCRIPT_PATH, "project scanner")
	var builder_script = _load_required_script(GRAPH_BUILDER_SCRIPT_PATH, "graph builder")
	var scope_script = _load_required_script(SNAPSHOT_SCOPE_SCRIPT_PATH, "snapshot scope projector")
	var graph_query_script = _load_required_script(GRAPH_QUERY_SCRIPT_PATH, "graph query service")
	var export_service_script = _load_required_script(EXPORT_SERVICE_SCRIPT_PATH, "export service")
	var state_store_script = _load_required_script(EDITOR_STATE_STORE_SCRIPT_PATH, "editor state store")
	_compat_script = _load_required_script(COMPAT_SCRIPT_PATH, "compatibility shim")
	_load_required_script(GRAPH_NODE_SCRIPT_PATH, "graph node")
	_graph_node_scene = _load_required_scene(GRAPH_NODE_SCENE_PATH, "graph node")
	if not _initialization_errors.is_empty():
		return false

	_logger = logger_script.new()
	_scanner = scanner_script.new()
	_builder = builder_script.new()
	_scope_projector = scope_script.new()
	_graph_query = graph_query_script.new()
	_export_service = export_service_script.new()
	_state_store = state_store_script.new()
	if (
		_logger == null
		or _scanner == null
		or _builder == null
		or _scope_projector == null
		or _graph_query == null
		or _export_service == null
		or _state_store == null
	):
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
	for required_method in ["to_scan_options", "to_graph_options", "to_style_dictionary", "to_editor_state_defaults"]:
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


## Scans the project, rebuilds the canonical snapshot, redraws the graph,
## runs enabled automatic exports, and only then restarts the one-shot timer.
func scan_project() -> void:
	if not _initialization_errors.is_empty():
		_present_initialization_failure()
		return
	if _scan_in_progress:
		_logger.warning("A dependency scan is already running.", {"code": "scan_already_running"})
		return
	_scan_in_progress = true
	auto_rescan_timer.stop()
	editor_change_timer.stop()
	_update_refresh_status()
	_capture_controls_into_settings()
	_capture_editor_state_controls()
	_save_editor_state()
	scan_button.disabled = true
	export_button.disabled = true
	status_label.text = "Scanning…"
	_logger.clear()
	log_view.clear()
	var scope_validation: Dictionary = _scanner.call("validate_root", _scan_root)
	if not scope_validation.get("ok", false):
		_scan_in_progress = false
		scan_button.disabled = false
		status_label.text = str(scope_validation.get("error", "Invalid scan root."))
		_update_refresh_schedules()
		return
	_scan_root = str(scope_validation.get("root", "res://"))
	var scan_result: Dictionary = _scanner.scan("res://", settings.call("to_scan_options"))
	var full_snapshot: Dictionary = _builder.build(scan_result, settings.call("to_graph_options"))
	_snapshot = _scope_projector.call("project", full_snapshot, _scan_root)
	if not _focused_node_id.is_empty() and not _snapshot_has_node(_focused_node_id):
		_focused_node_id = ""
	_render_snapshot()
	if _graph_view_enabled():
		_apply_search()
		if search_input.text.strip_edges().is_empty():
			_follow_current_editor_script()
	else:
		_search_match_ids.clear()
		_search_index = -1
	for warning_value in _snapshot.get("warnings", []):
		_logger.warning(str(warning_value))
	for error_value in _snapshot.get("errors", []):
		_logger.error(str(error_value))
	# Suppress editor refresh notifications only when an enabled automatic export
	# writes below res://. v0.2.0 opened this blind window after every scan,
	# including scans that performed no writes.
	if _automatic_exports_touch_resource_filesystem():
		_ignore_filesystem_events_until_msec = Time.get_ticks_msec() + 2000
	else:
		_ignore_filesystem_events_until_msec = 0
	var automatic_exports: Array[String] = _run_automatic_exports()
	_scan_in_progress = false
	scan_button.disabled = false
	export_button.disabled = _snapshot.get("nodes", []).is_empty()
	status_label.text = _snapshot_status_text(automatic_exports)
	if _editor_change_pending and sync_on_editor_changes_check.button_pressed:
		_editor_change_pending = false
		_start_editor_change_timer()
	else:
		_update_refresh_schedules()


func _snapshot_status_text(automatic_exports: Array[String] = []) -> String:
	var base: String = (
		"%s nodes · %s edges · %s warnings · %s errors"
		% [
			_snapshot.get("nodes", []).size(),
			_snapshot.get("edges", []).size(),
			_snapshot.get("warnings", []).size(),
			_snapshot.get("errors", []).size(),
		]
	)
	if not automatic_exports.is_empty():
		base += " · auto-exported %s" % ", ".join(automatic_exports)
	return base


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
	for control in [
		sync_on_editor_changes_check,
		follow_active_script_check,
		auto_rescan_check,
		auto_export_json_check,
		auto_export_mermaid_check,
		auto_export_plantuml_check,
	]:
		control.toggled.connect(_on_automation_option_changed)
	auto_rescan_delay_spin.value_changed.connect(_on_auto_rescan_delay_changed)
	editor_sync_debounce_spin.value_changed.connect(_on_editor_sync_debounce_changed)
	for path_edit in [
		auto_export_json_path,
		auto_export_mermaid_path,
		auto_export_plantuml_path,
	]:
		path_edit.text_submitted.connect(_on_automation_path_submitted)
		path_edit.focus_exited.connect(_on_automation_path_commit)
	browse_auto_export_json.pressed.connect(_open_automation_path_dialog.bind("json"))
	browse_auto_export_mermaid.pressed.connect(_open_automation_path_dialog.bind("mermaid"))
	browse_auto_export_plantuml.pressed.connect(_open_automation_path_dialog.bind("plantuml"))
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


func _setup_fold_sections() -> void:
	_fold_sections.clear()
	for section_key_value in CONTROL_SECTION_CONFIG:
		var section_key: String = str(section_key_value)
		var config: Array = CONTROL_SECTION_CONFIG[section_key]
		var header: Button = get_node_or_null("%%%s" % str(config[0])) as Button
		var body: Control = get_node_or_null("%%%s" % str(config[1])) as Control
		if header == null or body == null:
			_record_initialization_error("Missing fold section controls: %s" % section_key)
			continue
		_fold_sections[section_key] = {
			"header": header,
			"body": body,
			"title": str(config[2]),
		}
		header.toggled.connect(_on_fold_section_toggled.bind(section_key))
		_apply_fold_section(section_key, header.button_pressed)


func _on_fold_section_toggled(expanded: bool, section_key: String) -> void:
	_apply_fold_section(section_key, expanded)
	if _suppress_control_events or not is_node_ready():
		return
	_capture_editor_state_controls()
	_save_editor_state()


func _apply_fold_section(section_key: String, expanded: bool) -> void:
	if not _fold_sections.has(section_key):
		return
	var section: Dictionary = _fold_sections[section_key]
	var header: Button = section.get("header")
	var body: Control = section.get("body")
	if header == null or body == null:
		return
	body.visible = expanded
	header.text = "%s %s" % ["▾" if expanded else "▸", str(section.get("title", section_key))]


func _control_section_state() -> Dictionary:
	var state: Dictionary = {}
	for section_key_value in _fold_sections:
		var section_key: String = str(section_key_value)
		var header: Button = (_fold_sections[section_key] as Dictionary).get("header")
		if header != null:
			state[section_key] = header.button_pressed
	return state


func _on_graph_view_toggled(_enabled: bool) -> void:
	_apply_graph_view_visibility(true)
	if _suppress_control_events or not is_node_ready():
		return
	_capture_editor_state_controls()
	_save_editor_state()


func _graph_view_enabled() -> bool:
	return show_graph_check != null and show_graph_check.button_pressed


func _apply_graph_view_visibility(render_if_needed: bool = true) -> void:
	if show_graph_check == null:
		return
	var enabled: bool = _graph_view_enabled()
	search_bar.visible = enabled
	focus_bar.visible = enabled
	legend_panel.visible = enabled
	graph_edit.visible = enabled
	if not enabled:
		_clear_rendered_graph()
		search_status.text = "Graph hidden"
		focus_status.text = "Graph view hidden; snapshot and export remain available"
	elif render_if_needed and not _snapshot.is_empty() and _graph_nodes.is_empty():
		_render_snapshot()
		_apply_search()
		if search_input.text.strip_edges().is_empty():
			_follow_current_editor_script()


func _clear_rendered_graph() -> void:
	if graph_edit == null:
		return
	graph_edit.clear_connections()
	for graph_node in _graph_nodes:
		if is_instance_valid(graph_node):
			if graph_node.get_parent() == graph_edit:
				graph_edit.remove_child(graph_node)
			graph_node.queue_free()
	_graph_nodes.clear()
	_id_to_graph_name.clear()
	_id_to_graph_node.clear()
	_node_data_by_id.clear()


func _populate_scope_options() -> void:
	var previous_suppression: bool = _suppress_control_events
	_suppress_control_events = true
	scope_option.clear()
	var ordered: Array[String] = []
	if not ordered.has(_scan_root):
		ordered.append(_scan_root)
	for root_value in _recent_scan_roots:
		var root: String = str(root_value)
		if not ordered.has(root):
			ordered.append(root)
	if not ordered.has("res://"):
		ordered.append("res://")
	for root in ordered:
		var label: String = "Entire project — res://" if root == "res://" else root
		scope_option.add_item(label)
		scope_option.set_item_metadata(scope_option.item_count - 1, root)
		if root == _scan_root:
			scope_option.select(scope_option.item_count - 1)
	_suppress_control_events = previous_suppression


func _open_scope_dialog() -> void:
	scope_dialog.current_dir = _scan_root
	scope_dialog.popup_centered_ratio(0.75)


func _on_scope_option_selected(index: int) -> void:
	if _suppress_control_events or index < 0:
		return
	_set_scan_root(str(scope_option.get_item_metadata(index)))


func _on_scope_selected(path: String) -> void:
	_set_scan_root(path)


func _set_scan_root(path: String) -> void:
	var validation: Dictionary = _scanner.call("validate_root", path)
	if not validation.get("ok", false):
		var error: String = str(validation.get("error", "Invalid scan root."))
		status_label.text = error
		_logger.warning(error, {"code": "invalid_scan_root", "root": path})
		_populate_scope_options()
		return
	var normalized: String = str(validation.get("root", "res://"))
	if normalized != "res://":
		normalized = normalized.trim_suffix("/")
	_scan_root = normalized
	_recent_scan_roots.erase(_scan_root)
	_recent_scan_roots.push_front(_scan_root)
	if not _recent_scan_roots.has("res://"):
		_recent_scan_roots.append("res://")
	while _recent_scan_roots.size() > 8:
		_recent_scan_roots.pop_back()
	_populate_scope_options()
	_capture_editor_state_controls()
	_save_editor_state()
	scan_project()


func _on_focus_option_changed(_pressed: bool) -> void:
	if _suppress_control_events or not is_node_ready():
		return
	_capture_editor_state_controls()
	_save_editor_state()
	_update_relationship_focus()


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


func _load_editor_state() -> void:
	var defaults: Dictionary = settings.call("to_editor_state_defaults")
	var result: Dictionary = _state_store.call("load_state", EDITOR_STATE_PATH, defaults)
	_editor_state = result.get("state", defaults).duplicate(true)
	var warning: String = str(result.get("warning", ""))
	if not warning.is_empty():
		_logger.warning(warning, {"code": "editor_state_load_warning", "path": EDITOR_STATE_PATH})
	_suppress_control_events = true
	_scan_root = str(_editor_state.get("scan_root", "res://"))
	_recent_scan_roots.clear()
	for root_value in _editor_state.get("recent_scan_roots", ["res://"]):
		var recent_root: String = str(root_value)
		var recent_validation: Dictionary = _scanner.call("validate_root", recent_root)
		if recent_validation.get("ok", false):
			var valid_recent_root: String = str(recent_validation.get("root", "res://"))
			if not _recent_scan_roots.has(valid_recent_root):
				_recent_scan_roots.append(valid_recent_root)
	var selected_validation: Dictionary = _scanner.call("validate_root", _scan_root)
	if selected_validation.get("ok", false):
		_scan_root = str(selected_validation.get("root", "res://"))
	else:
		_logger.warning(
			"Remembered scan scope is unavailable; the entire project will be used.",
			{
				"code": "remembered_scan_root_unavailable",
				"root": _scan_root,
				"reason": selected_validation.get("error", "invalid root"),
			}
		)
		_scan_root = "res://"
	if not _recent_scan_roots.has(_scan_root):
		_recent_scan_roots.push_front(_scan_root)
	if not _recent_scan_roots.has("res://"):
		_recent_scan_roots.append("res://")
	include_descendants_check.button_pressed = bool(
		_editor_state.get("focus_include_descendants", false)
	)
	isolate_neighborhood_check.button_pressed = bool(
		_editor_state.get("isolate_neighborhood", false)
	)
	show_graph_check.button_pressed = bool(_editor_state.get("graph_view_enabled", true))
	var section_state: Dictionary = _editor_state.get("control_section_expanded", {})
	for section_key_value in _fold_sections:
		var section_key: String = str(section_key_value)
		var section: Dictionary = _fold_sections[section_key]
		var header: Button = section.get("header")
		var expanded: bool = bool(section_state.get(section_key, header.button_pressed))
		header.button_pressed = expanded
		_apply_fold_section(section_key, expanded)
	_populate_scope_options()
	sync_on_editor_changes_check.button_pressed = bool(
		_editor_state.get("sync_on_editor_changes", true)
	)
	editor_sync_debounce_spin.value = float(
		_editor_state.get("editor_change_debounce_seconds", 1.0)
	)
	follow_active_script_check.button_pressed = bool(
		_editor_state.get("follow_active_script", true)
	)
	auto_rescan_check.button_pressed = bool(_editor_state.get("auto_rescan_enabled", false))
	auto_rescan_delay_spin.value = float(_editor_state.get("auto_rescan_delay_seconds", 60.0))
	var auto_export: Dictionary = _editor_state.get("auto_export", {})
	var export_paths: Dictionary = _editor_state.get("export_paths", {})
	auto_export_json_check.button_pressed = bool(auto_export.get("json", false))
	auto_export_mermaid_check.button_pressed = bool(auto_export.get("mermaid", false))
	auto_export_plantuml_check.button_pressed = bool(auto_export.get("plantuml", false))
	auto_export_json_path.text = str(export_paths.get("json", ""))
	auto_export_mermaid_path.text = str(export_paths.get("mermaid", ""))
	auto_export_plantuml_path.text = str(export_paths.get("plantuml", ""))
	_suppress_control_events = false
	_update_automation_control_availability()


func _capture_editor_state_controls() -> void:
	_editor_state = {
		"schema_version": 4,
		"scan_root": _scan_root,
		"recent_scan_roots": _recent_scan_roots.duplicate(),
		"focus_include_descendants": include_descendants_check.button_pressed,
		"isolate_neighborhood": isolate_neighborhood_check.button_pressed,
		"graph_view_enabled": show_graph_check.button_pressed,
		"control_section_expanded": _control_section_state(),
		"sync_on_editor_changes": sync_on_editor_changes_check.button_pressed,
		"editor_change_debounce_seconds": editor_sync_debounce_spin.value,
		"follow_active_script": follow_active_script_check.button_pressed,
		"auto_rescan_enabled": auto_rescan_check.button_pressed,
		"auto_rescan_delay_seconds": auto_rescan_delay_spin.value,
		"auto_export": {
			"json": auto_export_json_check.button_pressed,
			"mermaid": auto_export_mermaid_check.button_pressed,
			"plantuml": auto_export_plantuml_check.button_pressed,
		},
		"export_paths": {
			"json": auto_export_json_path.text.strip_edges(),
			"mermaid": auto_export_mermaid_path.text.strip_edges(),
			"plantuml": auto_export_plantuml_path.text.strip_edges(),
		},
	}


func _save_editor_state() -> void:
	if _state_store == null or _editor_state.is_empty():
		return
	var result: Dictionary = _state_store.call("save_state", EDITOR_STATE_PATH, _editor_state)
	if not result.get("ok", false):
		_logger.warning(
			str(result.get("error", "Could not persist editor state.")),
			{"code": "editor_state_save_failed", "path": EDITOR_STATE_PATH}
		)


func _update_automation_control_availability() -> void:
	editor_sync_debounce_spin.editable = sync_on_editor_changes_check.button_pressed
	auto_rescan_delay_spin.editable = auto_rescan_check.button_pressed
	for format_id in ["json", "mermaid", "plantuml"]:
		var enabled: bool = _automatic_export_enabled(format_id)
		var path_edit: LineEdit = _automatic_export_path_edit(format_id)
		var browse_button: Button = _automatic_export_browse_button(format_id)
		if path_edit != null:
			path_edit.editable = enabled
		if browse_button != null:
			browse_button.disabled = not enabled


func _on_automation_option_changed(_pressed: bool) -> void:
	if _suppress_control_events or not is_node_ready():
		return
	_capture_editor_state_controls()
	_save_editor_state()
	_update_automation_control_availability()
	_update_refresh_schedules()


func _on_auto_rescan_delay_changed(_value: float) -> void:
	if _suppress_control_events or not is_node_ready():
		return
	_capture_editor_state_controls()
	_save_editor_state()
	_update_refresh_schedules()


func _on_editor_sync_debounce_changed(_value: float) -> void:
	if _suppress_control_events or not is_node_ready():
		return
	_capture_editor_state_controls()
	_save_editor_state()
	_update_refresh_schedules()


func _on_automation_path_submitted(_text: String) -> void:
	_on_automation_path_commit()


func _on_automation_path_commit() -> void:
	if _suppress_control_events or not is_node_ready():
		return
	_capture_editor_state_controls()
	_save_editor_state()


func _on_auto_rescan_timeout() -> void:
	if auto_rescan_check.button_pressed and not _scan_in_progress:
		scan_project()


func _update_refresh_schedules() -> void:
	_update_auto_rescan_schedule()
	_update_scan_mode_indicator()
	if sync_on_editor_changes_check.button_pressed and not _scan_in_progress:
		_update_editor_sync_status()
	else:
		editor_change_timer.stop()
		_update_editor_sync_status()


func _update_auto_rescan_schedule() -> void:
	if auto_rescan_timer == null:
		return
	auto_rescan_timer.stop()
	if auto_rescan_check.button_pressed and not _scan_in_progress:
		auto_rescan_timer.wait_time = clampf(auto_rescan_delay_spin.value, 5.0, 86400.0)
		auto_rescan_timer.start()
	_update_auto_rescan_status()


func _update_refresh_status() -> void:
	_update_auto_rescan_status()
	_update_editor_sync_status()
	_update_scan_mode_indicator()


func _update_auto_rescan_status() -> void:
	if auto_rescan_status == null:
		return
	if _scan_in_progress:
		auto_rescan_status.text = "Timed rescan waits for the current scan and exports to finish."
	elif auto_rescan_check.button_pressed and not auto_rescan_timer.is_stopped():
		auto_rescan_status.text = "Timed fallback: next scan starts %.0f seconds after completion." % auto_rescan_timer.wait_time
	else:
		auto_rescan_status.text = "Timed rescan disabled"


func _update_editor_sync_status() -> void:
	if editor_sync_status == null:
		return
	if not sync_on_editor_changes_check.button_pressed:
		editor_sync_status.text = "Editor synchronization disabled"
	elif _scan_in_progress:
		editor_sync_status.text = "Editor synchronization waits for the current update."
	elif not editor_change_timer.is_stopped():
		editor_sync_status.text = "Editor change detected; waiting for the quiet period."
	else:
		editor_sync_status.text = "Editor synchronization enabled; waiting for changes."


func _update_scan_mode_indicator() -> void:
	if scan_mode_indicator == null:
		return
	var save_synced: bool = sync_on_editor_changes_check.button_pressed
	var timed: bool = auto_rescan_check.button_pressed
	if save_synced and timed:
		scan_mode_indicator.text = "Save + timed"
	elif save_synced:
		scan_mode_indicator.text = "Save sync"
	elif timed:
		scan_mode_indicator.text = "Timed"
	else:
		scan_mode_indicator.text = "Manual"
	var save_text: String = (
		"enabled after %.2f s quiet period" % editor_sync_debounce_spin.value
		if save_synced
		else "disabled"
	)
	var timed_text: String = (
		"enabled %.0f s after completion" % auto_rescan_delay_spin.value
		if timed
		else "disabled"
	)
	scan_mode_indicator.tooltip_text = (
		"Automatic scan triggers — editor save/import synchronization: %s; timed fallback: %s."
		% [save_text, timed_text]
	)


func _automatic_export_enabled(format_id: String) -> bool:
	match format_id:
		"json":
			return auto_export_json_check.button_pressed
		"mermaid":
			return auto_export_mermaid_check.button_pressed
		"plantuml":
			return auto_export_plantuml_check.button_pressed
		_:
			return false


func _automatic_export_path_edit(format_id: String) -> LineEdit:
	match format_id:
		"json":
			return auto_export_json_path
		"mermaid":
			return auto_export_mermaid_path
		"plantuml":
			return auto_export_plantuml_path
		_:
			return null


func _automatic_export_browse_button(format_id: String) -> Button:
	match format_id:
		"json":
			return browse_auto_export_json
		"mermaid":
			return browse_auto_export_mermaid
		"plantuml":
			return browse_auto_export_plantuml
		_:
			return null


func _default_export_path(format_id: String) -> String:
	var defaults: Dictionary = settings.call("to_editor_state_defaults")
	return str((defaults.get("export_paths", {}) as Dictionary).get(format_id, ""))


func _resolved_automatic_export_path(format_id: String) -> String:
	var path_edit: LineEdit = _automatic_export_path_edit(format_id)
	if path_edit == null:
		return ""
	var path: String = path_edit.text.strip_edges()
	if path.is_empty():
		path = _default_export_path(format_id)
		_suppress_control_events = true
		path_edit.text = path
		_suppress_control_events = false
	return path


func _automatic_exports_touch_resource_filesystem() -> bool:
	for format_id in ["json", "mermaid", "plantuml"]:
		if _automatic_export_enabled(format_id) and _resolved_automatic_export_path(format_id).begins_with("res://"):
			return true
	return false


func _run_automatic_exports() -> Array[String]:
	var completed: Array[String] = []
	if _snapshot.is_empty():
		return completed
	var filesystem_refresh_needed: bool = false
	for format_id in ["json", "mermaid", "plantuml"]:
		if not _automatic_export_enabled(format_id):
			continue
		var path: String = _resolved_automatic_export_path(format_id)
		if path.is_empty():
			_logger.error(
				"Automatic export path is empty.",
				{"code": "empty_auto_export_path", "format": format_id}
			)
			continue
		var result: Dictionary = _export_service.export_to_file(
			format_id,
			path,
			_snapshot,
			{"include_colors": export_colors_check.button_pressed}
		)
		if result.get("ok", false):
			var written_path: String = str(result.get("path", path))
			_set_automatic_export_path(format_id, written_path)
			completed.append(_format_display_name(format_id))
			filesystem_refresh_needed = filesystem_refresh_needed or written_path.begins_with("res://")
		else:
			_logger.error(
				"Automatic %s export failed: %s"
				% [format_id, str(result.get("error", "unknown error"))],
				{"code": str(result.get("code", "auto_export_failed")), "format": format_id, "path": path}
			)
	_capture_editor_state_controls()
	_save_editor_state()
	if filesystem_refresh_needed and _editor_interface != null:
		_editor_interface.get_resource_filesystem().scan()
	return completed


func _format_display_name(format_id: String) -> String:
	match format_id:
		"json":
			return "JSON"
		"mermaid":
			return "Mermaid"
		"plantuml":
			return "PlantUML"
		_:
			return format_id


func _set_automatic_export_path(format_id: String, path: String) -> void:
	var path_edit: LineEdit = _automatic_export_path_edit(format_id)
	if path_edit == null:
		return
	_suppress_control_events = true
	path_edit.text = path
	_suppress_control_events = false


func _open_automation_path_dialog(format_id: String) -> void:
	_pending_path_format = format_id
	_pending_manual_export = false
	_configure_file_dialog(format_id, _resolved_automatic_export_path(format_id))
	file_dialog.popup_centered_ratio(0.75)


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
	var inheritance_color = str(settings.call("to_style_dictionary").get("inheritance_edge_color", "e5e7eb"))
	var dependency_color = str(settings.call("to_style_dictionary").get("dependency_edge_color", "e69f00"))
	var type_color = str(settings.call("to_style_dictionary").get("type_dependency_edge_color", "56b4e9"))
	legend_view.text = (
		"[color=#%s]Inheritance[/color]  ·  [color=#%s]load/preload or class-member use[/color]\n"
		+ "[color=#%s]Type-annotation use[/color]  ·  Context nodes are labelled and dimmed\n"
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
	var autoload_count: int = 0
	for node_value in _snapshot.get("nodes", []):
		var node: Dictionary = node_value
		var kind = str(node.get("kind", "unknown"))
		var family = str(node.get("inheritance_family", "other"))
		node_kind_counts[kind] = int(node_kind_counts.get(kind, 0)) + 1
		family_counts[family] = int(family_counts.get(family, 0)) + 1
		if not (node.get("autoload", {}) as Dictionary).is_empty():
			autoload_count += 1
	for edge_value in _snapshot.get("edges", []):
		var edge: Dictionary = edge_value
		var kind = str(edge.get("kind", "unknown"))
		edge_kind_counts[kind] = int(edge_kind_counts.get(kind, 0)) + 1
	var metadata: Dictionary = _snapshot.get("metadata", {})
	var scope_summary: Dictionary = metadata.get("scope_summary", {})
	var lines: Array[String] = [
		"[b]Dependency graph summary[/b]",
		"[b]How to read it[/b]: solid = inheritance; orange = load/preload or direct member use; blue = type-only use. Node border colors identify the most specific inheritance family.",
		"Selected scope: %s" % str(metadata.get("root_path", "res://")),
		"Indexed root: %s" % str(metadata.get("index_root_path", metadata.get("root_path", "res://"))),
		"Scope nodes: %s in scope; %s required context." % [
			int(scope_summary.get("in_scope_nodes", _snapshot.get("nodes", []).size())),
			int(scope_summary.get("context_nodes", 0)),
		],
		"Engine: %s" % str(metadata.get("engine_version", "unknown")),
		"Exact data: choose JSON, then Export, for paths, members, provenance, and diagnostics.",
		"Nodes: %s (%s)" % [_snapshot.get("nodes", []).size(), _count_summary(node_kind_counts)],
		"Autoloads: %s; exact scene attachments: %s." % [autoload_count, _snapshot.get("scene_usages", []).size()],
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
	var had_rendered_nodes: bool = not _graph_nodes.is_empty()
	var previous_scroll: Vector2 = graph_edit.scroll_offset
	_clear_rendered_graph()
	if _snapshot.is_empty() or not _graph_view_enabled():
		_update_summary()
		return

	var style: Dictionary = settings.call("to_style_dictionary")
	var display_options = _display_options()
	var member_port_usage_by_node = _member_port_usage_by_node(_snapshot)
	var relationship_occurrences_by_node = _relationship_occurrences_by_node(_snapshot)
	var descendant_counts: Dictionary = _graph_query.call("descendant_counts", _snapshot)
	var size_by_id: Dictionary = {}
	for index in range(_snapshot.get("nodes", []).size()):
		var node_data: Dictionary = _snapshot["nodes"][index]
		var node_id = str(node_data.get("id", ""))
		var node_display_data: Dictionary = node_data.duplicate(true)
		node_display_data["descendant_counts"] = descendant_counts.get(node_id, {})
		node_display_data["relationship_occurrences"] = relationship_occurrences_by_node.get(
			node_id, []
		)
		var graph_node = _graph_node_scene.instantiate()
		var graph_name = "DependencyNode_%s" % index
		graph_node.name = graph_name
		graph_edit.add_child(graph_node)
		var node_display_options: Dictionary = display_options.duplicate(true)
		node_display_options["member_port_usage"] = member_port_usage_by_node.get(
			node_id, {}
		)
		graph_node.call("configure", node_display_data, style, node_display_options)
		if graph_node.has_signal("source_requested"):
			graph_node.connect("source_requested", Callable(self, "_open_source"))
		if graph_node.has_signal("scene_requested"):
			graph_node.connect("scene_requested", Callable(self, "_open_scene_usage"))
		if graph_node.has_method("layout_size"):
			size_by_id[node_id] = graph_node.call("layout_size")
		_graph_nodes.append(graph_node)
		_id_to_graph_name[node_id] = graph_name
		_id_to_graph_node[node_id] = graph_node
		_node_data_by_id[node_id] = node_data

	var positions = _layout_positions(_snapshot, size_by_id)
	for index in range(_snapshot.get("nodes", []).size()):
		var node_data: Dictionary = _snapshot["nodes"][index]
		var graph_node = _graph_nodes[index]
		graph_node.position_offset = positions.get(node_data["id"], Vector2.ZERO)

	if bool(settings.get("arrange_with_engine_when_available")):
		_compat_script.call("arrange_graph", graph_edit)
	_update_summary()
	_update_relationship_focus()
	if had_rendered_nodes and _focused_node_id.is_empty():
		graph_edit.set_deferred("scroll_offset", previous_scroll)
	elif _focused_node_id.is_empty():
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


func _relationship_occurrences_by_node(snapshot: Dictionary) -> Dictionary:
	var node_by_id: Dictionary = {}
	for node_value in snapshot.get("nodes", []):
		if node_value is Dictionary:
			var node: Dictionary = node_value
			node_by_id[str(node.get("id", ""))] = node
	var occurrences_by_node: Dictionary = {}
	for edge_value in snapshot.get("edges", []):
		if not edge_value is Dictionary:
			continue
		var edge: Dictionary = edge_value
		var source_id = str(edge.get("source", ""))
		var target_id = str(edge.get("target", ""))
		if source_id.is_empty() or not node_by_id.has(source_id):
			continue
		var target: Dictionary = node_by_id.get(target_id, {})
		for link_value in edge.get("member_links", []):
			if not link_value is Dictionary:
				continue
			var link: Dictionary = link_value
			var source_location: Dictionary = link.get("source_location", {})
			if source_location.is_empty():
				continue
			var values: Array = occurrences_by_node.get(source_id, [])
			values.append(
				{
					"kind": str(edge.get("kind", "uses")),
					"target_id": target_id,
					"target_name": str(target.get("name", target_id)),
					"source_member": link.get("source_member", {}).duplicate(true),
					"target_member": link.get("target_member", {}).duplicate(true),
					"source_location": source_location.duplicate(true),
					"evidence": str(link.get("evidence", "dependency")),
				}
			)
			occurrences_by_node[source_id] = values
	for source_id_value in occurrences_by_node:
		var source_id = str(source_id_value)
		var values: Array = occurrences_by_node[source_id]
		values.sort_custom(
			func(left: Dictionary, right: Dictionary) -> bool:
				var left_location: Dictionary = left.get("source_location", {})
				var right_location: Dictionary = right.get("source_location", {})
				return "%09d|%09d|%s|%s" % [
					int(left_location.get("line", 0)),
					int(left_location.get("column", 0)),
					str(left.get("target_id", "")),
					str(left.get("evidence", "")),
				] < "%09d|%09d|%s|%s" % [
					int(right_location.get("line", 0)),
					int(right_location.get("column", 0)),
					str(right.get("target_id", "")),
					str(right.get("evidence", "")),
				]
		)
	return occurrences_by_node


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
	_pending_path_format = _selected_format_id()
	_pending_manual_export = true
	_configure_file_dialog(
		_pending_path_format, _resolved_automatic_export_path(_pending_path_format)
	)
	file_dialog.popup_centered_ratio(0.75)


func _configure_file_dialog(format_id: String, suggested_path: String) -> void:
	var extension: String = _export_service.extension_for(format_id)
	file_dialog.clear_filters()
	file_dialog.add_filter("*.%s ; %s" % [extension, format_id.to_upper()])
	var normalized_path: String = suggested_path.strip_edges()
	if normalized_path.is_empty():
		normalized_path = _default_export_path(format_id)
	if normalized_path.begins_with("res://"):
		file_dialog.access = FileDialog.ACCESS_RESOURCES
	elif normalized_path.begins_with("user://"):
		file_dialog.access = FileDialog.ACCESS_USERDATA
	else:
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.current_dir = normalized_path.get_base_dir()
	file_dialog.current_file = normalized_path.get_file()


func _on_export_path_selected(path: String) -> void:
	var format_id: String = _pending_path_format if not _pending_path_format.is_empty() else _selected_format_id()
	if not _pending_manual_export:
		_set_automatic_export_path(format_id, path)
		_capture_editor_state_controls()
		_save_editor_state()
		status_label.text = "Automatic %s destination: %s" % [format_id, path]
		_pending_path_format = ""
		return
	_capture_controls_into_settings()
	if path.begins_with("res://"):
		_ignore_filesystem_events_until_msec = Time.get_ticks_msec() + 1500
	var result: Dictionary = _export_service.export_to_file(
		format_id,
		path,
		_snapshot,
		{"include_colors": export_colors_check.button_pressed}
	)
	if result.get("ok", false):
		var written_path: String = str(result.get("path", path))
		status_label.text = "Exported: %s" % written_path
		_set_automatic_export_path(format_id, written_path)
		_capture_editor_state_controls()
		_save_editor_state()
		if _editor_interface != null and written_path.begins_with("res://"):
			_editor_interface.get_resource_filesystem().scan()
	else:
		status_label.text = "Export failed: %s" % result.get("error", "unknown error")
	_pending_path_format = ""
	_pending_manual_export = false


func _on_export_dialog_canceled() -> void:
	_pending_path_format = ""
	_pending_manual_export = false


func _connect_editor_signals() -> void:
	if _editor_interface == null or _editor_signals_connected:
		return
	var filesystem = _editor_interface.get_resource_filesystem()
	if filesystem != null and filesystem.has_signal("filesystem_changed"):
		var filesystem_callable = Callable(self, "_on_editor_filesystem_changed")
		if not filesystem.is_connected("filesystem_changed", filesystem_callable):
			filesystem.connect("filesystem_changed", filesystem_callable)
	var script_editor = _editor_interface.get_script_editor()
	if script_editor != null and script_editor.has_signal("editor_script_changed"):
		var script_callable = Callable(self, "_on_editor_script_changed")
		if not script_editor.is_connected("editor_script_changed", script_callable):
			script_editor.connect("editor_script_changed", script_callable)
	_editor_signals_connected = true


func _on_editor_filesystem_changed() -> void:
	if not sync_on_editor_changes_check.button_pressed:
		return
	if Time.get_ticks_msec() < _ignore_filesystem_events_until_msec:
		return
	if _scan_in_progress:
		_editor_change_pending = true
		_update_editor_sync_status()
		return
	_start_editor_change_timer()


func _start_editor_change_timer() -> void:
	if not sync_on_editor_changes_check.button_pressed:
		return
	editor_change_timer.wait_time = clampf(editor_sync_debounce_spin.value, 0.25, 30.0)
	editor_change_timer.start()
	_update_editor_sync_status()


func _on_editor_change_timeout() -> void:
	if sync_on_editor_changes_check.button_pressed:
		scan_project()


func _on_editor_script_changed(script: Script) -> void:
	if not _graph_view_enabled():
		return
	if not follow_active_script_check.button_pressed or script == null:
		return
	var path = str(script.resource_path)
	if _id_to_graph_node.has(path):
		_focus_node_id(path)


func _follow_current_editor_script() -> void:
	if _editor_interface == null or not follow_active_script_check.button_pressed:
		return
	var script_editor = _editor_interface.get_script_editor()
	if script_editor == null or not script_editor.has_method("get_current_script"):
		return
	var current_script = script_editor.call("get_current_script")
	if current_script is Script:
		_on_editor_script_changed(current_script as Script)


func _open_source(path: String, line: int = 1, column: int = 1) -> void:
	if _editor_interface == null or path.is_empty():
		return
	var resource = ResourceLoader.load(path)
	if resource == null or not resource is Script:
		_logger.warning(
			"Could not open script source.",
			{"code": "source_navigation_failed", "path": path, "line": line, "column": column}
		)
		return
	_editor_interface.edit_script(
		resource as Script, maxi(0, line - 1), maxi(0, column - 1), true
	)


func _open_scene_usage(path: String, _line: int = 1, _column: int = 1) -> void:
	if _editor_interface == null or path.is_empty():
		return
	if _editor_interface.has_method("open_scene_from_path"):
		_editor_interface.call("open_scene_from_path", path)
	else:
		_logger.warning(
			"Scene navigation is unavailable in this Godot version.",
			{"code": "scene_navigation_unavailable", "path": path}
		)


func _on_search_query_changed(_query: String) -> void:
	_apply_search()


func _apply_search() -> void:
	_search_match_ids.clear()
	if not _graph_view_enabled():
		_search_index = -1
		search_status.text = "Graph hidden"
		return
	_search_index = -1
	var query = search_input.text.strip_edges().to_lower()
	if not query.is_empty():
		for node_value in _snapshot.get("nodes", []):
			var node: Dictionary = node_value
			if _node_search_text(node).contains(query):
				_search_match_ids.append(str(node.get("id", "")))
	if not _search_match_ids.is_empty():
		_search_index = 0
	_update_search_visuals()
	if _search_index >= 0:
		_focus_node_id(_search_match_ids[_search_index], false)


func _node_search_text(node: Dictionary) -> String:
	var parts: Array[String] = [
		str(node.get("name", "")),
		str(node.get("class_name", "")),
		str(node.get("path", "")),
	]
	var autoload: Dictionary = node.get("autoload", {})
	parts.append(str(autoload.get("name", "")))
	for collection_name in ["properties", "signals", "methods", "inner_classes"]:
		for member_value in node.get(collection_name, []):
			if member_value is Dictionary:
				parts.append(str((member_value as Dictionary).get("name", "")))
	for usage_value in node.get("scene_usages", []):
		if usage_value is Dictionary:
			parts.append(str((usage_value as Dictionary).get("scene_path", "")))
			parts.append(str((usage_value as Dictionary).get("node_path", "")))
	return " ".join(parts).to_lower()


func _update_search_visuals() -> void:
	var search_active = not search_input.text.strip_edges().is_empty()
	var current_id = (
		_search_match_ids[_search_index]
		if _search_index >= 0 and _search_index < _search_match_ids.size()
		else ""
	)
	_apply_node_presentation_states(current_id, search_active)
	previous_match_button.disabled = _search_match_ids.is_empty()
	next_match_button.disabled = _search_match_ids.is_empty()
	if not search_active:
		search_status.text = ""
	elif not _search_match_ids.is_empty():
		search_status.text = "%s/%s" % [_search_index + 1, _search_match_ids.size()]
	else:
		search_status.text = "0 matches"


func _focus_previous_match() -> void:
	if _search_match_ids.is_empty():
		return
	_search_index = (_search_index - 1 + _search_match_ids.size()) % _search_match_ids.size()
	_update_search_visuals()
	_focus_node_id(_search_match_ids[_search_index])


func _focus_next_match() -> void:
	if _search_match_ids.is_empty():
		return
	_search_index = (_search_index + 1) % _search_match_ids.size()
	_update_search_visuals()
	_focus_node_id(_search_match_ids[_search_index])


func _focus_node_id(node_id: String, update_status: bool = true) -> void:
	if not _id_to_graph_node.has(node_id):
		return
	_focused_node_id = node_id
	var graph_node = _id_to_graph_node[node_id]
	_suppress_graph_selection_events = true
	for node_value in _graph_nodes:
		if is_instance_valid(node_value):
			node_value.selected = node_value == graph_node
	_suppress_graph_selection_events = false
	_update_relationship_focus(update_status)
	var center: Vector2 = graph_node.position_offset + graph_node.size * 0.5
	graph_edit.scroll_offset = center * graph_edit.zoom - graph_edit.size * 0.5
	if update_status:
		status_label.text = "Focused: %s" % str(_node_data_by_id.get(node_id, {}).get("name", node_id))


func _on_graph_node_selected(node: Node) -> void:
	if _suppress_graph_selection_events or node == null:
		return
	for node_id_value in _id_to_graph_node:
		var node_id: String = str(node_id_value)
		if _id_to_graph_node[node_id] == node:
			_focused_node_id = node_id
			_update_relationship_focus()
			return


func _on_graph_node_deselected(_node: Node) -> void:
	# Selection changes commonly emit deselection immediately before selection of
	# another node. Defer the check so a replacement selection can settle first.
	call_deferred("_clear_focus_if_no_graph_node_selected")


func _clear_focus_if_no_graph_node_selected() -> void:
	if _suppress_graph_selection_events:
		return
	for node_value in _graph_nodes:
		if is_instance_valid(node_value) and bool(node_value.selected):
			return
	if not _focused_node_id.is_empty():
		_focused_node_id = ""
		_update_relationship_focus()


func _clear_relationship_focus() -> void:
	_focused_node_id = ""
	_suppress_graph_selection_events = true
	for node_value in _graph_nodes:
		if is_instance_valid(node_value):
			node_value.selected = false
	_suppress_graph_selection_events = false
	_update_relationship_focus()


func _update_relationship_focus(_update_status: bool = true) -> void:
	_focus_related_ids.clear()
	_focus_visible_ids.clear()
	var focus_active: bool = not _focused_node_id.is_empty() and _snapshot_has_node(_focused_node_id)
	if focus_active:
		_focus_related_ids = _graph_query.call(
			"relationship_focus_ids",
			_snapshot,
			_focused_node_id,
			include_descendants_check.button_pressed
		)
		if isolate_neighborhood_check.button_pressed:
			_focus_visible_ids = _graph_query.call(
				"neighborhood_ids",
				_snapshot,
				_focused_node_id,
				include_descendants_check.button_pressed
			)
	else:
		_focused_node_id = ""
	for node_id_value in _id_to_graph_node:
		var node_id: String = str(node_id_value)
		var graph_node = _id_to_graph_node[node_id]
		if is_instance_valid(graph_node):
			graph_node.visible = not focus_active or not isolate_neighborhood_check.button_pressed or _focus_visible_ids.has(node_id)
	_apply_node_presentation_states()
	_render_visible_edges()
	clear_focus_button.disabled = not focus_active
	isolate_neighborhood_check.disabled = not focus_active
	if not focus_active:
		focus_status.text = "Select a node to inspect inheritance context"
	else:
		var counts: Dictionary = _graph_query.call("descendant_counts", _snapshot).get(
			_focused_node_id, {}
		)
		focus_status.text = "%s · %s direct · %s descendants%s" % [
			str(_node_data_by_id.get(_focused_node_id, {}).get("name", _focused_node_id)),
			int(counts.get("direct", 0)),
			int(counts.get("transitive", 0)),
			" · neighborhood isolated" if isolate_neighborhood_check.button_pressed else "",
		]


func _apply_node_presentation_states(current_search_id: String = "", search_active_override = null) -> void:
	var search_active: bool = (
		not search_input.text.strip_edges().is_empty()
		if search_active_override == null
		else bool(search_active_override)
	)
	var current_id: String = current_search_id
	if current_id.is_empty() and _search_index >= 0 and _search_index < _search_match_ids.size():
		current_id = _search_match_ids[_search_index]
	var focus_active: bool = not _focused_node_id.is_empty() and _snapshot_has_node(_focused_node_id)
	for node_id_value in _id_to_graph_node:
		var node_id: String = str(node_id_value)
		var graph_node = _id_to_graph_node[node_id]
		if graph_node != null and graph_node.has_method("set_presentation_state"):
			graph_node.call(
				"set_presentation_state",
				_search_match_ids.has(node_id),
				node_id == current_id,
				search_active,
				_focus_related_ids.has(node_id),
				node_id == _focused_node_id,
				focus_active
			)


func _render_visible_edges() -> void:
	graph_edit.clear_connections()
	var rendered_connections: Dictionary = {}
	for edge_value in _snapshot.get("edges", []):
		if not edge_value is Dictionary:
			continue
		var edge: Dictionary = edge_value
		var source_node = _id_to_graph_node.get(str(edge.get("source", "")))
		var target_node = _id_to_graph_node.get(str(edge.get("target", "")))
		if not is_instance_valid(source_node) or not is_instance_valid(target_node):
			continue
		if not source_node.visible or not target_node.visible:
			continue
		_render_edge(edge, rendered_connections)


func _snapshot_has_node(node_id: String) -> bool:
	for node_value in _snapshot.get("nodes", []):
		if node_value is Dictionary and str((node_value as Dictionary).get("id", "")) == node_id:
			return true
	return false


func _selected_format_id() -> String:
	if format_option.selected < 0:
		return "json"
	return str(format_option.get_item_metadata(format_option.selected))


func _on_log_entry(entry: Dictionary) -> void:
	log_view.append_text(
		"[%s] %s\n" % [str(entry.get("level", "info")).to_upper(), str(entry.get("message", ""))]
	)
