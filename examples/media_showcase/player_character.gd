class_name MediaPlayerCharacter
extends MediaBaseCharacter

## Player node with every supported member category represented.
@export var weapon: MediaWeaponData
@export var critical_chance: float = 0.15
var damage_service_script: Script = preload("res://examples/media_showcase/damage_service.gd")


func perform_attack(target: MediaEnemyCharacter, critical: bool = false) -> int:
	var damage: int = MediaDamageService.calculate_damage(weapon, critical)
	target.take_damage(damage)
	return damage


func preview_damage() -> int:
	return MediaDamageService.calculate_damage(weapon, false)
