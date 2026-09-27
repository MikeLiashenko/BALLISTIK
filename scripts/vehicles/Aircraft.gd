class_name Aircraft
extends Vehicle
## Самолёт (истребитель или ударный), полностью описанный данными GameDB:
##  * аркадная модель полёта: тяга по РУД и квадратичное сопротивление (на полном газе — max_speed),
##    набор высоты замедляет, пикирование разгоняет, сваливание ниже min_speed, инерция вектора скорости;
##  * автопилот «лететь в точку» — для ботов и режима мышь-наведения игрока;
##  * оружие по слотам (основное / дополнительное / тактическое): пушки и пулемёты со сведением
##    к точке, ракеты «воздух-воздух» с ИК ГСН, неуправляемые ракеты, бомбы с прицелом CCIP,
##    управляемые ракеты по выбранной цели или по метке тактической карты; тепловые ловушки;
##  * детальная модель AircraftBuilder: вращающиеся винты (диск), форсаж, подвески, инверсионные следы.

const CONTRAIL_ALTITUDE := 2400.0
const GUN_CONVERGENCE := 330.0
const AAM_LOCK_CONE := 28.0
const BOMB_DRAG := 0.00006

var role: String = "fighter"
var engine_kind: String = "jet"
var cfg: Dictionary = {}
var min_speed: float = 70.0
var cruise_speed: float = 160.0
var max_speed: float = 270.0
var thrust_accel: float = 45.0
var pitch_rate: float = 1.4
var roll_rate: float = 3.2
var yaw_rate: float = 0.45
var throttle: float = 0.75
var ceiling: float = 5500.0
var flares: Weapon = null
var stall_warning: bool = false
var ground_warning: bool = false
## Слоты оружия: "primary", "secondary", "special" → {"type", "weapon": Weapon, "cfg"}.
var slots: Dictionary = {}
var lock_target: Vehicle = null
var lock_progress: float = 0.0
var gun_target: Vehicle = null
var ccip_point: Vector3 = Vector3.ZERO
var ccip_valid: bool = false
var designated_target: Node3D = null

var _drag_k: float = 0.0
var _vel_dir: Vector3 = Vector3.FORWARD
var _sink: float = 0.0
var _afterburners: Array[MeshInstance3D] = []
var _props: Array[Node3D] = []
var _prop_blades: Array[Node3D] = []
var _prop_discs: Array[Node3D] = []
var _muzzles: Array[Node3D] = []
var _flashes: Array[MeshInstance3D] = []
var _hardpoints: Array[Node3D] = []
var _rails: Array[Node3D] = []
var _wingtips: Array[Node3D] = []
var _nozzles: Array[Node3D] = []
var _bomb_bay: Vector3 = Vector3(0.0, -1.0, 0.0)
var _stores: Dictionary = {}
var _muzzle_index: int = 0
var _mount_index: int = 0
var _flash_timer: float = 0.0
var _flare_burst_left: int = 0
var _flare_timer: float = 0.0
var _decoy_pending: bool = false
var _target_timer: float = 0.0
var _ccip_timer: float = 0.0
var _lock_tone_timer: float = 0.0
var _contrails: Array[GPUParticles3D] = []
var _vortex: Array[GPUParticles3D] = []
var _prop_angle: float = 0.0


