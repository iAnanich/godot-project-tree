@tool
extends RefCounted

const SUPPORTED_SCHEMA_VERSION: int = 2
const REQUIRED_NODE_FIELDS: Array[String] = [
	"id", "name", "kind", "properties", "signals", "methods", "inner_classes"
]
const REQUIRED_EDGE_FIELDS: Array[String] = ["source", "target", "kind", "member_links"]
const REQUIRED_MEMBER_LINK_FIELDS: Array[String] = ["source_member", "target_member", "evidence"]


## Validates a canonical dependency snapshot at a public serialization boundary.
##
## The validator is intentionally strict about fields that define graph meaning
## and permissive about additive extension fields. It never mutates the input.
## Results are deterministic dictionaries containing stable issue codes,
## reader-facing messages, and machine-readable context.
func validate(snapshot: Dictionary) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	_validate_root(snapshot, errors, warnings)
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "warnings": warnings}

	var node_index: Dictionary = {}
	_validate_nodes(snapshot.get("nodes", []), node_index, errors, warnings)
	_validate_scope_consistency(snapshot.get("metadata", {}), node_index, errors)
	_validate_edges(snapshot.get("edges", []), node_index, errors, warnings)
	_validate_scene_usages(snapshot.get("scene_usages", []), node_index, errors)
	_validate_node_scene_usage_consistency(snapshot.get("scene_usages", []), node_index, errors)
	_validate_diagnostics(snapshot.get("diagnostics", []), errors)
	return {"ok": errors.is_empty(), "errors": errors, "warnings": warnings}


func _validate_root(snapshot: Dictionary, errors: Array, warnings: Array) -> void:
	if not snapshot.has("schema_version"):
		_add_issue(errors, "missing_schema_version", "Snapshot is missing schema_version.")
	elif not snapshot["schema_version"] is int:
		_add_issue(
			errors,
			"invalid_schema_version_type",
			"Snapshot schema_version must be an integer.",
			{"actual_type": typeof(snapshot["schema_version"])}
		)
	elif snapshot["schema_version"] != SUPPORTED_SCHEMA_VERSION:
		_add_issue(
			errors,
			"unsupported_schema_version",
			"Unsupported snapshot schema version: %s." % snapshot["schema_version"],
			{"supported": SUPPORTED_SCHEMA_VERSION}
		)
	for key in ["metadata", "nodes", "edges", "scene_usages", "warnings", "errors"]:
		if not snapshot.has(key):
			_add_issue(
				errors,
				"missing_snapshot_field",
				"Snapshot is missing required field '%s'." % key,
				{"field": key}
			)
	if snapshot.has("metadata") and not snapshot["metadata"] is Dictionary:
		_add_issue(errors, "invalid_metadata", "Snapshot metadata must be a dictionary.")
	elif snapshot.has("metadata"):
		_validate_metadata(snapshot["metadata"], errors, warnings)
	for key in ["nodes", "edges", "scene_usages", "warnings", "errors"]:
		if snapshot.has(key) and not snapshot[key] is Array:
			_add_issue(
				errors,
				"invalid_snapshot_collection",
				"Snapshot field '%s' must be an array." % key,
				{"field": key}
			)
	for key in ["warnings", "errors"]:
		if snapshot.get(key, null) is Array:
			_validate_text_collection(snapshot[key], key, errors)
	if snapshot.has("diagnostics") and not snapshot["diagnostics"] is Array:
		_add_issue(
			errors,
			"invalid_snapshot_collection",
			"Snapshot field 'diagnostics' must be an array.",
			{"field": "diagnostics"}
		)


func _validate_text_collection(values: Array, field_name: String, errors: Array) -> void:
	for index in range(values.size()):
		if not values[index] is String:
			_add_issue(
				errors,
				"invalid_snapshot_message",
				"Snapshot field '%s' item %s must be text." % [field_name, index],
				{"field": field_name, "index": index}
			)


