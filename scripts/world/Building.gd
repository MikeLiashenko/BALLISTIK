class_name Building
extends StaticBody3D
## Разрушаемое сооружение: ангар, КДП, РЛС, топливный резервуар, штаб, бункер, маяк, склад, дом,
## нефтяная платформа. Имеет прочность и принадлежность команде (или нейтральное), получает урон
## от взрывов (зоны поражения Explosion) и попаданий, при разрушении превращается в горящие руины
## и приносит очки команде атакующего.

signal destroyed(building: Building, killer: Dictionary)

var kind: String = "house"
var team: int = -1
var variant: int = 0
var display_name: String = "Сооружение"
var max_health: float = 500.0
var health: float = 500.0
var score_value: int = 0
var is_dead: bool = false
var size: Vector3 = Vector3(10.0, 8.0, 10.0)
var footprint_radius: float = 7.0
var hit_radius: float = 6.0
var explodes_on_death: bool = false
var damage_modifiers: Dictionary = {"bullet": 0.15, "flak": 0.2, "missile": 0.7}

var _model: Node3D = null
var _spin: Node3D = null
var _fire: Node3D = null
var _damage_stage: int = 0


func setup(p_kind: String, p_team: int, p_variant: int = 0) -> Building:
	kind = p_kind
	team = p_team
	variant = p_variant
	var info := StructureModels.info(kind)
	display_name = str(info["name"])
	max_health = float(info["hp"])
	score_value = int(info["score"])
	size = info["size"]
	explodes_on_death = kind == "fuel"
	return self


func _ready() -> void:
	collision_layer = GameDB.LAYER_STRUCTURES
	collision_mask = 0
	health = max_health
	footprint_radius = Vector2(size.x, size.z).length() * 0.5
	hit_radius = minf(size.x, size.z) * 0.5
	var parts := StructureModels.build(kind, team, variant)
	_model = parts["root"]
	_spin = parts["spin"]
	add_child(_model)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = Vector3(0.0, size.y * 0.5 - (20.0 if kind == "oil_rig" else 0.0), 0.0)
	if kind == "oil_rig":
		box.size = Vector3(size.x, size.y + 20.0, size.z)
		cs.position = Vector3(0.0, (size.y - 20.0) * 0.5, 0.0)
	add_child(cs)
	GlobalBattleManager.register_structure(self)


func _exit_tree() -> void:
	GlobalBattleManager.unregister_structure(self)


func _physics_process(delta: float) -> void:
	if _spin != null and not is_dead:
		_spin.rotate_y(delta * (1.2 if kind == "radar" else 0.6))


func get_team() -> int:
	return team


func get_hit_radius() -> float:
	return hit_radius


func apply_damage(amount: float, damage_type: String, source: Dictionary) -> void:
	if is_dead or amount <= 0.0:
		return
	var src_team := int(source.get("team", -1))
	if team >= 0 and src_team == team:
		return
	var dmg := amount * float(damage_modifiers.get(damage_type, 1.0))
	health -= dmg
	GlobalBattleManager.report_damage(self, dmg, source)
	_update_damage_fx()
	if health <= 0.0:
		_destroy(source)


func _update_damage_fx() -> void:
	var ratio := health / max_health
	var stage := 2 if ratio < 0.3 else (1 if ratio < 0.65 else 0)
	if stage <= _damage_stage:
		return
	_damage_stage = stage
	if _fire != null and is_instance_valid(_fire):
		_fire.queue_free()
	_fire = Effects.create_fire() if stage == 2 else Effects.create_smoke()
	_fire.position = Vector3(0.0, size.y * 0.8, 0.0)
	add_child(_fire)


func _destroy(killer: Dictionary) -> void:
	is_dead = true
	health = 0.0
	collision_layer = 0
	var center := global_position + Vector3(0.0, size.y * 0.4, 0.0)
	if explodes_on_death:
		Explosion.spawn(center, 32.0, 160.0, "explosive", -1, killer, 1.0, false)
	else:
		Effects.explosion(center, clampf(footprint_radius, 8.0, 26.0), kind == "oil_rig")
	if _model != null:
		_model.queue_free()
		_model = null
	_spin = null
	var rubble := StructureModels.build_rubble(size, get_instance_id())
	add_child(rubble)
	if _fire != null and is_instance_valid(_fire):
		_fire.queue_free()
	_fire = Effects.create_fire()
	_fire.position = Vector3(0.0, 2.0, 0.0)
	add_child(_fire)
	var fire_ref := _fire
	get_tree().create_timer(35.0, false).timeout.connect(func() -> void:
		if is_instance_valid(fire_ref):
			fire_ref.queue_free()
	)
	destroyed.emit(self, killer)
	GlobalBattleManager.report_structure_destroyed(self, killer)
