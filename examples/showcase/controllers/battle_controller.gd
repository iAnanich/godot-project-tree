class_name ShowcaseBattleController
extends Node

## Coordinates two actors and exposes typed script relationships.
signal battle_started
signal battle_finished(winner: ShowcaseBaseActor)

@export var player_path: NodePath
@export var enemy_path: NodePath
var turn_index: int = 0


func start_battle() -> void:
	turn_index = 0
	battle_started.emit()


func finish_battle(winner: ShowcaseBaseActor) -> void:
	battle_finished.emit(winner)
