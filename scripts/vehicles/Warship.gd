class_name Warship
extends Vehicle
## Эсминец — крупный корабль команды и стратегическая цель (не занимает слот, не возрождается).
## Управляется встроенным ИИ: медленно патрулирует у своей ВМБ; зенитные артиллерийские комплексы (ЗАК)
## ведут огонь с упреждением по вражеской авиации, артустановка — по катерам и наземной технике.
## Уязвим для торпед, крылатых и баллистических ракет, бомб.

const CIWS_RANGE := 1500.0
const CIWS_SPEED := 1100.0
const CIWS_DRAG := 0.0003
const GUN_RANGE := 2800.0
const GUN_SPEED := 700.0
const MISSILE_DEFENSE_RANGE := 1100.0
const MISSILE_KILL_CHANCE := 0.035

var anchor: Vector3 = Vector3.ZERO
var patrol_radius: float = 260.0
var cruise_speed: float = 5.0
var ciws_weapon: Weapon
var gun_weapon: Weapon

var _angle: float = 0.0
var _heading: float = 0.0
var _radar: Node3D = null
var _main_turret: Node3D = null
var _main_pivot: Node3D = null
var _main_muzzle: Node3D = null
var _ciws: Array[Dictionary] = []
var _ciws_target: Vehicle = null
var _missile_threat: Projectile = null
var _gun_target: Vehicle = null
var _think: float = 0.0
var _ciws_index: int = 0


func _init() -> void:
	vehicle_type = "warship"


func _build() -> void:
	max_health = 4000.0
	hit_radius = 14.0
	damage_modifiers = {"bullet": 0.08, "flak": 0.12, "missile": 0.5, "shell": 0.5, "torpedo": 1.4, "cruise": 0.8, "bomb": 0.9, "ballistic": 0.6}
	var parts := VehicleModels.build_destroyer(team)
	model = parts["root"]
	add_child(model)
	_radar = parts["radar"]
	_main_turret = parts["main_turret"]
	_main_pivot = parts["main_pivot"]
	_main_muzzle = parts["main_muzzle"]
	_ciws.assign(parts["ciws"])
	_add_box_collision(Vector3(13.0, 16.0, 112.0), Vector3(0.0, 4.5, -4.0))
	ciws_weapon = Weapon.new("ciws", "ЗАК", -1, 0.06, 2.5, 60)
	gun_weapon = Weapon.new("gun", "АУ 130-мм", -1, 3.5, 6.0, 20)
	weapons = [ciws_weapon, gun_weapon]


func _after_build() -> void:
	if anchor == Vector3.ZERO:
		anchor = global_position
	_angle = atan2(global_position.z - anchor.z, global_position.x - anchor.x)
	_heading = GameDB.yaw_of(-global_basis.z)
	spawn_protection = 0.0


func damage_fx_offset() -> Vector3:
	return Vector3(0.0, 9.0, 8.0)


func _vehicle_physics(delta: float) -> void:
	_angle += delta * cruise_speed / patrol_radius
	var target := anchor + Vector3(cos(_angle), 0.0, sin(_angle)) * patrol_radius
	var to_t := GameDB.flat(target - global_position)
	if to_t.length() > 1.0:
		_heading = lerp_angle(_heading, GameDB.yaw_of(to_t), clampf(delta * 0.35, 0.0, 1.0))
	var fwd := Vector3(-sin(_heading), 0.0, -cos(_heading))
	speed = cruise_speed
	var next := global_position + fwd * speed * delta
	global_transform = Transform3D(Basis(Vector3.UP, _heading), Vector3(next.x, 0.0, next.z))
	velocity = fwd * speed
	if _radar != null:
		_radar.rotate_y(delta * 1.5)


func _handle_weapons(delta: float) -> void:
	_think -= delta
	if _think <= 0.0:
		_think = 0.4
		_select_targets()
	_update_ciws(delta)
	_update_main_gun(delta)


func _select_targets() -> void:
	_ciws_target = null
	_missile_threat = null
	var best_d := CIWS_RANGE
	for v in GlobalBattleManager.enemies_in_radius(team, global_position, CIWS_RANGE, GameDB.Category.AIR):
		var d := global_position.distance_to(v.global_position)
		if d < best_d:
			best_d = d
			_ciws_target = v
	if level != null:
		var best_m := MISSILE_DEFENSE_RANGE
		for p in level.projectiles_root.get_children():
			if not (p is CruiseMissile or p is BallisticMissile):
				continue
			var proj := p as Projectile
			if proj.team == team:
				continue
			var dm := global_position.distance_to(proj.global_position)
			if dm < best_m:
				best_m = dm
				_missile_threat = proj
	_gun_target = null
	best_d = GUN_RANGE
	for v in GlobalBattleManager.enemies_in_radius(team, global_position, GUN_RANGE):
		if v.category == GameDB.Category.AIR:
			continue
		var d := global_position.distance_to(v.global_position) * (0.7 if v.category == GameDB.Category.NAVAL else 1.0)
		if d < best_d and terrain.line_of_sight(global_position + Vector3.UP * 10.0, v.global_position + Vector3.UP * 2.0):
			best_d = d
			_gun_target = v


