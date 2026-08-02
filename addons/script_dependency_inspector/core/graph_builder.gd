@tool
extends RefCounted

const MODELS_SCRIPT_PATH: String = "res://addons/script_dependency_inspector/core/models.gd"
const COMPAT_SCRIPT_PATH: String = "res://addons/script_dependency_inspector/core/compat.gd"

var logger: RefCounted
var _models_script: Script
var _compat_script: Script
var _dependency_errors: Array[String] = []


func _init() -> void:
	_models_script = _load_required_script(MODELS_SCRIPT_PATH, "graph model")
	_compat_script = _load_required_script(COMPAT_SCRIPT_PATH, "compatibility shim")


## Converts a scanner result into a deterministic graph snapshot.
## Edges point from dependent/derived nodes to dependency/base nodes.
func build(scan_result: Dictionary, options: Dictionary = {}) -> Dictionary:
	var resolved_options = _with_defaults(options)
	var snapshot = _new_snapshot()
	snapshot["warnings"].append_array(scan_result.get("warnings", []))
	snapshot["errors"].append_array(scan_result.get("errors", []))
	snapshot["errors"].append_array(_dependency_errors)
	snapshot["diagnostics"].append_array(scan_result.get("diagnostics", []))
	snapshot["metadata"] = {
		"engine_version": scan_result.get("engine_version", _engine_version_string()),
		"root_path": scan_result.get("root_path", "res://"),
		"style": resolved_options["style"].duplicate(true),
		"options": _serializable_options(resolved_options),
	}
	if not _dependency_errors.is_empty():
		_log_info(
			"Dependency graph build stopped because required plugin scripts are unavailable.",
			{"errors": _dependency_errors}
		)
		return snapshot

	var node_index = {}
	var class_index = {}
	for record_value in scan_result.get("scripts", []):
		var record: Dictionary = record_value
		_add_node(snapshot, node_index, _script_node(record, resolved_options))
		var registered_name = str(record.get("class_name", ""))
		if not registered_name.is_empty() and not class_index.has(registered_name):
			class_index[registered_name] = str(record["id"])

	_attach_scene_usages(snapshot, node_index, scan_result.get("scene_usages", []))
	var global_classes = _global_class_index()
	for record_value in scan_result.get("scripts", []):
		var record: Dictionary = record_value
		_add_base_relationship(snapshot, node_index, record, resolved_options)
		if resolved_options["include_resource_dependencies"]:
			_add_resource_dependencies(snapshot, node_index, record)
		if resolved_options["include_type_dependencies"]:
			_add_type_dependencies(
				snapshot, node_index, record, class_index, global_classes, resolved_options
			)
		if resolved_options["include_member_access_dependencies"]:
			_add_member_access_dependencies(
				snapshot, node_index, record, class_index, global_classes, resolved_options
			)

	_assign_inheritance_families(snapshot)
	_sort_snapshot(snapshot)
	_detect_inheritance_cycles(snapshot)
	_log_info(
		"Dependency graph built.",
		{
			"nodes": snapshot["nodes"].size(),
			"edges": snapshot["edges"].size(),
			"errors": snapshot["errors"].size()
		}
	)
	return snapshot


func _with_defaults(options: Dictionary) -> Dictionary:
	var defaults = {
		"include_native_bases": true,
		"include_external_bases": true,
		"include_methods": true,
		"include_signals": true,
		"include_properties": true,
		"include_resource_dependencies": false,
		"include_type_dependencies": true,
		"include_member_access_dependencies": false,
		"show_member_dependency_edges": false,
		"show_method_signatures": false,
		"show_signal_signatures": false,
		"show_property_types": false,
		"style": {},
	}
	for key in options:
		defaults[key] = options[key]
	return defaults


