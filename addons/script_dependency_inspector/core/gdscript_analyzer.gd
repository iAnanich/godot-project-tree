@tool
extends RefCounted

## Lightweight non-executing GDScript declaration analyzer. It extracts only
## dependency-inspection data. Valid scripts may be enriched with Script
## reflection by ProjectScanner, but local members come from source so inherited
## reflection entries are not misreported as local declarations.


## Parses one GDScript source file without executing it.
## Returns class/base declarations, local members, inner classes, literal
## load/preload .gd dependencies, declared type references, direct class-qualified
## member accesses, source-member provenance, and non-fatal warnings.
func analyze(source: String, script_path: String = "") -> Dictionary:
	var result = {
		"path": script_path,
		"class_name": "",
		"extends": {"kind": "none", "value": "", "raw": ""},
		"methods": [],
		"signals": [],
		"properties": [],
		"inner_classes": [],
		"resource_dependencies": [],
		"resource_dependency_details": [],
		"type_references": [],
		"type_reference_details": [],
		"member_accesses": [],
		"warnings": [],
	}

	var lines = source.replace("\r\n", "\n").replace("\r", "\n").split("\n", true)
	var pending_annotations: Array = []
	var lexical_state = {"multiline_delimiter": ""}
	var line_index = 0

	while line_index < lines.size():
		var raw_line = str(lines[line_index])
		var without_comment = _strip_comment_and_multiline_string(raw_line, lexical_state)
		var trimmed = without_comment.strip_edges()

		if trimmed.is_empty():
			line_index += 1
			continue
		if _indent_width(without_comment) > 0:
			line_index += 1
			continue

		var annotation_parse = _consume_leading_annotations(trimmed)
		var annotations: Array = pending_annotations.duplicate()
		annotations.append_array(annotation_parse["annotations"])
		var declaration = str(annotation_parse["remainder"]).strip_edges()

		if declaration.is_empty() and not annotation_parse["annotations"].is_empty():
			pending_annotations = annotations
			line_index += 1
			continue
		pending_annotations.clear()

		if declaration.begins_with("class_name "):
			result["class_name"] = _first_identifier(declaration.trim_prefix("class_name "))
			line_index += 1
			continue

		if declaration.begins_with("extends "):
			result["extends"] = _parse_extends_expression(declaration.trim_prefix("extends "))
			line_index += 1
			continue

		if _is_function_declaration(declaration):
			var combined = declaration
			while _parenthesis_balance(combined) > 0 and line_index + 1 < lines.size():
				line_index += 1
				combined += (
					" "
					+ (
						_strip_comment_and_multiline_string(str(lines[line_index]), lexical_state)
						. strip_edges()
					)
				)
			result["methods"].append(_parse_function(combined, annotations))
			line_index += 1
			continue

		if declaration.begins_with("signal "):
			var combined_signal = declaration
			while _parenthesis_balance(combined_signal) > 0 and line_index + 1 < lines.size():
				line_index += 1
				combined_signal += (
					" "
					+ (
						_strip_comment_and_multiline_string(str(lines[line_index]), lexical_state)
						. strip_edges()
					)
				)
			result["signals"].append(_parse_signal(combined_signal))
			line_index += 1
			continue

		if _is_variable_declaration(declaration):
			result["properties"].append(_parse_property(declaration, annotations))
			line_index += 1
			continue

		if declaration.begins_with("class ") and declaration.ends_with(":"):
			var inner_tail = declaration.trim_prefix("class ").trim_suffix(":").strip_edges()
			result["inner_classes"].append({"name": _first_identifier(inner_tail)})

		line_index += 1

	var resource_details = _collect_resource_dependency_details(source)
	result["resource_dependency_details"] = resource_details
	result["resource_dependencies"] = _unique_detail_values(resource_details, "path")
	var type_details = _collect_declared_type_reference_details(result, source)
	result["type_reference_details"] = type_details
	result["type_references"] = _unique_detail_values(type_details, "symbol")
	result["member_accesses"] = _collect_member_accesses(source)
	if result["class_name"].is_empty() and script_path.is_empty():
		result["warnings"].append(
			"Source has no path and no class_name; display naming will be synthetic."
		)
	return result


