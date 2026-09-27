class_name Aircraft
extends Vehicle
## Общая аркадная модель полёта (истребитель и бомбардировщик):
##  * тяга по РУД и квадратичное сопротивление (установившаяся скорость = max_speed на полном газе);
##  * набор высоты замедляет, пикирование разгоняет;
##  * подъёмная сила зависит от скорости: ниже min_speed — сваливание, просадка и опускание носа;
##  * эффективность рулей растёт со скоростью, вектор скорости догоняет ориентацию с инерцией;
##  * автопилот «лететь в точку» — для ботов и режима мышь-наведения игрока;
##  * тепловые ловушки против ракет с ИК ГСН.

var min_speed: float = 70.0
var cruise_speed: float = 160.0
var max_speed: float = 270.0
var thrust_accel: float = 45.0
var pitch_rate: float = 1.4
var roll_rate: float = 3.2
var yaw_rate: float = 0.45
var throttle: float = 0.75
var ceiling: float = 4500.0
var flares: Weapon = null
var stall_warning: bool = false
var ground_warning: bool = false

var _drag_k: float = 0.0
var _vel_dir: Vector3 = Vector3.FORWARD
var _sink: float = 0.0
var _afterburners: Array[MeshInstance3D] = []
var _flare_burst_left: int = 0
var _flare_timer: float = 0.0
var _decoy_pending: bool = false


func _after_build() -> void:
	_drag_k = thrust_accel / (max_speed * max_speed)
	speed = cruise_speed
	_vel_dir = -global_basis.z
	velocity = _vel_dir * speed
	throttle = 0.8
	controls.throttle = throttle
	spawn_protection = 4.0


func _engine_sound_key() -> String:
	return "engine_jet"


func _engine_pitch() -> float:
	return 0.7 + throttle * 0.55


func damage_fx_offset() -> Vector3:
	return Vector3(0.0, 0.5, 4.0)


func camera_offset() -> Vector2:
	return Vector2(26.0, 6.0)


func _vehicle_physics(delta: float) -> void:
	var c := controls
	var pitch_in := clampf(c.pitch, -1.0, 1.0)
	var roll_in := clampf(c.roll, -1.0, 1.0)
	var yaw_in := clampf(c.yaw, -1.0, 1.0)
	if c.use_autopilot:
		var ap := compute_autopilot(c.fly_target)
		if absf(pitch_in) < 0.05:
			pitch_in = ap.x
		if absf(roll_in) < 0.05:
			roll_in = ap.y
		if absf(yaw_in) < 0.05:
			yaw_in = ap.z
	throttle = move_toward(throttle, clampf(c.throttle, 0.0, 1.0), delta * 0.9)
	var lift := clampf((speed - min_speed * 0.55) / (min_speed * 0.45), 0.0, 1.0)
	stall_warning = lift < 0.95
	var eff := clampf(speed / cruise_speed, 0.3, 1.2)
	rotate_object_local(Vector3.RIGHT, pitch_in * pitch_rate * eff * delta)
	rotate_object_local(Vector3.FORWARD, roll_in * roll_rate * eff * delta)
	rotate_object_local(Vector3.UP, -yaw_in * yaw_rate * eff * delta)
	if lift < 1.0:
		var nose_down := (1.0 - lift) * 0.9 * delta
		var right := global_basis.x
		if global_basis.z.y < 0.95:
			global_rotate(right, -nose_down)
	global_transform = global_transform.orthonormalized()
	var fwd := -global_basis.z
	var accel := thrust_accel * throttle - _drag_k * speed * speed - GameDB.GRAVITY * fwd.y * 0.9
	if global_position.y > ceiling:
		accel -= (global_position.y - ceiling) * 0.05
	speed = clampf(speed + accel * delta, 25.0, max_speed * 1.25)
	var blended := _vel_dir.lerp(fwd, clampf(delta * 3.5, 0.0, 1.0))
	if blended.length_squared() > 0.0001:
		_vel_dir = blended.normalized()
	_sink = move_toward(_sink, (1.0 - lift) * 32.0, GameDB.GRAVITY * delta)
	velocity = _vel_dir * speed + Vector3.DOWN * _sink
	global_position += velocity * delta
	_update_afterburners()
	_check_ground()


