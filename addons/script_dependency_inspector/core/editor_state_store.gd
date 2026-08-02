@tool
extends RefCounted

## Persists editor-only inspector preferences outside release artifacts.
## The state is stored below res://.godot, which is project-local and normally
## excluded from version control and exported games.

const STATE_SCHEMA_VERSION: int = 4


## Returns a validated state merged with defaults and optional warning text.
func load_state(path: String, defaults: Dictionary) -> Dictionary:
	var state: Dictionary = defaults.duplicate(true)
	if not FileAccess.file_exists(path):
		return {"ok": true, "state": state, "warning": ""}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"state": state,
			"warning": "Could not read editor state: %s" % path,
		}
	var text: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {
			"ok": false,
			"state": state,
			"warning": "Editor state is not a JSON object; defaults were used.",
		}
	var loaded: Dictionary = parsed
	var loaded_schema_value = loaded.get("schema_version", null)
	if not loaded_schema_value is int and not loaded_schema_value is float:
		return {
			"ok": false,
			"state": state,
			"warning": "Editor state schema must be an integer; defaults were used.",
		}
	var loaded_schema_number: float = float(loaded_schema_value)
	if not is_equal_approx(loaded_schema_number, floorf(loaded_schema_number)):
		return {
			"ok": false,
			"state": state,
			"warning": "Editor state schema must be an integer; defaults were used.",
		}
	var loaded_schema: int = int(loaded_schema_number)
	if loaded_schema not in [1, 2, 3, STATE_SCHEMA_VERSION]:
		return {
			"ok": false,
			"state": state,
			"warning": "Editor state has an unsupported schema; defaults were used.",
		}
	_merge_known_fields(state, loaded)
	return {"ok": true, "state": state, "warning": ""}


## Atomically writes validated editor-only state with same-directory rollback.
func save_state(path: String, state: Dictionary) -> Dictionary:
	var normalized: Dictionary = _normalized_state(state)
	var directory_result: Dictionary = _ensure_parent_directory(path)
	if not directory_result.get("ok", false):
		return directory_result
	var operation_id: String = str(Time.get_ticks_usec())
	var temporary_path: String = path + ".%s.tmp" % operation_id
	var backup_path: String = path + ".%s.bak" % operation_id
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"error": "Could not open temporary editor-state file: %s" % temporary_path,
		}
	file.store_string(JSON.stringify(normalized, "  ", false) + "\n")
	file.flush()
	file.close()
	var absolute_temp: String = ProjectSettings.globalize_path(temporary_path)
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var absolute_backup: String = ProjectSettings.globalize_path(backup_path)
	var had_existing: bool = FileAccess.file_exists(path)
	if had_existing:
		var stage_error: Error = DirAccess.rename_absolute(absolute_path, absolute_backup)
		if stage_error != OK:
			DirAccess.remove_absolute(absolute_temp)
			return {
				"ok": false,
				"error": "Could not stage existing editor-state file: %s" % path,
			}
	var commit_error: Error = DirAccess.rename_absolute(absolute_temp, absolute_path)
	if commit_error != OK:
		DirAccess.remove_absolute(absolute_temp)
		if had_existing:
			DirAccess.rename_absolute(absolute_backup, absolute_path)
		return {
			"ok": false,
			"error": "Could not commit editor state: %s" % path,
		}
	if had_existing:
		DirAccess.remove_absolute(absolute_backup)
	return {"ok": true, "error": ""}


