class_name ShowcaseTargetingService
extends RefCounted

## Demonstrates dependencies that exist only through type annotations.
static func choose_target(candidates: Array[ShowcaseBaseActor]) -> ShowcaseBaseActor:
	return candidates.front() if not candidates.is_empty() else null
