class_name BotAI
extends Node
## ИИ бота:
##  * выбор свободного слота техники по потребностям команды (роли: истребитель, ударный, ЗСУ, ЗРК, катер);
##  * патрулирование по раскладке карты: авиация — между базами на высоте, флот — акватория,
##    ПВО — точки обороны своей базы;
##  * обнаружение с учётом дальности, прямой видимости и времени реакции (уровень сложности);
##  * стрельба с упреждением (BallisticSolver) и ошибкой наводки; пуски ракет с задержкой;
##  * тактика: воздушный бой, штурмовка (пушки, НАР, бомбы по CCIP, УР по цели и по метке),
##    захват целей ЗРК, торпедные и баллистические удары катеров, уклонение от ракет с ловушками.
## Уровни сложности заметно мягче прежних: боты промахиваются, медлят и реже выбирают целью игрока.

var vehicle: Vehicle = null
var terrain: Terrain = null
var layout: MapLayout = null
var difficulty: Dictionary = {}
var target: Node3D = null
var waypoint: Vector3 = Vector3.ZERO
var rng := RandomNumberGenerator.new()

var _initialized: bool = false
var _think_timer: float = 0.0
var _reaction_timer: float = 0.0
var _aim_offset: Vector3 = Vector3.ZERO
var _aim_offset_timer: float = 0.0
var _burst_timer: float = 0.0
var _burst_on: bool = true
var _special_cooldown: float = 3.0
var _missile_cooldown: float = 3.0
var _attack_phase: int = 0
var _egress_timer: float = 0.0
var _evade_timer: float = 0.0
var _evade_dir: Vector3 = Vector3.ZERO
var _stuck_timer: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _scan_yaw: float = 0.0


# --- Выбор слота техники -----------------------------------------------------------------------------------
## Взвешенный выбор роли (больше ПВО против авиации противника, истребители против ударных самолётов,
## ударная авиация против флота и ПВО), затем случайный свободный тип внутри роли.
static func choose_vehicle_type(manager: Node, team: int, p_rng: RandomNumberGenerator) -> String:
	var enemy := GameDB.enemy_team(team)
	var weights := {"fighter": 1.1, "strike": 0.75, "spaag": 0.95, "sam": 0.8, "boat": 1.0}
	var enemy_air := 0
	var enemy_strike := 0
	var enemy_naval := 0
	var enemy_ground := 0
	if bool(manager.get("match_running")):
		enemy_air = int(manager.call("count_units", enemy, "", GameDB.Category.AIR))
		enemy_naval = int(manager.call("count_units", enemy, "", GameDB.Category.NAVAL))
		enemy_ground = int(manager.call("count_units", enemy, "", GameDB.Category.GROUND))
		for t in GameDB.types_with_role("strike"):
			enemy_strike += int(manager.call("count_units", enemy, t, -1))
	else:
		enemy_air = int(manager.call("role_count", enemy, "fighter")) + int(manager.call("role_count", enemy, "strike"))
		enemy_strike = int(manager.call("role_count", enemy, "strike"))
		enemy_naval = int(manager.call("role_count", enemy, "boat")) + 1
		enemy_ground = int(manager.call("role_count", enemy, "spaag")) + int(manager.call("role_count", enemy, "sam"))
	weights["spaag"] = float(weights["spaag"]) + 0.3 * enemy_air
	weights["sam"] = float(weights["sam"]) + 0.25 * enemy_air
	weights["fighter"] = float(weights["fighter"]) + 0.35 * enemy_air + 0.5 * enemy_strike
	weights["strike"] = float(weights["strike"]) + 0.25 * enemy_naval + 0.2 * enemy_ground
	weights["boat"] = float(weights["boat"]) + 0.3 * enemy_naval
	var by_role: Dictionary = {}
	for t: String in GameDB.VEHICLE_ORDER:
		if not bool(manager.call("is_slot_free", team, t)):
			continue
		var role := GameDB.role_of(t)
		if not by_role.has(role):
			by_role[role] = []
		(by_role[role] as Array).append(t)
	if by_role.is_empty():
		return ""
	var total := 0.0
	var role_w: Dictionary = {}
	for role: String in by_role.keys():
		var w := float(weights.get(role, 1.0)) / (1.0 + 0.6 * float(manager.call("role_count", team, role)))
		role_w[role] = w
		total += w
	var r := p_rng.randf() * total
	var chosen := ""
	for role: String in role_w.keys():
		r -= float(role_w[role])
		chosen = role
		if r <= 0.0:
			break
	var list: Array = by_role[chosen]
	return str(list[p_rng.randi() % list.size()])


