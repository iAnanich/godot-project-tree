@tool
extends EditorPlugin

const DOCK_SCRIPT_PATH := "res://addons/script_dependency_inspector/ui/dependency_dock.gd"
const TARGET_SCRIPT_PATH := "res://examples/media_showcase/player_character.gd"
const TARGET_NODE_ID := TARGET_SCRIPT_PATH
const TARGET_LINE := 10
const TARGET_COLUMN := 1

var _capture_state: String = ""
var _output_path: String = ""


func _enter_tree() -> void:
	_capture_state = OS.get_environment("SDI_MEDIA_CAPTURE_STATE").strip_edges()
	_output_path = OS.get_environment("SDI_MEDIA_CAPTURE_OUTPUT").strip_edges()
	if _capture_state.is_empty() or _output_path.is_empty():
		return
	call_deferred("_prepare_capture")


func _prepare_capture() -> void:
	await get_tree().create_timer(4.0).timeout
	var dock := _find_dependency_dock(get_editor_interface().get_base_control())
	if dock == null:
		_fail("Could not find the Script Dependency Inspector dock.")
		return
	var editor_dock := dock.get_parent()
	if editor_dock != null:
		if editor_dock.has_method("open"):
			editor_dock.call("open")
		if editor_dock.has_method("make_visible"):
			editor_dock.call("make_visible")
		if editor_dock is Control:
			(editor_dock as Control).custom_minimum_size.x = 660.0
	_configure_dock(dock)
	dock.call("scan_project")
	await get_tree().create_timer(2.0).timeout
	dock.call("_focus_node_id", TARGET_NODE_ID)
	dock.call("_open_source", TARGET_SCRIPT_PATH, TARGET_LINE, TARGET_COLUMN)
	get_editor_interface().set_main_screen_editor("Script")
	await get_tree().create_timer(2.0).timeout
	_focus_member_row(dock, "perform_attack")
	await get_tree().create_timer(1.0).timeout
	var image: Image = DisplayServer.screen_get_image(DisplayServer.get_primary_screen())
	var error := image.save_png(_output_path)
	if error != OK:
		_fail("Could not save editor media capture: %s" % error)
		return
	print("Saved editor media capture: %s" % _output_path)
	get_tree().quit(0)


func _configure_dock(dock: Control) -> void:
	dock.set("_suppress_control_events", true)
	dock.set("_scan_root", "res://examples/media_showcase")
	dock.call("_populate_scope_options")
	for path in [
		"%IncludeNative",
		"%IncludeExternal",
		"%IncludeMethods",
		"%IncludeSignals",
		"%IncludeProperties",
		"%IncludeDependencies",
		"%IncludeTypeDependencies",
		"%IncludeMemberAccessDependencies",
		"%ShowMemberDependencyEdges",
		"%MethodSignatures",
		"%SignalSignatures",
		"%PropertyTypes"
	]:
		(dock.get_node(path) as CheckBox).button_pressed = true
	(dock.get_node("%IncludeAddons") as CheckBox).button_pressed = false
	(dock.get_node("%AutoRescan") as CheckBox).button_pressed = false
	(dock.get_node("%AutoExportJson") as CheckBox).button_pressed = false
	(dock.get_node("%AutoExportMermaid") as CheckBox).button_pressed = false
	(dock.get_node("%AutoExportPlantUML") as CheckBox).button_pressed = false
	dock.set("_suppress_control_events", false)
	var split: VSplitContainer = dock.get_node("%MainSplit")
	split.split_offset = 105
	var tabs: TabContainer = dock.get_node("%ControlsTabs")
	tabs.current_tab = 0


func _focus_member_row(dock: Control, member_text: String) -> void:
	var id_to_graph_node = dock.get("_id_to_graph_node")
	if (
		not id_to_graph_node is Dictionary
		or not (id_to_graph_node as Dictionary).has(TARGET_NODE_ID)
	):
		return
	var graph_node = (id_to_graph_node as Dictionary)[TARGET_NODE_ID]
	if not graph_node is Node:
		return
	var member_button := _find_button_with_text(graph_node as Node, member_text)
	if member_button != null:
		member_button.grab_focus()


func _find_button_with_text(node: Node, expected: String) -> Button:
	if node is Button and expected in (node as Button).text:
		return node as Button
	for child in node.get_children():
		var match := _find_button_with_text(child, expected)
		if match != null:
			return match
	return null


func _find_dependency_dock(node: Node) -> Control:
	var script = node.get_script()
	if script is Script and (script as Script).resource_path == DOCK_SCRIPT_PATH:
		return node as Control
	for child in node.get_children():
		var match := _find_dependency_dock(child)
		if match != null:
			return match
	return null


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
