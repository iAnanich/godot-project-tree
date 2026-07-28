@tool
extends RefCounted

const SUPPORTED_SCHEMA_VERSION: int = 1
const REQUIRED_NODE_FIELDS: Array[String] = [
	"id", "name", "kind", "properties", "signals", "methods", "inner_classes"
]
const REQUIRED_EDGE_FIELDS: Array[String] = ["source", "target", "kind", "member_links"]
const REQUIRED_MEMBER_LINK_FIELDS: Array[String] = [
	"source_member", "target_member", "evidence"
]


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
	_validate_edges(snapshot.get("edges", []), node_index, errors, warnings)
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
	for key in ["metadata", "nodes", "edges", "warnings", "errors"]:
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
	for key in ["nodes", "edges", "warnings", "errors"]:
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
	for field_name in ["root_path", "engine_version"]:
		if metadata.has(field_name) and not metadata[field_name] is String:
			_add_issue(
				errors,
				"invalid_metadata_field",
				"Snapshot metadata field '%s' must be text." % field_name,
				{"field": field_name}
			)
	if not metadata.has("root_path") or (
		metadata["root_path"] is String and (metadata["root_path"] as String).is_empty()
	):
		_add_issue(
			warnings,
			"missing_root_path_metadata",
			"Snapshot metadata does not identify the scanned root.",
			{},
			"warning"
		)
	for field_name in ["options", "style"]:
		if metadata.has(field_name) and not metadata[field_name] is Dictionary:
			_add_issue(
				errors,
				"invalid_metadata_field",
				"Snapshot metadata field '%s' must be a dictionary." % field_name,
				{"field": field_name}
			)


func _validate_nodes(
	nodes_value, node_index: Dictionary, errors: Array, warnings: Array
) -> void:
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
					errors,
					"duplicate_node_id",
					"Duplicate node id: %s." % node_id,
					{"id": node_id}
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
			"path", "class_name", "qualified_name", "native_base", "inheritance_family"
		]:
			if node.has(text_field) and not node[text_field] is String:
				_add_issue(
					errors,
					"invalid_node_field",
					"Node '%s' field '%s' must be text." % [node_id, text_field],
					{"id": node_id, "field": text_field}
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
		_validate_member_collection(node, node_id, "properties", "property", errors)
		_validate_member_collection(node, node_id, "signals", "signal", errors)
		_validate_member_collection(node, node_id, "methods", "method", errors)
		_validate_inner_classes(node, node_id, errors)
		index += 1


func _validate_member_collection(
	node: Dictionary,
	node_id: String,
	collection_name: String,
	member_kind: String,
	errors: Array
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
				"Node '%s' %s at index %s must be a dictionary."
				% [node_id, member_kind, member_index],
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
				"Node '%s' %s at index %s has no name."
				% [node_id, member_kind, member_index],
				{"id": node_id, "kind": member_kind, "index": member_index}
			)
		elif not member["name"] is String:
			_add_issue(
				errors,
				"invalid_member_field",
				"Node '%s' %s at index %s field 'name' must be text."
				% [node_id, member_kind, member_index],
				{"id": node_id, "kind": member_kind, "index": member_index, "field": "name"}
			)
		else:
			member_name = member["name"]
			if member_name.is_empty():
				_add_issue(
					errors,
					"missing_member_name",
					"Node '%s' %s at index %s has no name."
					% [node_id, member_kind, member_index],
					{"id": node_id, "kind": member_kind, "index": member_index}
				)
			elif names.has(member_name):
				_add_issue(
					errors,
					"duplicate_member",
					"Node '%s' contains duplicate %s '%s'."
					% [node_id, member_kind, member_name],
					{"id": node_id, "kind": member_kind, "name": member_name}
				)
			else:
				names[member_name] = true
		if member.has("annotations") and not member["annotations"] is Array:
			_add_issue(
				errors,
				"invalid_member_field",
				"Node '%s' %s '%s' annotations must be an array."
				% [node_id, member_kind, member_name],
				{"id": node_id, "kind": member_kind, "name": member_name, "field": "annotations"}
			)
		for text_field in ["arguments", "return_type", "signature", "declaration", "type"]:
			if member.has(text_field) and not member[text_field] is String:
				_add_issue(
					errors,
					"invalid_member_field",
					"Node '%s' %s '%s' field '%s' must be text."
					% [node_id, member_kind, member_name, text_field],
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
					"Node '%s' %s '%s' field '%s' must be boolean."
					% [node_id, member_kind, member_name, boolean_field],
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
		if not item.has("name") or not item["name"] is String or (item["name"] as String).is_empty():
			_add_issue(
				errors,
				"invalid_inner_class",
				"Node '%s' inner class at index %s has an invalid name." % [node_id, index],
				{"id": node_id, "index": index}
			)


func _validate_edges(
	edges_value, node_index: Dictionary, errors: Array, warnings: Array
) -> void:
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
					"Edge %s member link %s is missing required field '%s'."
					% [edge_index, link_index, required_field],
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
		if not source_member.is_empty() and node_index.has(source_id):
			_validate_member_exists(
				node_index[source_id], source_member, edge_index, link_index, "source", errors
			)
		if not target_member.is_empty() and node_index.has(target_id):
			_validate_member_exists(
				node_index[target_id], target_member, edge_index, link_index, "target", errors
			)
		var link_key: String = "%s|%s|%s|%s|%s" % [
			str(source_member.get("kind", "")),
			str(source_member.get("name", "")),
			str(target_member.get("kind", "")),
			str(target_member.get("name", "")),
			evidence,
		]
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
	member_value,
	edge_index: int,
	link_index: int,
	field_name: String,
	errors: Array
) -> Dictionary:
	if not member_value is Dictionary:
		_add_issue(
			errors,
			"invalid_member_reference",
			"Edge %s member link %s field '%s' must be a dictionary."
			% [edge_index, link_index, field_name],
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
			"Edge %s member link %s field '%s' must contain kind and name together."
			% [edge_index, link_index, field_name],
			{"edge_index": edge_index, "link_index": link_index, "field": field_name}
		)
		return {}
	if not member["kind"] is String or not member["name"] is String:
		_add_issue(
			errors,
			"invalid_member_reference",
			"Edge %s member link %s field '%s' kind and name must be text."
			% [edge_index, link_index, field_name],
			{"edge_index": edge_index, "link_index": link_index, "field": field_name}
		)
		return {}
	var kind: String = member["kind"]
	var name: String = member["name"]
	if not _is_member_kind(kind) or name.is_empty():
		_add_issue(
			errors,
			"invalid_member_reference",
			"Edge %s member link %s has an invalid %s."
			% [edge_index, link_index, field_name],
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
		"Edge %s member link %s references an unknown %s member '%s'."
		% [edge_index, link_index, endpoint, member["name"]],
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
					"Diagnostic at index %s field '%s' must be text."
					% [index, field_name],
					{"index": index, "field": field_name}
				)
		var severity: String = diagnostic["severity"] if diagnostic.get("severity", null) is String else ""
		if severity != "warning" and severity != "error" and severity != "info":
			_add_issue(
				errors,
				"invalid_diagnostic_severity",
				"Diagnostic at index %s has unsupported severity '%s'." % [index, severity],
				{"index": index, "severity": severity}
			)
		for field_name in ["code", "message"]:
			if diagnostic.get(field_name, null) is String and (diagnostic[field_name] as String).is_empty():
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
	issues.append(
		{
			"severity": severity,
			"code": code,
			"message": message,
			"context": context.duplicate(true),
		}
	)
