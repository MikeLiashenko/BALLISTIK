class_name PlayerController
extends Node
## Управление игрока: клавиатура и мышь, геймпад, сенсорный экран (TouchControls).
## Преобразует ввод в VehicleControls текущей техники, управляет обзором камеры и тактическим режимом
## баллистического прицеливания: метка на карте → проверка дальности → предпросмотр дуги → пуск.

signal tactical_mode_changed(active: bool)

const ARC_WIDTH_FACTOR := 0.006

var level: BattleLevel = null
var rig: CameraRig = null
var hud: HUD = null
var vehicle: Vehicle = null
var autopilot: bool = false
var tactical_active: bool = false
var tactical_point: Vector3 = Vector3.ZERO
var tactical_has_point: bool = false
var tactical_valid: bool = false
var tactical_info: String = ""
var preferred_target: Vehicle = null

var _mouse_delta: Vector2 = Vector2.ZERO
var _throttle_target: float = 0.8
var _stick: Vector2 = Vector2.ZERO
var _marker: TacticalMarker = null
var _range_ring: MeshInstance3D = null
var _arc_instance: MeshInstance3D = null
var _arc_mesh: ImmediateMesh = null
var _arc_material: StandardMaterial3D = null
var _arc_timer: float = 0.0
var _marker_blast_radius: float = 38.0
var _marker_text: String = ""


func setup(p_level: BattleLevel, p_rig: CameraRig, p_hud: HUD) -> void:
	level = p_level
	rig = p_rig
	hud = p_hud


func _ready() -> void:
	process_physics_priority = -20


func touch() -> TouchControls:
	if hud == null:
		return null
	return hud.touch_controls


func is_touch() -> bool:
	return touch() != null and touch().visible


# --- Владение техникой ----------------------------------------------------------------------------------
func possess(v: Vehicle, bot_driven: bool) -> void:
	if tactical_active:
		exit_tactical()
	vehicle = v
	autopilot = bot_driven
	_throttle_target = 0.8
	_stick = Vector2.ZERO
	var cam_mode := CameraRig.Mode.ORBIT
	if v.category == GameDB.Category.AIR and not GameSettings.aircraft_mouse_aim and not is_touch():
		cam_mode = CameraRig.Mode.CHASE
	rig.follow(v, cam_mode)
	v.destroyed.connect(_on_vehicle_destroyed, CONNECT_ONE_SHOT)
	update_mouse_mode()
	if hud != null:
		hud.on_player_vehicle(v)


func _on_vehicle_destroyed(v: Vehicle, _killer: Dictionary) -> void:
	if tactical_active:
		exit_tactical()
	vehicle = null
	rig.enter_death(v.global_position)
	update_mouse_mode()


func has_vehicle() -> bool:
	return vehicle != null and is_instance_valid(vehicle) and not vehicle.is_dead


## Захват курсора на ПК, когда игрок управляет техникой и не открыто меню.
func update_mouse_mode() -> void:
	if is_touch() or DisplayServer.get_name() == "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	var menu_open := hud != null and hud.is_menu_open()
	if has_vehicle() and not autopilot and not tactical_active and not menu_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- Ввод -------------------------------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if is_touch() and (event is InputEventMouseMotion or event is InputEventMouseButton):
		return
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_mouse_delta += (event as InputEventMouseMotion).relative
		return
	if event is InputEventMouseButton and event.is_pressed():
		var mb := event as InputEventMouseButton
		if tactical_active:
			match mb.button_index:
				MOUSE_BUTTON_LEFT:
					tactical_click(mb.position)
				MOUSE_BUTTON_RIGHT:
					exit_tactical()
				MOUSE_BUTTON_WHEEL_UP:
					rig.tactical_size = clampf(rig.tactical_size * 0.87, 900.0, 18000.0)
				MOUSE_BUTTON_WHEEL_DOWN:
					rig.tactical_size = clampf(rig.tactical_size * 1.15, 900.0, 18000.0)
			get_viewport().set_input_as_handled()
			return
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and has_vehicle() and hud != null and not hud.is_menu_open():
			update_mouse_mode()
	if not has_vehicle() or autopilot:
		return
	if event.is_action_pressed("special"):
		if tactical_active:
			exit_tactical()
		else:
			enter_tactical()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm") and tactical_active:
		tactical_launch()
	elif event.is_action_pressed("fire_primary") and tactical_active and not (event is InputEventMouseButton):
		tactical_launch()
	elif event.is_action_pressed("camera_mode") and vehicle.category == GameDB.Category.AIR:
		var new_mode := CameraRig.Mode.CHASE if rig.mode == CameraRig.Mode.ORBIT else CameraRig.Mode.ORBIT
		rig.follow(vehicle, new_mode)


