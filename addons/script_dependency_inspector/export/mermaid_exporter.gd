@tool
extends "res://addons/script_dependency_inspector/export/exporter.gd"


## Returns the stable format identifier used by ExportService.
func format_id() -> String:
	return "mermaid"


## Returns the reader-facing format name used by the dock.
func display_name() -> String:
	return "Mermaid class diagram"


## Returns the default filename extension without a period.
func file_extension() -> String:
	return "mmd"


## Mermaid class diagrams support colors and member labels, but not member endpoints.
func capabilities() -> Dictionary:
	return {
		"colors": true,
		"class_members": true,
		"structured_member_links": false,
		"exact_member_endpoints": false,
		"member_relation_labels": true,
	}


## Renders a Mermaid class diagram with labeled class-level member relations.
func export_text(snapshot: Dictionary, options: Dictionary = {}) -> String:
	var lines: Array[String] = ["classDiagram", "direction LR"]
	var aliases = _aliases(snapshot.get("nodes", []))
	var metadata: Dictionary = snapshot.get("metadata", {})
	var style: Dictionary = metadata.get("style", {})
	var display_options: Dictionary = metadata.get("options", {})

	for node_value in snapshot.get("nodes", []):
		var node: Dictionary = node_value
		var alias = str(aliases[node["id"]])
		var display_name: String = str(node["name"])
		if str(node.get("scope_role", "")) == "context":
			display_name += " (context)"
		lines.append('class %s["%s"] {' % [alias, _escape_label(display_name)])
		for property_value in node.get("properties", []):
			var property: Dictionary = property_value
			var suffix = ""
			if bool(display_options.get("show_property_types", false)):
				var property_type = str(property.get("type", ""))
				if not property_type.is_empty():
					suffix = " : " + _mermaid_member_text(property_type)
			var static_suffix = "$" if property.get("static", false) else ""
			lines.append(
				(
					"  +%s%s%s"
					% [_escape_member(str(property.get("name", "property"))), suffix, static_suffix]
				)
			)
		for signal_value in node.get("signals", []):
			var signal_data: Dictionary = signal_value
			var signal_name = _escape_member(str(signal_data.get("name", "signal")))
			if bool(display_options.get("show_signal_signatures", false)):
				lines.append(
					(
						"  +signal %s(%s)"
						% [signal_name, _mermaid_arguments(str(signal_data.get("arguments", "")))]
					)
				)
			else:
				lines.append("  +signal %s" % signal_name)
		for method_value in node.get("methods", []):
			var method: Dictionary = method_value
			var method_name = _escape_member(str(method.get("name", "method")))
			var static_suffix = "$" if method.get("static", false) else ""
			if bool(display_options.get("show_method_signatures", false)):
				var return_suffix = (
					" " + _mermaid_member_text(str(method.get("return_type", "")))
					if not str(method.get("return_type", "")).is_empty()
					else ""
				)
				lines.append(
					(
						"  +%s(%s)%s%s"
						% [
							method_name,
							_mermaid_arguments(str(method.get("arguments", ""))),
							return_suffix,
							static_suffix
						]
					)
				)
			else:
				lines.append("  +%s%s" % [method_name, static_suffix])
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
				_append_unique_relation(
					lines,
					emitted_relations,
					_relation_line(
						source, target, str(edge.get("kind", "uses")), _member_relation_label(link)
					)
				)
			continue
		_append_unique_relation(
			lines, emitted_relations, _relation_line(source, target, str(edge.get("kind", "uses")))
		)

	_append_styles(lines, snapshot.get("nodes", []), aliases, style, options)
	return "\n".join(lines) + "\n"


func _append_unique_relation(
	lines: Array[String], emitted_relations: Dictionary, relation_line: String
) -> void:
	if emitted_relations.has(relation_line):
		return
	emitted_relations[relation_line] = true
	lines.append(relation_line)


func _relation_line(
	source: String, target: String, kind: String, member_label: String = ""
) -> String:
	if kind == "extends":
		return "%s --|> %s" % [source, target]
	var label = "type" if kind == "type_uses" else "uses"
	if not member_label.is_empty():
		label = member_label + " " + label
	return "%s ..> %s : %s" % [source, target, _escape_relation_label(label)]


func _member_relation_label(link: Dictionary) -> String:
	var source_member: Dictionary = link.get("source_member", {})
	var target_member: Dictionary = link.get("target_member", {})
	var source_text = _member_reference_text(source_member)
	var target_text = _member_reference_text(target_member)
	if source_text.is_empty():
		return target_text
	if target_text.is_empty():
		return source_text
	return source_text + " to " + target_text


func _member_reference_text(member: Dictionary) -> String:
	var name = str(member.get("name", ""))
	if name.is_empty():
		return ""
	return name + "()" if str(member.get("kind", "")) in ["method", "signal"] else name


func _escape_relation_label(value: String) -> String:
	return value.replace("\n", " ").replace(":", "-").replace('"', "'")


func _aliases(nodes: Array) -> Dictionary:
	var result = {}
	for index in range(nodes.size()):
		result[str(nodes[index]["id"])] = "C_%s" % index
	return result


func _append_styles(
	lines: Array[String], nodes: Array, aliases: Dictionary, style: Dictionary, options: Dictionary
) -> void:
	if not options.get("include_colors", true):
		return
	var colors = {
		"user": str(style.get("user_script_color", "005a8d")),
		"addon": str(style.get("addon_script_color", "8f4f79")),
		"native": str(style.get("native_class_color", "59616d")),
		"external": str(style.get("external_class_color", "9a6500")),
	}
	for kind in colors:
		lines.append("classDef %s fill:#%s,stroke:#222,color:#fff" % [kind, colors[kind]])
	for node_value in nodes:
		var node: Dictionary = node_value
		var kind = str(node.get("kind", "external"))
		if colors.has(kind):
			lines.append('cssClass "%s" %s' % [aliases[node["id"]], kind])


func _escape_label(value: String) -> String:
	return value.replace("\\", "\\\\").replace('"', '\\"')


func _mermaid_arguments(value: String) -> String:
	return _mermaid_member_text(_arguments_without_defaults(value))


func _mermaid_member_text(value: String) -> String:
	var result: String = ""
	var generic_depth: int = 0
	for index in range(value.length()):
		var character: String = value.substr(index, 1)
		match character:
			"[", "<":
				generic_depth += 1
				result += "~"
			"]", ">":
				generic_depth = maxi(0, generic_depth - 1)
				result += "~"
			",":
				# Mermaid does not support commas inside generic declarations.
				result += ";" if generic_depth > 0 else ","
			"{":
				result += "("
			"}":
				result += ")"
			"\n", "\r":
				result += " "
			_:
				result += character
	return result


func _escape_member(value: String) -> String:
	return _mermaid_member_text(value)