func _serializable_options(options: Dictionary) -> Dictionary:
	return {
		"include_native_bases": options["include_native_bases"],
		"include_external_bases": options["include_external_bases"],
		"include_methods": options["include_methods"],
		"include_signals": options["include_signals"],
		"include_properties": options["include_properties"],
		"include_resource_dependencies": options["include_resource_dependencies"],
		"include_type_dependencies": options["include_type_dependencies"],
		"include_member_access_dependencies": options["include_member_access_dependencies"],
		"show_member_dependency_edges": options["show_member_dependency_edges"],
		"show_method_signatures": options["show_method_signatures"],
		"show_signal_signatures": options["show_signal_signatures"],
		"show_property_types": options["show_property_types"],
	}


func _script_node(record: Dictionary, options: Dictionary) -> Dictionary:
	var analysis: Dictionary = record["analysis"]
	var class_name_value = str(record.get("class_name", ""))
	var reflection: Dictionary = record.get("reflection", {})
	var native_base = str(reflection.get("native_base", ""))
	var direct_base: Dictionary = record.get("direct_base", {})
	if native_base.is_empty() and str(direct_base.get("kind", "")) == "native":
		native_base = str(direct_base.get("value", ""))
	return {
		"id": str(record["id"]),
		"name": str(record["name"]),
		"qualified_name": str(record["name"]),
		"class_name": class_name_value,
		"has_custom_name": not class_name_value.is_empty(),
		"path": str(record["path"]),
		"source_location": analysis.get("class_name_location", {"line": 1, "column": 1}).duplicate(true),
		"kind": "addon" if record["is_addon"] else "user",
		"autoload": record.get("autoload", {}).duplicate(true),
		"scene_usages": [],
		"base": direct_base.duplicate(true),
		"native_base": native_base,
		"inheritance_family": "other",
		"methods": analysis["methods"].duplicate(true) if options["include_methods"] else [],
		"signals": analysis["signals"].duplicate(true) if options["include_signals"] else [],
		"properties":
		analysis["properties"].duplicate(true) if options["include_properties"] else [],
		"inner_classes": analysis["inner_classes"].duplicate(true),
	}


func _attach_scene_usages(
	snapshot: Dictionary, node_index: Dictionary, usage_values
) -> void:
	if not usage_values is Array:
		return
	for usage_value in usage_values:
		if not usage_value is Dictionary:
			continue
		var usage: Dictionary = usage_value.duplicate(true)
		var script_path = str(usage.get("script_path", ""))
		if script_path.is_empty():
			continue
		snapshot["scene_usages"].append(usage)
		if node_index.has(script_path):
			var node: Dictionary = node_index[script_path]
			var node_usages: Array = node.get("scene_usages", [])
			node_usages.append(usage)
			node["scene_usages"] = node_usages
	snapshot["scene_usages"].sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return "%s|%s|%s|%09d" % [
				left.get("script_path", ""),
				left.get("scene_path", ""),
				left.get("node_path", ""),
				int(left.get("line", 0)),
			] < "%s|%s|%s|%09d" % [
				right.get("script_path", ""),
				right.get("scene_path", ""),
				right.get("node_path", ""),
				int(right.get("line", 0)),
			]
	)


func _add_base_relationship(
	snapshot: Dictionary, node_index: Dictionary, record: Dictionary, options: Dictionary
) -> void:
	var base: Dictionary = record["direct_base"]
	var kind = str(base.get("kind", "none"))
	var target_id = ""

	match kind:
		"script":
			target_id = str(base["value"])
			if not node_index.has(target_id) and options["include_external_bases"]:
				_add_node(
					snapshot,
					node_index,
					_external_node(
						target_id,
						str(base.get("display", "External script")),
						"external",
						target_id
					)
				)
		"native":
			if options["include_native_bases"]:
				target_id = _ensure_native_chain(snapshot, node_index, str(base["value"]))
		"external_script", "unresolved":
			if options["include_external_bases"]:
				target_id = _external_id(base)
				_add_node(
					snapshot,
					node_index,
					_external_node(
						target_id,
						str(base.get("display", base.get("value", "External"))),
						"external",
						str(base.get("value", ""))
					)
				)
				var fallback_native = str(base.get("native_base", ""))
				if (
					options["include_native_bases"]
					and not fallback_native.is_empty()
					and ClassDB.class_exists(fallback_native)
				):
					var native_target = _ensure_native_chain(snapshot, node_index, fallback_native)
					_add_edge(snapshot, target_id, native_target, "extends")

	if not target_id.is_empty() and node_index.has(str(record["id"])) and node_index.has(target_id):
		_add_edge(snapshot, str(record["id"]), target_id, "extends")