func _build() -> void:
	cfg = GameDB.vehicle_info(vehicle_type)
	role = str(cfg.get("role", "fighter"))
	engine_kind = str(cfg.get("engine", "jet"))
	var fl: Dictionary = cfg.get("flight", {})
	min_speed = float(fl.get("min", 70.0))
	cruise_speed = float(fl.get("cruise", 160.0))
	max_speed = float(fl.get("max", 270.0))
	thrust_accel = float(fl.get("thrust", 45.0))
	pitch_rate = float(fl.get("pitch", 1.4))
	roll_rate = float(fl.get("roll", 3.2))
	yaw_rate = float(fl.get("yaw", 0.45))
	ceiling = 4800.0 if is_prop() else 6000.0
	max_health = float(cfg.get("hp", 150.0))
	hit_radius = float(cfg.get("hit_radius", 6.0))
	damage_modifiers = {"bullet": 1.0, "flak": 1.0, "missile": 1.0}
	damage_modifiers.merge(cfg.get("armor", {}), true)
	var parts := AircraftBuilder.build(vehicle_type, team)
	model = parts["root"]
	add_child(model)
	_afterburners.assign(parts["afterburners"])
	_props.assign(parts["props"])
	_prop_blades.assign(parts["prop_blades"])
	_prop_discs.assign(parts["prop_discs"])
	_muzzles.assign(parts["muzzles"])
	_hardpoints.assign(parts["hardpoints"])
	_rails.assign(parts["rails"])
	_wingtips.assign(parts["wingtips"])
	_nozzles.assign(parts["nozzles"])
	_bomb_bay = parts["bomb_bay"]
	for b in _prop_blades:
		b.visible = false
	for d in _prop_discs:
		d.visible = true
	for m in _muzzles:
		var f := Effects.create_muzzle_flash(0.9 if is_prop() else 1.2)
		m.add_child(f)
		_flashes.append(f)
	_add_box_collision(cfg.get("collision", Vector3(10.0, 3.0, 10.0)), Vector3(0.0, 0.2, 0.0))
	for key: String in ["primary", "secondary"]:
		if cfg.has(key):
			slots[key] = _make_slot(cfg[key])
	var sp := str(cfg.get("special", ""))
	if sp == "secondary" and slots.has("secondary"):
		slots["special"] = slots["secondary"]
	elif sp != "" and cfg.has(sp):
		slots["special"] = _make_slot(cfg[sp])
	var flare_count := int(cfg.get("flares", 0))
	if flare_count > 0:
		flares = Weapon.new("flares", "ЛТЦ", flare_count, 0.8, 9.0)
	weapons.clear()
	for key: String in ["primary", "secondary", "special"]:
		if slots.has(key):
			var w: Weapon = (slots[key] as Dictionary)["weapon"]
			if not weapons.has(w):
				weapons.append(w)
	if flares != null:
		weapons.append(flares)
	_create_stores()
	_create_trails()


func _make_slot(c: Dictionary) -> Dictionary:
	var type := str(c.get("type", "guns"))
	var w: Weapon
	match type:
		"guns":
			w = Weapon.new("guns", str(c["name"]), -1, float(c.get("interval", 0.06)), float(c.get("reload", 4.0)), int(c.get("magazine", 150)))
		_:
			w = Weapon.new(type, str(c["name"]), int(c.get("count", 2)), float(c.get("interval", 0.5)), float(c.get("reload", 15.0)))
	return {"type": type, "weapon": w, "cfg": c}


func _after_build() -> void:
	_drag_k = thrust_accel / (max_speed * max_speed)
	speed = cruise_speed
	_vel_dir = -global_basis.z
	velocity = _vel_dir * speed
	throttle = 0.8
	controls.throttle = throttle
	spawn_protection = 4.0


func is_prop() -> bool:
	return engine_kind != "jet"


func _engine_sound_key() -> String:
	return "engine_jet" if engine_kind == "jet" else ("engine_radial" if engine_kind == "radial" else "engine_prop")


func _engine_pitch() -> float:
	return (0.7 + throttle * 0.55) if engine_kind == "jet" else (0.75 + throttle * 0.4 + clampf(speed / max_speed, 0.0, 1.0) * 0.15)


func damage_fx_offset() -> Vector3:
	return Vector3(0.0, 0.5, -1.5) if is_prop() else Vector3(0.0, 0.5, 4.0)


func camera_offset() -> Vector2:
	return cfg.get("camera", Vector2(26.0, 6.0))


# --- Полёт --------------------------------------------------------------------------------------------
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
		if global_basis.z.y < 0.95:
			global_rotate(global_basis.x, -nose_down)
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
	_update_engine_visuals(delta, absf(pitch_in))
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


func _update_engine_visuals(delta: float, g_load: float) -> void:
	var s := 0.35 + throttle * 1.1
	for ab in _afterburners:
		ab.scale = Vector3(1.0, s, 1.0)
		ab.visible = throttle > 0.15
	if not _props.is_empty():
		_prop_angle = fposmod(_prop_angle + delta * (18.0 + 26.0 * throttle), TAU)
		for p in _props:
			p.rotation = Vector3(0.0, 0.0, _prop_angle)
	var high := global_position.y > CONTRAIL_ALTITUDE and speed > 120.0
	for t in _contrails:
		t.emitting = high
	var pulling := g_load > 0.55 and speed > 110.0
	for v in _vortex:
		v.emitting = pulling and not high


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