## ЗАК: приоритет — перехват подлетающих крылатых/баллистических ракет, затем авиация.
func _update_ciws(delta: float) -> void:
	if _ciws_target != null and (not is_instance_valid(_ciws_target) or _ciws_target.is_dead):
		_ciws_target = null
	if _missile_threat != null and not is_instance_valid(_missile_threat):
		_missile_threat = null
	var aim_pos := Vector3.ZERO
	var aim_vel := Vector3.ZERO
	var anti_missile := false
	if _missile_threat != null:
		aim_pos = _missile_threat.global_position
		aim_vel = _missile_threat.velocity
		anti_missile = true
	elif _ciws_target != null:
		aim_pos = _ciws_target.global_position
		aim_vel = _ciws_target.velocity
	else:
		return
	var fired := false
	for i in _ciws.size():
		var entry: Dictionary = _ciws[i]
		var pivot: Node3D = entry["pivot"]
		var base: Node3D = entry["base"]
		var muzzle: Node3D = entry["muzzle"]
		var lead := BallisticSolver.compute_lead(pivot.global_position, velocity, aim_pos, aim_vel, CIWS_SPEED, CIWS_DRAG, GameDB.GRAVITY)
		var local := base.global_basis.inverse() * (lead - base.global_position)
		base.rotation.y = lerp_angle(base.rotation.y, atan2(-local.x, -local.z), clampf(delta * 6.0, 0.0, 1.0))
		var pl := pivot.global_basis.inverse() * (lead - pivot.global_position)
		pivot.rotation.x = clampf(pivot.rotation.x + clampf(atan2(pl.y, Vector2(pl.x, pl.z).length()), -4.0 * delta, 4.0 * delta), deg_to_rad(-5.0), deg_to_rad(85.0))
		var dir := -pivot.global_basis.z
		if not fired and i == _ciws_index and rad_to_deg(dir.angle_to(lead - pivot.global_position)) < 4.0 and ciws_weapon.can_fire():
			ciws_weapon.consume()
			fired = true
			var p := Projectile.new()
			p.velocity = GameDB.spread_direction(dir, 0.5, _rng) * CIWS_SPEED + velocity
			p.drag = CIWS_DRAG
			p.damage = 5.0
			p.damage_type = "flak"
			p.proximity_radius = 3.5
			p.proximity_damage = 6.0
			p.max_lifetime = 1.8
			p.tracer_color = Color(1.0, 0.5, 0.3)
			p.tracer_width = 0.25
			p.setup(team, make_source("ЗАК"), self)
			p.position = muzzle.global_position
			level.spawn_projectile(p)
			if _rng.randf() < 0.5:
				SoundFX.play_3d("mg", p.position, -2.0, 0.8, 30.0)
			if anti_missile and _rng.randf() < MISSILE_KILL_CHANCE:
				_missile_threat.intercept()
				_missile_threat = null
	_ciws_index = (_ciws_index + 1) % maxi(_ciws.size(), 1)


func _update_main_gun(delta: float) -> void:
	if _gun_target != null and (not is_instance_valid(_gun_target) or _gun_target.is_dead):
		_gun_target = null
	if _gun_target == null:
		return
	var from := _main_muzzle.global_position
	var t := from.distance_to(_gun_target.global_position) / GUN_SPEED
	var predicted := _gun_target.global_position + _gun_target.velocity * t
	var dir := BallisticSolver.solve_direction(from, predicted, GUN_SPEED, GameDB.GRAVITY)
	if dir == Vector3.ZERO:
		return
	var local := global_basis.inverse() * dir
	_main_turret.rotation.y = lerp_angle(_main_turret.rotation.y, atan2(-local.x, -local.z), clampf(delta * 1.5, 0.0, 1.0))
	_main_pivot.rotation.x = lerpf(_main_pivot.rotation.x, asin(clampf(dir.y, -1.0, 1.0)), clampf(delta * 2.0, 0.0, 1.0))
	var barrel := -_main_pivot.global_basis.z
	if gun_weapon.can_fire() and rad_to_deg(barrel.angle_to(dir)) < 3.0:
		gun_weapon.consume()
		var p := Projectile.new()
		p.velocity = GameDB.spread_direction(dir, 0.35, _rng) * GUN_SPEED
		p.drag = 0.0
		p.damage = 0.0
		p.damage_type = "shell"
		p.blast_radius = 8.0
		p.blast_damage = 95.0
		p.max_lifetime = 12.0
		p.tracer_color = Color(1.0, 0.9, 0.6)
		p.tracer_width = 0.4
		p.setup(team, make_source("АУ 130-мм"), self)
		p.position = from
		level.spawn_projectile(p)
		Effects.puff(from, Color(1.0, 0.75, 0.4, 1.0), 4.0, 0.15)
		SoundFX.play_3d("cannon", from, 4.0, 0.55, 60.0)


func _on_destroyed() -> void:
	var p := global_position
	Effects.explosion(p + Vector3(0.0, 8.0, 0.0), 30.0, true)
	Effects.explosion(p + get_forward() * 30.0 + Vector3(0.0, 5.0, 0.0), 18.0, true)
	if model != null:
		Effects.spawn_model_wreck(model, true)


func get_hud_lines() -> PackedStringArray:
	return PackedStringArray(["ЭСМИНЕЦ"])
