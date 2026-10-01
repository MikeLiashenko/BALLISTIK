class_name CameraRig
extends Node3D
## Камера боя. Режимы:
##  * ORBIT    — от третьего лица, направление взгляда задаёт мышь/касание/стик (наземная техника,
##               катера, авиация в режиме «мышь-наведение»: самолёт летит туда, куда смотрит камера);
##  * CHASE    — жёсткая камера за самолётом при прямом управлении;
##  * TACTICAL — наклонный вид сверху на карту для баллистического прицеливания;
##  * DEATH    — облёт места гибели;
##  * OVERVIEW — общий план арены;
##  * FIRST_PERSON — вид от первого лица: из кабины самолёта (с приборной доской), с места наводчика
##               ПВО или с мостика корабля (с качкой). Мышь у самолёта — как в ORBIT (самолёт летит
##               туда, куда смотрит пилот) или как в CHASE (виртуальная ручка), см. fp_mouse_aim.
## Камера обновляется в _process по интерполированным трансформам техники и трясётся от взрывов.

enum Mode { ORBIT, CHASE, TACTICAL, DEATH, OVERVIEW, FIRST_PERSON }

var mode: int = Mode.OVERVIEW
var camera: Camera3D = null
var target: Vehicle = null
var terrain: Terrain = null
var look_yaw: float = 0.0
var look_pitch: float = -0.1
var zoomed: bool = false
var tactical_center: Vector3 = Vector3.ZERO
var tactical_size: float = 4000.0
var focus_point: Vector3 = Vector3.ZERO
## Вид из кабины: самолёт летит туда, куда смотрит пилот (иначе мышь — виртуальная ручка).
var fp_mouse_aim: bool = true

var _mode_before_tactical: int = Mode.ORBIT
var _trauma: float = 0.0
var _noise_t: float = 0.0
var _death_angle: float = 0.0
var _overview_angle: float = 0.0
var _chase_basis: Basis = Basis()
var _tactical_distance: float = 4000.0
var _fp_basis: Basis = Basis()
var _fp_shake: float = 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 70.0
	camera.near = 0.5
	camera.far = 60000.0
	add_child(camera)
	camera.make_current()
	var level := GlobalBattleManager.level
	if level != null:
		terrain = level.terrain
	GlobalBattleManager.explosion_event.connect(_on_explosion)


func _on_explosion(pos: Vector3, radius: float) -> void:
	var d := camera.global_position.distance_to(pos)
	add_trauma(clampf(radius * 5.0 / maxf(d, 1.0), 0.0, 0.7))


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func get_look_direction() -> Vector3:
	return GameDB.dir_from_yaw_pitch(look_yaw, look_pitch)


func set_look_from_direction(dir: Vector3) -> void:
	if dir.length_squared() < 0.0001:
		return
	var d := dir.normalized()
	look_yaw = GameDB.yaw_of(d)
	look_pitch = asin(clampf(d.y, -1.0, 1.0))


func follow(v: Vehicle, new_mode: int) -> void:
	target = v
	mode = new_mode
	if v != null:
		set_look_from_direction(v.get_forward() + Vector3(0.0, -0.12 if new_mode != Mode.FIRST_PERSON else -0.02, 0.0))
		_chase_basis = v.global_basis.orthonormalized()
		_fp_basis = _chase_basis


func _valid_target() -> bool:
	return target != null and is_instance_valid(target) and not target.is_dead


func _process(delta: float) -> void:
	_trauma = maxf(_trauma - delta * 1.4, 0.0)
	_noise_t += delta * 38.0
	_sync_cockpit()
	camera.near = (0.03 if _is_air() else 0.15) if mode == Mode.FIRST_PERSON else 0.5
	match mode:
		Mode.ORBIT:
			_update_orbit()
		Mode.CHASE:
			_update_chase(delta)
		Mode.TACTICAL:
			_update_tactical(delta)
		Mode.DEATH:
			_update_death(delta)
		Mode.FIRST_PERSON:
			_update_first_person(delta)
		_:
			_update_overview(delta)
	if mode != Mode.TACTICAL:
		var target_fov := 30.0 if zoomed else 70.0
		if mode == Mode.FIRST_PERSON:
			target_fov = (18.0 if zoomed else 74.0) if not _is_air() else (40.0 if zoomed else 78.0)
		if _valid_target() and target.category == GameDB.Category.AIR and not zoomed:
			target_fov += clampf((target.speed - 150.0) * 0.06, 0.0, 8.0)
		camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 8.0, 0.0, 1.0))
		_apply_shake()


func _keep_above_ground(p: Vector3, clearance: float = 1.5) -> Vector3:
	if terrain == null:
		return p
	var g := terrain.get_surface_height(p.x, p.z) + clearance
	return Vector3(p.x, maxf(p.y, g), p.z)


func _update_orbit() -> void:
	if not _valid_target():
		return
	var t := target.get_global_transform_interpolated()
	var off := target.camera_offset()
	var pivot := t.origin + Vector3.UP * off.y
	var dir := get_look_direction()
	var dist := off.x * (0.55 if zoomed else 1.0)
	camera.global_position = _keep_above_ground(pivot - dir * dist)
	camera.global_basis = GameDB.basis_from_forward(dir)


func _update_chase(delta: float) -> void:
	if not _valid_target():
		return
	var t := target.get_global_transform_interpolated()
	_chase_basis = _chase_basis.slerp(t.basis.orthonormalized(), clampf(delta * 6.0, 0.0, 1.0)).orthonormalized()
	var off := target.camera_offset()
	camera.global_position = _keep_above_ground(t.origin + _chase_basis * Vector3(0.0, off.y, off.x))
	camera.global_basis = _chase_basis
	set_look_from_direction(-_chase_basis.z)