# --- Основной цикл ---------------------------------------------------------------------------------------------
func _ready() -> void:
	process_physics_priority = -10
	rng.randomize()
	difficulty = GameDB.difficulty(GlobalBattleManager.difficulty)
	_think_timer = rng.randf_range(0.0, 0.4)
	_missile_cooldown = float(difficulty.get("missile_delay", 5.0)) * rng.randf_range(0.8, 1.4)
	_special_cooldown = float(difficulty.get("missile_delay", 5.0)) * rng.randf_range(1.0, 1.8)


func _physics_process(delta: float) -> void:
	if vehicle == null:
		vehicle = get_parent() as Vehicle
	if vehicle == null or vehicle.is_dead or vehicle.terrain == null:
		return
	if not _initialized:
		_initialize()
	if not _valid(target):
		target = null
	var c := vehicle.controls
	if GlobalBattleManager.match_over:
		c.fire_primary = false
		c.fire_secondary = false
		if vehicle.category != GameDB.Category.AIR:
			c.throttle = 0.0
		return
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = rng.randf_range(0.3, 0.5)
		_think()
	_reaction_timer -= delta
	_special_cooldown -= delta
	_missile_cooldown -= delta
	_update_aim_error(delta)
	if vehicle is Aircraft:
		if (vehicle as Aircraft).role == "strike":
			_drive_strike(delta)
		else:
			_drive_fighter(delta)
		return
	match vehicle.vehicle_type:
		"spaag":
			_drive_spaag(delta)
		"sam":
			_drive_sam()
		"boat":
			_drive_boat(delta)


func _initialize() -> void:
	_initialized = true
	terrain = vehicle.terrain
	layout = terrain.layout
	_last_pos = vehicle.global_position
	if vehicle is SAMLauncher:
		(vehicle as SAMLauncher).lock_time_scale = float(difficulty.get("lock_time", 1.4))
	match vehicle.category:
		GameDB.Category.AIR:
			waypoint = _air_patrol_point()
		GameDB.Category.GROUND:
			waypoint = _ground_defense_point()
		_:
			waypoint = _sea_patrol_point()


func _think() -> void:
	var detect := float(difficulty.get("detect", 1.0))
	var previous := target
	if vehicle is Aircraft:
		var a := vehicle as Aircraft
		if a.role == "strike":
			target = _pick_strike_target()
		else:
			target = _pick_target((5000.0 if a.is_prop() else 5500.0) * detect, "fighter")
	else:
		match vehicle.vehicle_type:
			"spaag":
				target = _pick_target(2600.0 * detect, "spaag")
			"sam":
				target = _pick_target(6500.0 * detect, "air")
			"boat":
				target = _pick_target(2100.0 * detect, "boat")
	if target != previous:
		_reaction_timer = float(difficulty.get("reaction", 1.0)) * rng.randf_range(0.7, 1.3)
	_check_stuck()


func _check_stuck() -> void:
	if vehicle.category == GameDB.Category.AIR:
		return
	var moved := vehicle.global_position.distance_to(_last_pos)
	_last_pos = vehicle.global_position
	if absf(vehicle.controls.throttle) > 0.3 and moved < 0.8:
		_stuck_timer += 0.4
		if _stuck_timer > 3.0:
			_stuck_timer = 0.0
			waypoint = _ground_defense_point() if vehicle.category == GameDB.Category.GROUND else _sea_patrol_point()
	else:
		_stuck_timer = 0.0