func _check_ground() -> void:
	if terrain == null:
		return
	var p := global_position
	var ground := terrain.get_surface_height(p.x, p.z)
	var ahead := p + velocity * 3.0
	var ground_ahead := terrain.get_surface_height(ahead.x, ahead.z)
	ground_warning = (p.y - ground < 90.0 and velocity.y < -12.0) or ahead.y < ground_ahead + 20.0
	if p.y < ground + 1.2:
		destroy({})


func _update_afterburners() -> void:
	var s := 0.35 + throttle * 1.1
	for ab in _afterburners:
		ab.scale = Vector3(1.0, s, 1.0)
		ab.visible = throttle > 0.15


## Автопилот: команды (тангаж, крен, рыскание) для полёта в точку target.
## Крупное отклонение — энергичный крен в сторону цели и «ручка на себя», малое — выравнивание крыльев.
func compute_autopilot(target: Vector3) -> Vector3:
	var to_target := target - global_position
	if to_target.length_squared() < 1.0:
		return Vector3.ZERO
	var local := global_basis.inverse() * to_target.normalized()
	var angle_off := Vector3.FORWARD.angle_to(local)
	var pitch_cmd := clampf(local.y * 4.0, -1.0, 1.0)
	var yaw_cmd := clampf(local.x * 2.0, -1.0, 1.0)
	var aggressive_roll := clampf(local.x * 4.0, -1.0, 1.0)
	if local.z > 0.0 and absf(local.x) < 0.25:
		aggressive_roll = 1.0 if local.x >= 0.0 else -1.0
	var wings_level := clampf(global_basis.x.y * 3.0, -1.0, 1.0)
	if global_basis.y.y < 0.2:
		wings_level = 1.0
	var t := clampf(angle_off / deg_to_rad(12.0), 0.0, 1.0)
	var roll_cmd := lerpf(wings_level, aggressive_roll, t)
	return Vector3(pitch_cmd, roll_cmd, yaw_cmd)


# --- Ловушки -------------------------------------------------------------------------------------------
func _handle_flares(delta: float) -> void:
	if controls.deploy_flares and flares != null and flares.can_fire():
		flares.consume()
		_flare_burst_left = 4
		_flare_timer = 0.0
		_decoy_pending = true
	if _flare_burst_left > 0:
		_flare_timer -= delta
		if _flare_timer <= 0.0:
			_flare_timer = 0.11
			_flare_burst_left -= 1
			_spawn_flare()


func _spawn_flare() -> void:
	var parent := GlobalBattleManager.get_fx_parent()
	if parent == null:
		return
	var f := Flare.new()
	f.velocity = velocity * 0.55 - global_basis.y * 18.0 + global_basis.x * _rng.randf_range(-16.0, 16.0)
	f.position = global_position + global_basis.z * 5.0
	parent.add_child(f)
	if _decoy_pending:
		_decoy_pending = false
		for m in incoming_missiles.duplicate():
			if is_instance_valid(m) and m.has_method("consider_decoy"):
				m.call("consider_decoy", f)
	SoundFX.play_3d("flare", global_position, -6.0, 1.0, 20.0)


func _on_destroyed() -> void:
	Effects.explosion(global_position, 11.0, false)
	if model != null:
		FallingWreck.spawn_from(model, velocity * 0.7)


func get_hud_lines() -> PackedStringArray:
	var alt := global_position.y
	var agl := alt
	if terrain != null:
		agl = alt - terrain.get_surface_height(global_position.x, global_position.z)
	var lines := PackedStringArray()
	lines.append("СКОРОСТЬ  %d км/ч" % int(speed * 3.6))
	lines.append("ВЫСОТА  %d м  (над землёй %d м)" % [int(alt), int(agl)])
	lines.append("ТЯГА  %d%%" % int(throttle * 100.0))
	return lines


func camera_look_ahead() -> float:
	return 80.0
