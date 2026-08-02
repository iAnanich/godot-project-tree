@tool
extends RefCounted

## Projects a full validated snapshot onto a selected project folder while
## retaining only the external context required to explain in-scope scripts.
## Relationship semantics and canonical edge direction are unchanged.


func project(snapshot: Dictionary, scope_root: String) -> Dictionary:
	var normalized_root: String = scope_root.simplify_path()
	var projected: Dictionary = snapshot.duplicate(true)
	for collection_name in ["nodes", "edges", "scene_usages", "warnings", "errors", "diagnostics"]:
		if not projected.get(collection_name) is Array:
			projected[collection_name] = []
	var metadata: Dictionary = projected.get("metadata", {}) if projected.get("metadata") is Dictionary else {}
	var index_root: String = str(metadata.get("root_path", "res://"))
	metadata["index_root_path"] = index_root
	metadata["root_path"] = normalized_root
	metadata["scope_active"] = normalized_root != "res://"
	projected["metadata"] = metadata

	if normalized_root == "res://":
		for node_value in projected.get("nodes", []):
			if node_value is Dictionary:
				var node: Dictionary = node_value
				node["scope_role"] = "in_scope"
				node["scope_reason"] = "selected_root"
		metadata["scope_summary"] = {
			"in_scope_nodes": projected.get("nodes", []).size(),
			"context_nodes": 0,
		}
		return projected

	var nodes_by_id: Dictionary = {}
	var in_scope: Dictionary = {}
	for node_value in projected.get("nodes", []):
		if not node_value is Dictionary:
			continue
		var node: Dictionary = node_value
		var node_id: String = str(node.get("id", ""))
		nodes_by_id[node_id] = node
		if _is_project_script(node) and _path_is_within(str(node.get("path", "")), normalized_root):
			in_scope[node_id] = true

	var kept: Dictionary = in_scope.duplicate()
	var reasons: Dictionary = {}
	for node_id_value in in_scope:
		reasons[str(node_id_value)] = "selected_root"

	var parent_by_child: Dictionary = {}
	var outgoing_dependencies: Dictionary = {}
	for edge_value in projected.get("edges", []):
		if not edge_value is Dictionary:
			continue
		var edge: Dictionary = edge_value
		var source: String = str(edge.get("source", ""))
		var target: String = str(edge.get("target", ""))
		var kind: String = str(edge.get("kind", ""))
		if kind == "extends":
			parent_by_child[source] = target
		elif kind in ["uses", "type_uses"]:
			var targets: Array = outgoing_dependencies.get(source, [])
			if not targets.has(target):
				targets.append(target)
			outgoing_dependencies[source] = targets

	# Every in-scope script retains its complete visible inheritance chain.
	for node_id_value in in_scope:
		_add_ancestor_chain(str(node_id_value), parent_by_child, kept, reasons, "required_ancestor")

	# Direct dependency targets are retained as context. Their ancestry is also
	# retained so the target class is not presented without its base context.
	for node_id_value in in_scope:
		for target_value in outgoing_dependencies.get(str(node_id_value), []):
			var target: String = str(target_value)
			if not target.is_empty():
				kept[target] = true
				if not reasons.has(target):
					reasons[target] = "required_dependency"
				_add_ancestor_chain(target, parent_by_child, kept, reasons, "dependency_ancestor")

	var filtered_nodes: Array = []
	for node_value in projected.get("nodes", []):
		if not node_value is Dictionary:
			continue
		var node: Dictionary = node_value
		var node_id: String = str(node.get("id", ""))
		if not kept.has(node_id):
			continue
		node["scope_role"] = "in_scope" if in_scope.has(node_id) else "context"
		node["scope_reason"] = str(reasons.get(node_id, "required_context"))
		filtered_nodes.append(node)

	var filtered_edges: Array = []
	for edge_value in projected.get("edges", []):
		if not edge_value is Dictionary:
			continue
		var edge: Dictionary = edge_value
		if kept.has(str(edge.get("source", ""))) and kept.has(str(edge.get("target", ""))):
			filtered_edges.append(edge)

	var filtered_scene_usages: Array = []
	for usage_value in projected.get("scene_usages", []):
		if usage_value is Dictionary and kept.has(str((usage_value as Dictionary).get("script_path", ""))):
			filtered_scene_usages.append(usage_value)

	projected["nodes"] = filtered_nodes
	projected["edges"] = filtered_edges
	projected["scene_usages"] = filtered_scene_usages
	metadata["scope_summary"] = {
		"in_scope_nodes": in_scope.size(),
		"context_nodes": maxi(0, filtered_nodes.size() - in_scope.size()),
	}
	if in_scope.is_empty():
		var warning: String = "No scanned scripts were found in selected scope: %s" % normalized_root
		if not projected.get("warnings", []).has(warning):
			projected["warnings"].append(warning)
		projected["diagnostics"].append(
			{
				"severity": "warning",
				"code": "empty_selected_scope",
				"message": warning,
				"context": {"scope_root": normalized_root},
			}
		)
	return projected


func _is_project_script(node: Dictionary) -> bool:
	return str(node.get("kind", "")) in ["user", "addon"] and str(node.get("path", "")).begins_with("res://")


func _path_is_within(path: String, root: String) -> bool:
	var normalized_path: String = path.simplify_path().trim_suffix("/")
	var normalized_root: String = root.simplify_path().trim_suffix("/")
	return normalized_path == normalized_root or normalized_path.begins_with(normalized_root + "/")


func _add_ancestor_chain(
	start_id: String,
	parent_by_child: Dictionary,
	kept: Dictionary,
	reasons: Dictionary,
	reason: String
) -> void:
	var current: String = start_id
	var visited: Dictionary = {}
	while parent_by_child.has(current) and not visited.has(current):
		visited[current] = true
		var parent: String = str(parent_by_child[current])
		if parent.is_empty():
			break
		kept[parent] = true
		if not reasons.has(parent):
			reasons[parent] = reason
		current = parent
