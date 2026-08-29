extends SceneTree

const DOCK_SCENE_PATH: String = "res://addons/script_dependency_inspector/ui/dependency_dock.tscn"

var _dock: Control
var _output_path: String = ""
var _capture_size: Vector2i = Vector2i(900, 1100)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: String = _requested_state()
	var resource: Resource = ResourceLoader.load(DOCK_SCENE_PATH)
	if resource == null or not resource is PackedScene:
		push_error("Could not load dependency dock scene.")
		quit(1)
		return
	root.size = _capture_size
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
		(
			visual_settings
			. set(
				"excluded_path_prefixes",
				PackedStringArray(
					[
						"res://.godot/",
						"res://addons/script_dependency_inspector/",
						"res://tests/",
					]
				)
			)
		)
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
		elif argument.begins_with("--width="):
			_capture_size.x = maxi(640, int(argument.trim_prefix("--width=")))
		elif argument.begins_with("--height="):
			_capture_size.y = maxi(480, int(argument.trim_prefix("--height=")))
	return requested


func _configure_state(state: String) -> void:
	_dock.set("_suppress_control_events", true)
	var media_state := state.begins_with("media_")
	var scan_root := "res://"
	if state == "scope":
		scan_root = "res://examples/showcase/actors"
	elif state == "media_complex":
		scan_root = "res://examples/showcase"
	elif state == "media_scope":
		scan_root = "res://examples/showcase/actors"
	elif media_state:
		scan_root = "res://examples/media_showcase"
	_dock.set("_scan_root", scan_root)
	_dock.call("_populate_scope_options")
	(_dock.get_node("%AutoRescan") as CheckBox).button_pressed = false
	(_dock.get_node("%AutoExportJson") as CheckBox).button_pressed = false
	(_dock.get_node("%AutoExportMermaid") as CheckBox).button_pressed = false
	(_dock.get_node("%AutoExportPlantUML") as CheckBox).button_pressed = false
	(_dock.get_node("%ShowGraph") as CheckButton).button_pressed = true
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
		(_dock.get_node(content_paths[key]) as CheckBox).button_pressed = false
	if media_state:
		for key in ["methods", "signals", "properties", "loads", "types"]:
			(_dock.get_node(content_paths[key]) as CheckBox).button_pressed = true
		if (
			state
			in [
				"media_max_info",
				"media_navigation",
				"media_member_tooltip",
				"media_connection_tooltip",
				"media_stale"
			]
		):
			for key in [
				"native",
				"external",
				"members",
				"anchors",
				"method_signatures",
				"signal_signatures",
				"property_types"
			]:
				(_dock.get_node(content_paths[key]) as CheckBox).button_pressed = true
		elif state == "media_complex":
			for key in ["native", "external", "members", "anchors"]:
				(_dock.get_node(content_paths[key]) as CheckBox).button_pressed = true
	else:
		for key in ["addons", "native", "external", "methods", "signals", "properties", "types"]:
			(_dock.get_node(content_paths[key]) as CheckBox).button_pressed = true
		if (
			state
			in ["analysis", "member_edges", "navigation", "context", "scope", "focus", "isolated"]
		):
			for key in [
				"loads",
				"members",
				"anchors",
				"method_signatures",
				"signal_signatures",
				"property_types"
			]:
				(_dock.get_node(content_paths[key]) as CheckBox).button_pressed = true
		if state == "native_chain":
			for key in ["loads", "types", "members"]:
				(_dock.get_node(content_paths[key]) as CheckBox).button_pressed = false
	if state in ["export_only", "media_export_only"]:
		(_dock.get_node("%ShowGraph") as CheckButton).button_pressed = false
	if (
		state
		in ["automation", "tooltip", "export_only", "media_tab_automation", "media_export_only"]
	):
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
		"automation", "tooltip", "sync", "export_only", "media_tab_automation", "media_export_only":
			split.split_offset = 420 if state.begins_with("media_") else 350
			tabs.current_tab = 3
		"colors", "media_tab_colors":
			split.split_offset = 500 if state.begins_with("media_") else 350
			tabs.current_tab = 2
		"appearance", "media_tab_appearance":
			split.split_offset = 500 if state.begins_with("media_") else 300
			tabs.current_tab = 1
		"summary", "media_tab_summary":
			split.split_offset = 500 if state.begins_with("media_") else 300
			tabs.current_tab = 4
		"media_tab_log":
			split.split_offset = 500
			tabs.current_tab = 5
		"media_tab_content":
			split.split_offset = 500
			tabs.current_tab = 0
		"media_overview", "media_max_info", "media_complex", "media_navigation", "media_scope", "media_search", "media_member_tooltip", "media_connection_tooltip", "media_stale":
			split.split_offset = 125
			tabs.current_tab = 0
		_:
			tabs.current_tab = 0
	if state in ["export_only", "media_export_only"]:
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
	if state in ["media_overview", "media_max_info"]:
		call_deferred("_prepare_media_simple_view", state == "media_max_info")
	if state == "media_complex":
		call_deferred("_prepare_media_complex_view")
	if state == "media_scope":
		call_deferred("_prepare_media_scope_view")
	if state == "media_search":
		call_deferred("_prepare_media_search_view")
	if state == "media_member_tooltip":
		call_deferred("_prepare_media_member_tooltip")
	if state == "media_connection_tooltip":
		call_deferred("_prepare_media_connection_tooltip")
	if state == "media_stale":
		call_deferred("_prepare_media_stale_view")


