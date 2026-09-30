class_name AirDefense
extends GroundVehicle
## Наземная ПВО, полностью описанная данными GameDB и моделью GroundModels:
##  * пушки (ЗСУ, зенитные орудия): очереди с чередованием стволов, трассеры, неконтактные и дистанционные
##    взрыватели; РЛС или прицел сопровождения — индикатор упреждения по ближайшей воздушной цели;
##  * ЗУР (ЗРК и пушечно-ракетные комплексы): захват цели в конусе прицела за время lock, пуск с
##    направляющих, из контейнеров под фиксированным углом, из поднятых вертикально ТПК или из ячеек
##    вертикального пуска; наведение радиолокационное, радиокомандное (ловушки почти не мешают) или
##    тепловое (ловушки уводят ракету);
##  * вращающиеся антенны РЛС; зенитные орудия на стационарных позициях не двигаются.

var cfg: Dictionary = {}
var guns: Weapon = null
var gun_cfg: Dictionary = {}
var missiles: Weapon = null
var missile_cfg: Dictionary = {}
## ЗУР — основное оружие (ЛКМ), пушки/пулемёт — дополнительное.
var missiles_primary: bool = false
var tracked_target: Vehicle = null
var lead_point: Vector3 = Vector3.ZERO
var lock_target: Vehicle = null
var lock_progress: float = 0.0
## Множитель времени захвата (боты на лёгких уровнях захватывают дольше).
var lock_time_scale: float = 1.0
var track_range: float = 0.0
var missile_range: float = 0.0

var _muzzles: Array[Node3D] = []
var _flashes: Array[MeshInstance3D] = []
var _barrel: int = 0
var _flash_timer: float = 0.0
var _track_timer: float = 0.0
var _scan_timer: float = 0.0
var _beep_timer: float = 0.0
var _radars: Array = []
var _launcher: Node3D = null
var _launch_points: Array[Node3D] = []
var _missile_nodes: Array[Node3D] = []
var _next_point: int = 0
var _launcher_pitch: float = 0.0
var _body_top: float = 2.0


func _build() -> void:
	cfg = GameDB.vehicle_info(vehicle_type)
	max_health = float(cfg.get("hp", 200.0))
	hit_radius = float(cfg.get("hit_radius", 4.0))
	damage_modifiers = {"bullet": 1.0, "flak": 1.0, "missile": 1.0}
	damage_modifiers.merge(cfg.get("armor", {}), true)
	var mv: Dictionary = cfg.get("move", {})
	max_forward_speed = float(mv.get("speed", 14.0))
	max_reverse_speed = float(mv.get("reverse", 5.0))
	acceleration = float(mv.get("accel", 5.0))
	turn_rate = float(mv.get("turn", 1.0))
	wheeled = bool(mv.get("wheeled", false))
	var tr: Dictionary = cfg.get("turret", {})
	turret_yaw_rate = float(tr.get("yaw", 2.0))
	gun_pitch_rate = float(tr.get("pitch", 1.5))
	gun_min_pitch = deg_to_rad(float(tr.get("min", -6.0)))
	gun_max_pitch = deg_to_rad(float(tr.get("max", 85.0)))
	var parts := VehicleModels.build(vehicle_type, team)
	model = parts["root"]
	add_child(model)
	turret = parts.get("turret")
	gun_pivot = parts.get("gun_pivot")
	_launcher = parts.get("launcher")
	_radars = parts.get("radars", [])
	_muzzles.assign(parts.get("muzzles", []))
	_launch_points.assign(parts.get("launch_points", []))
	_missile_nodes.assign(parts.get("missiles", []))
	var body: AABB = parts.get("body_aabb", AABB(Vector3(-1.6, 0.0, -3.0), Vector3(3.2, 2.2, 6.0)))
	_body_top = body.end.y
	_add_box_collision(Vector3(maxf(body.size.x * 0.95, 1.5), maxf(body.size.y, 1.5), maxf(body.size.z * 0.95, 2.0)), body.get_center())
	for m in _muzzles:
		var f := Effects.create_muzzle_flash(float(cfg.get("guns", {}).get("flash", 1.0)))
		m.add_child(f)
		_flashes.append(f)
	weapons.clear()
	if cfg.has("guns"):
		gun_cfg = cfg["guns"]
		guns = Weapon.new("guns", str(gun_cfg.get("name", "Пушка")), -1, float(gun_cfg.get("interval", 0.1)), float(gun_cfg.get("reload", 4.0)), int(gun_cfg.get("magazine", 60)))
		var r := float(cfg.get("radar", 0.0))
		track_range = r if r > 0.0 else float(gun_cfg.get("range", 2000.0)) * 0.6
	if cfg.has("missiles"):
		missile_cfg = cfg["missiles"]
		missiles = Weapon.new("sam", str(missile_cfg.get("name", "ЗУР")), int(missile_cfg.get("count", 4)), float(missile_cfg.get("interval", 2.0)), float(missile_cfg.get("reload", 9.0)))
		missile_range = float(missile_cfg.get("radar", 6000.0))
	missiles_primary = missiles != null and (guns == null or str(cfg.get("primary", "")) == "missiles")
	if missiles_primary:
		weapons.append(missiles)
		if guns != null:
			weapons.append(guns)
	else:
		if guns != null:
			weapons.append(guns)
		if missiles != null:
			weapons.append(missiles)


