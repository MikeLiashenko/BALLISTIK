class_name GroundVehicle
extends Vehicle
## Наземная техника: движение только по суше (вода, крутые склоны, здания и границы карты
## непроходимы), наклон корпуса по нормали рельефа, башня с наведением по азимуту и углу места
## на точку прицеливания (VehicleControls.aim_point).

var max_forward_speed: float = 15.0
var max_reverse_speed: float = 6.0
var acceleration: float = 6.0
var turn_rate: float = 1.0
var turret_yaw_rate: float = 2.0
var gun_pitch_rate: float = 1.5
var gun_min_pitch: float = deg_to_rad(-6.0)
var gun_max_pitch: float = deg_to_rad(85.0)
var turret: Node3D = null
var gun_pivot: Node3D = null
var turret_yaw: float = 0.0
var gun_pitch: float = 0.0
var hull_yaw: float = 0.0

var _ground_normal: Vector3 = Vector3.UP


func _after_build() -> void:
	hull_yaw = GameDB.yaw_of(-global_basis.z)
	spawn_protection = 3.0
	if terrain != null:
		var p := global_position
		global_position = Vector3(p.x, terrain.get_height(p.x, p.z), p.z)
		_ground_normal = terrain.get_normal(p.x, p.z)


func _engine_sound_key() -> String:
	return "engine_diesel"


func _engine_pitch() -> float:
	return 0.8 + absf(speed) / maxf(max_forward_speed, 1.0) * 0.5


func damage_fx_offset() -> Vector3:
	return Vector3(0.0, 2.6, 1.5)


func camera_offset() -> Vector2:
	return Vector2(16.0, 5.0)


func _vehicle_physics(delta: float) -> void:
	if terrain == null:
		return
	var c := controls
	var target_speed := c.throttle * (max_forward_speed if c.throttle >= 0.0 else max_reverse_speed)
	speed = move_toward(speed, target_speed, acceleration * delta)
	var steer := c.steer if speed >= -0.5 else -c.steer
	hull_yaw = wrapf(hull_yaw - steer * turn_rate * delta, -PI, PI)
	var heading := Vector3(-sin(hull_yaw), 0.0, -cos(hull_yaw))
	var pos := global_position
	var next := pos + heading * speed * delta
	if absf(speed) > 0.01 and not _is_passable(pos, next):
		speed = 0.0
		next = pos
	next.y = terrain.get_height(next.x, next.z)
	var n := terrain.get_normal(next.x, next.z)
	_ground_normal = _ground_normal.lerp(n, clampf(delta * 5.0, 0.0, 1.0)).normalized()
	var right := heading.cross(_ground_normal).normalized()
	var back := right.cross(_ground_normal).normalized()
	global_transform = Transform3D(Basis(right, _ground_normal, back), next)
	velocity = heading * speed
	_update_turret(delta)


func _is_passable(from: Vector3, to: Vector3) -> bool:
	var bound := GlobalBattleManager.bounds() + 150.0
	if absf(to.x) > bound or absf(to.z) > bound:
		return false
	var h := terrain.get_height(to.x, to.z)
	if h < Terrain.LAND_HEIGHT:
		return false
	var n := terrain.get_normal(to.x, to.z)
	if n.y < 0.74 and h > terrain.get_height(from.x, from.z) + 0.02:
		return false
	for b in GlobalBattleManager.structures:
		if not is_instance_valid(b) or b.is_dead:
			continue
		var r := b.footprint_radius + 3.0
		var d_to := GameDB.flat_distance(b.global_position, to)
		if d_to < r and d_to < GameDB.flat_distance(b.global_position, from):
			return false
	return true


## Мировая точка, на которую наводится башня (подклассы могут переопределить — напр. автосопровождение ЗРК).
func _turret_aim_point() -> Variant:
	if controls.has_aim:
		return controls.aim_point
	return null


func _update_turret(delta: float) -> void:
	if turret == null:
		return
	var aim: Variant = _turret_aim_point()
	if aim != null:
		var aim_point: Vector3 = aim
		var pivot_world := gun_pivot.global_position if gun_pivot != null else turret.global_position
		var local := global_transform.basis.inverse() * (aim_point - pivot_world)
		var desired_yaw := atan2(-local.x, -local.z)
		var desired_pitch := atan2(local.y, Vector2(local.x, local.z).length())
		var dy := wrapf(desired_yaw - turret_yaw, -PI, PI)
		turret_yaw = wrapf(turret_yaw + clampf(dy, -turret_yaw_rate * delta, turret_yaw_rate * delta), -PI, PI)
		var dp := desired_pitch - gun_pitch
		gun_pitch = clampf(gun_pitch + clampf(dp, -gun_pitch_rate * delta, gun_pitch_rate * delta), gun_min_pitch, gun_max_pitch)
	turret.rotation = Vector3(0.0, turret_yaw, 0.0)
	if gun_pivot != null:
		gun_pivot.rotation = Vector3(gun_pitch, 0.0, 0.0)


func gun_direction() -> Vector3:
	if gun_pivot != null:
		return -gun_pivot.global_basis.z
	if turret != null:
		return -turret.global_basis.z
	return get_forward()


func gun_origin() -> Vector3:
	if gun_pivot != null:
		return gun_pivot.global_position
	if turret != null:
		return turret.global_position
	return global_position + Vector3.UP * 2.0


## Угол (град) между направлением ствола и направлением на точку.
func aim_error_to(point: Vector3) -> float:
	return rad_to_deg(gun_direction().angle_to(point - gun_origin()))