func _strip_comment_and_multiline_string(line: String, state: Dictionary) -> String:
	var output = ""
	var quote = ""
	var escaped = false
	var delimiter = str(state.get("multiline_delimiter", ""))
	var triple_double = '"' + '"' + '"'
	var triple_single = "'" + "'" + "'"
	var index = 0
	while index < line.length():
		if not delimiter.is_empty():
			var close_index = line.find(delimiter, index)
			if close_index < 0:
				state["multiline_delimiter"] = delimiter
				return output
			index = close_index + delimiter.length()
			delimiter = ""
			state["multiline_delimiter"] = ""
			continue

		var character = line.substr(index, 1)
		if escaped:
			output += character
			escaped = false
			index += 1
			continue
		if character == "\\" and not quote.is_empty():
			output += character
			escaped = true
			index += 1
			continue
		if not quote.is_empty():
			output += character
			if character == quote:
				quote = ""
			index += 1
			continue

		var candidate = line.substr(index, 3)
		if candidate == triple_double or candidate == triple_single:
			delimiter = candidate
			state["multiline_delimiter"] = delimiter
			index += delimiter.length()
			continue
		if character == '"' or character == "'":
			quote = character
			output += character
			index += 1
			continue
		if character == "#":
			return output
		output += character
		index += 1
	state["multiline_delimiter"] = delimiter
	return output


func _indent_width(line: String) -> int:
	var width = 0
	while width < line.length() and line.substr(width, 1) in [" ", "\t"]:
		width += 1
	return width


func _consume_leading_annotations(text: String) -> Dictionary:
	var remainder = text.strip_edges()
	var annotations: Array = []
	while remainder.begins_with("@"):
		var index = 1
		while index < remainder.length() and _is_identifier_character(remainder.substr(index, 1)):
			index += 1
		if index < remainder.length() and remainder.substr(index, 1) == "(":
			var balance = 1
			var quote = ""
			index += 1
			while index < remainder.length() and balance > 0:
				var character = remainder.substr(index, 1)
				if character == '"' or character == "'":
					if quote.is_empty():
						quote = character
					elif quote == character:
						quote = ""
				elif quote.is_empty():
					if character == "(":
						balance += 1
					elif character == ")":
						balance -= 1
				index += 1
		annotations.append(remainder.substr(0, index).strip_edges())
		remainder = remainder.substr(index).strip_edges()
	return {"annotations": annotations, "remainder": remainder}


func _is_identifier_character(character: String) -> bool:
	if character.is_empty():
		return false
	var code = character.unicode_at(0)
	return (
		character == "_"
		or (code >= 48 and code <= 57)
		or (code >= 65 and code <= 90)
		or (code >= 97 and code <= 122)
	)


func _first_identifier(text: String) -> String:
	var value = text.strip_edges()
	var end = 0
	while end < value.length() and _is_identifier_character(value.substr(end, 1)):
		end += 1
	return value.substr(0, end)


func _parse_extends_expression(expression: String) -> Dictionary:
	var raw = expression.strip_edges().trim_suffix(":").strip_edges()
	if raw.begins_with("preload(") or raw.begins_with("load("):
		var loaded_path = _extract_first_quoted_argument(raw)
		if not loaded_path.is_empty():
			return {"kind": "path", "value": loaded_path, "raw": raw}
	if (
		(raw.begins_with('"') and raw.ends_with('"'))
		or (raw.begins_with("'") and raw.ends_with("'"))
	):
		return {"kind": "path", "value": raw.substr(1, raw.length() - 2), "raw": raw}
	var symbol = _first_identifier(raw)
	if not symbol.is_empty():
		return {"kind": "symbol", "value": symbol, "raw": raw}
	return {"kind": "unresolved", "value": raw, "raw": raw}


func _extract_first_quoted_argument(expression: String) -> String:
	var quote = ""
	var start = -1
	for index in range(expression.length()):
		var character = expression.substr(index, 1)
		if quote.is_empty() and character in ['"', "'"]:
			quote = character
			start = index + 1
		elif not quote.is_empty() and character == quote:
			return expression.substr(start, index - start)
	return ""


func _is_function_declaration(declaration: String) -> bool:
	return declaration.begins_with("func ") or declaration.begins_with("static func ")