func _validate_metadata(metadata: Dictionary, errors: Array, warnings: Array) -> void:
	for field_name in ["root_path", "index_root_path", "engine_version"]:
		if metadata.has(field_name) and not metadata[field_name] is String:
			_add_issue(
				errors,
				"invalid_metadata_field",
				"Snapshot metadata field '%s' must be text." % field_name,
				{"field": field_name}
			)
	if (
		not metadata.has("root_path")
		or (metadata["root_path"] is String and (metadata["root_path"] as String).is_empty())
	):
		_add_issue(
			warnings,
			"missing_root_path_metadata",
			"Snapshot metadata does not identify the scanned root.",
			{},
			"warning"
		)
	if metadata.has("scope_active") and not metadata["scope_active"] is bool:
		_add_issue(
			errors,
			"invalid_metadata_field",
			"Snapshot metadata field 'scope_active' must be boolean.",
			{"field": "scope_active"}
		)
	if metadata.has("scope_summary"):
		if not metadata["scope_summary"] is Dictionary:
			_add_issue(
				errors,
				"invalid_metadata_field",
				"Snapshot metadata field 'scope_summary' must be a dictionary.",
				{"field": "scope_summary"}
			)
		else:
			var scope_summary: Dictionary = metadata["scope_summary"]
			for count_field in ["in_scope_nodes", "context_nodes"]:
				if scope_summary.has(count_field) and not scope_summary[count_field] is int:
					_add_issue(
						errors,
						"invalid_scope_summary",
						"Scope summary field '%s' must be an integer." % count_field,
						{"field": count_field}
					)
	for field_name in ["options", "style"]:
		if metadata.has(field_name) and not metadata[field_name] is Dictionary:
			_add_issue(
				errors,
				"invalid_metadata_field",
				"Snapshot metadata field '%s' must be a dictionary." % field_name,
				{"field": field_name}
			)


func _validate_scope_consistency(metadata_value, node_index: Dictionary, errors: Array) -> void:
	if not metadata_value is Dictionary:
		return
	var metadata: Dictionary = metadata_value
	if not metadata.has("scope_active") and not metadata.has("scope_summary"):
		return
	var scope_active: bool = bool(metadata.get("scope_active", false))
	var root_path: String = str(metadata.get("root_path", ""))
	if scope_active and not metadata.has("index_root_path"):
		_add_issue(
			errors,
			"missing_scope_index_root",
			"A scoped snapshot must identify the full index root.",
			{"root_path": root_path}
		)
	var in_scope_count: int = 0
	var context_count: int = 0
	for node_id_value in node_index:
		var node_id: String = str(node_id_value)
		var node: Dictionary = node_index[node_id]
		var role: String = str(node.get("scope_role", ""))
		if role == "in_scope":
			in_scope_count += 1
		elif role == "context":
			context_count += 1
		elif scope_active:
			_add_issue(
				errors,
				"missing_scope_role",
				"Node '%s' is missing a scope role in a scoped snapshot." % node_id,
				{"id": node_id}
			)
		if scope_active and role == "in_scope" and str(node.get("kind", "")) in ["user", "addon"]:
			var path: String = str(node.get("path", "")).simplify_path().trim_suffix("/")
			var normalized_root: String = root_path.simplify_path().trim_suffix("/")
			if path != normalized_root and not path.begins_with(normalized_root + "/"):
				_add_issue(
					errors,
					"in_scope_node_outside_root",
					"Node '%s' is marked in scope but is outside '%s'." % [node_id, root_path],
					{"id": node_id, "path": path, "root_path": root_path}
				)
	if metadata.get("scope_summary") is Dictionary:
		var summary: Dictionary = metadata["scope_summary"]
		if int(summary.get("in_scope_nodes", -1)) != in_scope_count:
			_add_issue(
				errors,
				"scope_summary_mismatch",
				"Scope summary in-scope count does not match node records.",
				{
					"declared": summary.get("in_scope_nodes", -1),
					"actual": in_scope_count,
				}
			)
		if int(summary.get("context_nodes", -1)) != context_count:
			_add_issue(
				errors,
				"scope_summary_mismatch",
				"Scope summary context count does not match node records.",
				{
					"declared": summary.get("context_nodes", -1),
					"actual": context_count,
				}
			)


