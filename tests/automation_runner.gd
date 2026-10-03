extends SceneTree

const DOCK_SCENE_PATH: String = "res://addons/script_dependency_inspector/ui/dependency_dock.tscn"
const OUTPUT_ROOT: String = "user://script_dependency_inspector/automation"

var _failures: Array[String] = []


class RejectingValidator:
	extends RefCounted

	func validate(_snapshot: Dictionary) -> Dictionary:
		return {
			"ok": false,
			"errors":
			[
				{
					"code": "forced_validation_failure",
					"message": "Forced validation failure for stale-snapshot lifecycle coverage.",
					"context": {"fixture": "automation_runner"},
				}
			],
			"warnings": [],
		}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var resource: Resource = ResourceLoader.load(DOCK_SCENE_PATH)
	if resource == null or not resource is PackedScene:
		_failures.append("Could not load dependency dock scene.")
		_finish()
		return
	var dock: Control = (resource as PackedScene).instantiate()
	root.add_child(dock)
	await process_frame
	var auto_rescan: CheckBox = dock.get_node("%AutoRescan")
	var delay: SpinBox = dock.get_node("%AutoRescanDelay")
	var json_check: CheckBox = dock.get_node("%AutoExportJson")
	var mermaid_check: CheckBox = dock.get_node("%AutoExportMermaid")
	var plantuml_check: CheckBox = dock.get_node("%AutoExportPlantUML")
	var json_path: LineEdit = dock.get_node("%AutoExportJsonPath")
	var mermaid_path: LineEdit = dock.get_node("%AutoExportMermaidPath")
	var plantuml_path: LineEdit = dock.get_node("%AutoExportPlantUMLPath")
	var timer: Timer = dock.get_node("%AutoRescanTimer")
	var status: Label = dock.get_node("%StatusLabel")
	var export_button: Button = dock.get_node("%ExportButton")
	var sync_on_changes: CheckBox = dock.get_node("%SyncOnEditorChanges")
	var sync_debounce: SpinBox = dock.get_node("%EditorSyncDebounce")
	var follow_active: CheckBox = dock.get_node("%FollowActiveScript")
	var editor_timer: Timer = dock.get_node("%EditorChangeTimer")
	var mode_indicator: Label = dock.get_node("%ScanModeIndicator")

	_check(
		sync_on_changes.button_pressed, "Editor-change synchronization must be enabled by default."
	)
	_check(
		mode_indicator.text == "Save sync",
		"Toolbar scan mode must show the default save-synchronized trigger."
	)
	_check(follow_active.button_pressed, "Active-script following must be enabled by default.")
	_check(not auto_rescan.button_pressed, "Timed rescanning must remain disabled by default.")
	dock.set("_ignore_filesystem_events_until_msec", Time.get_ticks_msec() + 10000)
	editor_timer.stop()
	dock.call("_on_editor_filesystem_changed")
	_check(
		editor_timer.is_stopped(),
		"Filesystem events caused by the add-on's own exports must be suppressed."
	)
	dock.set("_ignore_filesystem_events_until_msec", 0)
	dock.set("_scan_in_progress", true)
	dock.call("_on_editor_filesystem_changed")
	_check(
		bool(dock.get("_editor_change_pending")) and editor_timer.is_stopped(),
		"Editor changes received during a scan must queue one follow-up instead of overlapping."
	)
	dock.set("_scan_in_progress", false)
	dock.set("_editor_change_pending", false)
	sync_debounce.value = 0.5
	dock.call("_on_editor_filesystem_changed")
	_check(
		not editor_timer.is_stopped(), "An editor filesystem change must start the debounce timer."
	)
	_check(
		is_equal_approx(editor_timer.wait_time, 0.5),
		"Editor synchronization must use the configured quiet period."
	)
	editor_timer.stop()

	_check(
		not bool(dock.call("_automatic_exports_touch_resource_filesystem")),
		"Scans without enabled automatic exports must not open a filesystem-event suppression window."
	)
	json_check.button_pressed = true
	json_path.text = OUTPUT_ROOT + "/suppression-check.json"
	_check(
		not bool(dock.call("_automatic_exports_touch_resource_filesystem")),
		"Automatic exports below user:// must not suppress project filesystem events."
	)
	json_path.text = "res://script_dependency_exports/suppression-check.json"
	_check(
		bool(dock.call("_automatic_exports_touch_resource_filesystem")),
		"Enabled automatic exports below res:// must activate loop suppression."
	)
	json_check.button_pressed = false

	auto_rescan.button_pressed = true
	delay.value = 5.0
	dock.call("_update_refresh_schedules")
	_check(
		mode_indicator.text == "Save + timed",
		"Toolbar scan mode must show both enabled automatic triggers."
	)
	json_check.button_pressed = true
	mermaid_check.button_pressed = true
	plantuml_check.button_pressed = true
	json_path.text = OUTPUT_ROOT + "/graph.json"
	mermaid_path.text = OUTPUT_ROOT + "/graph.mmd"
	plantuml_path.text = OUTPUT_ROOT + "/graph.puml"
	dock.call("scan_project")

	_check(FileAccess.file_exists(json_path.text), "Automatic JSON export was not written.")
	_check(FileAccess.file_exists(mermaid_path.text), "Automatic Mermaid export was not written.")
	_check(FileAccess.file_exists(plantuml_path.text), "Automatic PlantUML export was not written.")
	_check(
		JSON.parse_string(FileAccess.get_file_as_string(json_path.text)) is Dictionary,
		"Automatic JSON export is not valid JSON."
	)
	_check(
		FileAccess.get_file_as_string(mermaid_path.text).begins_with("classDiagram"),
		"Automatic Mermaid export is not a class diagram."
	)
	_check(
		FileAccess.get_file_as_string(plantuml_path.text).contains("@startuml"),
		"Automatic PlantUML export is missing its start marker."
	)
	_check(timer.one_shot, "Auto-rescan timer must be one-shot.")
	_check(
		not timer.is_stopped(), "Auto-rescan timer must restart after scan and exports complete."
	)
	_check(
		is_equal_approx(timer.wait_time, 5.0), "Auto-rescan timer must use the configured delay."
	)
	_check(
		status.text.contains("auto-exported JSON, Mermaid, PlantUML"),
		"Scan status must report completed automatic exports."
	)
	auto_rescan.button_pressed = false
	timer.stop()

	# A validator object can become invalid after an editor script hot reload.
	# Root switching must recover the service rather than surface validator_unavailable.
	dock.set("_snapshot_validator", null)
	dock.call("_set_scan_root", "res://tests/contract_fixtures/hidden_member_scope")
	_check(
		str(dock.get("_snapshot_state")) == "current",
		"A root switch must recover an unavailable validator and publish the valid candidate.",
	)
	_check(
		not status.text.contains("validator_unavailable"),
		"A recoverable validator lifecycle loss must not surface validator_unavailable.",
	)

	# The export boundary has the same hot-reload recovery obligation.
	var export_service = dock.get("_export_service")
	export_service.set("_validator", null)
	var export_recovery: Dictionary = export_service.call(
		"export_to_string", "json", dock.get("_snapshot"), {}
	)
	_check(
		export_recovery.get("ok", false),
		"Export validation must recover its validator service after a lifecycle loss.",
	)

	# OPEN-001: a fatal rescan preserves the last valid snapshot for inspection,
	# labels it stale, and blocks all export until a later successful scan.
	mermaid_check.button_pressed = false
	plantuml_check.button_pressed = false
	json_check.button_pressed = true
	json_path.text = OUTPUT_ROOT + "/stale-must-not-export.json"
	if FileAccess.file_exists(json_path.text):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(json_path.text))
	var previous_snapshot_text: String = JSON.stringify(dock.get("_snapshot"))
	var previous_success_at: String = str(dock.get("_last_successful_scan_at"))
	dock.set("_snapshot_validator", RejectingValidator.new())
	dock.call("_set_scan_root", "res://tests/contract_fixtures/hidden_member_scope/feature")
	_check(
		str(dock.get("_snapshot_state")) == "stale",
		"A fatal rescan must mark the retained snapshot stale.",
	)
	_check(
		JSON.stringify(dock.get("_snapshot")) == previous_snapshot_text,
		"A fatal rescan must preserve the exact last valid snapshot for inspection.",
	)
	_check(
		(
			str(dock.get("_last_successful_scan_at")) == previous_success_at
			and not previous_success_at.is_empty()
		),
		"A stale snapshot must retain the last-successful-scan timestamp.",
	)
	_check(
		status.text.begins_with("STALE"),
		"The visible scan status must identify retained data as stale.",
	)
	_check(
		status.text.contains("forced_validation_failure"),
		"The stale-state status must expose the failed-scan reason.",
	)
	_check(
		(dock.get_node("%SummaryView") as RichTextLabel).text.contains("STALE SNAPSHOT"),
		"The non-visual summary must identify the retained snapshot as stale.",
	)
	_check(
		export_button.disabled,
		"Manual export must remain disabled while the retained snapshot is stale.",
	)
	_check(
		not FileAccess.file_exists(json_path.text),
		"Automatic export must not run from a stale retained snapshot.",
	)

	# A later successful scan clears stale state and can export the new current result.
	dock.set("_snapshot_validator", null)
	dock.call("scan_project")
	_check(
		str(dock.get("_snapshot_state")) == "current",
		"A successful rescan must clear stale snapshot state.",
	)
	_check(
		status.text.begins_with("Current"),
		"A successful rescan must be presented as the current result.",
	)
	_check(
		FileAccess.file_exists(json_path.text),
		"Automatic export may resume only after a successful rescan publishes a current snapshot.",
	)

	dock.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Script Dependency Inspector automation tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