func _parse_function(declaration: String, annotations: Array) -> Dictionary:
	var work = declaration.strip_edges()
	var is_static = work.begins_with("static func ")
	if is_static:
		work = work.trim_prefix("static ")
	work = work.trim_prefix("func ")
	var open_parenthesis = work.find("(")
	var close_parenthesis = _matching_parenthesis(work, open_parenthesis)
	var arguments = ""
	var return_type = ""
	if open_parenthesis >= 0 and close_parenthesis > open_parenthesis:
		arguments = (
			work
			. substr(open_parenthesis + 1, close_parenthesis - open_parenthesis - 1)
			. strip_edges()
		)
		var tail = work.substr(close_parenthesis + 1).strip_edges()
		var body_colon = tail.find(":")
		var declaration_tail = tail if body_colon < 0 else tail.substr(0, body_colon)
		declaration_tail = declaration_tail.strip_edges()
		if declaration_tail.begins_with("->"):
			return_type = declaration_tail.trim_prefix("->").strip_edges()
	var signature = declaration
	var declaration_open = signature.find("(")
	var declaration_close = _matching_parenthesis(signature, declaration_open)
	if declaration_close >= 0:
		var signature_body_colon = signature.find(":", declaration_close + 1)
		if signature_body_colon >= 0:
			signature = signature.substr(0, signature_body_colon)
	return {
		"name": _first_identifier(work),
		"arguments": arguments,
		"return_type": return_type,
		"static": is_static,
		"annotations": annotations.duplicate(),
		"signature": _normalize_whitespace(signature),
	}


func _parse_signal(declaration: String) -> Dictionary:
	var work = declaration.trim_prefix("signal ").strip_edges()
	var open_parenthesis = work.find("(")
	if open_parenthesis < 0:
		var simple_name = _first_identifier(work)
		return {"name": simple_name, "arguments": "", "signature": "signal " + simple_name}
	var close_parenthesis = _matching_parenthesis(work, open_parenthesis)
	var arguments = ""
	if close_parenthesis > open_parenthesis:
		arguments = (
			work
			. substr(open_parenthesis + 1, close_parenthesis - open_parenthesis - 1)
			. strip_edges()
		)
	var name = _first_identifier(work.substr(0, open_parenthesis))
	return {"name": name, "arguments": arguments, "signature": "signal %s(%s)" % [name, arguments]}


func _is_variable_declaration(declaration: String) -> bool:
	return declaration.begins_with("var ") or declaration.begins_with("static var ")


func _parse_property(declaration: String, annotations: Array) -> Dictionary:
	var work = declaration.strip_edges()
	var is_static = work.begins_with("static var ")
	if is_static:
		work = work.trim_prefix("static ")
	work = work.trim_prefix("var ").strip_edges()
	var name = _first_identifier(work)
	var type_name = ""
	var colon = work.find(":")
	var equals = work.find("=")
	if colon >= 0 and (equals < 0 or colon < equals):
		var end = work.length() if equals < 0 else equals
		type_name = work.substr(colon + 1, end - colon - 1).strip_edges()
		var setter_position = type_name.find(" set")
		if setter_position >= 0:
			type_name = type_name.substr(0, setter_position).strip_edges()
	var is_exported = false
	for annotation in annotations:
		if _is_export_annotation(str(annotation)):
			is_exported = true
			break
	return {
		"name": name,
		"type": type_name,
		"exported": is_exported,
		"static": is_static,
		"annotations": annotations.duplicate(),
		"declaration": _normalize_whitespace(declaration),
	}


func _is_export_annotation(annotation: String) -> bool:
	for group_annotation in ["@export_group", "@export_subgroup", "@export_category"]:
		if annotation.begins_with(group_annotation):
			return false
	return annotation == "@export" or annotation.begins_with("@export_")


func _parenthesis_balance(text: String) -> int:
	var balance = 0
	var quote = ""
	var escaped = false
	for index in range(text.length()):
		var character = text.substr(index, 1)
		if escaped:
			escaped = false
			continue
		if character == "\\" and not quote.is_empty():
			escaped = true
			continue
		if character in ['"', "'"]:
			if quote.is_empty():
				quote = character
			elif quote == character:
				quote = ""
			continue
		if quote.is_empty():
			if character == "(":
				balance += 1
			elif character == ")":
				balance -= 1
	return balance