# --- Цели -------------------------------------------------------------------------------------------------------
func _valid(t: Variant) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	if t is Vehicle:
		return not (t as Vehicle).is_dead
	if t is Building:
		return not (t as Building).is_dead
	return true


## На лёгких уровнях игрок реже становится приоритетной целью.
func _focus(v: Vehicle) -> float:
	if v.is_player:
		return 1.0 / maxf(float(difficulty.get("player_focus", 1.0)), 0.2)
	return 1.0


func _pick_target(max_range: float, mode: String) -> Vehicle:
	var pos := vehicle.global_position + Vector3.UP * 3.0
	var best: Vehicle = null
	var best_score := INF
	for v in GlobalBattleManager.enemies_in_radius(vehicle.team, pos, max_range):
		var d := pos.distance_to(v.global_position)
		var factor := 1.0
		match mode:
			"fighter":
				if v.category == GameDB.Category.AIR:
					factor = 0.5 if GameDB.role_of(v.vehicle_type) == "strike" else 0.65
				elif v.vehicle_type == "warship" or d > 2600.0:
					continue
				else:
					factor = 1.7
			"spaag":
				if v.category == GameDB.Category.AIR:
					factor = 0.5
				elif d > 1600.0 or v.vehicle_type == "warship":
					continue
			"air":
				if v.category != GameDB.Category.AIR:
					continue
			"boat":
				if v.category == GameDB.Category.AIR:
					continue
				if v.vehicle_type == "warship":
					factor = 0.55
				elif v.category == GameDB.Category.GROUND:
					factor = 1.4
		if not terrain.line_of_sight(pos, v.global_position + Vector3.UP * 2.0):
			continue
		var score := d * factor * _focus(v)
		if v == target:
			score *= 0.8
		if score < best_score:
			best_score = score
			best = v
	return best


func _pick_strike_target() -> Node3D:
	var pos := vehicle.global_position
	var best: Node3D = null
	var best_score := INF
	var reach := 9000.0 * float(difficulty.get("detect", 1.0))
	for v in GlobalBattleManager.enemies_in_radius(vehicle.team, pos, reach):
		if v.category == GameDB.Category.AIR:
			continue
		var pri := 1.2
		match v.vehicle_type:
			"warship":
				pri = 0.45
			"sam":
				pri = 0.55
			"spaag":
				pri = 0.7
		var s := pos.distance_to(v.global_position) * pri * _focus(v)
		if v == target:
			s *= 0.7
		if s < best_score:
			best_score = s
			best = v
	for b in GlobalBattleManager.enemy_structures_in_radius(vehicle.team, pos, reach):
		var pri := 0.75 if b.score_value >= 40 else 1.05
		var s := pos.distance_to(b.global_position) * pri
		if b == target:
			s *= 0.7
		if s < best_score:
			best_score = s
			best = b
	return best


func _update_aim_error(delta: float) -> void:
	_aim_offset_timer -= delta
	if _aim_offset_timer <= 0.0:
		_aim_offset_timer = rng.randf_range(0.4, 0.9)
		var err := deg_to_rad(float(difficulty.get("aim_error_deg", 3.0)))
		_aim_offset = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * err


func _apply_error(origin: Vector3, point: Vector3) -> Vector3:
	var k := 0.45 if vehicle.category == GameDB.Category.AIR else 1.0
	return point + _aim_offset * origin.distance_to(point) * k


## Стрельба очередями: чередование «огонь / пауза» (дисциплина огня зависит от сложности).
func _burst(delta: float, on_time: float, off_time: float) -> bool:
	_burst_timer -= delta
	if _burst_timer <= 0.0:
		_burst_on = not _burst_on
		var discipline := float(difficulty.get("burst", 0.6))
		_burst_timer = on_time * rng.randf_range(0.6, 1.2) if _burst_on else off_time * (2.2 - discipline) * rng.randf_range(0.8, 1.4)
	return _burst_on


