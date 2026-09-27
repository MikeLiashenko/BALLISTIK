class_name PatrolBoat
extends Vehicle
## Бронекатер (Sea Baby / G-5). Высокая манёвренность на воде: корпус всегда на уровне моря (Y = 0),
## занос при поворотах, крен внутрь поворота и подъём носа на глиссировании (визуально).
## Вооружение: дистанционный пулемётный модуль, торпеды против крупных кораблей и баллистическая
## ракета для удара по тактической метке на суше или воде.

const MG_SPEED := 850.0
const MG_DRAG := 0.0006

var max_speed_fwd: float = 28.0
var max_speed_rev: float = 7.0
var accel: float = 7.5
var turn_rate: float = 1.25
var heading: float = 0.0
var turret_yaw: float = 0.0
var gun_pitch: float = 0.0
var mg: Weapon
var torpedoes: Weapon
var ballistic: Weapon

var _drift: Vector3 = Vector3.ZERO
var _roll: float = 0.0
var _bob_time: float = 0.0
var _hull: Node3D = null
var _turret: Node3D = null
var _gun_pivot: Node3D = null
var _muzzle: Node3D = null
var _flash: MeshInstance3D = null
var _flash_timer: float = 0.0
var _torpedo_points: Array[Node3D] = []
var _ballistic_point: Node3D = null
var _wake: GPUParticles3D = null
var _next_tube: int = 0


func _init() -> void:
	vehicle_type = "boat"


func _build() -> void:
	max_health = 140.0
	hit_radius = 6.0
	damage_modifiers = {"bullet": 0.8, "flak": 0.9}
	var parts := VehicleModels.build_boat(team)
	model = parts["root"]
	add_child(model)
	_hull = parts["hull"]
	_turret = parts["turret"]
	_gun_pivot = parts["gun_pivot"]
	_muzzle = parts["muzzle"]
	_torpedo_points.assign(parts["torpedo_points"])
	_ballistic_point = parts["ballistic_point"]
	var wake_point: Node3D = parts["wake_point"]
	var length: float = parts["length"]
	_flash = Effects.create_muzzle_flash(0.8)
	_muzzle.add_child(_flash)
	_wake = Effects.create_wake()
	wake_point.add_child(_wake)
	_add_box_collision(Vector3(3.8, 3.8, length + 4.5), Vector3(0.0, 0.3, -1.0))
	mg = Weapon.new("mg", "12,7-мм пулемёт", -1, 0.085, 3.5, 100)
	torpedoes = Weapon.new("torpedo", "Торпеды 533-мм", 2, 1.2, 16.0)
	ballistic = Weapon.new("ballistic", "Баллистическая ракета", 1, 1.0, 45.0)
	weapons = [mg, torpedoes, ballistic]


func _after_build() -> void:
	heading = GameDB.yaw_of(-global_basis.z)
	global_position = Vector3(global_position.x, 0.0, global_position.z)
	spawn_protection = 3.0


func _engine_sound_key() -> String:
	return "engine_boat"


func _engine_pitch() -> float:
	return 0.75 + absf(speed) / max_speed_fwd * 0.6


func damage_fx_offset() -> Vector3:
	return Vector3(0.0, 1.8, 2.0)


func camera_offset() -> Vector2:
	return Vector2(15.0, 4.5)


func _vehicle_physics(delta: float) -> void:
	if terrain == null:
		return
	var c := controls
	var target_speed := c.throttle * (max_speed_fwd if c.throttle >= 0.0 else max_speed_rev)
	speed = move_toward(speed, target_speed, accel * delta)
	var turn_eff := clampf(absf(speed) / 9.0, 0.25, 1.0)
	var steer := c.steer if speed >= -0.5 else -c.steer
	heading = wrapf(heading - steer * turn_rate * turn_eff * delta, -PI, PI)
	var fwd := Vector3(-sin(heading), 0.0, -cos(heading))
	_drift = _drift.lerp(fwd * speed, clampf(delta * 2.2, 0.0, 1.0))
	var pos := global_position
	var next := pos + _drift * delta
	next.y = 0.0
	if not terrain.is_navigable(next.x, next.z, 5.0):
		_drift = -_drift * 0.25
		speed *= -0.2
		next = Vector3(pos.x, 0.0, pos.z)
	global_transform = Transform3D(Basis(Vector3.UP, heading), next)
	velocity = _drift
	_bob_time += delta
	var planing := clampf(absf(speed) / max_speed_fwd, 0.0, 1.0)
	_roll = lerpf(_roll, -steer * planing * 0.22, clampf(delta * 3.0, 0.0, 1.0))
	_hull.rotation = Vector3(planing * 0.07 + sin(_bob_time * 1.7) * 0.02, 0.0, _roll + sin(_bob_time * 1.3) * 0.03)
	_hull.position = Vector3(0.0, sin(_bob_time * 2.1) * 0.12 + planing * 0.25, 0.0)
	_wake.emitting = absf(speed) > 3.0
	_update_gun(delta)