func _matching_parenthesis(text: String, open_index: int) -> int:
	if open_index < 0:
		return -1
	var balance = 0
	var quote = ""
	var escaped = false
	for index in range(open_index, text.length()):
		var character = text.substr(index, 1)
		if escaped:
			escaped = false
			continue
		if character == "\\" and not quote.is_empty():
			escaped = true
			continue
		if character in ['"', "'"]:
			if quote.is_empty():
				quote = character
			elif quote == character:
				quote = ""
			continue
		if not quote.is_empty():
			continue
		if character == "(":
			balance += 1
		elif character == ")":
			balance -= 1
			if balance == 0:
				return index
	return -1


func _collect_resource_dependency_details(source: String) -> Array:
	var details: Array = []
	var detail_keys: Dictionary = {}
	var scope_by_line = _member_scope_by_line(source)
	var index = 0
	while index < source.length():
		var character = source.substr(index, 1)
		if character == "#":
			var newline = source.find("\n", index + 1)
			index = source.length() if newline < 0 else newline + 1
			continue
		if character in ['"', "'"]:
			index = _skip_quoted_string(source, index)
			continue
		if not _is_identifier_character(character):
			index += 1
			continue

		var token_start = index
		while index < source.length() and _is_identifier_character(source.substr(index, 1)):
			index += 1
		var token = source.substr(token_start, index - token_start)
		if token != "load" and token != "preload":
			continue

		var cursor = _skip_whitespace(source, index)
		if cursor >= source.length() or source.substr(cursor, 1) != "(":
			continue
		cursor = _skip_whitespace(source, cursor + 1)
		if cursor >= source.length() or source.substr(cursor, 1) not in ['"', "'"]:
			continue

		var path_result = _read_quoted_string(source, cursor)
		var dependency_path = str(path_result.get("value", ""))
		if dependency_path.ends_with(".gd"):
			var source_member: Dictionary = scope_by_line.get(
				_source_line_number(source, token_start), {}
			)
			var detail = {
				"path": dependency_path,
				"source_member": source_member.duplicate(true),
				"evidence": token,
			}
			var detail_key = "%s|%s|%s|%s" % [
				dependency_path,
				str(source_member.get("kind", "")),
				str(source_member.get("name", "")),
				token,
			]
			if not detail_keys.has(detail_key):
				detail_keys[detail_key] = true
				details.append(detail)
		index = maxi(index, int(path_result.get("next_index", cursor + 1)))

	details.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return _dependency_detail_sort_key(left, "path") < _dependency_detail_sort_key(right, "path")
	)
	return details


func _collect_declared_type_reference_details(analysis: Dictionary, source: String) -> Array:
	var details: Array = []
	for property_value in analysis.get("properties", []):
		var property: Dictionary = property_value
		_append_type_expression_details(
			str(property.get("type", "")),
			{"kind": "property", "name": str(property.get("name", ""))},
			"property_type",
			details
		)
	for signal_value in analysis.get("signals", []):
		var signal_data: Dictionary = signal_value
		_append_argument_type_details(
			str(signal_data.get("arguments", "")),
			{"kind": "signal", "name": str(signal_data.get("name", ""))},
			"signal_argument_type",
			details
		)
	for method_value in analysis.get("methods", []):
		var method: Dictionary = method_value
		var method_ref = {"kind": "method", "name": str(method.get("name", ""))}
		_append_argument_type_details(
			str(method.get("arguments", "")), method_ref, "method_argument_type", details
		)
		_append_type_expression_details(
			str(method.get("return_type", "")), method_ref, "method_return_type", details
		)
	_collect_source_scope_type_reference_details(source, details)

	var own_name = str(analysis.get("class_name", ""))
	var unique: Dictionary = {}
	var filtered: Array = []
	for detail_value in details:
		var detail: Dictionary = detail_value
		if str(detail.get("symbol", "")) == own_name:
			continue
		var key = _dependency_detail_sort_key(detail, "symbol") + "|" + str(detail.get("evidence", ""))
		if unique.has(key):
			continue
		unique[key] = true
		filtered.append(detail)
	filtered.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return _dependency_detail_sort_key(left, "symbol") < _dependency_detail_sort_key(right, "symbol")
	)
	return filtered


