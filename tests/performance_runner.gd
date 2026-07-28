extends SceneTree

const ADDON_ROOT: String = "res://addons/script_dependency_inspector/"
const ANALYZER_PATH: String = ADDON_ROOT + "core/gdscript_analyzer.gd"
const BUILDER_PATH: String = ADDON_ROOT + "core/graph_builder.gd"
const ANALYZER_METHOD_COUNT: int = 500
const GRAPH_SCRIPT_COUNT: int = 1000
const ANALYZER_BUDGET_MSEC: float = 5000.0
const GRAPH_BUDGET_MSEC: float = 6000.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var analyzer = _new_instance(ANALYZER_PATH)
	var builder = _new_instance(BUILDER_PATH)
	if analyzer == null or builder == null:
		quit(1)
		return

	var source_lines: Array[String] = ["extends RefCounted", "class_name PerformanceFixture"]
	for index in range(ANALYZER_METHOD_COUNT):
		source_lines.append("func method_%s(value: PerformanceFixture) -> PerformanceFixture:" % index)
		source_lines.append("    return value")
	var analyzer_start: int = Time.get_ticks_usec()
	var analysis: Dictionary = analyzer.analyze("\n".join(source_lines), "res://performance_fixture.gd")
	var analyzer_msec: float = float(Time.get_ticks_usec() - analyzer_start) / 1000.0
	if analysis.get("methods", []).size() != ANALYZER_METHOD_COUNT:
		push_error("Performance fixture analyzer result is incomplete.")
		quit(1)
		return

	var scripts: Array = []
	for index in range(GRAPH_SCRIPT_COUNT):
		var path: String = "res://synthetic/class_%04d.gd" % index
		var direct_base: Dictionary = {"kind": "native", "value": "RefCounted", "display": "RefCounted"}
		if index > 0:
			direct_base = {
				"kind": "script",
				"value": "res://synthetic/class_%04d.gd" % (index - 1),
				"display": "Synthetic%04d" % (index - 1),
			}
		scripts.append(
			{
				"id": path,
				"path": path,
				"name": "Synthetic%04d" % index,
				"class_name": "Synthetic%04d" % index,
				"is_addon": false,
				"analysis": {
					"methods": [],
					"signals": [],
					"properties": [],
					"inner_classes": [],
					"resource_dependencies": [],
					"resource_dependency_details": [],
					"type_references": [],
					"type_reference_details": [],
					"member_accesses": [],
				},
				"reflection": {},
				"direct_base": direct_base,
			}
		)
	var scan_result: Dictionary = {
		"root_path": "res://synthetic",
		"scripts": scripts,
		"warnings": [],
		"errors": [],
		"diagnostics": [],
		"engine_version": Engine.get_version_info().get("string", "unknown"),
	}
	var graph_start: int = Time.get_ticks_usec()
	var snapshot: Dictionary = builder.build(scan_result, {"include_native_bases": true})
	var graph_msec: float = float(Time.get_ticks_usec() - graph_start) / 1000.0
	if snapshot.get("nodes", []).size() != GRAPH_SCRIPT_COUNT + 2:
		push_error("Performance fixture graph result is incomplete.")
		quit(1)
		return

	var report: Dictionary = {
		"engine": Engine.get_version_info().get("string", "unknown"),
		"analyzer_methods": ANALYZER_METHOD_COUNT,
		"analyzer_msec": snappedf(analyzer_msec, 0.01),
		"analyzer_budget_msec": ANALYZER_BUDGET_MSEC,
		"graph_scripts": GRAPH_SCRIPT_COUNT,
		"graph_nodes": snapshot.get("nodes", []).size(),
		"graph_edges": snapshot.get("edges", []).size(),
		"graph_msec": snappedf(graph_msec, 0.01),
		"graph_budget_msec": GRAPH_BUDGET_MSEC,
	}
	print("SDI_PERFORMANCE " + JSON.stringify(report))
	if analyzer_msec > ANALYZER_BUDGET_MSEC or graph_msec > GRAPH_BUDGET_MSEC:
		push_error("Performance budget exceeded: %s" % JSON.stringify(report))
		quit(1)
		return
	quit(0)


func _new_instance(path: String):
	var resource: Resource = ResourceLoader.load(path)
	if resource == null or not resource is Script:
		push_error("Could not load performance dependency: %s" % path)
		return null
	return (resource as Script).new()