# --- Авиация --------------------------------------------------------------------------------------------------
## Точка патрулирования между базами, ближе к своей стороне; поршневые летают ниже.
func _air_patrol_point() -> Vector3:
	var team := vehicle.team
	var own := layout.airfield[team]
	var enemy := layout.airfield[GameDB.enemy_team(team)]
	var axis := (enemy - own)
	var lat := Vector2(-axis.y, axis.x).normalized()
	var p := own.lerp(enemy, rng.randf_range(0.15, 0.78)) + lat * rng.randf_range(-0.5, 0.5) * layout.bounds
	var lim := layout.bounds * 0.82
	p = Vector2(clampf(p.x, -lim, lim), clampf(p.y, -lim, lim))
	var prop := vehicle is Aircraft and (vehicle as Aircraft).is_prop()
	var alt := rng.randf_range(380.0, 1300.0) if prop else rng.randf_range(600.0, 2200.0)
	return Vector3(p.x, terrain.get_surface_height(p.x, p.y) + alt, p.y)


## Безопасность полёта: границы карты, минимальная высота над рельефом с упреждением, потолок.
func _air_safety(a: Aircraft, fly: Vector3, allow_low: bool) -> Vector3:
	var pos := a.global_position
	var result := fly
	var lim := layout.bounds * 0.9
	if absf(pos.x) > lim or absf(pos.z) > lim:
		result = Vector3(0.0, maxf(pos.y, 800.0), 0.0)
	var ground := terrain.get_surface_height(pos.x, pos.z)
	for t: float in [1.5, 3.0, 5.0]:
		var ahead := pos + a.velocity * t
		ground = maxf(ground, terrain.get_surface_height(ahead.x, ahead.z))
	if not allow_low and result.y < ground + 240.0:
		result.y = ground + 240.0
	if pos.y < ground + 120.0 and a.velocity.y < 5.0:
		result = pos + GameDB.flat(a.velocity).normalized() * 500.0 + Vector3.UP * 700.0
	result.y = minf(result.y, a.ceiling - 300.0)
	return result


func _evade_missiles(a: Aircraft, delta: float) -> bool:
	if _evade_timer > 0.0:
		_evade_timer -= delta
		return true
	if a.incoming_missiles.is_empty():
		return false
	var m: Variant = a.incoming_missiles[0]
	if not is_instance_valid(m):
		return false
	if rng.randf() > float(difficulty.get("evade", 0.5)) * 0.5 + 0.3:
		return false
	var mn := m as Node3D
	var from_missile := GameDB.flat(a.global_position - mn.global_position).normalized()
	var perpendicular := from_missile.cross(Vector3.UP).normalized()
	if rng.randf() < 0.5:
		perpendicular = -perpendicular
	_evade_dir = (perpendicular + Vector3.DOWN * 0.25).normalized()
	_evade_timer = rng.randf_range(2.0, 3.2)
	a.controls.deploy_flares = rng.randf() < 0.25 + 0.6 * float(difficulty.get("evade", 0.5))
	return true


func _reset_air_controls(a: Aircraft, throttle: float) -> void:
	var c := a.controls
	c.use_autopilot = true
	c.pitch = 0.0
	c.roll = 0.0
	c.yaw = 0.0
	c.throttle = throttle
	c.fire_primary = false
	c.fire_secondary = false


