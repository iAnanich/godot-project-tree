@tool
extends RefCounted

## Behavioral contract for deterministic dependency graph exporters.
## Implementations must be stateless for a single export call and must not
## mutate the supplied canonical snapshot.


## Returns the stable lowercase format identifier used by the export service.
func format_id() -> String:
	push_error("Exporter.format_id() must be overridden.")
	return "unknown"


## Returns the human-readable format name used by the editor dock.
func display_name() -> String:
	return format_id().capitalize()


## Returns the filename extension without a leading period.
func file_extension() -> String:
	push_error("Exporter.file_extension() must be overridden.")
	return "txt"


## Declares optional representation capabilities before an export is attempted.
## Unknown capability keys are allowed for forward-compatible exporters.
func capabilities() -> Dictionary:
	return {
		"colors": false,
		"class_members": true,
		"structured_member_links": false,
		"exact_member_endpoints": false,
		"member_relation_labels": false,
	}


## Returns a deterministic textual representation of snapshot.
func export_text(_snapshot: Dictionary, _options: Dictionary = {}) -> String:
	push_error("Exporter.export_text() must be overridden.")
	return ""

## Returns a diagram-safe argument list that omits default expressions.
## JSON remains the lossless representation; textual diagram grammars cannot
## reliably represent arbitrary GDScript expressions such as dictionary literals.
func _arguments_without_defaults(arguments: String) -> String:
	var values: Array[String] = []
	for argument_value in _split_top_level(arguments, ","):
		var argument: String = _strip_top_level_assignment(str(argument_value)).strip_edges()
		if not argument.is_empty():
			values.append(argument)
	return ", ".join(values)


func _strip_top_level_assignment(value: String) -> String:
	var round_depth: int = 0
	var square_depth: int = 0
	var curly_depth: int = 0
	var quote: String = ""
	var escaped: bool = false
	for index in range(value.length()):
		var character: String = value.substr(index, 1)
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
			"=":
				if round_depth == 0 and square_depth == 0 and curly_depth == 0:
					return value.substr(0, index)
	return value


func _split_top_level(value: String, delimiter: String) -> Array[String]:
	var parts: Array[String] = []
	var start: int = 0
	var round_depth: int = 0
	var square_depth: int = 0
	var curly_depth: int = 0
	var quote: String = ""
	var escaped: bool = false
	for index in range(value.length()):
		var character: String = value.substr(index, 1)
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
		if (
			character == delimiter
			and round_depth == 0
			and square_depth == 0
			and curly_depth == 0
		):
			parts.append(value.substr(start, index - start))
			start = index + 1
	parts.append(value.substr(start))
	return parts