func _ensure_native_chain(
	snapshot: Dictionary, node_index: Dictionary, native_class_name: String
) -> String:
	if native_class_name.is_empty():
		return ""
	var current = native_class_name
	var first_id = "native://" + current
	var visited = {}
	while not current.is_empty() and not visited.has(current):
		visited[current] = true
		var current_id = "native://" + current
		_add_node(snapshot, node_index, _external_node(current_id, current, "native"))
		if not ClassDB.class_exists(current):
			break
		var parent = str(ClassDB.get_parent_class(current))
		if parent.is_empty():
			break
		var parent_id = "native://" + parent
		_add_node(snapshot, node_index, _external_node(parent_id, parent, "native"))
		_add_edge(snapshot, current_id, parent_id, "extends")
		current = parent
	return first_id


func _add_resource_dependencies(
	snapshot: Dictionary, node_index: Dictionary, record: Dictionary
) -> void:
	var analysis: Dictionary = record["analysis"]
	var handled_paths: Dictionary = {}
	for detail_value in analysis.get("resource_dependency_details", []):
		var detail: Dictionary = detail_value
		var dependency_path = _normalize_dependency_path(
			str(detail.get("path", "")), str(record["path"])
		)
		if dependency_path.is_empty():
			continue
		handled_paths[dependency_path] = true
		var target_id = _ensure_resource_target(snapshot, node_index, dependency_path)
		_add_edge(
			snapshot,
			str(record["id"]),
			target_id,
			"uses",
			_member_link(
				detail.get("source_member", {}),
				{},
				str(detail.get("evidence", "load")),
				detail.get("source_location", {})
			)
		)
	for dependency_value in analysis.get("resource_dependencies", []):
		var dependency_path = _normalize_dependency_path(str(dependency_value), str(record["path"]))
		if handled_paths.has(dependency_path):
			continue
		_add_edge(
			snapshot,
			str(record["id"]),
			_ensure_resource_target(snapshot, node_index, dependency_path),
			"uses"
		)


func _ensure_resource_target(
	snapshot: Dictionary, node_index: Dictionary, dependency_path: String
) -> String:
	if node_index.has(dependency_path):
		return dependency_path
	var target_id = "resource://" + dependency_path
	_add_node(
		snapshot,
		node_index,
		_external_node(
			target_id, dependency_path.get_file().get_basename(), "external", dependency_path
		)
	)
	return target_id


func _add_type_dependencies(
	snapshot: Dictionary,
	node_index: Dictionary,
	record: Dictionary,
	class_index: Dictionary,
	global_classes: Dictionary,
	options: Dictionary
) -> void:
	var analysis: Dictionary = record["analysis"]
	var handled_symbols: Dictionary = {}
	for detail_value in analysis.get("type_reference_details", []):
		var detail: Dictionary = detail_value
		var symbol = str(detail.get("symbol", ""))
		var target_id = _resolve_type_target(
			snapshot, node_index, symbol, class_index, global_classes, options
		)
		if not target_id.is_empty() and target_id != str(record["id"]):
			handled_symbols[symbol] = true
			_add_edge(
				snapshot,
				str(record["id"]),
				target_id,
				"type_uses",
				_member_link(
					detail.get("source_member", {}),
					{},
					str(detail.get("evidence", "type")),
					detail.get("source_location", {})
				)
			)
	for symbol_value in analysis.get("type_references", []):
		var symbol = str(symbol_value)
		if handled_symbols.has(symbol):
			continue
		var target_id = _resolve_type_target(
			snapshot, node_index, symbol, class_index, global_classes, options
		)
		if not target_id.is_empty() and target_id != str(record["id"]):
			_add_edge(snapshot, str(record["id"]), target_id, "type_uses")


