class_name Warship
extends Vehicle
## Боевой корабль (эсминец, ракетный катер) под управлением игрока или бота, а также флагман команды —
## стратегическая цель под встроенным ИИ (autonomous: медленно патрулирует у своей ВМБ, не занимает слот).
## Вооружение из данных GameDB и узлов модели NavalModels:
##  * главный калибр — башни с баллистическим наведением на точку прицеливания (основное оружие);
##  * зенитная артиллерия / ЗАК — всегда автоматически: сначала перехват подлетающих ПКР и баллистических
##    ракет, затем авиация (с упреждением);
##  * дополнительное — торпедные аппараты (веер по направлению прицела) или ЗУР с захватом цели;
##  * удар по метке тактической карты — противокорабельные крылатые ракеты.

const MISSILE_DEFENSE_RANGE := 1300.0

var cfg: Dictionary = {}
var autonomous: bool = false
var anchor: Vector3 = Vector3.ZERO
var patrol_radius: float = 260.0
var cruise_speed: float = 5.0
var max_speed_fwd: float = 16.0
var max_speed_rev: float = 5.0
var accel: float = 1.3
var turn_rate: float = 0.13
var heading: float = 0.0
var main_weapon: Weapon = null
var aa_weapon: Weapon = null
var torpedoes: Weapon = null
var sam: Weapon = null
var special: Weapon = null
var lock_target: Vehicle = null
var lock_progress: float = 0.0
var lock_time_scale: float = 1.0
## Цель главного калибра для ИИ (флагман, бот): точка прицеливания ставится автоматически.
var gun_target: Node3D = null

var _hull: Node3D = null
var _main: Array[Dictionary] = []
var _aa: Array[Dictionary] = []
var _torpedo_mounts: Array[Dictionary] = []
var _sam_points: Array[Node3D] = []
var _special_points: Array[Node3D] = []
var _radars: Array = []
var _wakes: Array[GPUParticles3D] = []
var _angle: float = 0.0
var _bob_time: float = 0.0
var _roll: float = 0.0
var _think: float = 0.0
var _aa_target: Vehicle = null
var _missile_threat: Projectile = null
var _last_aim: Variant = null
var _aa_index: int = 0
var _main_index: int = 0
var _next_tube: int = 0
var _next_sam: int = 0
var _next_special: int = 0
var _scan_timer: float = 0.0
var _beep_timer: float = 0.0
var _auto_sam_timer: float = 6.0
var _length: float = 100.0
var _beam: float = 12.0
var _deck: float = 5.0