func _validate_nodes(nodes_value, node_index: Dictionary, errors: Array, warnings: Array) -> void:
	if not nodes_value is Array:
		return
	var index: int = 0
	for node_value in nodes_value:
		if not node_value is Dictionary:
			_add_issue(
				errors,
				"invalid_node",
				"Node at index %s must be a dictionary." % index,
				{"index": index}
			)
			index += 1
			continue
		var node: Dictionary = node_value
		for required_field in REQUIRED_NODE_FIELDS:
			if not node.has(required_field):
				_add_issue(
					errors,
					"missing_node_field",
					"Node at index %s is missing required field '%s'." % [index, required_field],
					{"index": index, "field": required_field}
				)

		var node_id: String = ""
		if node.has("id") and not node["id"] is String:
			_add_issue(
				errors,
				"invalid_node_field",
				"Node at index %s field 'id' must be text." % index,
				{"index": index, "field": "id"}
			)
		elif node.has("id"):
			node_id = node["id"]
			if node_id.is_empty():
				_add_issue(
					errors,
					"missing_node_id",
					"Node at index %s has no stable id." % index,
					{"index": index}
				)
			elif node_index.has(node_id):
				_add_issue(
					errors, "duplicate_node_id", "Duplicate node id: %s." % node_id, {"id": node_id}
				)
			else:
				node_index[node_id] = node

		var kind: String = ""
		if node.has("kind") and not node["kind"] is String:
			_add_issue(
				errors,
				"invalid_node_field",
				"Node '%s' field 'kind' must be text." % node_id,
				{"id": node_id, "field": "kind"}
			)
		elif node.has("kind"):
			kind = node["kind"]
			if not _is_node_kind(kind):
				_add_issue(
					errors,
					"invalid_node_kind",
					"Node '%s' has unsupported kind '%s'." % [node_id, kind],
					{"id": node_id, "kind": kind}
				)

		if node.has("name") and not node["name"] is String:
			_add_issue(
				errors,
				"invalid_node_field",
				"Node '%s' field 'name' must be text." % node_id,
				{"id": node_id, "field": "name"}
			)
		elif node.has("name") and (node["name"] as String).is_empty():
			_add_issue(
				warnings,
				"empty_node_name",
				"Node '%s' has an empty display name." % node_id,
				{"id": node_id},
				"warning"
			)

		for text_field in [
			"path",
			"class_name",
			"qualified_name",
			"native_base",
			"inheritance_family",
			"scope_role",
			"scope_reason"
		]:
			if node.has(text_field) and not node[text_field] is String:
				_add_issue(
					errors,
					"invalid_node_field",
					"Node '%s' field '%s' must be text." % [node_id, text_field],
					{"id": node_id, "field": text_field}
				)
		if node.has("scope_role") and str(node["scope_role"]) not in ["in_scope", "context"]:
			_add_issue(
				errors,
				"invalid_scope_role",
				"Node '%s' has unsupported scope role '%s'." % [node_id, node["scope_role"]],
				{"id": node_id, "scope_role": node["scope_role"]}
			)
		if node.has("has_custom_name") and not node["has_custom_name"] is bool:
			_add_issue(
				errors,
				"invalid_node_field",
				"Node '%s' field 'has_custom_name' must be boolean." % node_id,
				{"id": node_id, "field": "has_custom_name"}
			)
		if node.has("base") and not node["base"] is Dictionary:
			_add_issue(
				errors,
				"invalid_node_field",
				"Node '%s' field 'base' must be a dictionary." % node_id,
				{"id": node_id, "field": "base"}
			)
		if node.has("source_location"):
			_validate_source_location(node["source_location"], "node '%s'" % node_id, errors)
		if node.has("autoload") and not node["autoload"] is Dictionary:
			_add_issue(
				errors,
				"invalid_node_field",
				"Node '%s' field 'autoload' must be a dictionary." % node_id,
				{"id": node_id, "field": "autoload"}
			)
		elif node.has("autoload"):
			var autoload: Dictionary = node["autoload"]
			if (
				autoload.has("name")
				and (not autoload["name"] is String or str(autoload["name"]).is_empty())
			):
				_add_issue(
					errors,
					"invalid_autoload",
					"Node '%s' autoload name must be non-empty text." % node_id
				)
			if autoload.has("singleton") and not autoload["singleton"] is bool:
				_add_issue(
					errors,
					"invalid_autoload",
					"Node '%s' autoload singleton must be boolean." % node_id
				)
		if node.has("scene_usages") and not node["scene_usages"] is Array:
			_add_issue(
				errors,
				"invalid_node_field",
				"Node '%s' field 'scene_usages' must be an array." % node_id,
				{"id": node_id, "field": "scene_usages"}
			)
		_validate_member_collection(node, node_id, "properties", "property", errors)
		_validate_member_collection(node, node_id, "signals", "signal", errors)
		_validate_member_collection(node, node_id, "methods", "method", errors)
		_validate_inner_classes(node, node_id, errors)
		index += 1


