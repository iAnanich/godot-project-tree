class_name ShowcaseBattleHud
extends CanvasLayer

## UI class with a dependency on the controller script.
@export var status_label_path: NodePath
var controller_script: Script = preload("res://examples/showcase/controllers/battle_controller.gd")


func controller_type_name() -> String:
	return str(controller_script)