func _build() -> void:
	cfg = GameDB.vehicle_info(vehicle_type)
	autonomous = autonomous or GameDB.is_flagship(vehicle_type)
	max_health = float(cfg.get("hp", 1500.0))
	hit_radius = float(cfg.get("hit_radius", 12.0))
	damage_modifiers = {"bullet": 0.1, "flak": 0.15, "missile": 0.55, "shell": 0.55, "torpedo": 1.3, "cruise": 0.8, "bomb": 0.9, "ballistic": 0.6}
	damage_modifiers.merge(cfg.get("armor", {}), true)
	var mv: Dictionary = cfg.get("move", {})
	max_speed_fwd = float(mv.get("speed", 16.0))
	max_speed_rev = float(mv.get("reverse", 5.0))
	accel = float(mv.get("accel", 1.3))
	turn_rate = float(mv.get("turn", 0.13))
	cruise_speed = minf(max_speed_fwd, 5.0)
	var parts := VehicleModels.build(vehicle_type, team)
	model = parts["root"]
	add_child(model)
	_hull = parts.get("hull", model)
	for m: Dictionary in parts.get("main", []):
		_main.append(_mount_entry(m))
	for m: Dictionary in parts.get("aa", []):
		_aa.append(_mount_entry(m))
	for tm: Dictionary in parts.get("torpedo_mounts", []):
		_torpedo_mounts.append({"yaw": tm.get("yaw"), "tubes": tm.get("tubes", []), "cur": 0.0, "rest": float(tm.get("rest", 0.0))})
	_sam_points.assign(parts.get("sam_points", []))
	_special_points.assign(parts.get("special_points", []))
	_radars = parts.get("radars", [])
	for wp: Node3D in parts.get("wake_points", []):
		var w := Effects.create_wake()
		w.amount = maxi(int(float(w.amount) * 1.6), 12)
		wp.add_child(w)
		_wakes.append(w)
	var body: AABB = parts.get("body_aabb", AABB(Vector3(-6.0, -4.0, -50.0), Vector3(12.0, 16.0, 100.0)))
	_length = body.size.z
	_beam = body.size.x
	_deck = clampf(body.end.y * 0.45, 2.0, 12.0)
	_add_box_collision(Vector3(body.size.x, maxf(body.size.y, 6.0), body.size.z), body.get_center())
	weapons.clear()
	if cfg.has("main"):
		var mc: Dictionary = cfg["main"]
		main_weapon = Weapon.new("main", str(mc.get("name", "Главный калибр")), -1, float(mc.get("interval", 1.5)) / float(maxi(_main.size(), 1)), 3.0, 1000)
		weapons.append(main_weapon)
	if cfg.has("torpedoes"):
		var tc: Dictionary = cfg["torpedoes"]
		torpedoes = Weapon.new("torpedo", str(tc.get("name", "Торпеды")), int(tc.get("count", 4)), float(tc.get("interval", 0.6)), float(tc.get("reload", 25.0)))
		weapons.append(torpedoes)
	if cfg.has("sam"):
		var sc: Dictionary = cfg["sam"]
		sam = Weapon.new("sam", str(sc.get("name", "ЗУР")), int(sc.get("count", 6)), float(sc.get("interval", 1.5)), float(sc.get("reload", 12.0)))
		weapons.append(sam)
	if cfg.has("special"):
		var spc: Dictionary = cfg["special"]
		special = Weapon.new("special", str(spc.get("name", "ПКР")), int(spc.get("count", 4)), float(spc.get("interval", 1.2)), float(spc.get("reload", 35.0)))
		weapons.append(special)
	if cfg.has("aa"):
		var ac: Dictionary = cfg["aa"]
		aa_weapon = Weapon.new("aa", str(ac.get("name", "ЗАК")) + " (авто)", -1, float(ac.get("interval", 0.06)), 2.5, 80)
		weapons.append(aa_weapon)


func _mount_entry(m: Dictionary) -> Dictionary:
	var rest := wrapf(float(m.get("rest", 0.0)), -PI, PI)
	return {"yaw": m.get("yaw"), "pitch": m.get("pitch"), "muzzles": m.get("muzzles", []), "arc": m.get("arc", Vector2(-180.0, 180.0)), "cur_yaw": rest, "cur_pitch": 0.0, "ready": false, "barrel": 0}


func _after_build() -> void:
	heading = GameDB.yaw_of(-global_basis.z)
	global_position = Vector3(global_position.x, 0.0, global_position.z)
	if autonomous:
		if anchor == Vector3.ZERO:
			anchor = global_position
		_angle = atan2(global_position.z - anchor.z, global_position.x - anchor.x)
		spawn_protection = 0.0
	else:
		spawn_protection = 4.0


func _engine_sound_key() -> String:
	return "" if autonomous else "engine_boat"


func _engine_pitch() -> float:
	return 0.45 + absf(speed) / maxf(max_speed_fwd, 1.0) * 0.35


func damage_fx_offset() -> Vector3:
	return Vector3(0.0, _deck + 3.0, _length * 0.12)


func camera_offset() -> Vector2:
	return cfg.get("camera", Vector2(80.0, 24.0))


# --- Движение ------------------------------------------------------------------------------------------
func _vehicle_physics(delta: float) -> void:
	if autonomous:
		_patrol(delta)
	else:
		_steer(delta)
	_animate_hull(delta)


func _puppet_visuals(delta: float) -> void:
	_animate_hull(delta)
	_update_main(delta, controls.aim_point if controls.has_aim else null)


func net_aim() -> Variant:
	return _last_aim


## Качка и крен корпуса, кильватер, вращение антенн.
func _animate_hull(delta: float) -> void:
	_bob_time += delta
	var speed_k := clampf(absf(speed) / maxf(max_speed_fwd, 1.0), 0.0, 1.0)
	# Водоизмещающий корпус кренится наружу поворота, мерно качается на волне.
	_roll = lerpf(_roll, controls.steer * speed_k * 0.05 if not autonomous else 0.0, clampf(delta * 0.8, 0.0, 1.0))
	_hull.rotation = Vector3(sin(_bob_time * 0.6) * 0.006 + speed_k * 0.008, 0.0, _roll + sin(_bob_time * 0.45) * 0.012)
	_hull.position = Vector3(0.0, sin(_bob_time * 0.7) * 0.18, 0.0)
	for w in _wakes:
		w.emitting = absf(speed) > 2.0
	for r: Dictionary in _radars:
		var n: Node3D = r["node"]
		if is_instance_valid(n):
			n.rotate_y(delta * float(r.get("speed", 1.5)))