func _drive_fighter(delta: float) -> void:
	var f := vehicle as Aircraft
	var c := f.controls
	_reset_air_controls(f, 0.85)
	var pos := f.global_position
	var fly := waypoint
	var allow_low := false
	if _evade_missiles(f, delta):
		fly = pos + _evade_dir * 1500.0
		c.throttle = 1.0
	elif _valid(target) and _reaction_timer <= 0.0:
		var t := target as Vehicle
		var tp := t.global_position
		var dist := pos.distance_to(tp)
		var lead := BallisticSolver.compute_lead(pos, f.velocity, tp, t.velocity, f.gun_speed(), f.gun_drag(), GameDB.GRAVITY)
		var aim := _apply_error(pos, lead)
		var ang := rad_to_deg(f.get_forward().angle_to(aim - pos))
		c.lock_target = t
		var sec := f.slot_type("secondary")
		if t.category == GameDB.Category.AIR:
			fly = aim if dist < 2500.0 else tp + t.velocity * 2.0
			c.fire_primary = dist < 950.0 and ang < 3.0 and _burst(delta, 0.5, 0.6)
			if sec == "aam" and f.lock_progress >= 1.0 and dist > 600.0 and dist < 2400.0 and _missile_cooldown <= 0.0:
				c.fire_secondary = true
				_missile_cooldown = rng.randf_range(7.0, 12.0) + float(difficulty.get("missile_delay", 5.0))
			c.throttle = 1.0 if dist > 1500.0 else 0.8
		else:
			allow_low = true
			fly = aim + Vector3.UP * 3.0
			c.fire_primary = dist < 1100.0 and ang < 3.0 and _burst(delta, 0.6, 0.6)
			if sec == "rockets" and dist < 1200.0 and dist > 350.0 and ang < 4.0 and _missile_cooldown <= 0.0:
				c.fire_secondary = true
				_missile_cooldown = rng.randf_range(1.5, 3.0)
			elif sec == "bombs" and f.ccip_valid and GameDB.flat_distance(f.ccip_point, tp) < 22.0 + t.hit_radius:
				c.fire_secondary = true
			var agl := pos.y - terrain.get_surface_height(pos.x, pos.z)
			if dist < 380.0 or agl < 140.0:
				target = null
				waypoint = _air_patrol_point()
				_reaction_timer = 3.0
	elif pos.distance_to(waypoint) < 450.0:
		waypoint = _air_patrol_point()
	c.fly_target = _air_safety(f, fly, allow_low)


