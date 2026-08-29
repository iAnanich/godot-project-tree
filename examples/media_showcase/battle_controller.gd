class_name MediaBattleController
extends Node

## Scene-attached coordinator with typed class and literal script dependencies.
signal battle_started(player: MediaPlayerCharacter, enemy: MediaEnemyCharacter)
signal round_completed(round_index: int)

@export var player: MediaPlayerCharacter
@export var enemy: MediaEnemyCharacter
var round_index: int = 0
var weapon_resource_script: Script = load("res://examples/media_showcase/weapon_data.gd")


func start_battle() -> void:
	round_index = 1
	battle_started.emit(player, enemy)


func run_player_turn() -> int:
	if player == null or enemy == null:
		return 0
	var dealt: int = player.perform_attack(enemy)
	round_completed.emit(round_index)
	round_index += 1
	return dealt