func _patrol(delta: float) -> void:
	_angle += delta * cruise_speed / patrol_radius
	var target := anchor + Vector3(cos(_angle), 0.0, sin(_angle)) * patrol_radius
	var to_t := GameDB.flat(target - global_position)
	if to_t.length() > 1.0:
		heading = lerp_angle(heading, GameDB.yaw_of(to_t), clampf(delta * 0.35, 0.0, 1.0))
	var fwd := Vector3(-sin(heading), 0.0, -cos(heading))
	speed = cruise_speed
	var next := global_position + fwd * speed * delta
	global_transform = Transform3D(Basis(Vector3.UP, heading), Vector3(next.x, 0.0, next.z))
	velocity = fwd * speed


func _steer(delta: float) -> void:
	var c := controls
	var target_speed := c.throttle * (max_speed_fwd if c.throttle >= 0.0 else max_speed_rev)
	speed = move_toward(speed, target_speed, accel * delta)
	var turn_eff := clampf(absf(speed) / 6.0, 0.15, 1.0)
	var steer := c.steer if speed >= -0.3 else -c.steer
	heading = wrapf(heading - steer * turn_rate * turn_eff * delta, -PI, PI)
	var fwd := Vector3(-sin(heading), 0.0, -cos(heading))
	var pos := global_position
	var next := pos + fwd * speed * delta
	next.y = 0.0
	if absf(speed) > 0.05 and not _water_ok(next, fwd):
		speed = move_toward(speed, 0.0, accel * 3.0 * delta) * 0.5
		next = pos
	global_transform = Transform3D(Basis(Vector3.UP, heading), next)
	velocity = fwd * speed


## Корпус целиком на достаточной глубине (нос, середина, корма).
func _water_ok(p: Vector3, fwd: Vector3) -> bool:
	var half := _length * 0.5 * signf(speed if speed != 0.0 else 1.0)
	var margin := _beam * 0.5 + 4.0
	for k: float in [1.0, 0.0, -0.8]:
		var q := p + fwd * half * k
		if not terrain.is_navigable(q.x, q.z, margin):
			return false
	return true


# --- Оружие --------------------------------------------------------------------------------------------
func _handle_weapons(delta: float) -> void:
	_think -= delta
	if _think <= 0.0:
		_think = 0.4
		_select_targets()
	_update_aa(delta)
	var aim: Variant = null
	if autonomous:
		aim = _auto_gun_aim()
	elif controls.has_aim:
		aim = controls.aim_point
	_last_aim = aim
	_update_main(delta, aim)
	var fire_main := controls.fire_primary
	if autonomous:
		fire_main = aim != null
	if fire_main and main_weapon != null and main_weapon.can_fire():
		_fire_main()
	if sam != null:
		if autonomous:
			_auto_sam(delta)
		else:
			_update_lock(delta)
			if controls.fire_secondary and sam.can_fire() and lock_progress >= 1.0 and lock_target != null:
				sam.consume()
				_launch_sam(lock_target)
	if torpedoes != null and not autonomous:
		_update_torpedo_mounts(delta)
		if controls.fire_secondary and torpedoes.can_fire() and controls.has_aim:
			torpedoes.consume()
			_launch_torpedo()
	if special != null and controls.fire_special and special.can_fire():
		_launch_special(controls.special_target)
	_update_hint()