func _collect_source_scope_type_reference_details(source: String, details: Array) -> void:
	var lines = source.replace("\r\n", "\n").replace("\r", "\n").split("\n", true)
	var lexical_state = {"multiline_delimiter": ""}
	var scope_by_line = _member_scope_by_line(source)
	for line_index in range(lines.size()):
		var without_comment = _strip_comment_and_multiline_string(str(lines[line_index]), lexical_state)
		var declaration = without_comment.strip_edges()
		if declaration.is_empty() or _indent_width(without_comment) <= 0:
			continue
		var source_member: Dictionary = scope_by_line.get(line_index, {})
		if source_member.is_empty():
			continue
		if _is_variable_declaration(declaration):
			var local_property = _parse_property(declaration, [])
			_append_type_expression_details(
				str(local_property.get("type", "")), source_member, "local_variable_type", details
			)
		if declaration.begins_with("for "):
			var colon = _find_top_level_character(declaration, ":")
			var in_position = declaration.find(" in ", colon + 1)
			if colon >= 0 and in_position > colon:
				_append_type_expression_details(
					declaration.substr(colon + 1, in_position - colon - 1).strip_edges(),
					source_member,
					"loop_variable_type",
					details
				)
		var function_position = declaration.find("func ")
		if function_position >= 0:
			var lambda_declaration = declaration.substr(function_position)
			var lambda_data = _parse_function(lambda_declaration, [])
			_append_argument_type_details(
				str(lambda_data.get("arguments", "")), source_member, "lambda_argument_type", details
			)
			_append_type_expression_details(
				str(lambda_data.get("return_type", "")), source_member, "lambda_return_type", details
			)


func _append_argument_type_details(
	arguments: String, source_member: Dictionary, evidence: String, details: Array
) -> void:
	for argument_value in _split_top_level(arguments, ","):
		var argument = str(argument_value).strip_edges()
		var colon = _find_top_level_character(argument, ":")
		if colon < 0:
			continue
		var type_expression = argument.substr(colon + 1).strip_edges()
		var equals = _find_top_level_character(type_expression, "=")
		if equals >= 0:
			type_expression = type_expression.substr(0, equals).strip_edges()
		_append_type_expression_details(type_expression, source_member, evidence, details)


func _append_type_expression_details(
	expression: String, source_member: Dictionary, evidence: String, details: Array
) -> void:
	for symbol_value in _type_symbols(expression):
		details.append(
			{
				"symbol": str(symbol_value),
				"source_member": source_member.duplicate(true),
				"evidence": evidence,
			}
		)


func _type_symbols(expression: String) -> Array:
	var symbols: Dictionary = {}
	var index = 0
	while index < expression.length():
		if not _is_identifier_character(expression.substr(index, 1)):
			index += 1
			continue
		var start = index
		while index < expression.length() and _is_identifier_character(expression.substr(index, 1)):
			index += 1
		var symbol = expression.substr(start, index - start)
		if not _is_builtin_type_name(symbol):
			symbols[symbol] = true
	var result: Array = symbols.keys()
	result.sort()
	return result