## Ударный самолёт: заход на цель с бомбометанием по CCIP, штурмовка пушками и НАР, пуск УР.
func _drive_strike(delta: float) -> void:
	var b := vehicle as Aircraft
	var c := b.controls
	_reset_air_controls(b, 0.9)
	var pos := b.global_position
	var fly := waypoint
	var allow_low := false
	if _evade_missiles(b, delta):
		fly = pos + _evade_dir * 1500.0
		c.throttle = 1.0
	elif _valid(target) and _reaction_timer <= 0.0:
		var tp := target.global_position
		var dist_flat := GameDB.flat_distance(pos, tp)
		var priority := target is Warship or target is SAMLauncher or target is AAGun or target is Building
		var sp_range := b.get_special_range()
		if sp_range != Vector2.ZERO and b.special_ready() and _special_cooldown <= 0.0 and priority and dist_flat > sp_range.x + 400.0 and dist_flat < sp_range.y * 0.8:
			c.special_target = Vector3(tp.x, tp.y + 1.0, tp.z)
			c.fire_special = true
			_special_cooldown = rng.randf_range(14.0, 22.0) + float(difficulty.get("missile_delay", 5.0))
		var bombs_key := "primary" if b.slot_type("primary") == "bombs" else ("secondary" if b.slot_type("secondary") == "bombs" else "")
		var guns := b.slot_type("primary") == "guns"
		if _attack_phase == 0:
			var tol := 18.0
			if target is Vehicle:
				tol += (target as Vehicle).hit_radius
			elif target is Building:
				tol += (target as Building).hit_radius
			if guns and dist_flat < 2600.0:
				# Пологое пикирование со стрельбой, затем сброс бомб.
				allow_low = true
				var aim := _apply_error(pos, tp + Vector3.UP * 2.0)
				fly = aim
				var ang := rad_to_deg(b.get_forward().angle_to(aim - pos))
				c.fire_primary = dist_flat < 1300.0 and ang < 3.5 and _burst(delta, 0.8, 0.5)
				if b.slot_type("secondary") == "rockets" and dist_flat < 1300.0 and ang < 4.0 and _missile_cooldown <= 0.0:
					c.fire_secondary = true
					_missile_cooldown = rng.randf_range(1.2, 2.5)
			else:
				var alt := maxf(terrain.get_surface_height(tp.x, tp.z), 0.0) + (320.0 if b.is_prop() else 450.0)
				var run_dir := GameDB.flat(tp - pos)
				run_dir = run_dir.normalized() if run_dir.length() > 1.0 else GameDB.flat(b.get_forward()).normalized()
				fly = Vector3(tp.x, alt, tp.z) + run_dir * 1500.0
				if b.slot_type("secondary") == "rockets" and dist_flat < 1400.0 and _missile_cooldown <= 0.0:
					var ang2 := rad_to_deg(b.get_forward().angle_to(tp - pos))
					if ang2 < 5.0:
						c.fire_secondary = true
						_missile_cooldown = rng.randf_range(1.2, 2.5)
			if bombs_key != "" and b.ccip_valid and GameDB.flat_distance(b.ccip_point, tp) < tol:
				if bombs_key == "primary":
					c.fire_primary = true
				else:
					c.fire_secondary = true
			var agl := pos.y - terrain.get_surface_height(pos.x, pos.z)
			var passed := GameDB.flat(b.get_forward()).dot(GameDB.flat(tp - pos)) < 0.0 and dist_flat < 900.0
			if dist_flat < 170.0 or passed or (guns and agl < 150.0):
				_attack_phase = 1
				_egress_timer = rng.randf_range(10.0, 14.0)
		else:
			_egress_timer -= delta
			var ahead := pos + GameDB.flat(b.get_forward()).normalized() * 2000.0
			fly = Vector3(ahead.x, terrain.get_surface_height(ahead.x, ahead.z) + 650.0, ahead.z)
			if _egress_timer <= 0.0:
				_attack_phase = 0
	elif pos.distance_to(waypoint) < 500.0:
		waypoint = _air_patrol_point()
	c.fly_target = _air_safety(b, fly, allow_low)


# --- Наземная ПВО -------------------------------------------------------------------------------------------------
func _ground_defense_point() -> Vector3:
	var options := layout.defense_points(vehicle.team)
	for attempt in 24:
		var base: Vector2 = options[rng.randi() % options.size()]
		var p := base + Vector2(rng.randf_range(-70.0, 70.0), rng.randf_range(-70.0, 70.0))
		var h := terrain.get_height(p.x, p.y)
		if h > 1.5 and terrain.get_normal(p.x, p.y).y > 0.85:
			return Vector3(p.x, h, p.y)
	return vehicle.global_position


## Движение наземной техники к точке. Возвращает true, если цель достигнута.
func _drive_ground_to(gv: GroundVehicle, dest: Vector3, arrive_radius: float) -> bool:
	var c := gv.controls
	var to := GameDB.flat(dest - gv.global_position)
	var dist := to.length()
	if dist < arrive_radius:
		c.throttle = 0.0
		c.steer = 0.0
		return true
	var diff := wrapf(GameDB.yaw_of(to) - gv.hull_yaw, -PI, PI)
	c.steer = clampf(-diff * 2.0, -1.0, 1.0)
	c.throttle = 1.0 if absf(diff) < 0.6 else 0.25
	return false


func _scan_point(gv: Vehicle) -> Vector3:
	_scan_yaw += 0.01
	return gv.global_position + GameDB.dir_from_yaw_pitch(_scan_yaw, 0.35) * 1500.0