func _select_targets() -> void:
	_aa_target = null
	_missile_threat = null
	var ac: Dictionary = cfg.get("aa", {})
	var aa_range := float(ac.get("range", 1500.0))
	var best_d := aa_range
	for v in GlobalBattleManager.enemies_in_radius(team, global_position, aa_range, GameDB.Category.AIR, participant_id):
		var d := global_position.distance_to(v.global_position)
		if d < best_d:
			best_d = d
			_aa_target = v
	if level != null:
		var best_m := MISSILE_DEFENSE_RANGE
		for p in level.projectiles_root.get_children():
			if not (p is CruiseMissile or p is BallisticMissile):
				continue
			var proj := p as Projectile
			if GlobalBattleManager.are_allies(proj.team, proj.owner_pid(), team, participant_id):
				continue
			var dm := global_position.distance_to(proj.global_position)
			if dm < best_m:
				best_m = dm
				_missile_threat = proj
	if autonomous:
		gun_target = null
		var mc: Dictionary = cfg.get("main", {})
		var gun_range := float(mc.get("range", 3000.0))
		best_d = gun_range
		for v in GlobalBattleManager.enemies_in_radius(team, global_position, gun_range, -1, participant_id):
			if v.category == GameDB.Category.AIR:
				continue
			var d := global_position.distance_to(v.global_position) * (0.7 if v.category == GameDB.Category.NAVAL else 1.0)
			if d < best_d and terrain.line_of_sight(global_position + Vector3.UP * 10.0, v.global_position + Vector3.UP * 2.0):
				best_d = d
				gun_target = v


## Точка прицеливания главного калибра по цели ИИ с упреждением.
func _auto_gun_aim() -> Variant:
	if gun_target == null or not is_instance_valid(gun_target):
		gun_target = null
		return null
	if gun_target is Vehicle and (gun_target as Vehicle).is_dead:
		gun_target = null
		return null
	var mc: Dictionary = cfg.get("main", {})
	var from := gun_origin()
	var tp := gun_target.global_position
	var tv := (gun_target as Vehicle).velocity if gun_target is Vehicle else Vector3.ZERO
	var t := from.distance_to(tp) / float(mc.get("speed", 800.0))
	return tp + tv * t * 1.15


func _update_main(delta: float, aim: Variant) -> void:
	var mc: Dictionary = cfg.get("main", {})
	var shell_speed := float(mc.get("speed", 800.0))
	for m in _main:
		var yaw_node: Node3D = m["yaw"]
		var pitch_node: Node3D = m["pitch"]
		if yaw_node == null or not is_instance_valid(yaw_node):
			continue
		var ready := false
		if aim != null:
			var aim_point: Vector3 = aim
			var origin := pitch_node.global_position if pitch_node != null else yaw_node.global_position
			var dir := BallisticSolver.solve_direction(origin, aim_point, shell_speed, GameDB.GRAVITY)
			if dir == Vector3.ZERO:
				dir = (aim_point - origin).normalized()
			var parent := yaw_node.get_parent() as Node3D
			var local := parent.global_basis.inverse() * dir
			var desired_yaw := atan2(-local.x, -local.z)
			var arc: Vector2 = m["arc"]
			var in_arc := _yaw_in_arc(desired_yaw, arc)
			var target_yaw := desired_yaw if in_arc else _nearest_arc_edge(desired_yaw, arc)
			var desired_pitch := clampf(atan2(local.y, Vector2(local.x, local.z).length()), deg_to_rad(-5.0), deg_to_rad(float(mc.get("max_pitch", 45.0))))
			var cy: float = m["cur_yaw"]
			cy = _turn_within_arc(cy, target_yaw, 0.55 * delta, arc)
			var cp: float = m["cur_pitch"]
			cp += clampf(desired_pitch - cp, -0.45 * delta, 0.45 * delta)
			m["cur_yaw"] = cy
			m["cur_pitch"] = cp
			ready = in_arc and absf(wrapf(desired_yaw - cy, -PI, PI)) < deg_to_rad(2.5) and absf(desired_pitch - cp) < deg_to_rad(2.0)
		yaw_node.rotation = Vector3(0.0, float(m["cur_yaw"]), 0.0)
		if pitch_node != null and pitch_node != yaw_node:
			pitch_node.rotation = Vector3(float(m["cur_pitch"]), 0.0, 0.0)
		m["ready"] = ready


static func _yaw_in_arc(yaw: float, arc: Vector2) -> bool:
	if arc.y - arc.x >= 359.0:
		return true
	var y := rad_to_deg(wrapf(yaw, -PI, PI))
	if arc.x <= arc.y:
		return y >= arc.x and y <= arc.y
	return y >= arc.x or y <= arc.y


static func _nearest_arc_edge(yaw: float, arc: Vector2) -> float:
	var a := deg_to_rad(arc.x)
	var b := deg_to_rad(arc.y)
	return a if absf(wrapf(yaw - a, -PI, PI)) < absf(wrapf(yaw - b, -PI, PI)) else b