func _collect_member_accesses(source: String) -> Array:
	var accesses: Array = []
	var access_keys: Dictionary = {}
	var scope_by_line = _member_scope_by_line(source)
	var index = 0
	while index < source.length():
		var character = source.substr(index, 1)
		if character == "#":
			var newline = source.find("\n", index + 1)
			index = source.length() if newline < 0 else newline + 1
			continue
		if character in ['"', "'"]:
			index = _skip_quoted_string(source, index)
			continue
		if not _is_identifier_character(character):
			index += 1
			continue

		var symbol_start = index
		while index < source.length() and _is_identifier_character(source.substr(index, 1)):
			index += 1
		var target_symbol = source.substr(symbol_start, index - symbol_start)
		if not _looks_like_class_symbol(target_symbol):
			continue
		var cursor = _skip_horizontal_whitespace(source, index)
		if cursor >= source.length() or source.substr(cursor, 1) != ".":
			continue
		cursor = _skip_horizontal_whitespace(source, cursor + 1)
		if cursor >= source.length() or not _is_identifier_character(source.substr(cursor, 1)):
			continue
		var member_start = cursor
		while cursor < source.length() and _is_identifier_character(source.substr(cursor, 1)):
			cursor += 1
		var member_name = source.substr(member_start, cursor - member_start)
		var after_member = _skip_horizontal_whitespace(source, cursor)
		var member_kind = (
			"method"
			if after_member < source.length() and source.substr(after_member, 1) == "("
			else "property"
		)
		var source_member: Dictionary = scope_by_line.get(
			_source_line_number(source, symbol_start), {}
		)
		var access = {
			"target_symbol": target_symbol,
			"target_member": {"kind": member_kind, "name": member_name},
			"source_member": source_member.duplicate(true),
			"evidence": "class_member_access",
		}
		var key = "%s|%s|%s|%s|%s" % [
			target_symbol,
			member_kind,
			member_name,
			str(source_member.get("kind", "")),
			str(source_member.get("name", "")),
		]
		if not access_keys.has(key):
			access_keys[key] = true
			accesses.append(access)
		index = cursor
	accesses.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return _member_access_sort_key(left) < _member_access_sort_key(right)
	)
	return accesses


func _member_scope_by_line(source: String) -> Dictionary:
	var lines = source.replace("\r\n", "\n").replace("\r", "\n").split("\n", true)
	var lexical_state = {"multiline_delimiter": ""}
	var scope_by_line: Dictionary = {}
	var current_member: Dictionary = {}
	var current_indent = -1
	for line_index in range(lines.size()):
		var without_comment = _strip_comment_and_multiline_string(str(lines[line_index]), lexical_state)
		var trimmed = without_comment.strip_edges()
		if trimmed.is_empty():
			if not current_member.is_empty():
				scope_by_line[line_index] = current_member.duplicate(true)
			continue
		var indent = _indent_width(without_comment)
		var annotation_parse = _consume_leading_annotations(trimmed)
		var declaration = str(annotation_parse.get("remainder", "")).strip_edges()
		if indent <= current_indent:
			current_member = {}
			current_indent = -1
		if indent == 0 and _is_function_declaration(declaration):
			var method = _parse_function(declaration, [])
			current_member = {"kind": "method", "name": str(method.get("name", ""))}
			current_indent = 0
			scope_by_line[line_index] = current_member.duplicate(true)
			continue
		if indent == 0 and _is_variable_declaration(declaration):
			var property = _parse_property(declaration, [])
			current_member = {"kind": "property", "name": str(property.get("name", ""))}
			current_indent = 0
			scope_by_line[line_index] = current_member.duplicate(true)
			continue
		if not current_member.is_empty() and indent > current_indent:
			scope_by_line[line_index] = current_member.duplicate(true)
	return scope_by_line


func _source_line_number(source: String, source_index: int) -> int:
	return source.substr(0, source_index).count("\n")


func _skip_horizontal_whitespace(text: String, start_index: int) -> int:
	var index = start_index
	while index < text.length() and text.substr(index, 1) in [" ", "\t"]:
		index += 1
	return index


func _looks_like_class_symbol(symbol: String) -> bool:
	if symbol.is_empty():
		return false
	var first = symbol.substr(0, 1)
	return first == first.to_upper() and first != first.to_lower()


func _unique_detail_values(details: Array, key_name: String) -> Array:
	var values: Dictionary = {}
	for detail_value in details:
		var detail: Dictionary = detail_value
		var value = str(detail.get(key_name, ""))
		if not value.is_empty():
			values[value] = true
	var result: Array = values.keys()
	result.sort()
	return result


func _dependency_detail_sort_key(detail: Dictionary, value_key: String) -> String:
	var member: Dictionary = detail.get("source_member", {})
	return "%s|%s|%s|%s" % [
		str(detail.get(value_key, "")),
		str(member.get("kind", "")),
		str(member.get("name", "")),
		str(detail.get("evidence", "")),
	]


func _member_access_sort_key(access: Dictionary) -> String:
	var source_member: Dictionary = access.get("source_member", {})
	var target_member: Dictionary = access.get("target_member", {})
	return "%s|%s|%s|%s|%s" % [
		str(access.get("target_symbol", "")),
		str(target_member.get("kind", "")),
		str(target_member.get("name", "")),
		str(source_member.get("kind", "")),
		str(source_member.get("name", "")),
	]


