class_name Boat
extends Vehicle
## Катер (торпедный, патрульный, штурмовой, безэкипажный), описанный данными GameDB и моделью NavalModels.
## Корпус всегда на уровне моря; занос в поворотах, крен внутрь поворота, у глиссирующих корпусов —
## подъём носа и удары о волну на скорости. Вооружение:
##  * основное — орудийные установки (turret-узлы модели) наводятся на точку прицеливания, стреляет та,
##    что уже довернулась и не упирается в ограничение сектора обстрела;
##  * дополнительное — торпеды вдоль курса или вторая группа установок (гранатомёт, пулемёт);
##  * удар по метке тактической карты — баллистическая ракета, залп реактивных снарядов или ПКР.

var cfg: Dictionary = {}
var max_speed_fwd: float = 25.0
var max_speed_rev: float = 6.0
var accel: float = 7.0
var turn_rate: float = 1.2
var planing: float = 0.8
var heading: float = 0.0
var guns: Weapon = null
var guns2: Weapon = null
var torpedoes: Weapon = null
var special: Weapon = null
var special_cfg: Dictionary = {}

var _drift: Vector3 = Vector3.ZERO
var _roll: float = 0.0
var _bob_time: float = 0.0
var _hull: Node3D = null
var _mounts: Array[Dictionary] = []
var _torpedo_tubes: Array[Node3D] = []
var _special_points: Array[Node3D] = []
var _wakes: Array[GPUParticles3D] = []
var _flashes: Dictionary = {}
var _flash_timer: float = 0.0
var _next_tube: int = 0
var _next_mount: int = 0
var _next_special: int = 0
var _salvo_left: int = 0
var _salvo_timer: float = 0.0
var _salvo_point: Vector3 = Vector3.ZERO
var _length: float = 10.0
var _radars: Array = []
var _body_aabb: AABB = AABB()


func _build() -> void:
	cfg = GameDB.vehicle_info(vehicle_type)
	max_health = float(cfg.get("hp", 140.0))
	hit_radius = float(cfg.get("hit_radius", 6.0))
	damage_modifiers = {"bullet": 0.8, "flak": 0.9}
	damage_modifiers.merge(cfg.get("armor", {}), true)
	var mv: Dictionary = cfg.get("move", {})
	max_speed_fwd = float(mv.get("speed", 25.0))
	max_speed_rev = float(mv.get("reverse", 6.0))
	accel = float(mv.get("accel", 7.0))
	turn_rate = float(mv.get("turn", 1.2))
	planing = float(mv.get("planing", 0.8))
	var parts := VehicleModels.build(vehicle_type, team)
	model = parts["root"]
	add_child(model)
	_hull = parts.get("hull", model)
	for m: Dictionary in parts.get("mounts", []):
		_mounts.append({"yaw": m.get("yaw"), "pitch": m.get("pitch"), "muzzles": m.get("muzzles", []), "arc": m.get("arc", Vector2(-180.0, 180.0)), "weapon": str(m.get("weapon", "guns")), "cur_yaw": wrapf(float(m.get("rest", 0.0)), -PI, PI), "cur_pitch": 0.0, "ready": false, "barrel": 0})
	_torpedo_tubes.assign(parts.get("torpedo_tubes", []))
	_special_points.assign(parts.get("special_points", []))
	_radars = parts.get("radars", [])
	for wp: Node3D in parts.get("wake_points", []):
		var w := Effects.create_wake()
		wp.add_child(w)
		_wakes.append(w)
	var body: AABB = parts.get("body_aabb", AABB(Vector3(-2.0, -1.0, -5.0), Vector3(4.0, 3.0, 10.0)))
	_body_aabb = body
	_length = body.size.z
	_add_box_collision(Vector3(maxf(body.size.x, 2.5), maxf(body.size.y, 2.5), body.size.z + 2.0), body.get_center())
	for m: Dictionary in _mounts:
		for mz: Node3D in m["muzzles"]:
			var gc: Dictionary = cfg.get(str(m["weapon"]), {})
			var f := Effects.create_muzzle_flash(float(gc.get("flash", 0.8)))
			mz.add_child(f)
			_flashes[mz] = f
	weapons.clear()
	if cfg.has("guns"):
		var g: Dictionary = cfg["guns"]
		guns = Weapon.new("guns", str(g.get("name", "Пулемёт")), -1, float(g.get("interval", 0.08)), float(g.get("reload", 3.5)), int(g.get("magazine", 100)))
		weapons.append(guns)
	if cfg.has("torpedoes"):
		var t: Dictionary = cfg["torpedoes"]
		torpedoes = Weapon.new("torpedo", str(t.get("name", "Торпеды")), int(t.get("count", 2)), float(t.get("interval", 1.2)), float(t.get("reload", 16.0)))
		weapons.append(torpedoes)
	if cfg.has("guns2"):
		var g2: Dictionary = cfg["guns2"]
		guns2 = Weapon.new("guns2", str(g2.get("name", "Пулемёт")), -1, float(g2.get("interval", 0.08)), float(g2.get("reload", 3.5)), int(g2.get("magazine", 100)))
		weapons.append(guns2)
	if cfg.has("special"):
		special_cfg = cfg["special"]
		special = Weapon.new("special", str(special_cfg.get("name", "Ракета")), int(special_cfg.get("count", 1)), float(special_cfg.get("interval", 1.0)), float(special_cfg.get("reload", 40.0)))
		weapons.append(special)


