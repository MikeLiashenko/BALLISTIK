class_name NavalModels
extends RefCounted
## Процедурные модели катеров и кораблей.

const PAINT := {}


static func has_model(type_id: String) -> bool:
	return PAINT.has(type_id)


static func build(_type_id: String, _team: int) -> Dictionary:
	return {}