func _drive_spaag(delta: float) -> void:
	var g := vehicle as AAGun
	var c := g.controls
	c.fire_primary = false
	var engaging := _valid(target) and _reaction_timer <= 0.0
	if not engaging:
		_drive_ground_to(g, waypoint, 25.0)
		c.has_aim = true
		c.aim_point = _scan_point(g)
		return
	var t := target as Vehicle
	c.throttle = 0.0
	c.steer = 0.0
	var origin := g.gun_origin()
	var lead := BallisticSolver.compute_lead(origin, g.velocity, t.global_position, t.velocity, AAGun.SHELL_SPEED, AAGun.SHELL_DRAG, GameDB.GRAVITY)
	var aim := _apply_error(origin, lead)
	c.aim_point = aim
	c.has_aim = true
	var dist := origin.distance_to(t.global_position)
	var max_range := 2300.0 if t.category == GameDB.Category.AIR else 1600.0
	c.fire_primary = dist < max_range and g.aim_error_to(aim) < 2.0 and _burst(delta, 0.9, 0.7)


func _drive_sam() -> void:
	var s := vehicle as SAMLauncher
	var c := s.controls
	c.fire_primary = false
	if not (_valid(target) and _reaction_timer <= 0.0):
		c.lock_target = null
		_drive_ground_to(s, waypoint, 30.0)
		c.has_aim = true
		c.aim_point = _scan_point(s)
		return
	c.throttle = 0.0
	c.steer = 0.0
	c.lock_target = target
	c.aim_point = target.global_position
	c.has_aim = true
	var dist := s.global_position.distance_to(target.global_position)
	if s.lock_progress >= 1.0 and _special_cooldown <= 0.0 and dist < SAMLauncher.RADAR_RANGE * 0.75 and not _own_missile_on(target):
		c.fire_primary = true
		_special_cooldown = rng.randf_range(6.0, 10.0) + float(difficulty.get("missile_delay", 5.0)) * 0.6


func _own_missile_on(t: Node3D) -> bool:
	if not (t is Vehicle):
		return false
	for m in (t as Vehicle).incoming_missiles:
		if is_instance_valid(m) and m is Projectile and (m as Projectile).shooter == vehicle:
			return true
	return false


# --- Флот -------------------------------------------------------------------------------------------------------
## Точка патрулирования в акватории между своим эсминцем и центром карты.
func _sea_patrol_point() -> Vector3:
	var own := layout.warship[vehicle.team]
	var lim := layout.bounds * 0.92
	for attempt in 40:
		var p := own.lerp(Vector2.ZERO, rng.randf_range(0.0, 1.1)) + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * 1600.0
		p = Vector2(clampf(p.x, -lim, lim), clampf(p.y, -lim, lim))
		if terrain.is_navigable(p.x, p.y, 60.0):
			return Vector3(p.x, 0.0, p.y)
	return Vector3(own.x, 0.0, own.y)


func _pick_ballistic_target(b: PatrolBoat) -> Node3D:
	var pos := b.global_position
	var best: Node3D = null
	var best_score := INF
	for v in GlobalBattleManager.enemies_in_radius(b.team, pos, BallisticMissile.MAX_RANGE - 50.0):
		if v.category == GameDB.Category.AIR:
			continue
		var d := GameDB.flat_distance(pos, v.global_position)
		if d < BallisticMissile.MIN_RANGE + 60.0:
			continue
		var pri := 1.0
		if v is Warship:
			pri = 0.45
		elif v is SAMLauncher:
			pri = 0.6
		elif v is AAGun:
			pri = 0.7
		if d * pri * _focus(v) < best_score:
			best_score = d * pri * _focus(v)
			best = v
	for s in GlobalBattleManager.enemy_structures_in_radius(b.team, pos, BallisticMissile.MAX_RANGE - 50.0):
		var d := GameDB.flat_distance(pos, s.global_position)
		if d < BallisticMissile.MIN_RANGE + 60.0:
			continue
		var score := d * (0.8 if s.score_value >= 40 else 1.15)
		if score < best_score:
			best_score = score
			best = s
	return best