func _engine_sound_key() -> String:
	return "" if max_forward_speed <= 0.0 else "engine_diesel"


func damage_fx_offset() -> Vector3:
	return Vector3(0.0, _body_top + 0.3, 0.8)


func camera_offset() -> Vector2:
	return cfg.get("camera", Vector2(16.0, 5.0))


func is_static() -> bool:
	return max_forward_speed <= 0.0


func gun_speed() -> float:
	return float(gun_cfg.get("speed", 1000.0))


func gun_drag() -> float:
	return float(gun_cfg.get("drag", 0.0003))


func gun_range() -> float:
	return float(gun_cfg.get("range", 2000.0))


func has_guns() -> bool:
	return guns != null


func has_missiles() -> bool:
	return missiles != null


func missile_guidance() -> String:
	return str(missile_cfg.get("guidance", "radar"))


## Пусковая следит за целью сама (чистые ЗРК); у пушечных комплексов башню ведёт наводчик.
func _turret_aim_point() -> Variant:
	if missiles_primary and lock_target != null and is_instance_valid(lock_target):
		return lock_target.global_position
	return super._turret_aim_point()


func _vehicle_physics(delta: float) -> void:
	super._vehicle_physics(delta)
	for r: Dictionary in _radars:
		var n: Node3D = r["node"]
		if is_instance_valid(n):
			n.rotate_y(delta * float(r.get("speed", 2.0)))
	_update_launcher(delta)


# --- Пусковая установка ЗУР ----------------------------------------------------------------------------
func _update_launcher(delta: float) -> void:
	if _launcher == null or missiles == null:
		return
	var mode := str(missile_cfg.get("launcher", "track"))
	var target_pitch := 0.0
	match mode:
		"fixed":
			target_pitch = deg_to_rad(float(missile_cfg.get("angle", 38.0)))
		"erect":
			# ТПК поднимаются вертикально на стоянке и опускаются для марша.
			target_pitch = PI * 0.5 if absf(speed) < 0.6 else 0.0
		_:
			var aim: Variant = _turret_aim_point()
			if aim != null:
				var to: Vector3 = (aim as Vector3) - _launcher.global_position
				target_pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), deg_to_rad(10.0), deg_to_rad(70.0))
			else:
				target_pitch = deg_to_rad(20.0)
	_launcher_pitch = move_toward(_launcher_pitch, target_pitch, gun_pitch_rate * delta)
	_launcher.rotation = Vector3(_launcher_pitch, 0.0, 0.0)


func _launcher_ready() -> bool:
	if lock_target == null:
		return false
	var mode := str(missile_cfg.get("launcher", "track"))
	match mode:
		"vertical":
			return true
		"erect":
			return _launcher_pitch > PI * 0.5 - 0.03
		"gun":
			return rad_to_deg(gun_direction().angle_to(lock_target.global_position - gun_origin())) < 30.0
	var ref: Node3D = _launcher if _launcher != null else turret
	if ref == null:
		return true
	var fwd := GameDB.flat(-ref.global_basis.z)
	var to_t := GameDB.flat(lock_target.global_position - ref.global_position)
	return rad_to_deg(fwd.angle_to(to_t)) < 25.0