func _add_member_access_dependencies(
	snapshot: Dictionary,
	node_index: Dictionary,
	record: Dictionary,
	class_index: Dictionary,
	global_classes: Dictionary,
	options: Dictionary
) -> void:
	var analysis: Dictionary = record["analysis"]
	for access_value in analysis.get("member_accesses", []):
		var access: Dictionary = access_value
		var target_id = _resolve_type_target(
			snapshot,
			node_index,
			str(access.get("target_symbol", "")),
			class_index,
			global_classes,
			options
		)
		if target_id.is_empty() or target_id == str(record["id"]):
			continue
		var target_member = _existing_member_reference(
			node_index, target_id, access.get("target_member", {})
		)
		_add_edge(
			snapshot,
			str(record["id"]),
			target_id,
			"uses",
			_member_link(
				access.get("source_member", {}),
				target_member,
				str(access.get("evidence", "class_member_access")),
				access.get("source_location", {})
			)
		)


func _existing_member_reference(
	node_index: Dictionary, node_id: String, requested_value
) -> Dictionary:
	if not requested_value is Dictionary or not node_index.has(node_id):
		return {}
	var requested: Dictionary = requested_value
	var kind = str(requested.get("kind", ""))
	var name = str(requested.get("name", ""))
	var collection_name = "methods" if kind == "method" else "properties"
	if kind == "signal":
		collection_name = "signals"
	var node: Dictionary = node_index[node_id]
	for member_value in node.get(collection_name, []):
		var member: Dictionary = member_value
		if str(member.get("name", "")) == name:
			return {
				"kind": kind,
				"name": name,
				"source_location": member.get("source_location", {}).duplicate(true),
			}
	return {}


func _member_link(
	source_member_value,
	target_member_value,
	evidence: String,
	source_location_value = {}
) -> Dictionary:
	var source_member: Dictionary = (
		source_member_value.duplicate(true) if source_member_value is Dictionary else {}
	)
	var target_member: Dictionary = (
		target_member_value.duplicate(true) if target_member_value is Dictionary else {}
	)
	var source_location: Dictionary = (
		source_location_value.duplicate(true)
		if source_location_value is Dictionary
		else {}
	)
	if source_member.is_empty() and target_member.is_empty() and source_location.is_empty():
		return {}
	return {
		"source_member": source_member,
		"target_member": target_member,
		"source_location": source_location,
		"evidence": evidence,
	}


func _resolve_type_target(
	snapshot: Dictionary,
	node_index: Dictionary,
	symbol: String,
	class_index: Dictionary,
	global_classes: Dictionary,
	options: Dictionary
) -> String:
	if class_index.has(symbol):
		return str(class_index[symbol])
	if global_classes.has(symbol):
		var entry: Dictionary = global_classes[symbol]
		var path = str(entry.get("path", ""))
		if node_index.has(path):
			return path
		if not options["include_external_bases"]:
			return ""
		var external_id = path if not path.is_empty() else "external://type/" + symbol
		_add_node(snapshot, node_index, _external_node(external_id, symbol, "external", path))
		return external_id
	if ClassDB.class_exists(symbol):
		if options["include_native_bases"]:
			return _ensure_native_chain(snapshot, node_index, symbol)
		return ""
	if options["include_external_bases"] and _looks_like_class_symbol(symbol):
		var external_id = "external://type/" + symbol
		_add_node(snapshot, node_index, _external_node(external_id, symbol, "external"))
		return external_id
	return ""


func _looks_like_class_symbol(symbol: String) -> bool:
	if symbol.is_empty():
		return false
	var first = symbol.substr(0, 1)
	return first == first.to_upper() and first != first.to_lower()


func _global_class_index() -> Dictionary:
	var index = {}
	if not ProjectSettings.has_method("get_global_class_list"):
		return index
	for entry_value in ProjectSettings.get_global_class_list():
		var entry: Dictionary = entry_value
		var registered_name = str(entry.get("class", ""))
		if not registered_name.is_empty():
			index[registered_name] = entry.duplicate(true)
	return index