func _after_build() -> void:
	heading = GameDB.yaw_of(-global_basis.z)
	global_position = Vector3(global_position.x, 0.0, global_position.z)
	spawn_protection = 3.0


func _engine_sound_key() -> String:
	return "engine_boat"


func _engine_pitch() -> float:
	return 0.75 + absf(speed) / max_speed_fwd * 0.6


func damage_fx_offset() -> Vector3:
	return Vector3(0.0, 1.8, _length * 0.15)


func camera_offset() -> Vector2:
	return cfg.get("camera", Vector2(15.0, 4.5))


# --- Движение ------------------------------------------------------------------------------------------
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
	_animate_hull(delta, steer)


func _puppet_visuals(delta: float) -> void:
	_animate_hull(delta, 0.0)


## Крен, подъём носа и качка корпуса, кильватер, антенны, наведение установок.
func _animate_hull(delta: float, steer: float) -> void:
	_bob_time += delta
	var speed_k := clampf(absf(speed) / max_speed_fwd, 0.0, 1.0)
	var rise := speed_k * planing
	_roll = lerpf(_roll, -steer * speed_k * lerpf(0.08, 0.22, planing), clampf(delta * 3.0, 0.0, 1.0))
	var slam := sin(_bob_time * 5.3) * 0.012 * rise
	_hull.rotation = Vector3(rise * 0.07 + sin(_bob_time * 1.7) * 0.02 + slam, 0.0, _roll + sin(_bob_time * 1.3) * 0.03)
	_hull.position = Vector3(0.0, sin(_bob_time * 2.1) * 0.12 + rise * 0.28, 0.0)
	for w in _wakes:
		w.emitting = absf(speed) > 3.0
	for r: Dictionary in _radars:
		var n: Node3D = r["node"]
		if is_instance_valid(n):
			n.rotate_y(delta * float(r.get("speed", 2.0)))
	_update_mounts(delta)


## Наведение установок на точку прицеливания с учётом секторов обстрела.
func _update_mounts(delta: float) -> void:
	for m: Dictionary in _mounts:
		var yaw_node: Node3D = m["yaw"]
		var pitch_node: Node3D = m["pitch"]
		if yaw_node == null or not is_instance_valid(yaw_node):
			continue
		var gc: Dictionary = cfg.get(str(m["weapon"]), {})
		var ready := false
		if controls.has_aim:
			var parent := yaw_node.get_parent() as Node3D
			var origin := pitch_node.global_position if pitch_node != null else yaw_node.global_position
			var dir := controls.aim_point - origin
			if bool(gc.get("lob", false)):
				var sol := BallisticSolver.solve_direction(origin, controls.aim_point, float(gc.get("speed", 240.0)), GameDB.GRAVITY)
				if sol != Vector3.ZERO:
					dir = sol
			var local := parent.global_basis.inverse() * dir
			var desired_yaw := atan2(-local.x, -local.z)
			var arc: Vector2 = m["arc"]
			var in_arc := Warship._yaw_in_arc(desired_yaw, arc)
			var target_yaw := desired_yaw if in_arc else Warship._nearest_arc_edge(desired_yaw, arc)
			var desired_pitch := clampf(atan2(local.y, Vector2(local.x, local.z).length()), deg_to_rad(-10.0), deg_to_rad(float(gc.get("max_pitch", 70.0))))
			var cy: float = m["cur_yaw"]
			var cp: float = m["cur_pitch"]
			cy = Warship._turn_within_arc(cy, target_yaw, 3.0 * delta, arc)
			cp += clampf(desired_pitch - cp, -2.0 * delta, 2.0 * delta)
			m["cur_yaw"] = cy
			m["cur_pitch"] = cp
			ready = in_arc and absf(wrapf(desired_yaw - cy, -PI, PI)) < deg_to_rad(4.0) and absf(desired_pitch - cp) < deg_to_rad(4.0)
		yaw_node.rotation = Vector3(0.0, float(m["cur_yaw"]), 0.0)
		if pitch_node != null and pitch_node != yaw_node:
			pitch_node.rotation = Vector3(float(m["cur_pitch"]), 0.0, 0.0)
		m["ready"] = ready


