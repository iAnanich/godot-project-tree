class_name MediaDamageService
extends RefCounted


## Stateless service that demonstrates typed and direct member dependencies.
static func calculate_damage(weapon: MediaWeaponData, critical: bool = false) -> int:
	if weapon == null:
		return 0
	var multiplier: float = weapon.critical_multiplier if critical else 1.0
	return roundi(weapon.base_damage * multiplier)
