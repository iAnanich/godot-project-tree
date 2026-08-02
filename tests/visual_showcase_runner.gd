extends SceneTree

const DOCK_SCENE_PATH: String = "res://addons/script_dependency_inspector/ui/dependency_dock.tscn"

var _dock: Control
var _output_path: String = ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var resource: Resource = ResourceLoader.load(DOCK_SCENE_PATH)
	if resource == null or not resource is PackedScene:
		push_error("Could not load dependency dock scene.")
		quit(1)
		return
	root.size = Vector2i(900, 1100)
	DisplayServer.window_set_title("Script Dependency Inspector — Visual Showcase")
	var background: ColorRect = ColorRect.new()
	background.color = Color("16181c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	_dock = (resource as PackedScene).instantiate()
	background.add_child(_dock)
	_dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	var visual_settings: Resource = _dock.get("settings")
	if visual_settings != null:
		visual_settings.set("excluded_path_prefixes", PackedStringArray([
			"res://.godot/",
			"res://addons/script_dependency_inspector/",
			"res://tests/",
		]))
	var state: String = _requested_state()
	_configure_state(state)
	_dock.call("scan_project")
	await process_frame
	await process_frame
	_configure_after_scan(state)
	call_deferred("_capture_when_ready")


func _requested_state() -> String:
	var requested: String = "overview"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--state="):
			requested = argument.trim_prefix("--state=")
		elif argument.begins_with("--output="):
			_output_path = argument.trim_prefix("--output=")
	return requested


func _configure_state(state: String) -> void:
	_dock.set("_suppress_control_events", true)
	_dock.set(
		"_scan_root",
		"res://examples/showcase/actors" if state == "scope" else "res://"
	)
	_dock.call("_populate_scope_options")
	(_dock.get_node("%AutoRescan") as CheckBox).button_pressed = false
	(_dock.get_node("%AutoExportJson") as CheckBox).button_pressed = false
	(_dock.get_node("%AutoExportMermaid") as CheckBox).button_pressed = false
	(_dock.get_node("%AutoExportPlantUML") as CheckBox).button_pressed = false
	var content_paths: Dictionary = {
		"addons": "%IncludeAddons",
		"native": "%IncludeNative",
		"external": "%IncludeExternal",
		"methods": "%IncludeMethods",
		"signals": "%IncludeSignals",
		"properties": "%IncludeProperties",
		"loads": "%IncludeDependencies",
		"types": "%IncludeTypeDependencies",
		"members": "%IncludeMemberAccessDependencies",
		"anchors": "%ShowMemberDependencyEdges",
		"method_signatures": "%MethodSignatures",
		"signal_signatures": "%SignalSignatures",
		"property_types": "%PropertyTypes",
	}
	for key in content_paths:
		var control: CheckBox = _dock.get_node(content_paths[key])
		control.button_pressed = key in ["addons", "native", "external", "methods", "signals", "properties", "types"]
	if state in ["analysis", "member_edges", "navigation", "context", "scope", "focus", "isolated"]:
		for key in ["loads", "members", "anchors", "method_signatures", "signal_signatures", "property_types"]:
			(_dock.get_node(content_paths[key]) as CheckBox).button_pressed = true
	if state == "native_chain":
		(_dock.get_node(content_paths["loads"]) as CheckBox).button_pressed = false
		(_dock.get_node(content_paths["types"]) as CheckBox).button_pressed = false
		(_dock.get_node(content_paths["members"]) as CheckBox).button_pressed = false
	if state == "export_only":
		(_dock.get_node("%ShowGraph") as CheckButton).button_pressed = false
	if state in ["automation", "tooltip", "export_only"]:
		(_dock.get_node("%AutoRescan") as CheckBox).button_pressed = true
		(_dock.get_node("%AutoRescanDelay") as SpinBox).value = 60.0
		(_dock.get_node("%AutoExportJson") as CheckBox).button_pressed = true
		(_dock.get_node("%AutoExportMermaid") as CheckBox).button_pressed = true
		(_dock.get_node("%AutoExportPlantUML") as CheckBox).button_pressed = true
		(_dock.get_node("%AutoExportJsonPath") as LineEdit).text = "user://script_dependency_inspector/visual_showcase/script_dependencies.json"
		(_dock.get_node("%AutoExportMermaidPath") as LineEdit).text = "user://script_dependency_inspector/visual_showcase/script_dependencies.mmd"
		(_dock.get_node("%AutoExportPlantUMLPath") as LineEdit).text = "user://script_dependency_inspector/visual_showcase/script_dependencies.puml"
	_dock.set("_suppress_control_events", false)


func _configure_after_scan(state: String) -> void:
	var split: VSplitContainer = _dock.get_node("%MainSplit")
	split.split_offset = 250
	var tabs: TabContainer = _dock.get_node("%ControlsTabs")
	match state:
		"automation", "tooltip", "sync", "export_only":
			split.split_offset = 350
			tabs.current_tab = 3
		"colors":
			split.split_offset = 350
			tabs.current_tab = 2
		"appearance":
			split.split_offset = 300
			tabs.current_tab = 1
		"summary":
			split.split_offset = 300
			tabs.current_tab = 4
		_:
			tabs.current_tab = 0
	if state == "export_only":
		tabs.current_tab = 3
		(_dock.get_node("%ShowGraph") as CheckButton).button_pressed = false
		_dock.call("_apply_graph_view_visibility", false)
	if state == "folded_controls":
		tabs.current_tab = 0
		for key in ["content_members", "content_relations", "content_export"]:
			var section: Dictionary = (_dock.get("_fold_sections") as Dictionary).get(key, {})
			var header: Button = section.get("header")
			if header != null:
				header.button_pressed = false
				_dock.call("_apply_fold_section", key, false)
	if state == "search":
		call_deferred("_prepare_search_view")
	if state == "navigation":
		call_deferred("_prepare_navigation_view")
	if state == "context":
		call_deferred("_prepare_context_view")
	if state == "member_edges":
		call_deferred("_prepare_member_edge_view")
	if state == "native_chain":
		call_deferred("_prepare_native_chain_view")
	if state == "scope":
		call_deferred("_prepare_scope_view")
	if state == "focus":
		call_deferred("_prepare_focus_view")
	if state == "isolated":
		call_deferred("_prepare_isolated_view")
	if state == "arranged":
		var graph: GraphEdit = _dock.get_node("%GraphEdit")
		if graph.has_method("arrange_nodes"):
			graph.call("arrange_nodes")
	if state == "tooltip":
		call_deferred("_hover_automation_delay")


func _prepare_scope_view() -> void:
	await process_frame
	_dock.call("_focus_node_id", "res://examples/showcase/actors/base_actor.gd")
	var graph: GraphEdit = _dock.get_node("%GraphEdit")
	graph.zoom = 0.78


func _prepare_focus_view() -> void:
	var include_descendants: CheckBox = _dock.get_node("%IncludeDescendants")
	include_descendants.button_pressed = true
	_dock.call("_focus_node_id", "res://examples/showcase/actors/base_actor.gd")
	await process_frame


func _prepare_isolated_view() -> void:
	var include_descendants: CheckBox = _dock.get_node("%IncludeDescendants")
	var isolate: CheckBox = _dock.get_node("%IsolateNeighborhood")
	include_descendants.button_pressed = false
	_dock.call("_focus_node_id", "res://examples/showcase/controllers/battle_controller.gd")
	isolate.button_pressed = true
	_dock.call("_update_relationship_focus")
	await process_frame


func _prepare_member_edge_view() -> void:
	_restrict_snapshot_to_names(
		[
			"Object",
			"Node",
			"RefCounted",
			"ShowcaseCombatEntity",
			"ShowcaseBaseActor",
			"ShowcaseDamageService",
			"ShowcaseWeaponProfile",
		]
	)
	await process_frame
	await process_frame
	_place_member_edge_nodes()


func _place_member_edge_nodes() -> void:
	var positions: Dictionary = {
		"Object": Vector2(30, 70),
		"Node": Vector2(30, 140),
		"ShowcaseCombatEntity": Vector2(30, 220),
		"ShowcaseBaseActor": Vector2(30, 500),
		"RefCounted": Vector2(500, 140),
		"ShowcaseWeaponProfile": Vector2(500, 220),
		"ShowcaseDamageService": Vector2(500, 500),
	}
	var snapshot: Dictionary = _dock.get("_snapshot")
	var graph_nodes: Array = _dock.get("_graph_nodes")
	for index in range(mini(snapshot.get("nodes", []).size(), graph_nodes.size())):
		var node_data: Dictionary = snapshot["nodes"][index]
		var display_name: String = str(node_data.get("name", ""))
		if positions.has(display_name):
			(graph_nodes[index] as GraphNode).position_offset = positions[display_name]
	var graph: GraphEdit = _dock.get_node("%GraphEdit")
	graph.zoom = 0.85
	graph.scroll_offset = Vector2.ZERO


func _prepare_native_chain_view() -> void:
	_restrict_snapshot_to_names(
		[
			"Object",
			"Node",
			"CanvasItem",
			"Control",
			"Node2D",
			"Node3D",
			"ShowcaseBattlePanel",
			"ambient_marker",
			"ShowcaseArenaAnchor3D",
		]
	)


func _restrict_snapshot_to_names(display_names: Array[String]) -> void:
	var snapshot_value = _dock.get("_snapshot")
	if not snapshot_value is Dictionary:
		return
	var snapshot: Dictionary = (snapshot_value as Dictionary).duplicate(true)
	var kept_nodes: Array = []
	var kept_ids: Dictionary = {}
	for node_value in snapshot.get("nodes", []):
		var node_data: Dictionary = node_value
		if display_names.has(str(node_data.get("name", ""))):
			kept_nodes.append(node_data)
			kept_ids[str(node_data.get("id", ""))] = true
	var kept_edges: Array = []
	for edge_value in snapshot.get("edges", []):
		var edge: Dictionary = edge_value
		if kept_ids.has(str(edge.get("source", ""))) and kept_ids.has(str(edge.get("target", ""))):
			kept_edges.append(edge)
	snapshot["nodes"] = kept_nodes
	snapshot["edges"] = kept_edges
	_dock.set("_snapshot", snapshot)
	_dock.call("_render_snapshot")
	var status: Label = _dock.get_node("StatusLabel")
	status.text = "%d nodes · %d edges · focused showcase" % [kept_nodes.size(), kept_edges.size()]


func _focus_graph_nodes(display_names: Array[String]) -> void:
	var snapshot_value = _dock.get("_snapshot")
	var graph_nodes_value = _dock.get("_graph_nodes")
	if not snapshot_value is Dictionary or not graph_nodes_value is Array:
		return
	var snapshot: Dictionary = snapshot_value
	var graph_nodes: Array = graph_nodes_value
	var positions: Array[Vector2] = []
	for index in range(mini(snapshot.get("nodes", []).size(), graph_nodes.size())):
		var node_data: Dictionary = snapshot["nodes"][index]
		if display_names.has(str(node_data.get("name", ""))):
			positions.append((graph_nodes[index] as GraphNode).position_offset)
	if positions.is_empty():
		return
	var minimum := positions[0]
	for position in positions:
		minimum.x = minf(minimum.x, position.x)
		minimum.y = minf(minimum.y, position.y)
	var graph: GraphEdit = _dock.get_node("%GraphEdit")
	graph.zoom = 1.0
	graph.scroll_offset = Vector2(maxf(0.0, minimum.x - 80.0), maxf(0.0, minimum.y - 380.0))


func _hover_automation_delay() -> void:
	await create_timer(0.5).timeout
	var control: Control = _dock.get_node("%AutoRescanDelay")
	Input.warp_mouse(control.global_position + control.size * 0.5)


func _prepare_search_view() -> void:
	var input: LineEdit = _dock.get_node("%SearchInput")
	input.text = "BattleCoordinator"
	_dock.call("_apply_search")


func _prepare_navigation_view() -> void:
	_restrict_snapshot_to_names([
		"Object", "RefCounted", "Node", "ShowcaseCombatEntity",
		"ShowcaseBaseActor", "ShowcaseDamageService", "ShowcaseWeaponProfile"
	])
	await process_frame
	var graph: GraphEdit = _dock.get_node("%GraphEdit")
	graph.zoom = 0.85
	graph.scroll_offset = Vector2.ZERO


func _prepare_context_view() -> void:
	_restrict_snapshot_to_names(["Object", "Node", "ShowcaseBattleController"])
	await process_frame
	var input: LineEdit = _dock.get_node("%SearchInput")
	input.text = "BattleCoordinator"
	_dock.call("_apply_search")


func _capture_when_ready() -> void:
	await create_timer(1.2).timeout
	if _output_path.is_empty():
		return
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(_output_path)
	if error != OK:
		push_error("Could not save visual showcase image: %s" % _output_path)
		quit(1)
		return
	print("Saved visual showcase: %s" % _output_path)
	quit(0)