# --- Слоты оружия ----------------------------------------------------------------------------------------
func slot(key: String) -> Dictionary:
	return slots.get(key, {})


func slot_type(key: String) -> String:
	return str(slot(key).get("type", ""))


func has_weapon_type(type: String) -> bool:
	for key: String in slots.keys():
		if slot_type(key) == type:
			return true
	return false


func weapon_of_type(type: String) -> Dictionary:
	for key: String in ["primary", "secondary", "special"]:
		if slot_type(key) == type:
			return slot(key)
	return {}


func has_ccip() -> bool:
	return has_weapon_type("bombs")


## Показывать прицел бомбометания: ударным — всегда, истребителям — в пикировании и при наличии бомб.
func show_ccip() -> bool:
	if not has_ccip() or not ccip_valid:
		return false
	var b := weapon_of_type("bombs")
	if (b["weapon"] as Weapon).ammo <= 0:
		return false
	return role == "strike" or get_forward().y < -0.18


## Короткая подпись оружия слота (для сенсорных кнопок).
func slot_label(key: String) -> String:
	var s := slot(key)
	if s.is_empty():
		return ""
	match str(s["type"]):
		"guns":
			return "ПУШКИ"
		"bombs":
			return "БОМБЫ"
		"rockets":
			return "НАР"
	return str((s["cfg"] as Dictionary).get("name", "РАКЕТА"))


func gun_speed() -> float:
	var g := weapon_of_type("guns")
	return float((g["cfg"] as Dictionary).get("speed", 850.0)) if not g.is_empty() else 850.0


func gun_drag() -> float:
	var g := weapon_of_type("guns")
	return float((g["cfg"] as Dictionary).get("drag", 0.0003)) if not g.is_empty() else 0.0003


func _handle_weapons(delta: float) -> void:
	_handle_flares(delta)
	_update_targeting(delta)
	if has_ccip():
		_ccip_timer -= delta
		if _ccip_timer <= 0.0:
			_ccip_timer = 0.1
			_update_ccip()
	if controls.fire_primary:
		_fire_slot("primary")
	if controls.fire_secondary:
		_fire_slot("secondary")
	if controls.fire_special:
		_fire_special(controls.special_target)
	_flash_timer -= delta
	for f in _flashes:
		if f.visible and _flash_timer <= 0.0:
			f.visible = false
	_update_stores()
	_update_hint()


func _fire_slot(key: String) -> void:
	var s := slot(key)
	if s.is_empty():
		return
	var w: Weapon = s["weapon"]
	if not w.can_fire():
		return
	var c: Dictionary = s["cfg"]
	match str(s["type"]):
		"guns":
			w.consume()
			_fire_guns(c)
		"aam":
			if lock_progress >= 1.0 and lock_target != null and is_instance_valid(lock_target):
				w.consume()
				_launch_aam(c)
		"rockets":
			w.consume()
			_fire_rocket(c)
		"bombs":
			w.consume()
			_drop_bomb(c)
		"agm":
			if designated_target != null and is_instance_valid(designated_target):
				w.consume()
				_launch_agm(c, designated_target.global_position, designated_target)


func _fire_special(point: Vector3) -> void:
	var s := slot("special")
	if s.is_empty():
		return
	var w: Weapon = s["weapon"]
	var c: Dictionary = s["cfg"]
	if not w.can_fire():
		return
	var d := GameDB.flat_distance(global_position, point)
	if d < float(c.get("min", 500.0)) or d > float(c.get("max", 8000.0)):
		return
	w.consume()
	_launch_agm(c, point, null)


func _next_muzzle() -> Node3D:
	if _muzzles.is_empty():
		return null
	var m := _muzzles[_muzzle_index % _muzzles.size()]
	_muzzle_index += 1
	return m


