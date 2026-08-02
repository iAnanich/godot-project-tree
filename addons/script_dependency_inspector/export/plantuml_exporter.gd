@tool
extends "res://addons/script_dependency_inspector/export/exporter.gd"


## Returns the stable format identifier used by ExportService.
func format_id() -> String:
	return "plantuml"


## Returns the reader-facing format name used by the dock.
func display_name() -> String:
	return "PlantUML"


## Returns the default filename extension without a period.
func file_extension() -> String:
	return "puml"


## PlantUML supports colors and exact Class::member relationship endpoints.
func capabilities() -> Dictionary:
	return {
		"colors": true,
		"class_members": true,
		"structured_member_links": false,
		"exact_member_endpoints": true,
		"member_relation_labels": true,
	}


## Renders a PlantUML class diagram with exact member endpoints where known.
func export_text(snapshot: Dictionary, options: Dictionary = {}) -> String:
	var lines: Array[String] = [
		"@startuml",
		"left to right direction",
		"hide empty members",
		"skinparam classAttributeIconSize 0"
	]
	var aliases = _aliases(snapshot.get("nodes", []))
	var node_by_id = _node_index(snapshot.get("nodes", []))
	var metadata: Dictionary = snapshot.get("metadata", {})
	var style: Dictionary = metadata.get("style", {})
	var display_options: Dictionary = metadata.get("options", {})

	for node_value in snapshot.get("nodes", []):
		var node: Dictionary = node_value
		var alias = str(aliases[node["id"]])
		var color = (
			_node_color(str(node.get("kind", "external")), style)
			if options.get("include_colors", true)
			else ""
		)
		var declaration = 'class "%s" as %s' % [_escape(str(node["name"])), alias]
		if str(node.get("scope_role", "")) == "context":
			declaration += " <<context>>"
		if not color.is_empty():
			declaration += " #%s" % color
		lines.append(declaration + " {")
		for property_value in node.get("properties", []):
			var property: Dictionary = property_value
			var type_name = (
				str(property.get("type", ""))
				if bool(display_options.get("show_property_types", false))
				else ""
			)
			var static_prefix = "{static} " if property.get("static", false) else ""
			lines.append(
				(
					"  +%s%s%s"
					% [
						static_prefix,
						_escape(str(property.get("name", "property"))),
						" : " + _escape(type_name) if not type_name.is_empty() else ""
					]
				)
			)
		for signal_value in node.get("signals", []):
			var signal_data: Dictionary = signal_value
			var signal_name = _escape(str(signal_data.get("name", "signal")))
			if bool(display_options.get("show_signal_signatures", false)):
				lines.append(
					"  +signal %s(%s)"
					% [signal_name, _escape(_arguments_without_defaults(str(signal_data.get("arguments", ""))))]
				)
			else:
				lines.append("  +signal %s" % signal_name)
		for method_value in node.get("methods", []):
			var method: Dictionary = method_value
			var method_name = _escape(str(method.get("name", "method")))
			var static_prefix = "{static} " if method.get("static", false) else ""
			if bool(display_options.get("show_method_signatures", false)):
				var suffix = (
					" : " + _escape(str(method.get("return_type", "")))
					if not str(method.get("return_type", "")).is_empty()
					else ""
				)
				lines.append(
					"  +%s%s(%s)%s"
					% [
						static_prefix,
						method_name,
						_escape(_arguments_without_defaults(str(method.get("arguments", "")))),
						suffix
					]
				)
			else:
				lines.append("  +%s%s" % [static_prefix, method_name])
		lines.append("}")

	var emitted_relations: Dictionary = {}
	for edge_value in snapshot.get("edges", []):
		var edge: Dictionary = edge_value
		if not aliases.has(edge["source"]) or not aliases.has(edge["target"]):
			continue
		var source = str(aliases[edge["source"]])
		var target = str(aliases[edge["target"]])
		var member_links: Array = edge.get("member_links", [])
		if (
			bool(display_options.get("show_member_dependency_edges", false))
			and not member_links.is_empty()
			and str(edge.get("kind", "")) != "extends"
		):
			for link_value in member_links:
				var link: Dictionary = link_value
				var source_endpoint = _member_endpoint(
					source, node_by_id.get(edge["source"], {}), link.get("source_member", {})
				)
				var target_endpoint = _member_endpoint(
					target, node_by_id.get(edge["target"], {}), link.get("target_member", {})
				)
				_append_unique_relation(
					lines,
					emitted_relations,
					_relation_line(source_endpoint, target_endpoint, str(edge.get("kind", "uses")))
				)
			continue
		_append_unique_relation(
			lines, emitted_relations, _relation_line(source, target, str(edge.get("kind", "uses")))
		)

	lines.append("@enduml")
	return "\n".join(lines) + "\n"


func _append_unique_relation(
	lines: Array[String], emitted_relations: Dictionary, relation_line: String
) -> void:
	if emitted_relations.has(relation_line):
		return
	emitted_relations[relation_line] = true
	lines.append(relation_line)


func _relation_line(source: String, target: String, kind: String) -> String:
	match kind:
		"extends":
			return "%s --|> %s" % [source, target]
		"type_uses":
			return "%s ..> %s : type" % [source, target]
		_:
			return "%s ..> %s : uses" % [source, target]


func _node_index(nodes: Array) -> Dictionary:
	var result: Dictionary = {}
	for node_value in nodes:
		var node: Dictionary = node_value
		result[str(node.get("id", ""))] = node
	return result


func _member_endpoint(alias: String, node_value, member_value) -> String:
	if not node_value is Dictionary or not member_value is Dictionary:
		return alias
	var node: Dictionary = node_value
	var member: Dictionary = member_value
	var kind = str(member.get("kind", ""))
	var name = str(member.get("name", ""))
	if name.is_empty() or not _node_has_member(node, kind, name):
		return alias
	if kind == "signal":
		return '%s::"signal %s"' % [alias, _escape(name)]
	return "%s::%s" % [alias, _escape_member_reference(name)]


func _node_has_member(node: Dictionary, kind: String, name: String) -> bool:
	var collection_name = "methods"
	match kind:
		"property":
			collection_name = "properties"
		"signal":
			collection_name = "signals"
	for member_value in node.get(collection_name, []):
		var member: Dictionary = member_value
		if str(member.get("name", "")) == name:
			return true
	return false


func _escape_member_reference(value: String) -> String:
	var safe = value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ")
	if safe.contains(" ") or safe.contains(":"):
		return '"%s"' % safe
	return safe


func _aliases(nodes: Array) -> Dictionary:
	var result = {}
	for index in range(nodes.size()):
		result[str(nodes[index]["id"])] = "C_%s" % index
	return result


func _node_color(kind: String, style: Dictionary) -> String:
	match kind:
		"user":
			return str(style.get("user_script_color", "005a8d"))
		"addon":
			return str(style.get("addon_script_color", "8f4f79"))
		"native":
			return str(style.get("native_class_color", "59616d"))
		_:
			return str(style.get("external_class_color", "9a6500"))


func _escape(value: String) -> String:
	return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ")