func _mount_dir(m: Dictionary) -> Vector3:
	var n: Node3D = m["pitch"] if m["pitch"] != null else m["yaw"]
	return -n.global_basis.z


## Направление первой установки основного оружия (для ИИ и прицела).
func gun_direction() -> Vector3:
	for m in _mounts:
		if str(m["weapon"]) == "guns":
			return _mount_dir(m)
	return get_forward()


func gun_origin() -> Vector3:
	for m in _mounts:
		if str(m["weapon"]) == "guns":
			var n: Node3D = m["pitch"] if m["pitch"] != null else m["yaw"]
			return n.global_position
	return global_position + Vector3.UP * 2.0


func gun_speed() -> float:
	return float(cfg.get("guns", {}).get("speed", 850.0))


func gun_drag() -> float:
	return float(cfg.get("guns", {}).get("drag", 0.0005))


func gun_range() -> float:
	return float(cfg.get("guns", {}).get("range", 1100.0))


## Хотя бы одна установка основного оружия довернулась на цель.
func guns_ready() -> bool:
	for m in _mounts:
		if str(m["weapon"]) == "guns" and bool(m["ready"]):
			return true
	return false


# --- Оружие --------------------------------------------------------------------------------------------
func _handle_weapons(delta: float) -> void:
	if controls.fire_primary and guns != null and guns.can_fire():
		_fire_group("guns", guns)
	if controls.fire_secondary:
		if torpedoes != null and torpedoes.can_fire():
			torpedoes.consume()
			_launch_torpedo()
		elif guns2 != null and guns2.can_fire():
			_fire_group("guns2", guns2)
	if controls.fire_special and special != null and special.can_fire():
		_try_special(controls.special_target)
	_update_salvo(delta)
	_flash_timer -= delta
	if _flash_timer <= 0.0:
		for f: MeshInstance3D in _flashes.values():
			f.visible = false
	if special != null:
		var label := str(special_cfg.get("name", "Удар"))
		hud_hint = ("%s: ГОТОВО (G — тактическая карта)" % label.to_upper()) if special.can_fire() else ("%s: ПЕРЕЗАРЯДКА %d%%" % [label.to_upper(), int(special.get_ready_ratio() * 100.0)])
	elif torpedoes != null:
		hud_hint = "ТОРПЕДЫ: %d — пуск по курсу катера" % torpedoes.ammo
	else:
		hud_hint = ""


## Выстрел из следующей довернувшейся установки группы (по кругу).
func _fire_group(group: String, w: Weapon) -> void:
	var n := _mounts.size()
	for i in n:
		var m: Dictionary = _mounts[(_next_mount + i) % n]
		if str(m["weapon"]) != group or not bool(m["ready"]):
			continue
		var muzzles: Array = m["muzzles"]
		if muzzles.is_empty():
			continue
		_next_mount = (_next_mount + i + 1) % n
		var b: int = m["barrel"]
		var mz: Node3D = muzzles[b % muzzles.size()]
		m["barrel"] = b + 1
		w.consume()
		var gc: Dictionary = cfg.get(group, {})
		fire_shell(gc, mz.global_position, _mount_dir(m))
		var f: MeshInstance3D = _flashes.get(mz)
		if f != null:
			f.visible = true
		_flash_timer = 0.04
		return


func _launch_torpedo() -> void:
	var from := global_position + get_forward() * 2.0
	if not _torpedo_tubes.is_empty():
		from = _torpedo_tubes[_next_tube % _torpedo_tubes.size()].global_position
		_next_tube += 1
	var t := Torpedo.new()
	t.velocity = get_forward() * 20.0
	t.position = Vector3(from.x, minf(from.y, 0.6), from.z)
	t.setup(team, make_source(str(cfg.get("torpedoes", {}).get("name", "Торпеда"))), self)
	level.spawn_projectile(t)


func _special_origin() -> Vector3:
	if _special_points.is_empty():
		return global_position + Vector3.UP * 2.0
	return _special_points[_next_special % _special_points.size()].global_position


## Проверка дальности удара по точке.
func can_strike(point: Vector3) -> bool:
	var r := get_special_range()
	var d := GameDB.flat_distance(global_position, point)
	return d >= r.x and d <= r.y