func _fire_guns(c: Dictionary) -> void:
	var muzzle := _next_muzzle()
	var from := muzzle.global_position if muzzle != null else global_position + get_forward() * 4.0
	var fwd := get_forward()
	var dir := fwd
	if muzzle != null and absf(muzzle.position.x) > 0.6:
		dir = (global_position + fwd * GUN_CONVERGENCE - from).normalized()
	dir = GameDB.spread_direction(dir, float(c.get("spread", 0.4)), _rng)
	var p := Projectile.new()
	p.velocity = velocity + dir * float(c.get("speed", 850.0))
	p.drag = float(c.get("drag", 0.0003))
	p.damage = float(c.get("damage", 9.0))
	p.damage_type = "bullet"
	p.max_lifetime = 2.3
	var heavy := p.damage >= 10.0
	p.tracer_color = Color(1.0, 0.72, 0.3) if heavy else Color(1.0, 0.86, 0.45)
	p.tracer_width = 0.3 if heavy else 0.22
	p.show_tracer = heavy or _muzzle_index % 2 == 0
	p.setup(team, make_source(str(c.get("name", "Пушка"))), self)
	p.position = from
	level.spawn_projectile(p)
	_flash_timer = 0.035
	if muzzle != null:
		var fi := _muzzles.find(muzzle)
		if fi >= 0 and fi < _flashes.size():
			_flashes[fi].visible = true
	if heavy or _muzzle_index % 2 == 0:
		SoundFX.play_3d("cannon_air" if heavy else "mg", from, -4.0, 1.0, 22.0)


func _launch_aam(c: Dictionary) -> void:
	var m := GuidedMissile.new()
	m.target = lock_target
	m.mesh_kind = "aam"
	m.trail_kind = "small"
	m.tail_offset = 1.4
	m.thrust = 260.0
	m.burn_time = 2.2
	m.max_speed = 920.0
	m.max_g = 34.0
	m.drag = 0.00005
	m.blast_radius = 11.0
	m.blast_damage = 150.0
	m.proximity_radius = 8.0
	m.max_lifetime = 11.0
	m.seeker_fov_deg = 100.0
	m.flare_resistance = 0.45
	var mount := _mount_for("aam")
	m.position = mount.global_position if mount != null else global_position - global_basis.y * 1.2
	m.velocity = velocity - global_basis.y * 6.0
	m.setup(team, make_source(str(c.get("name", "Ракета"))), self)
	level.spawn_projectile(m)


func _fire_rocket(c: Dictionary) -> void:
	var r := Rocket.new()
	var mount := _mount_for("rockets")
	r.position = mount.global_position if mount != null else global_position - global_basis.y
	var dir := GameDB.spread_direction(get_forward(), 0.6, _rng)
	r.velocity = velocity + dir * 40.0
	r.motor_speed = float(c.get("speed", 400.0))
	r.blast_radius = float(c.get("blast", 9.0))
	r.blast_damage = float(c.get("damage", 100.0))
	r.setup(team, make_source(str(c.get("name", "НАР"))), self)
	level.spawn_projectile(r)
	SoundFX.play_3d("missile", r.position, -6.0, 1.4, 25.0)


func _drop_bomb(c: Dictionary) -> void:
	var b := Bomb.new()
	var mount := _mount_for("bombs")
	b.velocity = velocity - global_basis.y * 2.0
	b.position = mount.global_position if mount != null else global_position + global_basis * _bomb_bay
	b.blast_damage = float(c.get("damage", 250.0))
	b.blast_radius = float(c.get("blast", 24.0))
	b.setup(team, make_source(str(c.get("name", "Бомба"))), self)
	level.spawn_projectile(b)
	SoundFX.play_3d("bomb_release", b.position, -4.0, 1.0, 20.0)


func _launch_agm(c: Dictionary, point: Vector3, node: Node3D) -> void:
	var m := CruiseMissile.new()
	m.target_point = point
	m.target_node = node
	m.direct = bool(c.get("direct", false))
	var mount := _mount_for("agm")
	m.position = mount.global_position if mount != null else global_position + global_basis * Vector3(2.0, -1.0, 0.5)
	m.velocity = velocity - global_basis.y * 6.0
	m.setup(team, make_source(str(c.get("name", "Ракета"))), self)
	level.spawn_projectile(m)


# --- Подвески (видимые боеприпасы) --------------------------------------------------------------------------
func _mount_points(type: String) -> Array[Node3D]:
	match type:
		"aam", "agm":
			if not _rails.is_empty():
				return _rails
			return _hardpoints
		"rockets":
			return _hardpoints
		"bombs":
			if has_weapon_type("rockets"):
				return []
			return _hardpoints
	return []