## Поворот установки к target с ограниченной скоростью, не проходя через запретный сектор.
static func _turn_within_arc(cur: float, target: float, step: float, arc: Vector2) -> float:
	if arc.y - arc.x >= 359.0:
		return wrapf(cur + clampf(wrapf(target - cur, -PI, PI), -step, step), -PI, PI)
	var lo := deg_to_rad(arc.x)
	var hi := deg_to_rad(arc.y)
	if arc.x <= arc.y:
		return clampf(cur + clampf(target - cur, -step, step), lo, hi)
	# Сектор через корму (±180°): считаем в развёрнутой шкале [lo, hi + 2π].
	var c := cur if cur >= lo else cur + TAU
	var t := target if target >= lo else target + TAU
	return wrapf(clampf(c + clampf(t - c, -step, step), lo, hi + TAU), -PI, PI)


func _mount_dir(m: Dictionary) -> Vector3:
	var n: Node3D = m["pitch"] if m["pitch"] != null else m["yaw"]
	return -n.global_basis.z


func _fire_main() -> void:
	var n := _main.size()
	for i in n:
		var m: Dictionary = _main[(_main_index + i) % n]
		if not bool(m["ready"]):
			continue
		var muzzles: Array = m["muzzles"]
		if muzzles.is_empty():
			continue
		_main_index = (_main_index + i + 1) % n
		main_weapon.consume()
		var mc: Dictionary = cfg.get("main", {})
		# Залп установки: все стволы башни.
		for mz: Node3D in muzzles:
			fire_shell(mc, mz.global_position, _mount_dir(m))
			Effects.puff(mz.global_position, Color(1.0, 0.75, 0.4, 1.0), 3.5, 0.15)
		SoundFX.play_3d("cannon", (muzzles[0] as Node3D).global_position, 5.0, 0.5, 70.0)
		return


## Зенитная артиллерия и ЗАК: приоритет — перехват подлетающих ПКР и баллистических ракет, затем авиация.
func _update_aa(delta: float) -> void:
	if aa_weapon == null or _aa.is_empty():
		return
	if _aa_target != null and (not is_instance_valid(_aa_target) or _aa_target.is_dead):
		_aa_target = null
	if _missile_threat != null and not is_instance_valid(_missile_threat):
		_missile_threat = null
	var aim_pos := Vector3.ZERO
	var aim_vel := Vector3.ZERO
	var anti_missile := false
	if _missile_threat != null:
		aim_pos = _missile_threat.global_position
		aim_vel = _missile_threat.velocity
		anti_missile = true
	elif _aa_target != null:
		aim_pos = _aa_target.global_position
		aim_vel = _aa_target.velocity
	else:
		return
	var ac: Dictionary = cfg.get("aa", {})
	var shell_speed := float(ac.get("speed", 900.0))
	var fired := false
	for i in _aa.size():
		var m: Dictionary = _aa[i]
		var yaw_node: Node3D = m["yaw"]
		var pitch_node: Node3D = m["pitch"]
		if yaw_node == null or not is_instance_valid(yaw_node):
			continue
		var origin := pitch_node.global_position if pitch_node != null else yaw_node.global_position
		var lead := BallisticSolver.compute_lead(origin, velocity, aim_pos, aim_vel, shell_speed, 0.0003, GameDB.GRAVITY)
		var parent := yaw_node.get_parent() as Node3D
		var local := parent.global_basis.inverse() * (lead - origin)
		var desired_yaw := atan2(-local.x, -local.z)
		var arc: Vector2 = m["arc"]
		var in_arc := _yaw_in_arc(desired_yaw, arc)
		var cy: float = m["cur_yaw"]
		cy = _turn_within_arc(cy, desired_yaw if in_arc else _nearest_arc_edge(desired_yaw, arc), 4.0 * delta, arc)
		m["cur_yaw"] = cy
		yaw_node.rotation = Vector3(0.0, cy, 0.0)
		var cp: float = m["cur_pitch"]
		var desired_pitch := clampf(atan2(local.y, Vector2(local.x, local.z).length()), deg_to_rad(-5.0), deg_to_rad(85.0))
		cp += clampf(desired_pitch - cp, -3.0 * delta, 3.0 * delta)
		m["cur_pitch"] = cp
		if pitch_node != null and pitch_node != yaw_node:
			pitch_node.rotation = Vector3(cp, 0.0, 0.0)
		if fired or i != _aa_index or not in_arc or not aa_weapon.can_fire():
			continue
		var dir := _mount_dir(m)
		if rad_to_deg(dir.angle_to(lead - origin)) > 4.0:
			continue
		var muzzles: Array = m["muzzles"]
		if muzzles.is_empty():
			continue
		aa_weapon.consume()
		fired = true
		var b: int = m["barrel"]
		m["barrel"] = b + 1
		var mz: Node3D = muzzles[b % muzzles.size()]
		var gc := ac.duplicate()
		gc["tracer"] = Color(1.0, 0.5, 0.3)
		gc["tracer_w"] = 0.25
		gc["type"] = "flak"
		gc["sound"] = "mg"
		gc["volume"] = -3.0 if _rng.randf() < 0.5 else -60.0
		gc["pitch"] = 0.8
		gc["spread"] = 0.5
		fire_shell(gc, mz.global_position, dir)
		if anti_missile and _rng.randf() < float(ac.get("missile_kill", 0.03)):
			_missile_threat.intercept()
			_missile_threat = null
	_aa_index = (_aa_index + 1) % maxi(_aa.size(), 1)