func _prepare_media_stale_view() -> void:
	await process_frame
	await process_frame
	_dock.set("_scan_root", "res://examples/media_showcase")
	(
		_dock
		. call(
			"_finish_scan_failure",
			"Snapshot validation failed [validator_unavailable] for res://examples/media_showcase; see Log."
		)
	)
	var split: VSplitContainer = _dock.get_node("%MainSplit")
	split.split_offset = 360
	var tabs: TabContainer = _dock.get_node("%ControlsTabs")
	tabs.current_tab = 4


func _prepare_media_simple_view(maximum_information: bool) -> void:
	await process_frame
	await process_frame
	var positions: Dictionary
	if maximum_information:
		positions = {
			"Object": Vector2(690, 10),
			"Node": Vector2(350, 105),
			"RefCounted": Vector2(960, 105),
			"Resource": Vector2(1160, 190),
			"MediaBaseCharacter": Vector2(330, 235),
			"MediaPlayerCharacter": Vector2(80, 555),
			"MediaEnemyCharacter": Vector2(570, 555),
			"MediaDamageService": Vector2(1050, 360),
			"MediaWeaponData": Vector2(1100, 610),
			"MediaBattleController": Vector2(1510, 500),
		}
		_place_nodes_by_name(positions)
		var graph_max: GraphEdit = _dock.get_node("%GraphEdit")
		graph_max.zoom = 0.52
		graph_max.scroll_offset = Vector2.ZERO
	else:
		positions = {
			"MediaWeaponData": Vector2(40, 45),
			"MediaBaseCharacter": Vector2(590, 35),
			"MediaDamageService": Vector2(1260, 45),
			"MediaPlayerCharacter": Vector2(275, 390),
			"MediaEnemyCharacter": Vector2(760, 390),
			"MediaBattleController": Vector2(1300, 400),
		}
		_place_nodes_by_name(positions)
		var graph: GraphEdit = _dock.get_node("%GraphEdit")
		graph.zoom = 0.72
		graph.scroll_offset = Vector2.ZERO


func _place_nodes_by_name(positions: Dictionary) -> void:
	var snapshot_value = _dock.get("_snapshot")
	var graph_nodes_value = _dock.get("_graph_nodes")
	if not snapshot_value is Dictionary or not graph_nodes_value is Array:
		return
	var snapshot: Dictionary = snapshot_value
	var graph_nodes: Array = graph_nodes_value
	for index in range(mini(snapshot.get("nodes", []).size(), graph_nodes.size())):
		var node_data: Dictionary = snapshot["nodes"][index]
		var display_name: String = str(node_data.get("name", ""))
		if positions.has(display_name):
			(graph_nodes[index] as GraphNode).position_offset = positions[display_name]


func _prepare_media_complex_view() -> void:
	await process_frame
	await process_frame
	var graph: GraphEdit = _dock.get_node("%GraphEdit")
	if graph.has_method("arrange_nodes"):
		graph.call("arrange_nodes")
	await process_frame
	await process_frame
	_fit_graph_to_nodes(55.0, 0.68)


func _prepare_media_scope_view() -> void:
	await process_frame
	_dock.call("_focus_node_id", "res://examples/showcase/actors/base_actor.gd")
	await process_frame
	_fit_graph_to_nodes(70.0, 0.9)


func _prepare_media_search_view() -> void:
	await process_frame
	var input: LineEdit = _dock.get_node("%SearchInput")
	input.text = "perform_attack"
	_dock.call("_apply_search")
	await process_frame
	_fit_graph_to_nodes(70.0, 0.9)


func _prepare_media_member_tooltip() -> void:
	_restrict_snapshot_to_names(["MediaPlayerCharacter"])
	await process_frame
	await process_frame
	_place_nodes_by_name({"MediaPlayerCharacter": Vector2(220, 60)})
	var graph: GraphEdit = _dock.get_node("%GraphEdit")
	graph.zoom = 1.0
	graph.scroll_offset = Vector2.ZERO
	await process_frame
	var id_to_graph_node_value = _dock.get("_id_to_graph_node")
	if not id_to_graph_node_value is Dictionary:
		return
	var id_to_graph_node: Dictionary = id_to_graph_node_value
	var target_id: String = "res://examples/media_showcase/player_character.gd"
	if not id_to_graph_node.has(target_id):
		return
	var graph_node: GraphNode = id_to_graph_node[target_id] as GraphNode
	var member_button: Button = _find_button_with_text(graph_node, "perform_attack")
	if member_button == null:
		return
	await _warp_mouse_to_control_position(member_button, member_button.size * 0.5)


