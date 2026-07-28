class_name ShowcaseDamageService
extends RefCounted


## Stateless service demonstrating static members in exported diagrams.
static func calculate_damage(profile: ShowcaseWeaponProfile, critical: bool = false) -> int:
	if profile == null:
		return 0
	var multiplier: float = profile.critical_multiplier if critical else 1.0
	return roundi(profile.base_damage * multiplier)