# --- ЗУР ----------------------------------------------------------------------------------------------
func _update_lock(delta: float) -> void:
	var sc: Dictionary = cfg.get("sam", {})
	var radar := float(sc.get("radar", 8000.0))
	if lock_target != null and (not is_instance_valid(lock_target) or lock_target.is_dead):
		lock_target = null
		lock_progress = 0.0
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.2
		var eye := global_position + Vector3.UP * (_deck + 10.0)
		var desired: Vehicle = null
		if is_instance_valid(controls.lock_target) and controls.lock_target is Vehicle:
			var preferred := controls.lock_target as Vehicle
			if not preferred.is_dead and preferred.category == GameDB.Category.AIR and not GlobalBattleManager.vehicles_allied(preferred, self) and eye.distance_to(preferred.global_position) < radar and terrain.line_of_sight(eye, preferred.global_position):
				desired = preferred
		if desired == null and controls.has_aim:
			desired = find_target_in_cone((controls.aim_point - eye).normalized(), float(sc.get("cone", 16.0)), radar, "air", Vector3.UP * (_deck + 10.0))
		if desired == null and lock_target != null and eye.distance_to(lock_target.global_position) < radar and terrain.line_of_sight(eye, lock_target.global_position):
			desired = lock_target
		if desired != lock_target:
			lock_target = desired
			lock_progress = 0.0
	if lock_target != null:
		var before := lock_progress
		lock_progress = minf(lock_progress + delta / (float(sc.get("lock", 1.8)) * lock_time_scale), 1.0)
		if is_player:
			_beep_timer -= delta
			if lock_progress >= 1.0 and before < 1.0:
				SoundFX.play_ui("locked", -8.0)
			elif lock_progress < 1.0 and _beep_timer <= 0.0:
				_beep_timer = 0.3
				SoundFX.play_ui("beep", -14.0)


## Флагман: самостоятельные пуски ЗУР по ближайшей авиации противника (с паузами по сложности).
func _auto_sam(delta: float) -> void:
	_auto_sam_timer -= delta
	if _auto_sam_timer > 0.0 or not sam.can_fire():
		return
	_auto_sam_timer = 4.0
	var sc: Dictionary = cfg.get("sam", {})
	var radar := float(sc.get("radar", 6000.0))
	var eye := global_position + Vector3.UP * (_deck + 10.0)
	var best: Vehicle = null
	var best_d := radar
	for v in GlobalBattleManager.enemies_in_radius(team, global_position, radar, GameDB.Category.AIR, participant_id):
		var d := eye.distance_to(v.global_position)
		if d < best_d and d > 400.0 and terrain.line_of_sight(eye, v.global_position):
			var busy := false
			for m in v.incoming_missiles:
				if is_instance_valid(m) and m is Projectile and (m as Projectile).shooter == self:
					busy = true
			if not busy:
				best_d = d
				best = v
	if best == null:
		return
	sam.consume()
	_launch_sam(best)
	_auto_sam_timer = float(GameDB.difficulty(GlobalBattleManager.difficulty).get("missile_delay", 5.0)) * 2.5 + 6.0


