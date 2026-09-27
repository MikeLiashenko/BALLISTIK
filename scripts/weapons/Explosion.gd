class_name Explosion
extends Area3D
## Взрыв с зоной поражения (blast_radius): Area3D со сферической формой. Через два физических шага
## (когда движок обновит пересечения) урон наносится всем технике и сооружениям внутри сферы
## с затуханием к краю. Здания и корабли получают повышенный урон (structure_multiplier).

var radius: float = 10.0
var damage: float = 100.0
var damage_type: String = "explosive"
var team: int = -1
var source: Dictionary = {}
var structure_multiplier: float = 1.0
var _frames: int = 0


static func spawn(pos: Vector3, p_radius: float, p_damage: float, p_type: String, p_team: int, p_source: Dictionary, p_structure_mult: float = 1.0, over_water: bool = false, visual: bool = true) -> Explosion:
	var parent := GlobalBattleManager.get_fx_parent()
	if parent == null:
		return null
	var e := Explosion.new()
	e.name = "BlastArea"
	e.radius = maxf(p_radius, 0.5)
	e.damage = p_damage
	e.damage_type = p_type
	e.team = p_team
	e.source = p_source
	e.structure_multiplier = p_structure_mult
	e.position = pos
	parent.add_child(e)
	if visual:
		Effects.explosion(pos, p_radius, over_water)
	return e


func _ready() -> void:
	collision_layer = 0
	collision_mask = GameDB.MASK_DAMAGEABLE
	monitoring = true
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	add_child(shape)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < 2:
		return
	_apply_damage()
	set_physics_process(false)
	queue_free()


func _apply_damage() -> void:
	for body in get_overlapping_bodies():
		if not body.has_method("apply_damage"):
			continue
		var body_team := int(body.call("get_team")) if body.has_method("get_team") else -1
		if team >= 0 and body_team == team:
			continue
		var hit_radius := float(body.call("get_hit_radius")) if body.has_method("get_hit_radius") else 2.0
		var dist := maxf(global_position.distance_to(body.global_position) - hit_radius, 0.0)
		var k := clampf(1.0 - dist / radius, 0.0, 1.0)
		if k <= 0.0:
			continue
		var dmg := damage * lerpf(0.2, 1.0, k * k)
		if body is Building or body is Warship:
			dmg *= structure_multiplier
		body.call("apply_damage", dmg, damage_type, source)