func _merge_known_fields(target: Dictionary, source: Dictionary) -> void:
	if source.get("scan_root") is String:
		target["scan_root"] = _normalized_project_root(str(source["scan_root"]))
	if source.get("recent_scan_roots") is Array:
		var recent: Array[String] = []
		for root_value in source["recent_scan_roots"]:
			if not root_value is String:
				continue
			var normalized_root: String = _normalized_project_root(str(root_value))
			if not recent.has(normalized_root):
				recent.append(normalized_root)
			if recent.size() >= 8:
				break
		if not recent.has("res://"):
			recent.append("res://")
		target["recent_scan_roots"] = recent
	if source.get("focus_include_descendants") is bool:
		target["focus_include_descendants"] = source["focus_include_descendants"]
	if source.get("isolate_neighborhood") is bool:
		target["isolate_neighborhood"] = source["isolate_neighborhood"]
	if source.get("graph_view_enabled") is bool:
		target["graph_view_enabled"] = source["graph_view_enabled"]
	if source.get("control_section_expanded") is Dictionary:
		var section_source: Dictionary = source["control_section_expanded"]
		var section_target: Dictionary = target.get("control_section_expanded", {})
		for section_key in section_target.keys():
			if section_source.get(section_key) is bool:
				section_target[section_key] = section_source[section_key]
		target["control_section_expanded"] = section_target
	if source.get("sync_on_editor_changes") is bool:
		target["sync_on_editor_changes"] = source["sync_on_editor_changes"]
	if source.get("editor_change_debounce_seconds") is float or source.get("editor_change_debounce_seconds") is int:
		target["editor_change_debounce_seconds"] = clampf(
			float(source["editor_change_debounce_seconds"]), 0.25, 30.0
		)
	if source.get("follow_active_script") is bool:
		target["follow_active_script"] = source["follow_active_script"]
	if source.get("auto_rescan_enabled") is bool:
		target["auto_rescan_enabled"] = source["auto_rescan_enabled"]
	if source.get("auto_rescan_delay_seconds") is float or source.get("auto_rescan_delay_seconds") is int:
		target["auto_rescan_delay_seconds"] = clampf(
			float(source["auto_rescan_delay_seconds"]), 5.0, 86400.0
		)
	for key in ["auto_export", "export_paths"]:
		if not source.get(key) is Dictionary:
			continue
		var source_values: Dictionary = source[key]
		var target_values: Dictionary = target.get(key, {})
		for format_id in ["json", "mermaid", "plantuml"]:
			if key == "auto_export" and source_values.get(format_id) is bool:
				target_values[format_id] = source_values[format_id]
			elif key == "export_paths" and source_values.get(format_id) is String:
				target_values[format_id] = str(source_values[format_id])
		target[key] = target_values


func _normalized_state(state: Dictionary) -> Dictionary:
	var defaults: Dictionary = {
		"schema_version": STATE_SCHEMA_VERSION,
		"scan_root": "res://",
		"recent_scan_roots": ["res://"],
		"focus_include_descendants": false,
		"isolate_neighborhood": false,
		"graph_view_enabled": true,
		"control_section_expanded": {
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
		"sync_on_editor_changes": true,
		"editor_change_debounce_seconds": 1.0,
		"follow_active_script": true,
		"auto_rescan_enabled": false,
		"auto_rescan_delay_seconds": 60.0,
		"auto_export": {"json": false, "mermaid": false, "plantuml": false},
		"export_paths": {"json": "", "mermaid": "", "plantuml": ""},
	}
	_merge_known_fields(defaults, state)
	return defaults


func _ensure_parent_directory(path: String) -> Dictionary:
	var directory: String = path.get_base_dir()
	if directory.is_empty():
		return {"ok": true}
	var absolute_directory: String = ProjectSettings.globalize_path(directory)
	if DirAccess.dir_exists_absolute(absolute_directory):
		return {"ok": true}
	var error: Error = DirAccess.make_dir_recursive_absolute(absolute_directory)
	if error != OK:
		return {
			"ok": false,
			"error": "Could not create editor-state directory: %s" % directory,
		}
	return {"ok": true}


func _normalized_project_root(value: String) -> String:
	var normalized: String = value.strip_edges().replace("\\", "/").simplify_path()
	if normalized.is_empty() or (normalized != "res://" and not normalized.begins_with("res://")):
		return "res://"
	return normalized.trim_suffix("/") if normalized != "res://" else normalized