func _normalize_dependency_path(path: String, owner_path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return path.simplify_path()
	return owner_path.get_base_dir().path_join(path).simplify_path()


func _external_id(base: Dictionary) -> String:
	var value = str(base.get("value", ""))
	if value.begins_with("res://") or value.begins_with("user://"):
		return value
	return "external://" + value


func _external_node(
	node_id: String, display_name: String, kind: String, path: String = ""
) -> Dictionary:
	var resolved_name = display_name if not display_name.is_empty() else node_id
	return {
		"id": node_id,
		"name": resolved_name,
		"qualified_name": resolved_name,
		"class_name": "",
		"has_custom_name": false,
		"path": path,
		"kind": kind,
		"base": {},
		"native_base": resolved_name if kind == "native" else "",
		"inheritance_family": _classify_native_family(resolved_name) if kind == "native" else "other",
		"methods": [],
		"signals": [],
		"properties": [],
		"inner_classes": [],
	}


func _assign_inheritance_families(snapshot: Dictionary) -> void:
	var node_by_id: Dictionary = {}
	var parent_by_child: Dictionary = {}
	for node_value in snapshot.get("nodes", []):
		var node: Dictionary = node_value
		node_by_id[str(node.get("id", ""))] = node
	for edge_value in snapshot.get("edges", []):
		var edge: Dictionary = edge_value
		if str(edge.get("kind", "")) == "extends":
			parent_by_child[str(edge.get("source", ""))] = str(edge.get("target", ""))

	for node_value in snapshot.get("nodes", []):
		var node: Dictionary = node_value
		var native_class = _terminal_native_class(
			str(node.get("id", "")), parent_by_child, node_by_id, {}
		)
		if native_class.is_empty():
			native_class = str(node.get("native_base", ""))
		node["inheritance_family"] = _classify_native_family(native_class)


func _terminal_native_class(
	node_id: String, parent_by_child: Dictionary, node_by_id: Dictionary, visiting: Dictionary
) -> String:
	if node_id.is_empty() or visiting.has(node_id) or not node_by_id.has(node_id):
		return ""
	visiting[node_id] = true
	var node: Dictionary = node_by_id[node_id]
	if str(node.get("kind", "")) == "native":
		return str(node.get("name", ""))
	if parent_by_child.has(node_id):
		var inherited = _terminal_native_class(
			str(parent_by_child[node_id]), parent_by_child, node_by_id, visiting
		)
		if not inherited.is_empty():
			return inherited
	return str(node.get("native_base", ""))


func _classify_native_family(native_class_name: String) -> String:
	if native_class_name.is_empty() or not ClassDB.class_exists(native_class_name):
		return "other"
	if native_class_name == "Control" or ClassDB.is_parent_class(native_class_name, "Control"):
		return "control"
	if native_class_name == "Node2D" or ClassDB.is_parent_class(native_class_name, "Node2D"):
		return "node_2d"
	if native_class_name == "Node3D" or ClassDB.is_parent_class(native_class_name, "Node3D"):
		return "node_3d"
	if native_class_name == "Node" or ClassDB.is_parent_class(native_class_name, "Node"):
		return "node"
	if (
		native_class_name == "RefCounted"
		or ClassDB.is_parent_class(native_class_name, "RefCounted")
	):
		return "ref_counted"
	if native_class_name == "Object" or ClassDB.is_parent_class(native_class_name, "Object"):
		return "object"
	return "other"


func _add_node(snapshot: Dictionary, node_index: Dictionary, node: Dictionary) -> void:
	var node_id = str(node["id"])
	if node_id.is_empty() or node_index.has(node_id):
		return
	node_index[node_id] = node
	snapshot["nodes"].append(node)


func _add_edge(
	snapshot: Dictionary,
	source: String,
	target: String,
	kind: String,
	member_link: Dictionary = {}
) -> void:
	if source.is_empty() or target.is_empty() or source == target:
		return
	for existing_value in snapshot["edges"]:
		var existing: Dictionary = existing_value
		if (
			existing["source"] == source
			and existing["target"] == target
			and existing["kind"] == kind
		):
			_append_member_link(existing, member_link)
			return
	var edge = {"source": source, "target": target, "kind": kind, "member_links": []}
	_append_member_link(edge, member_link)
	snapshot["edges"].append(edge)


func _append_member_link(edge: Dictionary, member_link: Dictionary) -> void:
	if member_link.is_empty():
		return
	var links: Array = edge.get("member_links", [])
	var candidate_key = _member_link_sort_key(member_link)
	for existing_value in links:
		var existing: Dictionary = existing_value
		if _member_link_sort_key(existing) == candidate_key:
			return
	links.append(member_link.duplicate(true))
	edge["member_links"] = links


func _member_link_sort_key(link: Dictionary) -> String:
	var source_member: Dictionary = link.get("source_member", {})
	var target_member: Dictionary = link.get("target_member", {})
	var source_location: Dictionary = link.get("source_location", {})
	return "%s|%s|%s|%s|%s|%09d|%09d" % [
		str(source_member.get("kind", "")),
		str(source_member.get("name", "")),
		str(target_member.get("kind", "")),
		str(target_member.get("name", "")),
		str(link.get("evidence", "")),
		int(source_location.get("line", 0)),
		int(source_location.get("column", 0)),
	]


func _sort_snapshot(snapshot: Dictionary) -> void:
	for edge_value in snapshot.get("edges", []):
		var edge: Dictionary = edge_value
		var member_links: Array = edge.get("member_links", [])
		member_links.sort_custom(
			func(left: Dictionary, right: Dictionary) -> bool:
				return _member_link_sort_key(left) < _member_link_sort_key(right)
		)
		edge["member_links"] = member_links
	snapshot["nodes"].sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool: return str(left["id"]) < str(right["id"])
	)
	snapshot["edges"].sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			var left_key = "%s|%s|%s" % [left["kind"], left["source"], left["target"]]
			var right_key = "%s|%s|%s" % [right["kind"], right["source"], right["target"]]
			return left_key < right_key
	)