# --- Оружие --------------------------------------------------------------------------------------------
func _handle_weapons(delta: float) -> void:
	var hints := PackedStringArray()
	if guns != null:
		_update_tracking(delta)
		var fire_guns := controls.fire_secondary if missiles_primary else controls.fire_primary
		if fire_guns and guns.can_fire():
			guns.consume()
			_fire_gun()
		if track_range > 0.0 and not missiles_primary:
			hints.append(_tracking_hint())
	if missiles != null:
		_update_lock(delta)
		var fire_missiles := controls.fire_primary if missiles_primary else controls.fire_secondary
		if fire_missiles and missiles.can_fire() and lock_progress >= 1.0 and lock_target != null and _launcher_ready():
			missiles.consume()
			_launch_missile()
		for i in _missile_nodes.size():
			_missile_nodes[i].visible = i < missiles.ammo
		hints.insert(0, _lock_hint())
	hud_hint = " · ".join(hints)
	_flash_timer -= delta
	for f in _flashes:
		if f.visible and _flash_timer <= 0.0:
			f.visible = false


func _update_tracking(delta: float) -> void:
	_track_timer -= delta
	if _track_timer <= 0.0:
		_track_timer = 0.2
		tracked_target = find_target_in_cone(gun_direction(), 25.0, track_range, "air")
	if tracked_target != null and (not is_instance_valid(tracked_target) or tracked_target.is_dead):
		tracked_target = null
	if tracked_target != null:
		lead_point = BallisticSolver.compute_lead(gun_origin(), velocity, tracked_target.global_position, tracked_target.velocity, gun_speed(), gun_drag(), GameDB.GRAVITY)


func _tracking_hint() -> String:
	var src := "РЛС" if float(cfg.get("radar", 0.0)) > 0.0 else "ПРИЦЕЛ"
	if is_static():
		src = "ПУАЗО"
	if tracked_target != null and is_instance_valid(tracked_target):
		return "%s: СОПРОВОЖДЕНИЕ — %s" % [src, GameDB.format_distance(global_position.distance_to(tracked_target.global_position))]
	return "%s: ПОИСК ЦЕЛИ" % src


func _fire_gun() -> void:
	if _muzzles.is_empty():
		return
	var muzzle := _muzzles[_barrel % _muzzles.size()]
	var flash := _flashes[_barrel % _flashes.size()]
	_barrel = (_barrel + 1) % _muzzles.size()
	var p := fire_shell(gun_cfg, muzzle.global_position, gun_direction())
	flash.visible = true
	_flash_timer = 0.04
	if p.blast_radius > 8.0:
		Effects.puff(muzzle.global_position, Color(1.0, 0.75, 0.4, 1.0), 3.0, 0.15)


# --- Захват и пуск ЗУР -----------------------------------------------------------------------------------
func _eye() -> Vector3:
	return global_position + Vector3.UP * (_body_top + 0.8)


func _aim_direction() -> Vector3:
	if controls.has_aim:
		return (controls.aim_point - _eye()).normalized()
	if turret != null:
		return -turret.global_basis.z
	return get_forward()


func _update_lock(delta: float) -> void:
	if lock_target != null and (not is_instance_valid(lock_target) or lock_target.is_dead):
		lock_target = null
		lock_progress = 0.0
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.2
		var eye := _eye()
		var desired: Vehicle = null
		if is_instance_valid(controls.lock_target) and controls.lock_target is Vehicle:
			var preferred := controls.lock_target as Vehicle
			if not preferred.is_dead and preferred.category == GameDB.Category.AIR and not GlobalBattleManager.vehicles_allied(preferred, self):
				if eye.distance_to(preferred.global_position) < missile_range and terrain.line_of_sight(eye, preferred.global_position):
					desired = preferred
		if desired == null:
			desired = find_target_in_cone(_aim_direction(), float(missile_cfg.get("cone", 16.0)), missile_range, "air", Vector3.UP * (_body_top + 0.8))
		if desired == null and lock_target != null:
			if eye.distance_to(lock_target.global_position) < missile_range and terrain.line_of_sight(eye, lock_target.global_position):
				desired = lock_target
		if desired != lock_target:
			lock_target = desired
			lock_progress = 0.0
	if lock_target != null:
		var before := lock_progress
		lock_progress = minf(lock_progress + delta / (float(missile_cfg.get("lock", 1.8)) * lock_time_scale), 1.0)
		if is_player:
			_beep_timer -= delta
			if lock_progress >= 1.0 and before < 1.0:
				SoundFX.play_ui("locked", -8.0)
			elif lock_progress < 1.0 and _beep_timer <= 0.0:
				_beep_timer = 0.3
				SoundFX.play_ui("beep", -14.0)