func _try_special(point: Vector3) -> void:
	if not can_strike(point):
		return
	var kind := str(special_cfg.get("type", "ballistic"))
	var from := _special_origin()
	match kind:
		"ballistic":
			var v0 := BallisticMissile.solve(from, point)
			if v0 == Vector3.ZERO:
				return
			special.consume()
			_next_special += 1
			var m := BallisticMissile.new()
			m.target_point = point
			m.velocity = v0
			m.position = from
			m.setup(team, make_source(str(special_cfg.get("name", "Баллистическая ракета"))), self)
			level.spawn_projectile(m)
		"rockets":
			if BallisticMissile.solve_rocket(from, point) == Vector3.ZERO:
				return
			special.consume()
			_salvo_left = int(special_cfg.get("salvo", 8))
			_salvo_timer = 0.0
			_salvo_point = point
		"cruise":
			special.consume()
			_next_special += 1
			var cm := CruiseMissile.new()
			cm.target_point = point
			cm.direct = bool(special_cfg.get("direct", false))
			cm.blast_radius = float(special_cfg.get("blast", cm.blast_radius))
			cm.blast_damage = float(special_cfg.get("damage", cm.blast_damage))
			var dir := -_special_points[(_next_special - 1) % _special_points.size()].global_basis.z if not _special_points.is_empty() else (get_forward() + Vector3.UP).normalized()
			cm.velocity = dir * 60.0 + velocity
			cm.position = from
			cm.setup(team, make_source(str(special_cfg.get("name", "Ракета"))), self)
			level.spawn_projectile(cm)
			Effects.puff(from, Color(0.9, 0.9, 0.85, 0.9), 4.0, 0.5, false)


## Залп реактивных снарядов: по одному через 0,12 с с разбросом по точке.
func _update_salvo(delta: float) -> void:
	if _salvo_left <= 0:
		return
	_salvo_timer -= delta
	if _salvo_timer > 0.0:
		return
	_salvo_timer = 0.12
	_salvo_left -= 1
	var from := _special_origin()
	_next_special += 1
	var spread := GameDB.flat_distance(from, _salvo_point) * 0.012
	var aim := _salvo_point + Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)) * spread
	var v0 := BallisticMissile.solve_rocket(from, aim)
	if v0 == Vector3.ZERO:
		return
	var r := BallisticMissile.new()
	r.rocket = true
	r.target_point = aim
	r.velocity = v0
	r.position = from
	r.blast_radius = float(special_cfg.get("blast", 12.0))
	r.blast_damage = float(special_cfg.get("damage", 110.0))
	r.setup(team, make_source(str(special_cfg.get("name", "РС"))), self)
	level.spawn_projectile(r)


func get_special_range() -> Vector2:
	if special == null:
		return Vector2.ZERO
	return Vector2(float(special_cfg.get("min", 600.0)), float(special_cfg.get("max", 9000.0)))


func get_special_origin() -> Vector3:
	return _special_origin()


func special_ready() -> bool:
	return special != null and special.can_fire() and _salvo_left <= 0


func get_special_blast() -> float:
	match str(special_cfg.get("type", "")):
		"ballistic":
			return 38.0
		"rockets":
			return 30.0
	return 24.0


func get_special_arc(origin: Vector3, point: Vector3) -> Dictionary:
	match str(special_cfg.get("type", "")):
		"ballistic":
			var v0 := BallisticMissile.solve(origin, point)
			if v0 == Vector3.ZERO:
				return {}
			return {"points": BallisticMissile.predict(origin, v0, level.terrain), "eta": BallisticMissile.flight_time(origin, v0, point.y)}
		"rockets":
			var v1 := BallisticMissile.solve_rocket(origin, point)
			if v1 == Vector3.ZERO:
				return {}
			return {"points": BallisticMissile.predict_rocket(origin, v1, level.terrain), "eta": BallisticMissile.flight_time_rocket(origin, v1, point.y)}
	return super.get_special_arc(origin, point)


func weapon_labels() -> Dictionary:
	var sec := ""
	if torpedoes != null:
		sec = "ТОРПЕДА"
	elif guns2 != null:
		sec = "ГРАНАТЫ" if bool(cfg.get("guns2", {}).get("lob", false)) else "ПУЛЕМЁТ"
	var sp := ""
	match str(special_cfg.get("type", "")):
		"ballistic":
			sp = "БАЛЛИСТ."
		"rockets":
			sp = "ЗАЛП РС"
		"cruise":
			sp = "РАКЕТЫ"
	return {"fire": "ОГОНЬ", "secondary": sec, "special": sp}


func _on_destroyed() -> void:
	Effects.explosion(global_position + Vector3(0.0, 1.0, 0.0), 12.0 + _length * 0.2, true)
	if model != null:
		Effects.spawn_model_wreck(model, true)


## Вид от первого лица — с ходового поста, вместе с качкой корпуса.
func first_person_point() -> Vector3:
	var a := _body_aabb
	var eye := Vector3(0.0, maxf(a.end.y * 0.8, 1.9), a.position.z + a.size.z * 0.4)
	return _hull.get_global_transform_interpolated() * eye