func _detect_inheritance_cycles(snapshot: Dictionary) -> void:
	var parent_by_child = {}
	for edge_value in snapshot["edges"]:
		var edge: Dictionary = edge_value
		if edge["kind"] == "extends":
			parent_by_child[str(edge["source"])] = str(edge["target"])

	for start_value in parent_by_child.keys():
		var chain = {}
		var current = str(start_value)
		while parent_by_child.has(current):
			if chain.has(current):
				var warning = "Inheritance cycle detected at %s." % current
				if not snapshot["warnings"].has(warning):
					snapshot["warnings"].append(warning)
					snapshot["diagnostics"].append(
						{
							"severity": "warning",
							"code": "inheritance_cycle",
							"message": warning,
							"context": {"node_id": current},
						}
					)
				break
			chain[current] = true
			current = str(parent_by_child[current])


func _new_snapshot() -> Dictionary:
	if _models_script != null:
		var value = _models_script.call("new_snapshot")
		if value is Dictionary:
			return value
	return {
		"schema_version": 2,
		"metadata": {},
		"nodes": [],
		"edges": [],
		"scene_usages": [],
		"warnings": [],
		"errors": [],
		"diagnostics": [],
	}


func _load_required_script(path: String, role: String) -> Script:
	if not FileAccess.file_exists(path):
		_record_dependency_error("Missing %s script: %s" % [role, path])
		return null
	var resource = ResourceLoader.load(path)
	if resource == null or not resource is Script:
		_record_dependency_error("Could not load %s script: %s" % [role, path])
		return null
	return resource as Script


func _record_dependency_error(message: String) -> void:
	if not _dependency_errors.has(message):
		_dependency_errors.append(message)
	push_error(message)


func _engine_version_string() -> String:
	if _compat_script != null:
		return str(_compat_script.call("engine_version_string"))
	var info = Engine.get_version_info()
	if info.has("string"):
		return str(info["string"])
	return "%s.%s.%s" % [info.get("major", 4), info.get("minor", 0), info.get("patch", 0)]


func _log_info(message: String, context: Dictionary = {}) -> void:
	if logger != null and logger.has_method("info"):
		logger.call("info", message, context)