func _physics_process(delta: float) -> void:
	if not has_vehicle():
		_mouse_delta = Vector2.ZERO
		return
	if autopilot:
		_mouse_delta = Vector2.ZERO
		var fwd := vehicle.get_forward()
		if vehicle.category != GameDB.Category.AIR and vehicle.controls.has_aim:
			fwd = vehicle.controls.aim_point - vehicle.global_position
		var cur := rig.get_look_direction()
		rig.set_look_from_direction(cur.lerp(fwd.normalized() + Vector3(0.0, -0.15, 0.0), clampf(delta * 2.0, 0.0, 1.0)))
		return
	var c := vehicle.controls
	if hud.is_menu_open() or GlobalBattleManager.match_over:
		_mouse_delta = Vector2.ZERO
		c.fire_primary = false
		c.fire_secondary = false
		c.steer = 0.0
		if vehicle.category != GameDB.Category.AIR:
			c.throttle = 0.0
		return
	_apply_look(delta)
	preferred_target = hud.target_near_crosshair()
	match vehicle.category:
		GameDB.Category.AIR:
			_drive_aircraft(c, delta)
		GameDB.Category.GROUND:
			_drive_ground(c)
		_:
			_drive_boat(c)
	if tactical_active:
		c.fire_primary = false
		c.fire_secondary = false


func _apply_look(delta: float) -> void:
	var sens := GameSettings.mouse_sensitivity * 0.0024
	var d := _mouse_delta
	_mouse_delta = Vector2.ZERO
	var t := touch()
	if t != null and t.visible and not tactical_active:
		d += t.consume_look_delta() * 1.6
	var joy := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	var invert := -1.0 if GameSettings.invert_y else 1.0
	if rig.mode == CameraRig.Mode.CHASE:
		_stick += Vector2(d.x, d.y * invert) * sens * 3.0
		_stick = _stick.limit_length(1.0).move_toward(Vector2.ZERO, delta * 1.6)
		return
	if tactical_active:
		return
	rig.look_yaw = wrapf(rig.look_yaw - d.x * sens - joy.x * 2.2 * delta, -PI, PI)
	var min_pitch := -1.35 if vehicle.category == GameDB.Category.AIR else -0.75
	var max_pitch := 1.35 if vehicle.category == GameDB.Category.AIR else 1.2
	rig.look_pitch = clampf(rig.look_pitch - (d.y * sens + joy.y * 1.8 * delta) * invert, min_pitch, max_pitch)


func _held(action: String, touch_button: String) -> bool:
	var t := touch()
	return Input.is_action_pressed(action) or (t != null and t.visible and t.is_held(touch_button))


func _drive_aircraft(c: VehicleControls, delta: float) -> void:
	var t := touch()
	var thr_axis := Input.get_axis("move_back", "move_forward")
	if t != null and t.visible:
		thr_axis += t.throttle_axis()
	_throttle_target = clampf(_throttle_target + thr_axis * delta * 0.7, 0.0, 1.0)
	c.throttle = _throttle_target
	var roll := Input.get_axis("move_left", "move_right") + Input.get_axis("arrow_left", "arrow_right")
	var pitch := Input.get_axis("arrow_up", "arrow_down")
	var yaw := Input.get_axis("yaw_left", "yaw_right")
	if t != null and t.visible and t.stick_active():
		var s := t.stick_vector()
		roll += s.x
		pitch += s.y
	if rig.mode == CameraRig.Mode.CHASE:
		roll += _stick.x
		pitch += -_stick.y
	c.roll = clampf(roll, -1.0, 1.0)
	c.pitch = clampf(pitch, -1.0, 1.0)
	c.yaw = clampf(yaw, -1.0, 1.0)
	c.use_autopilot = rig.mode == CameraRig.Mode.ORBIT
	c.fly_target = rig.camera.global_position + rig.get_look_direction() * 2500.0
	c.fire_primary = _held("fire_primary", "fire")
	c.fire_secondary = _held("fire_secondary", "secondary")
	if Input.is_action_just_pressed("flares") or (t != null and t.visible and t.consume_tap("flares")):
		c.deploy_flares = true
	c.lock_target = preferred_target
	c.has_aim = false