func _launch_sam(target: Vehicle) -> void:
	var sc: Dictionary = cfg.get("sam", {})
	var from := global_position + Vector3.UP * (_deck + 2.0)
	var dir := Vector3.UP
	if not _sam_points.is_empty():
		var p := _sam_points[_next_sam % _sam_points.size()]
		_next_sam += 1
		from = p.global_position
		dir = -p.global_basis.z
	if bool(sc.get("vertical", false)):
		dir = Vector3.UP
	var m := GuidedMissile.new()
	m.target = target
	m.mesh_kind = str(sc.get("mesh", "sam"))
	m.trail_kind = str(sc.get("trail", "large"))
	m.tail_offset = VehicleModels.missile_tail(m.mesh_kind)
	m.thrust = float(sc.get("thrust", 200.0))
	m.burn_time = float(sc.get("burn", 3.0))
	m.sustain_thrust = float(sc.get("sustain", 0.0))
	m.sustain_time = float(sc.get("sustain_time", 0.0))
	m.max_speed = float(sc.get("max_speed", 1100.0))
	m.max_g = float(sc.get("max_g", 25.0))
	m.drag = 0.00003
	m.blast_radius = float(sc.get("blast", 15.0))
	m.blast_damage = float(sc.get("damage", 200.0))
	m.proximity_radius = float(sc.get("prox", 12.0))
	m.max_lifetime = float(sc.get("life", 20.0))
	m.seeker_fov_deg = float(sc.get("fov", 160.0))
	m.flare_resistance = float(sc.get("flare_res", 0.8))
	m.guidance_delay = 0.5 if bool(sc.get("vertical", false)) else 0.15
	m.fov_grace = 1.6 if bool(sc.get("vertical", false)) else 0.0
	m.velocity = dir * float(sc.get("speed0", 30.0)) + velocity
	m.position = from
	m.setup(team, make_source(str(sc.get("name", "ЗУР"))), self)
	level.spawn_projectile(m)
	Effects.puff(from, Color(0.9, 0.9, 0.85, 0.9), 6.0, 0.7, false)


# --- Торпеды и ПКР -------------------------------------------------------------------------------------
func _update_torpedo_mounts(delta: float) -> void:
	for tm in _torpedo_mounts:
		var n: Node3D = tm["yaw"]
		if n == null or not is_instance_valid(n):
			continue
		var want: float = tm["rest"]
		if controls.has_aim:
			var parent := n.get_parent() as Node3D
			var local := parent.global_basis.inverse() * (controls.aim_point - n.global_position)
			var y := atan2(-local.x, -local.z)
			# Трубы разворачиваются только на борт (не через надстройки).
			if absf(y) > deg_to_rad(35.0) and absf(y) < deg_to_rad(145.0):
				want = y
		var cur: float = tm["cur"]
		cur = wrapf(cur + clampf(wrapf(want - cur, -PI, PI), -0.8 * delta, 0.8 * delta), -PI, PI)
		tm["cur"] = cur
		n.rotation = Vector3(0.0, cur, 0.0)


func _launch_torpedo() -> void:
	var from := global_position + Vector3.UP * 1.0
	var tubes: Array[Node3D] = []
	for tm in _torpedo_mounts:
		for t: Node3D in tm["tubes"]:
			tubes.append(t)
	if not tubes.is_empty():
		from = tubes[_next_tube % tubes.size()].global_position
		_next_tube += 1
	var dir := GameDB.flat(controls.aim_point - from)
	if dir.length() < 1.0:
		dir = GameDB.flat(get_forward())
	dir = dir.normalized().rotated(Vector3.UP, deg_to_rad(_rng.randf_range(-3.0, 3.0)))
	var t := Torpedo.new()
	t.velocity = dir * 20.0
	t.position = Vector3(from.x, minf(from.y, 1.0), from.z) + dir * 3.0
	t.setup(team, make_source(str(cfg.get("torpedoes", {}).get("name", "Торпеда"))), self)
	level.spawn_projectile(t)