func _drive_boat(delta: float) -> void:
	var b := vehicle as PatrolBoat
	var c := b.controls
	var pos := b.global_position
	c.fire_primary = false
	c.fire_secondary = false
	if b.ballistic.can_fire() and _special_cooldown <= 0.0:
		var st := _pick_ballistic_target(b)
		if st != null:
			var tp := st.global_position
			if st is Vehicle:
				var eta := 8.0 + GameDB.flat_distance(pos, tp) / 400.0
				tp += (st as Vehicle).velocity * eta
			tp += Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * float(difficulty.get("aim_error_deg", 3.0)) * 12.0
			c.special_target = Vector3(tp.x, terrain.get_surface_height(tp.x, tp.z), tp.z)
			c.fire_special = true
			_special_cooldown = rng.randf_range(12.0, 20.0) + float(difficulty.get("missile_delay", 5.0))
	var dest := waypoint
	c.has_aim = false
	if _valid(target) and _reaction_timer <= 0.0:
		var t := target as Vehicle
		var tp := t.global_position
		var dist := GameDB.flat_distance(pos, tp)
		if t is Warship:
			var lead := tp + t.velocity * (dist / 34.0)
			dest = lead
			var ang := rad_to_deg(b.get_forward().angle_to(GameDB.flat(lead - pos)))
			if dist < 1100.0 and ang < 7.0 and b.torpedoes.can_fire():
				c.fire_secondary = true
			if dist < 520.0:
				dest = pos + b.get_forward().rotated(Vector3.UP, PI * 0.5) * 700.0
		else:
			var origin := b.gun_origin()
			var lead := BallisticSolver.compute_lead(origin, b.velocity, tp, t.velocity, PatrolBoat.MG_SPEED, PatrolBoat.MG_DRAG, GameDB.GRAVITY)
			var aim := _apply_error(origin, lead)
			c.aim_point = aim
			c.has_aim = true
			var err := rad_to_deg(b.gun_direction().angle_to(aim - origin))
			c.fire_primary = dist < 900.0 and err < 3.0 and _burst(delta, 0.7, 0.6)
			var to := GameDB.flat(tp - pos)
			if dist > 520.0:
				dest = tp
			else:
				dest = pos + to.normalized().rotated(Vector3.UP, PI * 0.5) * 320.0
			if t.category == GameDB.Category.NAVAL and dist < 650.0 and b.torpedoes.can_fire():
				var ang2 := rad_to_deg(b.get_forward().angle_to(to))
				c.fire_secondary = ang2 < 5.0
	elif GameDB.flat_distance(pos, waypoint) < 160.0:
		waypoint = _sea_patrol_point()
	if not c.has_aim:
		c.has_aim = true
		c.aim_point = pos + b.get_forward() * 600.0 + Vector3.UP * 20.0
	_steer_boat(b, dest)


## Руление катера к точке с обходом суши (веер лучей вперёд).
func _steer_boat(b: PatrolBoat, dest: Vector3) -> void:
	var c := b.controls
	var pos := b.global_position
	var to := GameDB.flat(dest - pos)
	var desired := GameDB.yaw_of(to) if to.length() > 1.0 else b.heading
	var best_yaw := desired
	var found := false
	for offset: float in [0.0, 0.35, -0.35, 0.7, -0.7, 1.1, -1.1, 1.6, -1.6, 2.2, -2.2, PI]:
		var yaw := desired + offset
		var dir := Vector3(-sin(yaw), 0.0, -cos(yaw))
		if _water_clear(pos, dir, 170.0):
			best_yaw = yaw
			found = true
			break
	var diff := wrapf(best_yaw - b.heading, -PI, PI)
	c.steer = clampf(-diff * 2.0, -1.0, 1.0)
	c.throttle = 1.0 if absf(diff) < 1.0 else 0.45
	if not found:
		c.throttle = -0.6
	elif to.length() < 40.0:
		c.throttle = 0.3


func _water_clear(pos: Vector3, dir: Vector3, dist: float) -> bool:
	for i in range(1, 5):
		var p := pos + dir * dist * float(i) / 4.0
		if not terrain.is_navigable(p.x, p.z, 6.0):
			return false
	return true
