@tool
extends GraphEdit

const TOOLTIP_MAX_OCCURRENCES: int = 4

var _connection_evidence: Dictionary = {}


## Removes evidence associated with the currently rendered connection set.
func clear_connection_evidence() -> void:
	_connection_evidence.clear()


## Associates one canonical relationship occurrence with one rendered GraphEdit connection.
func register_connection_evidence(
	from_node: StringName, from_port: int, to_node: StringName, to_port: int, evidence: Dictionary
) -> void:
	var key: String = _connection_key(from_node, from_port, to_node, to_port)
	var values: Array = _connection_evidence.get(key, [])
	var candidate: Dictionary = evidence.duplicate(true)
	if not values.has(candidate):
		values.append(candidate)
	_connection_evidence[key] = values


## Returns relationship-specific evidence when the pointer is close to a rendered connection.
func _get_tooltip(at_position: Vector2) -> String:
	var connection: Dictionary = get_closest_connection_at_point(at_position, 6.0)
	if connection.is_empty():
		return tooltip_text
	var key: String = _connection_key(
		StringName(connection.get("from_node", "")),
		int(connection.get("from_port", -1)),
		StringName(connection.get("to_node", "")),
		int(connection.get("to_port", -1))
	)
	var values: Array = _connection_evidence.get(key, [])
	if values.is_empty():
		return tooltip_text
	return _connection_tooltip(values)


func _connection_key(
	from_node: StringName, from_port: int, to_node: StringName, to_port: int
) -> String:
	return "%s|%s|%s|%s" % [from_node, from_port, to_node, to_port]


func _connection_tooltip(values: Array) -> String:
	var first: Dictionary = values[0]
	var lines: Array[String] = [
		_relationship_label(str(first.get("kind", "uses"))),
		"Dependent: %s" % str(first.get("dependent", "")),
		"Dependency: %s" % str(first.get("dependency", "")),
		"Canonical direction: dependent → dependency",
		"Rendered direction: dependency → dependent (layout only)",
		"Exact evidence occurrences represented: %s" % values.size(),
	]
	var shown: int = mini(values.size(), TOOLTIP_MAX_OCCURRENCES)
	for index in range(shown):
		lines.append(_occurrence_line(values[index]))
	if shown < values.size():
		lines.append(
			(
				"… %s additional occurrence%s"
				% [values.size() - shown, "" if values.size() - shown == 1 else "s"]
			)
		)
	return "\n".join(lines)


func _occurrence_line(value: Dictionary) -> String:
	var evidence: String = _evidence_label(str(value.get("evidence", "relationship")))
	var source_member: Dictionary = value.get("source_member", {})
	var target_member: Dictionary = value.get("target_member", {})
	var source_location: Dictionary = value.get("source_location", {})
	var parts: Array[String] = ["• %s" % evidence]
	if not source_member.is_empty():
		parts.append("source %s" % _member_label(source_member))
	if not target_member.is_empty():
		parts.append("target %s" % _member_label(target_member))
	if not source_location.is_empty():
		parts.append(
			(
				"line %s:%s"
				% [int(source_location.get("line", 1)), int(source_location.get("column", 1))]
			)
		)
	return " · ".join(parts)


func _member_label(member: Dictionary) -> String:
	var kind: String = str(member.get("kind", "member")).replace("_", " ")
	var name: String = str(member.get("name", ""))
	return "%s %s" % [kind, name] if not name.is_empty() else kind


func _relationship_label(kind: String) -> String:
	match kind:
		"extends":
			return "Inheritance relationship"
		"type_uses":
			return "Type dependency"
		_:
			return "Direct dependency"


func _evidence_label(evidence: String) -> String:
	match evidence:
		"preload":
			return "preload()"
		"load":
			return "load()"
		"class_member_access":
			return "class-member access"
		"method_parameter_type":
			return "method parameter type"
		"method_return_type":
			return "method return type"
		"property_type":
			return "property type"
		"signal_parameter_type":
			return "signal parameter type"
		"local_variable_type":
			return "local variable type"
		"extends":
			return "extends"
		_:
			return evidence.replace("_", " ")