func _launch_special(point: Vector3) -> void:
	var r := get_special_range()
	var d := GameDB.flat_distance(global_position, point)
	if d < r.x or d > r.y:
		return
	special.consume()
	var spc: Dictionary = cfg.get("special", {})
	var from := global_position + Vector3.UP * (_deck + 2.0)
	var dir := (get_forward() + Vector3.UP * 0.6).normalized()
	if not _special_points.is_empty():
		var p := _special_points[_next_special % _special_points.size()]
		_next_special += 1
		from = p.global_position
		dir = -p.global_basis.z
	var cm := CruiseMissile.new()
	cm.target_point = point
	cm.direct = bool(spc.get("direct", false))
	cm.blast_radius = float(spc.get("blast", cm.blast_radius))
	cm.blast_damage = float(spc.get("damage", cm.blast_damage))
	cm.velocity = dir * 70.0 + velocity
	cm.position = from
	cm.setup(team, make_source(str(spc.get("name", "ПКР"))), self)
	level.spawn_projectile(cm)
	Effects.puff(from, Color(0.9, 0.9, 0.85, 0.9), 6.0, 0.7, false)
	SoundFX.play_3d("launch_heavy", from, 2.0, 1.1, 60.0)


func get_special_range() -> Vector2:
	if special == null:
		return Vector2.ZERO
	var spc: Dictionary = cfg.get("special", {})
	return Vector2(float(spc.get("min", 1500.0)), float(spc.get("max", 9000.0)))


func get_special_origin() -> Vector3:
	if not _special_points.is_empty():
		return _special_points[0].global_position
	return global_position + Vector3.UP * (_deck + 2.0)


func special_ready() -> bool:
	return special != null and special.can_fire()


func _update_hint() -> void:
	var parts := PackedStringArray()
	if sam != null and not autonomous:
		if lock_target != null:
			parts.append("ЗУР: ЗАХВАТ ЦЕЛИ — ПУСК РАЗРЕШЁН" if lock_progress >= 1.0 else "ЗУР: ЗАХВАТ %d%%" % int(lock_progress * 100.0))
	if special != null:
		parts.append("ПКР: ГОТОВЫ (G — карта)" if special.can_fire() else "ПКР: ПЕРЕЗАРЯДКА %d%%" % int(special.get_ready_ratio() * 100.0))
	if torpedoes != null:
		parts.append("ТОРПЕДЫ: %d — веер по прицелу" % torpedoes.ammo)
	hud_hint = " · ".join(parts)


# --- Утилиты для ИИ и интерфейса ------------------------------------------------------------------------
func gun_origin() -> Vector3:
	for m in _main:
		var n: Node3D = m["pitch"] if m["pitch"] != null else m["yaw"]
		if n != null and is_instance_valid(n):
			return n.global_position
	return global_position + Vector3.UP * (_deck + 3.0)


func gun_direction() -> Vector3:
	for m in _main:
		return _mount_dir(m)
	return get_forward()


func gun_speed() -> float:
	return float(cfg.get("main", {}).get("speed", 800.0))


func gun_range() -> float:
	return float(cfg.get("main", {}).get("range", 5000.0))


func has_sam() -> bool:
	return sam != null


func sam_range() -> float:
	return float(cfg.get("sam", {}).get("radar", 8000.0))


func length() -> float:
	return _length


func get_lock_info() -> Dictionary:
	if lock_target == null or not is_instance_valid(lock_target):
		return {}
	return {"target": lock_target, "progress": lock_progress}


func get_radar_range() -> float:
	return maxf(sam_range() if sam != null else 0.0, 8000.0)


func weapon_labels() -> Dictionary:
	var sec := ""
	if sam != null:
		sec = "ЗУР"
	elif torpedoes != null:
		sec = "ТОРПЕДЫ"
	return {"fire": "ГК", "secondary": sec, "special": "ПКР" if special != null else ""}


func get_hud_lines() -> PackedStringArray:
	return PackedStringArray(["%s · ХОД %d уз" % [GameDB.vehicle_role(vehicle_type).to_upper(), int(absf(speed) * 1.944)]])


func _on_destroyed() -> void:
	var p := global_position
	var fwd := get_forward()
	Effects.explosion(p + Vector3(0.0, _deck + 3.0, 0.0), 20.0 + _length * 0.1, true)
	Effects.explosion(p + fwd * _length * 0.3 + Vector3(0.0, _deck, 0.0), 12.0 + _length * 0.06, true)
	if model != null:
		Effects.spawn_model_wreck(model, true, 26.0, _deck * 2.0 + 20.0)
