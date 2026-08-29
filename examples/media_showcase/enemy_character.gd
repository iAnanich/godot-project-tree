class_name MediaEnemyCharacter
extends MediaBaseCharacter

## Path-based inheritance with local gameplay metadata.
@export_range(0, 100, 1) var armor: int = 4
@export var preferred_target_path: NodePath


func choose_action() -> StringName:
	return &"attack" if not is_defeated() else &"wait"


func reduce_damage(incoming_damage: int) -> int:
	return maxi(0, incoming_damage - armor)
