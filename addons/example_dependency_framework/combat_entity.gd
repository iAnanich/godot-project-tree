class_name ShowcaseCombatEntity
extends Node

## Minimal third-party-style add-on base used by the showcase project.
signal health_changed(current: int, maximum: int)
signal defeated

@export var maximum_health: int = 100
var current_health: int = 100


func receive_damage(amount: int) -> void:
	current_health = maxi(0, current_health - maxi(amount, 0))
	health_changed.emit(current_health, maximum_health)
	if current_health == 0:
		defeated.emit()


func is_alive() -> bool:
	return current_health > 0