func _prepare_media_connection_tooltip() -> void:
	_restrict_snapshot_to_names(["MediaPlayerCharacter", "MediaDamageService", "MediaWeaponData"])
	await process_frame
	await process_frame
	_place_nodes_by_name(
		{
			"MediaPlayerCharacter": Vector2(120, 20),
			"MediaDamageService": Vector2(760, 20),
			"MediaWeaponData": Vector2(760, 260),
		}
	)
	var graph: GraphEdit = _dock.get_node("%GraphEdit")
	graph.zoom = 0.9
	graph.scroll_offset = Vector2.ZERO
	await process_frame
	for connection_value in graph.get_connection_list():
		if not connection_value is Dictionary:
			continue
		var connection: Dictionary = connection_value
		var from_node: GraphNode = (
			graph.get_node_or_null(NodePath(str(connection.get("from_node", "")))) as GraphNode
		)
		var to_node: GraphNode = (
			graph.get_node_or_null(NodePath(str(connection.get("to_node", "")))) as GraphNode
		)
		if from_node == null or to_node == null:
			continue
		var from_port: int = int(connection.get("from_port", 0))
		var to_port: int = int(connection.get("to_port", 0))
		var from_position: Vector2 = (
			from_node.position + from_node.get_output_port_position(from_port)
		)
		var to_position: Vector2 = to_node.position + to_node.get_input_port_position(to_port)
		var line: PackedVector2Array = graph.get_connection_line(from_position, to_position)
		for point: Vector2 in line:
			var tooltip: String = str(graph.call("_get_tooltip", point))
			if tooltip == graph.tooltip_text:
				continue
			await _warp_mouse_to_control_position(graph, point)
			if (
				str(graph.call("_get_tooltip", graph.get_local_mouse_position()))
				!= graph.tooltip_text
			):
				return


func _warp_mouse_to_control_position(control: Control, local_position: Vector2) -> void:
	var screen_target: Vector2 = control.get_screen_transform() * local_position
	for _attempt in range(3):
		Input.warp_mouse(screen_target)
		await process_frame
		await process_frame
		var actual_local: Vector2 = control.get_local_mouse_position()
		var local_error: Vector2 = local_position - actual_local
		if local_error.length() <= 1.0:
			return
		screen_target += local_error


func _find_button_with_text(node: Node, expected: String) -> Button:
	if node is Button and expected in (node as Button).text:
		return node as Button
	for child in node.get_children():
		var match: Button = _find_button_with_text(child, expected)
		if match != null:
			return match
	return null


func _fit_graph_to_nodes(margin: float, maximum_zoom: float) -> void:
	var graph: GraphEdit = _dock.get_node("%GraphEdit")
	var graph_nodes_value = _dock.get("_graph_nodes")
	if not graph_nodes_value is Array or (graph_nodes_value as Array).is_empty():
		return
	var graph_nodes: Array = graph_nodes_value
	var first_node: GraphNode = graph_nodes[0] as GraphNode
	var minimum: Vector2 = first_node.position_offset
	var maximum: Vector2 = first_node.position_offset + first_node.size
	for node_value in graph_nodes:
		var graph_node: GraphNode = node_value as GraphNode
		minimum.x = minf(minimum.x, graph_node.position_offset.x)
		minimum.y = minf(minimum.y, graph_node.position_offset.y)
		maximum.x = maxf(maximum.x, graph_node.position_offset.x + graph_node.size.x)
		maximum.y = maxf(maximum.y, graph_node.position_offset.y + graph_node.size.y)
	var bounds: Vector2 = maximum - minimum + Vector2(margin * 2.0, margin * 2.0)
	var available: Vector2 = Vector2(maxf(1.0, graph.size.x), maxf(1.0, graph.size.y))
	var zoom_value: float = minf(available.x / bounds.x, available.y / bounds.y)
	graph.zoom = clampf(zoom_value, 0.25, maximum_zoom)
	var center: Vector2 = (minimum + maximum) * 0.5
	graph.scroll_offset = center * graph.zoom - graph.size * 0.5


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
	_restrict_snapshot_to_names(
		[
			"Object",
			"RefCounted",
			"Node",
			"ShowcaseCombatEntity",
			"ShowcaseBaseActor",
			"ShowcaseDamageService",
			"ShowcaseWeaponProfile"
		]
	)
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
