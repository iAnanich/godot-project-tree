@tool
extends RefCounted

## Narrow compatibility shims. Optional behavior is capability-checked and
## absence is reported by the caller rather than silently changing semantics.


static func engine_version() -> Dictionary:
	return Engine.get_version_info().duplicate(true)


static func engine_version_string() -> String:
	var info = engine_version()
	if info.has("string"):
		return str(info["string"])
	return "%s.%s.%s" % [info.get("major", 4), info.get("minor", 0), info.get("patch", 0)]


static func call_optional(
	target: Object, method_name: StringName, arguments: Array = []
) -> Variant:
	if target == null or not is_instance_valid(target) or not target.has_method(method_name):
		return null
	return target.callv(method_name, arguments)


static func script_global_name(script: Script) -> String:
	var value = call_optional(script, &"get_global_name")
	return "" if value == null else str(value)


static func script_base_script(script: Script) -> Script:
	var value = call_optional(script, &"get_base_script")
	return value as Script


static func script_native_base(script: Script) -> String:
	var value = call_optional(script, &"get_instance_base_type")
	return "" if value == null else str(value)


static func arrange_graph(graph_edit: GraphEdit) -> bool:
	if graph_edit != null and graph_edit.has_method("arrange_nodes"):
		graph_edit.call("arrange_nodes")
		return true
	return false