func _create_stores() -> void:
	for type: String in ["aam", "agm", "rockets", "bombs"]:
		var s := weapon_of_type(type)
		if s.is_empty():
			continue
		var mounts := _mount_points(type)
		var w: Weapon = s["weapon"]
		var shown: Array[Node3D] = []
		var n := mini(mounts.size(), w.max_ammo)
		for i in n:
			var mesh_kind := {"aam": "aam", "agm": "cruise", "rockets": "rocket", "bombs": "bomb"}[type] as String
			var mi := MeshFactory.mesh_instance(VehicleModels.missile_mesh(mesh_kind), null, "Store")
			mi.position = Vector3(0.0, -0.25 if type != "aam" else -0.12, 0.0)
			if type == "bombs" and w.max_ammo > 4:
				mi.scale = Vector3.ONE * 1.25
			mounts[i].add_child(mi)
			shown.append(mi)
		_stores[type] = shown


func _update_stores() -> void:
	for type: String in _stores.keys():
		var list: Array = _stores[type]
		if list.is_empty():
			continue
		var w: Weapon = weapon_of_type(type)["weapon"]
		var visible_n := ceili(float(w.ammo) / float(maxi(w.max_ammo, 1)) * float(list.size()))
		for i in list.size():
			(list[i] as Node3D).visible = i < visible_n


func _mount_for(type: String) -> Node3D:
	var list: Array = _stores.get(type, [])
	var w_slot := weapon_of_type(type)
	if not list.is_empty() and not w_slot.is_empty():
		var w: Weapon = w_slot["weapon"]
		var visible_n := ceili(float(w.ammo + 1) / float(maxi(w.max_ammo, 1)) * float(list.size()))
		var idx := clampi(visible_n - 1, 0, list.size() - 1)
		return (list[idx] as Node3D).get_parent() as Node3D
	var mounts := _mount_points(type)
	if mounts.is_empty():
		return null
	_mount_index += 1
	return mounts[_mount_index % mounts.size()]


# --- Наведение ---------------------------------------------------------------------------------------------
func _update_targeting(delta: float) -> void:
	_target_timer -= delta
	if lock_target != null and (not is_instance_valid(lock_target) or lock_target.is_dead):
		lock_target = null
		lock_progress = 0.0
	if gun_target != null and (not is_instance_valid(gun_target) or gun_target.is_dead):
		gun_target = null
	if designated_target != null and not is_instance_valid(designated_target):
		designated_target = null
	var aam := weapon_of_type("aam")
	if _target_timer <= 0.0:
		_target_timer = 0.15
		if not aam.is_empty():
			var aam_range := float((aam["cfg"] as Dictionary).get("range", 3200.0))
			var desired: Vehicle = null
			if is_instance_valid(controls.lock_target) and controls.lock_target is Vehicle:
				var preferred := controls.lock_target as Vehicle
				if not preferred.is_dead and preferred.category == GameDB.Category.AIR:
					var to_p := preferred.global_position - global_position
					if to_p.length() < aam_range and rad_to_deg(get_forward().angle_to(to_p)) < AAM_LOCK_CONE:
						desired = preferred
			if desired == null:
				desired = find_target_in_cone(get_forward(), AAM_LOCK_CONE, aam_range, "air", Vector3.ZERO)
			if desired != lock_target:
				lock_target = desired
				lock_progress = 0.0
		gun_target = find_target_in_cone(get_forward(), 18.0, 1800.0, "any", Vector3.ZERO)
		var agm := weapon_of_type("agm")
		if not agm.is_empty() and slot_type("secondary") == "agm":
			var max_r := float((agm["cfg"] as Dictionary).get("max", 8000.0))
			var t: Node3D = find_target_in_cone(get_forward(), 22.0, max_r, "surface", Vector3.ZERO)
			designated_target = t if t != null else _structure_in_cone(22.0, max_r)
	if lock_target != null:
		var before := lock_progress
		var lock_time := 1.8 if lock_target is Aircraft and (lock_target as Aircraft).is_prop() else 1.0
		lock_progress = minf(lock_progress + delta / lock_time, 1.0)
		if is_player:
			_lock_tone_timer -= delta
			if lock_progress >= 1.0 and before < 1.0:
				SoundFX.play_ui("locked", -8.0)
			elif lock_progress < 1.0 and _lock_tone_timer <= 0.0:
				_lock_tone_timer = 0.25
				SoundFX.play_ui("beep", -14.0)


