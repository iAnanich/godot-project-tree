class_name MediaBaseCharacter
extends Node

## Small release-media fixture used to demonstrate readable dependency graphs.
signal health_changed(current: int, maximum: int)
signal defeated

@export var display_name: String = "Character"
@export_range(1, 500, 1) var maximum_health: int = 100
var current_health: int = 100


func take_damage(amount: int) -> void:
	current_health = maxi(0, current_health - maxi(0, amount))
	health_changed.emit(current_health, maximum_health)
	if current_health == 0:
		defeated.emit()


func is_defeated() -> bool:
	return current_health <= 0


class TurnState:
	var action_points: int = 2
	var guarded: bool = false