func _validate_member_collection(
	node: Dictionary, node_id: String, collection_name: String, member_kind: String, errors: Array
) -> void:
	if not node.has(collection_name):
		return
	var collection_value = node[collection_name]
	if not collection_value is Array:
		_add_issue(
			errors,
			"invalid_member_collection",
			"Node '%s' field '%s' must be an array." % [node_id, collection_name],
			{"id": node_id, "field": collection_name}
		)
		return
	var names: Dictionary = {}
	var member_index: int = 0
	for member_value in collection_value:
		if not member_value is Dictionary:
			_add_issue(
				errors,
				"invalid_member",
				(
					"Node '%s' %s at index %s must be a dictionary."
					% [node_id, member_kind, member_index]
				),
				{"id": node_id, "kind": member_kind, "index": member_index}
			)
			member_index += 1
			continue
		var member: Dictionary = member_value
		var member_name: String = ""
		if not member.has("name"):
			_add_issue(
				errors,
				"missing_member_name",
				"Node '%s' %s at index %s has no name." % [node_id, member_kind, member_index],
				{"id": node_id, "kind": member_kind, "index": member_index}
			)
		elif not member["name"] is String:
			_add_issue(
				errors,
				"invalid_member_field",
				(
					"Node '%s' %s at index %s field 'name' must be text."
					% [node_id, member_kind, member_index]
				),
				{"id": node_id, "kind": member_kind, "index": member_index, "field": "name"}
			)
		else:
			member_name = member["name"]
			if member_name.is_empty():
				_add_issue(
					errors,
					"missing_member_name",
					"Node '%s' %s at index %s has no name." % [node_id, member_kind, member_index],
					{"id": node_id, "kind": member_kind, "index": member_index}
				)
			elif names.has(member_name):
				_add_issue(
					errors,
					"duplicate_member",
					"Node '%s' contains duplicate %s '%s'." % [node_id, member_kind, member_name],
					{"id": node_id, "kind": member_kind, "name": member_name}
				)
			else:
				names[member_name] = true
		if member.has("source_location"):
			_validate_source_location(
				member["source_location"],
				"node '%s' %s '%s'" % [node_id, member_kind, member_name],
				errors
			)
		if member.has("annotations") and not member["annotations"] is Array:
			_add_issue(
				errors,
				"invalid_member_field",
				(
					"Node '%s' %s '%s' annotations must be an array."
					% [node_id, member_kind, member_name]
				),
				{"id": node_id, "kind": member_kind, "name": member_name, "field": "annotations"}
			)
		for text_field in ["arguments", "return_type", "signature", "declaration", "type"]:
			if member.has(text_field) and not member[text_field] is String:
				_add_issue(
					errors,
					"invalid_member_field",
					(
						"Node '%s' %s '%s' field '%s' must be text."
						% [node_id, member_kind, member_name, text_field]
					),
					{
						"id": node_id,
						"kind": member_kind,
						"name": member_name,
						"field": text_field,
					}
				)
		for boolean_field in ["static", "exported"]:
			if member.has(boolean_field) and not member[boolean_field] is bool:
				_add_issue(
					errors,
					"invalid_member_field",
					(
						"Node '%s' %s '%s' field '%s' must be boolean."
						% [node_id, member_kind, member_name, boolean_field]
					),
					{
						"id": node_id,
						"kind": member_kind,
						"name": member_name,
						"field": boolean_field,
					}
				)
		member_index += 1


func _validate_inner_classes(node: Dictionary, node_id: String, errors: Array) -> void:
	if not node.has("inner_classes"):
		return
	var inner_value = node["inner_classes"]
	if not inner_value is Array:
		_add_issue(
			errors,
			"invalid_member_collection",
			"Node '%s' field 'inner_classes' must be an array." % node_id,
			{"id": node_id, "field": "inner_classes"}
		)
		return
	for index in range((inner_value as Array).size()):
		var item_value = (inner_value as Array)[index]
		if not item_value is Dictionary:
			_add_issue(
				errors,
				"invalid_inner_class",
				"Node '%s' inner class at index %s must be a dictionary." % [node_id, index],
				{"id": node_id, "index": index}
			)
			continue
		var item: Dictionary = item_value
		if (
			not item.has("name")
			or not item["name"] is String
			or (item["name"] as String).is_empty()
		):
			_add_issue(
				errors,
				"invalid_inner_class",
				"Node '%s' inner class at index %s has an invalid name." % [node_id, index],
				{"id": node_id, "index": index}
			)
		if item.has("source_location"):
			_validate_source_location(
				item["source_location"],
				"node '%s' inner class '%s'" % [node_id, str(item.get("name", ""))],
				errors
			)


