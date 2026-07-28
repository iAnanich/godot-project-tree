class_name FixtureChild
extends FixtureBase

signal child_changed

@export var title: String = "Child"

var helper_script = load("res://tests/fixtures/helper.gd")


func child_method() -> void:
	var helper = helper_script.new()
	helper.touch()
