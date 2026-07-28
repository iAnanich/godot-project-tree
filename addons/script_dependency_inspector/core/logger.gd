@tool
extends RefCounted

signal entry_added(entry: Dictionary)

const LEVEL_DEBUG := "debug"
const LEVEL_INFO := "info"
const LEVEL_WARNING := "warning"
const LEVEL_ERROR := "error"

var entries: Array = []
var minimum_level: String = LEVEL_INFO


## Records a debug entry; console output depends on minimum_level.
func debug(message: String, context: Dictionary = {}) -> void:
	_record(LEVEL_DEBUG, message, context)


## Records and prints an informational entry.
func info(message: String, context: Dictionary = {}) -> void:
	_record(LEVEL_INFO, message, context)


## Records a warning entry and forwards it to Godot's warning channel.
func warning(message: String, context: Dictionary = {}) -> void:
	_record(LEVEL_WARNING, message, context)


## Records an error entry and forwards it to Godot's error channel.
func error(message: String, context: Dictionary = {}) -> void:
	_record(LEVEL_ERROR, message, context)


## Removes retained entries without disconnecting listeners.
func clear() -> void:
	entries.clear()


func _record(level: String, message: String, context: Dictionary) -> void:
	var entry = {
		"level": level,
		"message": message,
		"context": context.duplicate(true),
	}
	entries.append(entry)
	entry_added.emit(entry)

	var rendered = "[ScriptDependencyInspector][%s] %s" % [level.to_upper(), message]
	if not context.is_empty():
		rendered += " | " + JSON.stringify(context)
	match level:
		LEVEL_ERROR:
			push_error(rendered)
		LEVEL_WARNING:
			push_warning(rendered)
		LEVEL_DEBUG:
			if minimum_level == LEVEL_DEBUG:
				print(rendered)
		_:
			print(rendered)
