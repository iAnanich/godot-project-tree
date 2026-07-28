@tool
extends EditorPlugin

const ADDON_ROOT: String = "res://addons/script_dependency_inspector/"
const DOCK_SCRIPT_PATH: String = ADDON_ROOT + "ui/dependency_dock.gd"
const DOCK_SCENE_PATH: String = ADDON_ROOT + "ui/dependency_dock.tscn"

var _dock: Control


func _enter_tree() -> void:
	var dock_scene = _load_dock_scene()
	if dock_scene == null:
		return
	_dock = dock_scene.instantiate()
	if _dock == null:
		push_error(
			"Script Dependency Inspector could not instantiate its dock scene: %s" % DOCK_SCENE_PATH
		)
		return
	_dock.name = "Script Dependencies"
	if _dock.has_method("setup"):
		_dock.call("setup", get_editor_interface())
	# This original Godot 4 dock API is intentionally retained because it is
	# present throughout the Godot 4.x line. Newer APIs can be adopted behind
	# a compatibility shim after the minimum supported version changes.
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
	if is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()
	_dock = null


func _get_plugin_name() -> String:
	return "Script Dependency Inspector"


func _load_dock_scene() -> PackedScene:
	if not FileAccess.file_exists(DOCK_SCRIPT_PATH):
		push_error(
			(
				"Script Dependency Inspector is incomplete; required dock script is missing: %s"
				% DOCK_SCRIPT_PATH
			)
		)
		return null
	var script_resource = ResourceLoader.load(DOCK_SCRIPT_PATH)
	if script_resource == null or not script_resource is Script:
		push_error(
			"Script Dependency Inspector could not load required dock script: %s" % DOCK_SCRIPT_PATH
		)
		return null
	if not FileAccess.file_exists(DOCK_SCENE_PATH):
		push_error(
			(
				"Script Dependency Inspector is incomplete; required dock scene is missing: %s"
				% DOCK_SCENE_PATH
			)
		)
		return null
	var resource = ResourceLoader.load(DOCK_SCENE_PATH)
	if resource == null or not resource is PackedScene:
		push_error(
			"Script Dependency Inspector could not load required dock scene: %s" % DOCK_SCENE_PATH
		)
		return null
	return resource as PackedScene