func _read_move() -> Vector2:
	var mv := Vector2(Input.get_axis("move_left", "move_right") + Input.get_axis("arrow_left", "arrow_right"),
		Input.get_axis("move_back", "move_forward") + Input.get_axis("arrow_down", "arrow_up"))
	var t := touch()
	if t != null and t.visible and t.stick_active():
		var s := t.stick_vector()
		mv += Vector2(s.x, -s.y)
	return mv.limit_length(1.0) if mv.length() > 1.0 else mv


func _drive_ground(c: VehicleControls) -> void:
	var mv := _read_move()
	c.throttle = mv.y
	c.steer = mv.x
	c.aim_point = rig.center_aim_point()
	c.has_aim = true
	c.fire_primary = _held("fire_primary", "fire")
	c.fire_secondary = _held("fire_secondary", "secondary")
	c.lock_target = preferred_target
	rig.zoomed = _held("zoom", "zoom")


func _drive_boat(c: VehicleControls) -> void:
	var mv := _read_move()
	c.throttle = mv.y
	c.steer = mv.x
	c.aim_point = rig.center_aim_point()
	c.has_aim = true
	c.fire_primary = _held("fire_primary", "fire")
	c.fire_secondary = _held("fire_secondary", "secondary")
	c.lock_target = preferred_target
	rig.zoomed = _held("zoom", "zoom")


# --- Тактический режим (баллистическое прицеливание) --------------------------------------------------
func can_use_tactical() -> bool:
	return has_vehicle() and vehicle.get_special_range() != Vector2.ZERO


func enter_tactical() -> void:
	if not can_use_tactical() or tactical_active:
		return
	tactical_active = true
	tactical_has_point = false
	tactical_valid = false
	tactical_info = ""
	var r := vehicle.get_special_range()
	var ahead := GameDB.flat(rig.get_look_direction())
	if ahead.length_squared() < 0.01:
		ahead = GameDB.flat(vehicle.get_forward())
	var center := vehicle.global_position + ahead.normalized() * r.y * 0.45
	center.y = 0.0
	rig.enter_tactical(center, r.y * 1.1)
	level.set_tactical_view(true)
	_create_tactical_visuals(r.y)
	update_mouse_mode()
	tactical_mode_changed.emit(true)
	SoundFX.play_ui("ui_confirm", -6.0)


func exit_tactical() -> void:
	if not tactical_active:
		return
	tactical_active = false
	tactical_has_point = false
	rig.exit_tactical()
	level.set_tactical_view(false)
	for n: Node in [_marker, _range_ring, _arc_instance]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_marker = null
	_range_ring = null
	_arc_instance = null
	_arc_mesh = null
	update_mouse_mode()
	tactical_mode_changed.emit(false)


func _create_tactical_visuals(max_range: float) -> void:
	var parent := level.fx_root
	_marker = TacticalMarker.new()
	_marker_blast_radius = 38.0 if vehicle is PatrolBoat else 24.0
	_marker.radius = _marker_blast_radius
	_marker.visible = false
	parent.add_child(_marker)
	_range_ring = MeshInstance3D.new()
	_range_ring.mesh = MeshFactory.torus(0.985, 1.0, 96, 4)
	_range_ring.material_override = MeshFactory.shared_fade_material("range_ring", Color(0.2, 0.95, 1.0, 0.55), true)
	_range_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_range_ring.scale = Vector3(max_range, 30.0, max_range)
	parent.add_child(_range_ring)
	_arc_mesh = ImmediateMesh.new()
	_arc_instance = MeshInstance3D.new()
	_arc_instance.mesh = _arc_mesh
	_arc_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _arc_material == null:
		_arc_material = MeshFactory.glow(Color(1.0, 0.7, 0.2), 3.0)
		_arc_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	parent.add_child(_arc_instance)


func tactical_click(screen_pos: Vector2) -> void:
	if not tactical_active or not has_vehicle():
		return
	if tactical_has_point and tactical_valid:
		var marker_screen := rig.camera.unproject_position(tactical_point)
		if marker_screen.distance_to(screen_pos) < 36.0 and not rig.camera.is_position_behind(tactical_point):
			tactical_launch()
			return
	var hit := rig.screen_to_world(screen_pos)
	if not bool(hit["hit"]):
		return
	set_tactical_point(hit["position"])