func enter_tactical(center: Vector3, view_size: float) -> void:
	if mode != Mode.TACTICAL:
		_mode_before_tactical = mode
	mode = Mode.TACTICAL
	tactical_center = center
	tactical_size = view_size
	_tactical_distance = view_size
	camera.fov = 50.0


func exit_tactical() -> void:
	if mode == Mode.TACTICAL:
		mode = _mode_before_tactical
	camera.fov = 70.0


func _update_tactical(delta: float) -> void:
	_tactical_distance = lerpf(_tactical_distance, tactical_size, clampf(delta * 8.0, 0.0, 1.0))
	var pitch := deg_to_rad(58.0)
	var offset := Vector3(0.0, sin(pitch), cos(pitch)) * _tactical_distance
	camera.global_position = tactical_center + offset
	camera.global_basis = GameDB.basis_from_forward(-offset)
	camera.fov = 50.0


func enter_death(pos: Vector3) -> void:
	mode = Mode.DEATH
	focus_point = pos
	_death_angle = look_yaw
	zoomed = false


func _update_death(delta: float) -> void:
	_death_angle += delta * 0.25
	var dir := Vector3(sin(_death_angle), 0.0, cos(_death_angle))
	camera.global_position = _keep_above_ground(focus_point + dir * 70.0 + Vector3.UP * 30.0, 5.0)
	camera.global_basis = GameDB.basis_from_forward(focus_point - camera.global_position)


func enter_overview() -> void:
	mode = Mode.OVERVIEW
	target = null


func _update_overview(delta: float) -> void:
	_overview_angle += delta * 0.04
	var r := GlobalBattleManager.bounds() * 0.75
	var pos := Vector3(sin(_overview_angle) * r, 1800.0, cos(_overview_angle) * r)
	camera.global_position = pos
	camera.global_basis = GameDB.basis_from_forward(Vector3(0.0, 0.0, 0.0) - pos)


func _apply_shake() -> void:
	if _trauma <= 0.001:
		return
	var s := _trauma * _trauma
	var k := 0.12 if mode == Mode.FIRST_PERSON else 1.0
	var off := Vector3(sin(_noise_t * 1.3), sin(_noise_t * 1.7 + 1.2), 0.0) * s * 0.9 * k
	camera.global_position += camera.global_basis * off
	camera.rotate_object_local(Vector3.FORWARD, sin(_noise_t * 1.1) * s * 0.03)


## Точка поверхности под экранной точкой (луч из камеры).
func screen_to_world(screen_pos: Vector2, max_dist: float = 12000.0) -> Dictionary:
	if terrain == null:
		return {"hit": false, "position": Vector3.ZERO, "distance": 0.0}
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	return terrain.raycast(origin, dir, max_dist)


## Точка прицеливания по центру экрана (рельеф/вода; если луч ушёл в небо — точка вдали по лучу).
func center_aim_point(max_dist: float = 6000.0) -> Vector3:
	var origin := camera.global_position
	var dir := -camera.global_basis.z
	if terrain != null:
		var hit := terrain.raycast(origin, dir, max_dist)
		if bool(hit["hit"]):
			return hit["position"]
	return origin + dir * 3000.0


# --- Вид от первого лица -----------------------------------------------------------------------------------
var _cockpit_owner: Aircraft = null


func _is_air() -> bool:
	return _valid_target() and target.category == GameDB.Category.AIR


## Вход в вид от первого лица (или выход в прежний режим).
func set_first_person(on: bool, fallback_mode: int = Mode.ORBIT) -> void:
	if on:
		mode = Mode.FIRST_PERSON
		if _valid_target():
			_fp_basis = target.get_global_transform_interpolated().basis.orthonormalized()
	elif mode == Mode.FIRST_PERSON:
		mode = fallback_mode
		if _valid_target():
			_chase_basis = target.global_basis.orthonormalized()


## Кабина видна только у своего самолёта в виде от первого лица.
func _sync_cockpit() -> void:
	var want: Aircraft = null
	if mode == Mode.FIRST_PERSON and _valid_target() and target is Aircraft:
		want = target as Aircraft
	if want == _cockpit_owner:
		return
	if _cockpit_owner != null and is_instance_valid(_cockpit_owner):
		_cockpit_owner.set_cockpit_visible(false)
	_cockpit_owner = want
	if want != null:
		want.set_cockpit_visible(true)


func _update_first_person(delta: float) -> void:
	if not _valid_target():
		return
	var eye := target.first_person_point()
	if target is Aircraft:
		var a := target as Aircraft
		var t := a.get_global_transform_interpolated()
		if fp_mouse_aim:
			# Взгляд — куда ведёт мышь, горизонт кренится вместе с самолётом.
			camera.global_basis = GameDB.basis_from_forward(get_look_direction(), t.basis.y)
		else:
			_fp_basis = _fp_basis.slerp(t.basis.orthonormalized(), clampf(delta * 14.0, 0.0, 1.0)).orthonormalized()
			camera.global_basis = _fp_basis
			set_look_from_direction(-_fp_basis.z)
		# Дрожь от двигателя, перегрузки и стрельбы.
		var vib := 0.0012 + a.throttle * 0.0016 + absf(a.stick_input.x) * a.speed * 0.00002
		if a.controls.fire_primary:
			vib += 0.0035
		eye += camera.global_basis * Vector3(sin(_noise_t * 2.3), sin(_noise_t * 3.1 + 0.7), 0.0) * vib
		camera.global_position = eye
	else:
		camera.global_position = eye
		camera.global_basis = GameDB.basis_from_forward(get_look_direction())