func _validate_edges(edges_value, node_index: Dictionary, errors: Array, warnings: Array) -> void:
	if not edges_value is Array:
		return
	var edge_keys: Dictionary = {}
	var index: int = 0
	for edge_value in edges_value:
		if not edge_value is Dictionary:
			_add_issue(
				errors,
				"invalid_edge",
				"Edge at index %s must be a dictionary." % index,
				{"index": index}
			)
			index += 1
			continue
		var edge: Dictionary = edge_value
		for required_field in REQUIRED_EDGE_FIELDS:
			if not edge.has(required_field):
				_add_issue(
					errors,
					"missing_edge_field",
					"Edge at index %s is missing required field '%s'." % [index, required_field],
					{"index": index, "field": required_field}
				)

		var source: String = _edge_text_field(edge, "source", index, errors)
		var target: String = _edge_text_field(edge, "target", index, errors)
		var kind: String = _edge_text_field(edge, "kind", index, errors)
		if source.is_empty() or target.is_empty():
			_add_issue(
				errors,
				"missing_edge_endpoint",
				"Edge at index %s is missing source or target." % index,
				{"index": index}
			)
		else:
			if not node_index.has(source):
				_add_issue(
					errors,
					"dangling_edge_source",
					"Edge source does not exist: %s." % source,
					{"index": index, "source": source}
				)
			if not node_index.has(target):
				_add_issue(
					errors,
					"dangling_edge_target",
					"Edge target does not exist: %s." % target,
					{"index": index, "target": target}
				)
		if not kind.is_empty() and not _is_edge_kind(kind):
			_add_issue(
				errors,
				"invalid_edge_kind",
				"Edge at index %s has unsupported kind '%s'." % [index, kind],
				{"index": index, "kind": kind}
			)
		var edge_key: String = "%s|%s|%s" % [kind, source, target]
		if edge_keys.has(edge_key):
			_add_issue(
				errors,
				"duplicate_edge",
				"Duplicate canonical edge: %s." % edge_key,
				{"index": index}
			)
		else:
			edge_keys[edge_key] = true
		if source == target and not source.is_empty():
			_add_issue(
				warnings,
				"self_edge",
				"Self-edge retained in snapshot: %s." % source,
				{"index": index, "id": source},
				"warning"
			)
		_validate_member_links(
			edge.get("member_links", null), index, source, target, node_index, errors
		)
		index += 1


func _edge_text_field(edge: Dictionary, field_name: String, index: int, errors: Array) -> String:
	if not edge.has(field_name):
		return ""
	if not edge[field_name] is String:
		_add_issue(
			errors,
			"invalid_edge_field",
			"Edge at index %s field '%s' must be text." % [index, field_name],
			{"index": index, "field": field_name}
		)
		return ""
	return edge[field_name]


