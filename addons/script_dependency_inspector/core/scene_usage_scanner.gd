@tool
extends RefCounted

## Bounded, text-only scanner for exact script attachments in Godot .tscn files.
## Binary .scn files and dynamic resource assignments are intentionally outside
## this scanner's evidence boundary.


## Returns deterministic usage records for external Script resources assigned to
## scene nodes. Lines and columns are one-based for user-facing navigation.
func scan(scene_paths: Array, maximum_scene_bytes: int = 4194304) -> Dictionary:
	var usages: Array = []
	var warnings: Array = []
	for scene_path_value in scene_paths:
		var scene_path = str(scene_path_value)
		var read_result = _read_text_file(scene_path, maximum_scene_bytes)
		if not read_result.get("ok", false):
			warnings.append(
				"Could not inspect scene %s: %s" % [scene_path, read_result.get("error", "read failed")]
			)
			continue
		usages.append_array(_scan_text(scene_path, str(read_result.get("text", ""))))
	usages.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return _usage_sort_key(left) < _usage_sort_key(right)
	)
	return {"usages": usages, "warnings": warnings}


func _scan_text(scene_path: String, text: String) -> Array:
	var external_scripts: Dictionary = {}
	var usages: Array = []
	var current_node_path = ""
	var lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n", true)
	for line_index in range(lines.size()):
		var raw_line: String = str(lines[line_index])
		var line = raw_line.strip_edges()
		if line.begins_with("[ext_resource ") and line.contains('type="Script"'):
			var resource_id = _attribute(line, "id")
			var script_path = _attribute(line, "path")
			if not resource_id.is_empty() and script_path.ends_with(".gd"):
				external_scripts[resource_id] = _normalize_resource_path(script_path, scene_path)
			continue
		if line.begins_with("["):
			current_node_path = _node_path(line) if line.begins_with("[node ") else ""
			continue
		if current_node_path.is_empty():
			continue
		var assignment_index: int = line.find("=")
		if assignment_index < 0 or line.substr(0, assignment_index).strip_edges() != "script":
			continue
		var resource_id = _ext_resource_id(line)
		if resource_id.is_empty() or not external_scripts.has(resource_id):
			continue
		usages.append(
			{
				"scene_path": scene_path,
				"node_path": current_node_path,
				"script_path": str(external_scripts[resource_id]),
				"line": line_index + 1,
				"column": _first_non_whitespace_column(raw_line),
				"evidence": "tscn_node_script_attachment",
			}
		)
	return usages


func _first_non_whitespace_column(line: String) -> int:
	for index in range(line.length()):
		if line.substr(index, 1) not in [" ", "\t"]:
			return index + 1
	return 1


func _attribute(header: String, key: String) -> String:
	var marker = key + '=\"'
	var start = header.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var finish = header.find('\"', start)
	if finish < 0:
		return ""
	return header.substr(start, finish - start)


func _node_path(header: String) -> String:
	var name = _attribute(header, "name")
	var parent = _attribute(header, "parent")
	if name.is_empty():
		return ""
	if parent.is_empty() or parent == ".":
		return name
	return parent.trim_suffix("/") + "/" + name


func _ext_resource_id(line: String) -> String:
	var marker = 'ExtResource("'
	var start = line.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var finish = line.find('\"', start)
	if finish < 0:
		return ""
	return line.substr(start, finish - start)


func _normalize_resource_path(path: String, owner_path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return path.simplify_path()
	return owner_path.get_base_dir().path_join(path).simplify_path()


func _read_text_file(path: String, maximum_bytes: int) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "text": "", "error": FileAccess.get_open_error()}
	var length = file.get_length()
	if length > maximum_bytes:
		file.close()
		return {
			"ok": false,
			"text": "",
			"error": "file is %s bytes; limit is %s" % [length, maximum_bytes],
		}
	var text = file.get_as_text()
	file.close()
	return {"ok": true, "text": text, "error": OK}


func _usage_sort_key(usage: Dictionary) -> String:
	return "%s|%s|%s|%09d" % [
		usage.get("script_path", ""),
		usage.get("scene_path", ""),
		usage.get("node_path", ""),
		int(usage.get("line", 0)),
	]