func _structure_in_cone(cone_deg: float, max_range: float) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	for b in GlobalBattleManager.enemy_structures_in_radius(team, global_position, max_range):
		var to_b := b.global_position - global_position
		var ang := rad_to_deg(get_forward().angle_to(to_b))
		if ang > cone_deg:
			continue
		var score := ang * 40.0 + to_b.length() * 0.02
		if score < best_score:
			best_score = score
			best = b
	return best


## Прицел CCIP: прогноз точки падения бомбы с учётом скорости носителя, гравитации и сопротивления.
func _update_ccip() -> void:
	if terrain == null:
		ccip_valid = false
		return
	var from := global_position + global_basis * _bomb_bay
	var path := BallisticSolver.predict_path(from, velocity, GameDB.GRAVITY, BOMB_DRAG, 40.0, terrain, 1.0 / 15.0)
	ccip_point = path[path.size() - 1]
	ccip_valid = path.size() > 1 and ccip_point.y <= terrain.get_surface_height(ccip_point.x, ccip_point.z) + 1.0


func _update_hint() -> void:
	hud_hint = ""
	var aam := weapon_of_type("aam")
	if lock_target != null and not aam.is_empty():
		var n := str((aam["cfg"] as Dictionary)["name"])
		hud_hint = "%s: ЦЕЛЬ ЗАХВАЧЕНА" % n if lock_progress >= 1.0 else "%s: ЗАХВАТ %d%%" % [n, int(lock_progress * 100.0)]
	elif designated_target != null and is_instance_valid(designated_target):
		var agm := weapon_of_type("agm")
		hud_hint = "%s: ЦЕЛЬ ВЫБРАНА — %s" % [str((agm["cfg"] as Dictionary)["name"]), GameDB.format_distance(global_position.distance_to(designated_target.global_position))]
	elif slots.has("special") and slot_type("secondary") != "agm":
		var sp := slot("special")
		var w: Weapon = sp["weapon"]
		hud_hint = "%s: %s" % [str((sp["cfg"] as Dictionary)["name"]), "ГОТОВА (G — тактическая карта)" if w.can_fire() else "ПЕРЕЗАРЯДКА %d%%" % int(w.get_ready_ratio() * 100.0)]
	elif show_ccip():
		hud_hint = "БОМБЫ: ПРИЦЕЛ CCIP"


# --- Ловушки и следы ------------------------------------------------------------------------------------------
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


func _create_trails() -> void:
	if GameSettings.quality < 1:
		return
	var sources: Array[Node3D] = _nozzles if not _nozzles.is_empty() else _wingtips
	for n in sources:
		var t := Effects.create_contrail(false)
		t.emitting = false
		n.add_child(t)
		_contrails.append(t)
	for w in _wingtips:
		var v := Effects.create_contrail(true)
		v.emitting = false
		w.add_child(v)
		_vortex.append(v)


func _on_destroyed() -> void:
	for t in _contrails + _vortex:
		Effects.detach_trail(t)
	Effects.explosion(global_position, 11.0, false)
	if model != null:
		FallingWreck.spawn_from(model, velocity * 0.7)


# --- Интерфейс ------------------------------------------------------------------------------------------------
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


func get_lock_info() -> Dictionary:
	if lock_target != null and is_instance_valid(lock_target):
		return {"target": lock_target, "progress": lock_progress}
	if designated_target != null and is_instance_valid(designated_target):
		return {"target": designated_target, "progress": 1.0}
	return {}


func get_lead_info() -> Dictionary:
	if gun_target == null or not is_instance_valid(gun_target) or not has_weapon_type("guns"):
		return {}
	var lead := BallisticSolver.compute_lead(global_position, velocity, gun_target.global_position, gun_target.velocity, gun_speed(), gun_drag(), GameDB.GRAVITY)
	return {"target": gun_target, "point": lead}


func get_special_range() -> Vector2:
	var s := slot("special")
	if s.is_empty():
		return Vector2.ZERO
	var c: Dictionary = s["cfg"]
	return Vector2(float(c.get("min", 500.0)), float(c.get("max", 8000.0)))


func special_ready() -> bool:
	var s := slot("special")
	return not s.is_empty() and (s["weapon"] as Weapon).can_fire()


func camera_look_ahead() -> float:
	return 80.0