func _validate_member_links(
	links_value,
	edge_index: int,
	source_id: String,
	target_id: String,
	node_index: Dictionary,
	errors: Array
) -> void:
	if not links_value is Array:
		_add_issue(
			errors,
			"invalid_member_links",
			"Edge %s member_links must be an array." % edge_index,
			{"index": edge_index}
		)
		return
	var link_keys: Dictionary = {}
	for link_index in range((links_value as Array).size()):
		var link_value = (links_value as Array)[link_index]
		if not link_value is Dictionary:
			_add_issue(
				errors,
				"invalid_member_link",
				"Edge %s member link %s must be a dictionary." % [edge_index, link_index],
				{"edge_index": edge_index, "link_index": link_index}
			)
			continue
		var link: Dictionary = link_value
		for required_field in REQUIRED_MEMBER_LINK_FIELDS:
			if not link.has(required_field):
				_add_issue(
					errors,
					"missing_member_link_field",
					(
						"Edge %s member link %s is missing required field '%s'."
						% [edge_index, link_index, required_field]
					),
					{
						"edge_index": edge_index,
						"link_index": link_index,
						"field": required_field,
					}
				)
		var evidence: String = ""
		if link.has("evidence") and not link["evidence"] is String:
			_add_issue(
				errors,
				"invalid_member_link_field",
				"Edge %s member link %s evidence must be text." % [edge_index, link_index],
				{"edge_index": edge_index, "link_index": link_index, "field": "evidence"}
			)
		elif link.has("evidence"):
			evidence = link["evidence"]
			if evidence.is_empty():
				_add_issue(
					errors,
					"missing_member_link_evidence",
					"Edge %s member link %s has no evidence code." % [edge_index, link_index],
					{"edge_index": edge_index, "link_index": link_index}
				)
		var source_member: Dictionary = _validate_member_reference(
			link.get("source_member", null), edge_index, link_index, "source_member", errors
		)
		var target_member: Dictionary = _validate_member_reference(
			link.get("target_member", null), edge_index, link_index, "target_member", errors
		)
		if link.has("source_location"):
			_validate_source_location(
				link["source_location"],
				"edge %s member link %s occurrence" % [edge_index, link_index],
				errors
			)
		if not source_member.is_empty() and node_index.has(source_id):
			_validate_member_exists(
				node_index[source_id], source_member, edge_index, link_index, "source", errors
			)
		if not target_member.is_empty() and node_index.has(target_id):
			_validate_member_exists(
				node_index[target_id], target_member, edge_index, link_index, "target", errors
			)
		var source_location: Dictionary = link.get("source_location", {})
		var link_key: String = (
			"%s|%s|%s|%s|%s|%s|%s"
			% [
				str(source_member.get("kind", "")),
				str(source_member.get("name", "")),
				str(target_member.get("kind", "")),
				str(target_member.get("name", "")),
				evidence,
				str(source_location.get("line", "")),
				str(source_location.get("column", "")),
			]
		)
		if link_keys.has(link_key):
			_add_issue(
				errors,
				"duplicate_member_link",
				"Edge %s contains a duplicate member link." % edge_index,
				{"edge_index": edge_index, "link_index": link_index}
			)
		else:
			link_keys[link_key] = true


func _validate_member_reference(
	member_value, edge_index: int, link_index: int, field_name: String, errors: Array
) -> Dictionary:
	if not member_value is Dictionary:
		_add_issue(
			errors,
			"invalid_member_reference",
			(
				"Edge %s member link %s field '%s' must be a dictionary."
				% [edge_index, link_index, field_name]
			),
			{"edge_index": edge_index, "link_index": link_index, "field": field_name}
		)
		return {}
	var member: Dictionary = member_value
	if member.is_empty():
		return {}
	if not member.has("kind") or not member.has("name"):
		_add_issue(
			errors,
			"invalid_member_reference",
			(
				"Edge %s member link %s field '%s' must contain kind and name together."
				% [edge_index, link_index, field_name]
			),
			{"edge_index": edge_index, "link_index": link_index, "field": field_name}
		)
		return {}
	if not member["kind"] is String or not member["name"] is String:
		_add_issue(
			errors,
			"invalid_member_reference",
			(
				"Edge %s member link %s field '%s' kind and name must be text."
				% [edge_index, link_index, field_name]
			),
			{"edge_index": edge_index, "link_index": link_index, "field": field_name}
		)
		return {}
	var kind: String = member["kind"]
	var name: String = member["name"]
	if not _is_member_kind(kind) or name.is_empty():
		_add_issue(
			errors,
			"invalid_member_reference",
			"Edge %s member link %s has an invalid %s." % [edge_index, link_index, field_name],
			{
				"edge_index": edge_index,
				"link_index": link_index,
				"field": field_name,
				"kind": kind,
				"name": name,
			}
		)
		return {}
	return {"kind": kind, "name": name}


func _validate_member_exists(
	node: Dictionary,
	member: Dictionary,
	edge_index: int,
	link_index: int,
	endpoint: String,
	errors: Array
) -> void:
	if _node_has_member(node, str(member["kind"]), str(member["name"])):
		return
	_add_issue(
		errors,
		"unknown_member_reference",
		(
			"Edge %s member link %s references an unknown %s member '%s'."
			% [edge_index, link_index, endpoint, member["name"]]
		),
		{
			"edge_index": edge_index,
			"link_index": link_index,
			"endpoint": endpoint,
			"node": str(node.get("id", "")),
			"kind": str(member["kind"]),
			"name": str(member["name"]),
		}
	)