func _update_gun(delta: float) -> void:
	if controls.has_aim:
		var local := _hull.global_basis.inverse() * (controls.aim_point - _gun_pivot.global_position)
		var desired_yaw := atan2(-local.x, -local.z)
		var desired_pitch := clampf(atan2(local.y, Vector2(local.x, local.z).length()), deg_to_rad(-10.0), deg_to_rad(70.0))
		turret_yaw = wrapf(turret_yaw + clampf(wrapf(desired_yaw - turret_yaw, -PI, PI), -3.0 * delta, 3.0 * delta), -PI, PI)
		gun_pitch += clampf(desired_pitch - gun_pitch, -2.0 * delta, 2.0 * delta)
	_turret.rotation = Vector3(0.0, turret_yaw, 0.0)
	_gun_pivot.rotation = Vector3(gun_pitch, 0.0, 0.0)


func gun_direction() -> Vector3:
	return -_gun_pivot.global_basis.z


func gun_origin() -> Vector3:
	return _gun_pivot.global_position


func _handle_weapons(delta: float) -> void:
	if controls.fire_primary and mg.can_fire():
		mg.consume()
		_fire_mg()
	if controls.fire_secondary and torpedoes.can_fire():
		torpedoes.consume()
		_launch_torpedo()
	if controls.fire_special and ballistic.can_fire():
		_try_ballistic(controls.special_target)
	_flash_timer -= delta
	_flash.visible = _flash_timer > 0.0
	hud_hint = "БАЛЛИСТИКА: ГОТОВА (G — тактическая карта)" if ballistic.can_fire() else "БАЛЛИСТИКА: ПЕРЕЗАРЯДКА %d%%" % int(ballistic.get_ready_ratio() * 100.0)


func _fire_mg() -> void:
	var dir := GameDB.spread_direction(gun_direction(), 0.45, _rng)
	var p := Projectile.new()
	p.velocity = dir * MG_SPEED + velocity
	p.drag = MG_DRAG
	p.damage = 6.0
	p.damage_type = "bullet"
	p.max_lifetime = 2.2
	p.tracer_color = Color(0.55, 1.0, 0.5)
	p.tracer_width = 0.2
	p.setup(team, make_source("Пулемёт"), self)
	p.position = _muzzle.global_position
	level.spawn_projectile(p)
	_flash_timer = 0.04
	SoundFX.play_3d("mg", p.position, -4.0, 1.0, 22.0)


func _launch_torpedo() -> void:
	var tp := _torpedo_points[_next_tube]
	_next_tube = (_next_tube + 1) % _torpedo_points.size()
	var t := Torpedo.new()
	t.velocity = get_forward() * 20.0
	t.position = tp.global_position
	t.setup(team, make_source("Торпеда"), self)
	level.spawn_projectile(t)


## Проверка дальности баллистического удара по точке.
func can_strike(point: Vector3) -> bool:
	var d := GameDB.flat_distance(global_position, point)
	return d >= BallisticMissile.MIN_RANGE and d <= BallisticMissile.MAX_RANGE


func _try_ballistic(point: Vector3) -> void:
	var from := _ballistic_point.global_position
	var v0 := BallisticMissile.solve(from, point)
	if v0 == Vector3.ZERO:
		return
	ballistic.consume()
	var m := BallisticMissile.new()
	m.target_point = point
	m.velocity = v0
	m.position = from
	m.setup(team, make_source("Баллистическая ракета"), self)
	level.spawn_projectile(m)


func get_special_range() -> Vector2:
	return Vector2(BallisticMissile.MIN_RANGE, BallisticMissile.MAX_RANGE)


func get_special_origin() -> Vector3:
	return _ballistic_point.global_position


func special_ready() -> bool:
	return ballistic.can_fire()


func _on_destroyed() -> void:
	Effects.explosion(global_position + Vector3(0.0, 1.0, 0.0), 12.0, true)
	if model != null:
		Effects.spawn_model_wreck(model, true)