func _split_top_level(text: String, separator: String) -> Array:
	var parts: Array = []
	var start = 0
	var round_depth = 0
	var square_depth = 0
	var curly_depth = 0
	var quote = ""
	var escaped = false
	for index in range(text.length()):
		var character = text.substr(index, 1)
		if escaped:
			escaped = false
			continue
		if character == "\\" and not quote.is_empty():
			escaped = true
			continue
		if character in ['"', "'"]:
			if quote.is_empty():
				quote = character
			elif quote == character:
				quote = ""
			continue
		if not quote.is_empty():
			continue
		match character:
			"(":
				round_depth += 1
			")":
				round_depth = maxi(0, round_depth - 1)
			"[":
				square_depth += 1
			"]":
				square_depth = maxi(0, square_depth - 1)
			"{":
				curly_depth += 1
			"}":
				curly_depth = maxi(0, curly_depth - 1)
			_:
				pass
		if (
			character == separator
			and round_depth == 0
			and square_depth == 0
			and curly_depth == 0
		):
			parts.append(text.substr(start, index - start))
			start = index + 1
	parts.append(text.substr(start))
	return parts


func _find_top_level_character(text: String, target: String) -> int:
	var round_depth = 0
	var square_depth = 0
	var curly_depth = 0
	var quote = ""
	var escaped = false
	for index in range(text.length()):
		var character = text.substr(index, 1)
		if escaped:
			escaped = false
			continue
		if character == "\\" and not quote.is_empty():
			escaped = true
			continue
		if character in ['"', "'"]:
			if quote.is_empty():
				quote = character
			elif quote == character:
				quote = ""
			continue
		if not quote.is_empty():
			continue
		if character == target and round_depth == 0 and square_depth == 0 and curly_depth == 0:
			return index
		match character:
			"(":
				round_depth += 1
			")":
				round_depth = maxi(0, round_depth - 1)
			"[":
				square_depth += 1
			"]":
				square_depth = maxi(0, square_depth - 1)
			"{":
				curly_depth += 1
			"}":
				curly_depth = maxi(0, curly_depth - 1)
			_:
				pass
	return -1


func _is_builtin_type_name(symbol: String) -> bool:
	return symbol in [
		"Variant", "void", "bool", "int", "float", "String", "StringName",
		"NodePath", "RID", "Callable", "Signal", "Array", "Dictionary",
		"Vector2", "Vector2i", "Rect2", "Rect2i", "Vector3", "Vector3i",
		"Transform2D", "Vector4", "Vector4i", "Plane", "Quaternion", "AABB",
		"Basis", "Transform3D", "Projection", "Color", "PackedByteArray",
		"PackedInt32Array", "PackedInt64Array", "PackedFloat32Array",
		"PackedFloat64Array", "PackedStringArray", "PackedVector2Array",
		"PackedVector3Array", "PackedColorArray", "PackedVector4Array",
		"null", "true", "false"
	]


func _skip_whitespace(text: String, start_index: int) -> int:
	var index = start_index
	while index < text.length() and text.substr(index, 1) in [" ", "\t", "\r", "\n"]:
		index += 1
	return index


func _skip_quoted_string(text: String, quote_index: int) -> int:
	return int(_read_quoted_string(text, quote_index).get("next_index", quote_index + 1))


func _read_quoted_string(text: String, quote_index: int) -> Dictionary:
	var quote = text.substr(quote_index, 1)
	var delimiter = quote
	if text.substr(quote_index, 3) == quote + quote + quote:
		delimiter = quote + quote + quote
	var value = ""
	var escaped = false
	var index = quote_index + delimiter.length()
	while index < text.length():
		var character = text.substr(index, 1)
		if escaped:
			value += character
			escaped = false
		elif character == "\\":
			escaped = true
		elif text.substr(index, delimiter.length()) == delimiter:
			return {
				"value": value,
				"next_index": index + delimiter.length(),
				"closed": true,
			}
		else:
			value += character
		index += 1
	return {"value": value, "next_index": text.length(), "closed": false}


func _normalize_whitespace(text: String) -> String:
	return " ".join(text.replace("\t", " ").split(" ", false))