func _node_has_member(node: Dictionary, kind: String, name: String) -> bool:
	var collection_name: String = "properties"
	if kind == "method":
		collection_name = "methods"
	elif kind == "signal":
		collection_name = "signals"
	for member_value in node.get(collection_name, []):
		if member_value is Dictionary and str((member_value as Dictionary).get("name", "")) == name:
			return true
	return false


func _validate_scene_usages(usages_value, node_index: Dictionary, errors: Array) -> void:
	if not usages_value is Array:
		return
	var usage_keys: Dictionary = {}
	for index in range((usages_value as Array).size()):
		var usage_value = (usages_value as Array)[index]
		if not usage_value is Dictionary:
			_add_issue(
				errors,
				"invalid_scene_usage",
				"Scene usage at index %s must be a dictionary." % index,
				{"index": index}
			)
			continue
		var usage: Dictionary = usage_value
		for field_name in ["scene_path", "node_path", "script_path", "evidence"]:
			if not usage.get(field_name) is String or str(usage.get(field_name, "")).is_empty():
				_add_issue(
					errors,
					"invalid_scene_usage_field",
					(
						"Scene usage at index %s field '%s' must be non-empty text."
						% [index, field_name]
					),
					{"index": index, "field": field_name}
				)
		for numeric_field in ["line", "column"]:
			if (
				not usage.has(numeric_field)
				or not usage[numeric_field] is int
				or int(usage[numeric_field]) < 1
			):
				_add_issue(
					errors,
					"invalid_scene_usage_field",
					(
						"Scene usage at index %s %s must be a positive integer."
						% [index, numeric_field]
					),
					{"index": index, "field": numeric_field}
				)
		var script_path = str(usage.get("script_path", ""))
		var usage_key = _scene_usage_key(usage)
		if not usage_key.is_empty():
			if usage_keys.has(usage_key):
				_add_issue(
					errors,
					"duplicate_scene_usage",
					"Scene usage at index %s duplicates an earlier record." % index,
					{"index": index}
				)
			else:
				usage_keys[usage_key] = true
		if not script_path.is_empty() and not node_index.has(script_path):
			# A scene can reference a script outside the selected scan root. Keep the
			# evidence record, but do not reject the otherwise valid snapshot.
			continue


func _validate_node_scene_usage_consistency(
	top_level_value, node_index: Dictionary, errors: Array
) -> void:
	if not top_level_value is Array:
		return
	var top_level_keys: Dictionary = {}
	for usage_value in top_level_value:
		if usage_value is Dictionary:
			var usage_key = _scene_usage_key(usage_value)
			if not usage_key.is_empty():
				top_level_keys[usage_key] = true
	for node_id_value in node_index:
		var node_id = str(node_id_value)
		var node: Dictionary = node_index[node_id]
		var node_usages_value = node.get("scene_usages", [])
		if not node_usages_value is Array:
			continue
		var node_usage_keys: Dictionary = {}
		for usage_index in range((node_usages_value as Array).size()):
			var usage_value = (node_usages_value as Array)[usage_index]
			if not usage_value is Dictionary:
				_add_issue(
					errors,
					"invalid_node_scene_usage",
					(
						"Node '%s' scene usage at index %s must be a dictionary."
						% [node_id, usage_index]
					),
					{"id": node_id, "index": usage_index}
				)
				continue
			var usage: Dictionary = usage_value
			if str(usage.get("script_path", "")) != node_id:
				_add_issue(
					errors,
					"node_scene_usage_script_mismatch",
					"Node '%s' contains scene evidence for a different script." % node_id,
					{"id": node_id, "index": usage_index}
				)
			var usage_key = _scene_usage_key(usage)
			if usage_key.is_empty():
				_add_issue(
					errors,
					"invalid_node_scene_usage",
					"Node '%s' scene usage at index %s is incomplete." % [node_id, usage_index],
					{"id": node_id, "index": usage_index}
				)
				continue
			if node_usage_keys.has(usage_key):
				_add_issue(
					errors,
					"duplicate_node_scene_usage",
					"Node '%s' contains duplicate scene evidence." % node_id,
					{"id": node_id, "index": usage_index}
				)
			else:
				node_usage_keys[usage_key] = true
			if not top_level_keys.has(usage_key):
				_add_issue(
					errors,
					"orphan_node_scene_usage",
					(
						"Node '%s' contains scene evidence missing from the top-level collection."
						% node_id
					),
					{"id": node_id, "index": usage_index}
				)
		for usage_value in top_level_value:
			if not usage_value is Dictionary:
				continue
			var usage: Dictionary = usage_value
			if str(usage.get("script_path", "")) != node_id:
				continue
			var usage_key = _scene_usage_key(usage)
			if not usage_key.is_empty() and not node_usage_keys.has(usage_key):
				_add_issue(
					errors,
					"missing_node_scene_usage",
					(
						"Node '%s' is missing scene evidence present in the top-level collection."
						% node_id
					),
					{"id": node_id}
				)