## Установить метку удара в мировую точку (клик мышью, касание или автотест).
func set_tactical_point(point: Vector3) -> void:
	if not tactical_active or _marker == null:
		return
	tactical_point = point
	tactical_has_point = true
	_marker.visible = true
	_marker.place(tactical_point)
	_arc_timer = 0.0
	SoundFX.play_ui("beep", -10.0)


func tactical_pan(screen_delta: Vector2) -> void:
	if not tactical_active:
		return
	var k := rig.tactical_size / 700.0
	rig.tactical_center += Vector3(-screen_delta.x, 0.0, -screen_delta.y) * k


func tactical_launch() -> void:
	if not tactical_active or not has_vehicle():
		return
	if not tactical_has_point or not tactical_valid or not vehicle.special_ready():
		SoundFX.play_ui("warning", -8.0)
		return
	vehicle.controls.special_target = tactical_point
	vehicle.controls.fire_special = true
	SoundFX.play_ui("ui_confirm", -4.0)
	exit_tactical()


func _process(delta: float) -> void:
	if tactical_active:
		_update_tactical(delta)


func _update_tactical(delta: float) -> void:
	if not has_vehicle():
		exit_tactical()
		return
	var pan := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	rig.tactical_center += Vector3(pan.x, 0.0, pan.y) * rig.tactical_size * 0.6 * delta
	var r := vehicle.get_special_range()
	var origin := vehicle.get_special_origin()
	if _range_ring != null:
		_range_ring.global_position = Vector3(vehicle.global_position.x, 2.0, vehicle.global_position.z)
	if _marker != null:
		_marker.radius = maxf(_marker_blast_radius, rig.tactical_size * 0.012)
	if not tactical_has_point:
		tactical_info = "Укажите точку удара на карте"
		return
	var d := GameDB.flat_distance(origin, tactical_point)
	var in_range := d >= r.x and d <= r.y
	_arc_timer -= delta
	if _arc_timer <= 0.0:
		_arc_timer = 0.2
		_rebuild_arc(origin, in_range)
	var ready := vehicle.special_ready()
	_marker.set_valid(tactical_valid and ready)
	if not in_range:
		tactical_info = "ВНЕ ДАЛЬНОСТИ: %s (допустимо %s–%s)" % [GameDB.format_distance(d), GameDB.format_distance(r.x), GameDB.format_distance(r.y)]
	elif not ready:
		tactical_info = "%s · ОРУЖИЕ ПЕРЕЗАРЯЖАЕТСЯ" % GameDB.format_distance(d)
	_marker.set_text(_marker_text if in_range else "ВНЕ ДАЛЬНОСТИ")


func _rebuild_arc(origin: Vector3, in_range: bool) -> void:
	if _arc_mesh == null:
		return
	_arc_mesh.clear_surfaces()
	tactical_valid = false
	if not in_range:
		return
	var pts := PackedVector3Array()
	var eta := 0.0
	var d := GameDB.flat_distance(origin, tactical_point)
	if vehicle is PatrolBoat:
		var v0 := BallisticMissile.solve(origin, tactical_point)
		if v0 == Vector3.ZERO:
			return
		pts = BallisticMissile.predict(origin, v0, level.terrain)
		eta = BallisticMissile.flight_time(origin, v0, tactical_point.y)
	else:
		var steps := 24
		for i in steps + 1:
			var k := float(i) / float(steps)
			var p := origin.lerp(tactical_point, k)
			p.y = lerpf(origin.y, tactical_point.y, k) + sin(k * PI) * 60.0
			pts.append(p)
		eta = d / 280.0
	tactical_valid = true
	_marker_text = "%s · %.1f с" % [GameDB.format_distance(d), eta]
	tactical_info = "ЦЕЛЬ: %s · ПОДЛЁТ %.1f с · ПУСК — повторный клик / Enter" % [GameDB.format_distance(d), eta]
	if pts.size() < 2:
		return
	var width := rig.tactical_size * ARC_WIDTH_FACTOR
	_arc_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _arc_material)
	for i in pts.size():
		var p := pts[i]
		var dir := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)])
		var side := Vector3(-dir.z, 0.0, dir.x).normalized() * width
		_arc_mesh.surface_add_vertex(p - side)
		_arc_mesh.surface_add_vertex(p + side)
	_arc_mesh.surface_end()