func _lock_hint() -> String:
	var src := "ИК ГСН" if missile_guidance() == "ir" else "РЛС"
	if missiles.ammo <= 0:
		return "ЗУР: ПЕРЕЗАРЯДКА %d%%" % int(missiles.get_ready_ratio() * 100.0)
	if lock_target != null:
		if lock_progress >= 1.0:
			if str(missile_cfg.get("launcher", "")) == "erect" and not _launcher_ready():
				return "%s: ЦЕЛЬ ЗАХВАЧЕНА — ПОДЪЁМ ТПК" % src
			return "%s: ЦЕЛЬ ЗАХВАЧЕНА — ПУСК РАЗРЕШЁН" % src
		return "%s: ЗАХВАТ %d%%" % [src, int(lock_progress * 100.0)]
	return "%s: НАВЕДИТЕ ПРИЦЕЛ НА ВОЗДУШНУЮ ЦЕЛЬ" % src


func _launch_missile() -> void:
	var point: Node3D = null
	if not _launch_points.is_empty():
		point = _launch_points[_next_point % _launch_points.size()]
		_next_point += 1
	var from := point.global_position if point != null else _eye()
	var dir := -point.global_basis.z if point != null else Vector3.UP
	if bool(missile_cfg.get("vertical", false)) and str(missile_cfg.get("launcher", "")) == "vertical":
		dir = Vector3.UP
	var c := missile_cfg
	var m := GuidedMissile.new()
	m.target = lock_target
	m.mesh_kind = str(c.get("mesh", "sam"))
	m.trail_kind = str(c.get("trail", "large"))
	m.tail_offset = VehicleModels.missile_tail(m.mesh_kind)
	m.thrust = float(c.get("thrust", 170.0))
	m.burn_time = float(c.get("burn", 3.0))
	m.sustain_thrust = float(c.get("sustain", 0.0))
	m.sustain_time = float(c.get("sustain_time", 0.0))
	m.max_speed = float(c.get("max_speed", 1000.0))
	m.max_g = float(c.get("max_g", 26.0))
	m.drag = 0.00003
	m.blast_radius = float(c.get("blast", 15.0))
	m.blast_damage = float(c.get("damage", 200.0))
	m.proximity_radius = float(c.get("prox", 10.0))
	m.max_lifetime = float(c.get("life", 18.0))
	m.seeker_fov_deg = float(c.get("fov", 140.0))
	m.flare_resistance = float(c.get("flare_res", 0.75))
	m.guidance_delay = 0.45 if bool(c.get("vertical", false)) else 0.12
	m.fov_grace = 1.6 if bool(c.get("vertical", false)) else 0.0
	m.velocity = dir * float(c.get("speed0", 40.0)) + velocity
	m.position = from
	m.setup(team, make_source(str(c.get("name", "ЗУР"))), self)
	level.spawn_projectile(m)
	if bool(c.get("vertical", false)):
		Effects.puff(from, Color(0.85, 0.85, 0.8, 0.9), 5.0, 0.6, false)


func get_lock_info() -> Dictionary:
	if lock_target == null or not is_instance_valid(lock_target):
		return {}
	return {"target": lock_target, "progress": lock_progress}


func get_lead_info() -> Dictionary:
	if tracked_target == null or not is_instance_valid(tracked_target) or guns == null:
		return {}
	return {"target": tracked_target, "point": lead_point}


func get_radar_range() -> float:
	return maxf(maxf(missile_range, track_range), 5000.0)


func weapon_labels() -> Dictionary:
	if missiles_primary:
		return {"fire": "ПУСК", "secondary": "ПУЛЕМЁТ" if guns != null else ""}
	return {"fire": "ОГОНЬ", "secondary": "ЗУР" if missiles != null else ""}


func net_aim() -> Variant:
	return _turret_aim_point()


func _puppet_visuals(delta: float) -> void:
	super._puppet_visuals(delta)
	for r: Dictionary in _radars:
		var n: Node3D = r["node"]
		if is_instance_valid(n):
			n.rotate_y(delta * float(r.get("speed", 2.0)))
	_update_launcher(delta)