func _scene_usage_key(usage: Dictionary) -> String:
	for field_name in ["scene_path", "node_path", "script_path", "evidence"]:
		if not usage.get(field_name) is String or str(usage.get(field_name, "")).is_empty():
			return ""
	for numeric_field in ["line", "column"]:
		if not usage.get(numeric_field) is int or int(usage.get(numeric_field, 0)) < 1:
			return ""
	return (
		"%s|%s|%s|%09d|%09d|%s"
		% [
			str(usage.get("scene_path", "")),
			str(usage.get("node_path", "")),
			str(usage.get("script_path", "")),
			int(usage.get("line", 0)),
			int(usage.get("column", 0)),
			str(usage.get("evidence", "")),
		]
	)


func _validate_source_location(value, owner: String, errors: Array) -> void:
	if not value is Dictionary:
		_add_issue(
			errors,
			"invalid_source_location",
			"Source location for %s must be a dictionary." % owner
		)
		return
	var location: Dictionary = value
	if location.is_empty():
		return
	for field_name in ["line", "column"]:
		if not location.get(field_name) is int or int(location.get(field_name, 0)) < 1:
			_add_issue(
				errors,
				"invalid_source_location",
				(
					"Source location for %s field '%s' must be a positive integer."
					% [owner, field_name]
				),
				{"owner": owner, "field": field_name}
			)


func _validate_diagnostics(diagnostics_value, errors: Array) -> void:
	if not diagnostics_value is Array:
		return
	for index in range((diagnostics_value as Array).size()):
		var diagnostic_value = (diagnostics_value as Array)[index]
		if not diagnostic_value is Dictionary:
			_add_issue(
				errors,
				"invalid_diagnostic",
				"Diagnostic at index %s must be a dictionary." % index,
				{"index": index}
			)
			continue
		var diagnostic: Dictionary = diagnostic_value
		for field_name in ["severity", "code", "message"]:
			if not diagnostic.has(field_name) or not diagnostic[field_name] is String:
				_add_issue(
					errors,
					"invalid_diagnostic_field",
					"Diagnostic at index %s field '%s' must be text." % [index, field_name],
					{"index": index, "field": field_name}
				)
		var severity: String = (
			diagnostic["severity"] if diagnostic.get("severity", null) is String else ""
		)
		if severity != "warning" and severity != "error" and severity != "info":
			_add_issue(
				errors,
				"invalid_diagnostic_severity",
				"Diagnostic at index %s has unsupported severity '%s'." % [index, severity],
				{"index": index, "severity": severity}
			)
		for field_name in ["code", "message"]:
			if (
				diagnostic.get(field_name, null) is String
				and (diagnostic[field_name] as String).is_empty()
			):
				_add_issue(
					errors,
					"invalid_diagnostic",
					"Diagnostic at index %s field '%s' must not be empty." % [index, field_name],
					{"index": index, "field": field_name}
				)
		if diagnostic.has("context") and not diagnostic["context"] is Dictionary:
			_add_issue(
				errors,
				"invalid_diagnostic_context",
				"Diagnostic at index %s context must be a dictionary." % index,
				{"index": index}
			)


func _is_node_kind(value: String) -> bool:
	return value == "user" or value == "addon" or value == "native" or value == "external"


func _is_edge_kind(value: String) -> bool:
	return value == "extends" or value == "uses" or value == "type_uses"


func _is_member_kind(value: String) -> bool:
	return value == "property" or value == "signal" or value == "method"


func _add_issue(
	issues: Array,
	code: String,
	message: String,
	context: Dictionary = {},
	severity: String = "error"
) -> void:
	(
		issues
		. append(
			{
				"severity": severity,
				"code": code,
				"message": message,
				"context": context.duplicate(true),
			}
		)
	)
