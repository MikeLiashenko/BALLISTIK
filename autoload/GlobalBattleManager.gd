extends Node
## Глобальный менеджер боя (Autoload).
##  * выбор карты и эпохи авиации, учёт слотов техники по командам — лимит машин каждого типа
##    и каждой роли (истребители, ударные, ЗСУ, ЗРК, катера) одновременно на поле боя;
##  * участники матча (игрок и боты): выбор слотов в лобби и при возрождении;
##  * очки команд, время матча, условия победы, лента событий;
##  * спавн и возрождение техники на точках своей базы (аэродром / берег / причал);
##  * реестр юнитов и сооружений на поле боя (для радара, ИИ и зон поражения).

signal slots_changed(team: int)
signal roster_changed
signal score_changed(team: int, score: int)
signal match_started
signal match_ended(winner_team: int)
signal unit_spawned(vehicle: Vehicle)
signal unit_destroyed(vehicle: Vehicle, killer: Dictionary)
signal structure_destroyed(building: Building, killer: Dictionary)
signal kill_feed(text: String, color: Color)
signal player_spawned(vehicle: Vehicle)
signal player_died(killer: Dictionary)
signal player_hit(target: Node, damage: float, killed: bool)
signal explosion_event(position: Vector3, radius: float)
signal announcement(text: String, color: Color)

const PLAYER_RESPAWN_DELAY := 5.0
const BOT_RESPAWN_DELAY := 7.0
const BATTLE_SCENE := "res://scenes/BattleLevel.tscn"
const MENU_SCENE := "res://scenes/MainMenu.tscn"

var player_team: int = 0
var team_size: int = 7
var difficulty: int = 1
var score_limit: int = 1000
var time_limit: float = 900.0
var map_seed: int = 1
## Выбранная в лобби карта (может быть MapPresets.RANDOM_ID) и фактическая карта текущего боя.
var map_choice: String = "coast"
var map_id: String = "coast"
## Эпоха авиации: 0 — смешанная, 1 — поршневая, 2 — реактивная.
var air_era: int = 0

var participants: Array[Participant] = []
var player: Participant = null
var slots: Array[Dictionary] = [{}, {}]
var scores: Array[int] = [0, 0]
var time_left: float = 0.0
var match_running: bool = false
var match_over: bool = false
var winner: int = -1
var level: BattleLevel = null
var units: Array[Vehicle] = []
var structures: Array[Building] = []
var rng := RandomNumberGenerator.new()

# Автотест (запуск: godot -- --smoke-test [--smoke-seconds=40] [--smoke-vehicle=boat] [--shots=DIR])
var smoke_test: bool = false
var smoke_seconds: float = 40.0
var smoke_vehicle: String = ""
var smoke_shots_dir: String = ""
var smoke_tactical: bool = false
var smoke_human: bool = false
var smoke_map: String = ""
## Автотест меню: обход экранов (главный, лобби, ангар) со скриншотами вместо боя.
var smoke_menu: bool = false
var _smoke_battle_time: float = 0.0
var _smoke_tactical_stage: int = 0
var _smoke_elapsed: float = 0.0
var _smoke_next_shot: float = 1.0
var _smoke_shot_index: int = 0
var smoke_stats: Dictionary = {}

var _next_participant_id: int = 1


func _ready() -> void:
	rng.randomize()
	_parse_cmdline()
	_reset_slots()


func _parse_cmdline() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--smoke-test":
			smoke_test = true
		elif arg.begins_with("--smoke-seconds="):
			smoke_seconds = maxf(float(arg.get_slice("=", 1)), 5.0)
		elif arg.begins_with("--smoke-vehicle="):
			smoke_vehicle = arg.get_slice("=", 1)
		elif arg.begins_with("--shots="):
			smoke_shots_dir = arg.get_slice("=", 1)
		elif arg == "--smoke-tactical":
			smoke_tactical = true
		elif arg == "--smoke-human":
			smoke_human = true
		elif arg.begins_with("--smoke-map="):
			smoke_map = arg.get_slice("=", 1)
		elif arg == "--smoke-menu":
			smoke_menu = true
		elif arg.begins_with("--smoke-era="):
			air_era = clampi(int(arg.get_slice("=", 1)), 0, 2)


func configure_from_settings() -> void:
	player_team = GameSettings.player_team
	difficulty = GameSettings.difficulty
	score_limit = GameSettings.score_limit
	time_limit = float(GameSettings.time_limit_min) * 60.0
	map_choice = GameSettings.map_id
	if not smoke_test:
		air_era = GameSettings.air_era
	elif smoke_map != "":
		map_choice = smoke_map
	team_size = clampi(GameSettings.team_size, 2, mini(GameDB.total_slots(air_era), 16))


## Половина размера зоны боя текущей карты (м).
func bounds() -> float:
	if level != null and is_instance_valid(level) and level.layout != null:
		return level.layout.bounds
	return GameDB.MAP_HALF


# --- Лобби и участники --------------------------------------------------------------------------------
## Формирует составы команд: игрок + боты. Боты сразу занимают свободные слоты техники.
func prepare_lobby() -> void:
	configure_from_settings()
	match_running = false
	match_over = false
	level = null
	participants.clear()
	units.clear()
	structures.clear()
	_reset_slots()
	_next_participant_id = 1
	player = _add_participant("Вы", player_team, true)
	if smoke_test and smoke_vehicle != "":
		reserve_slot(player, GameDB.resolve_id(smoke_vehicle))
	var names: Array = GameDB.BOT_CALLSIGNS.duplicate()
	names.shuffle()
	var name_index := 0
	for team in 2:
		var bots := team_size - (1 if team == player_team else 0)
		for i in bots:
			var callsign := str(names[name_index % names.size()])
			name_index += 1
			var p := _add_participant(callsign, team, false)
			var t := BotAI.choose_vehicle_type(self, team, rng)
			if t != "":
				reserve_slot(p, t)
	roster_changed.emit()


func _add_participant(p_name: String, team: int, is_player: bool) -> Participant:
	var p := Participant.new(_next_participant_id, p_name, team, is_player)
	_next_participant_id += 1
	participants.append(p)
	return p


func get_participant(id: int) -> Participant:
	for p in participants:
		if p.id == id:
			return p
	return null


func get_team_participants(team: int) -> Array[Participant]:
	var result: Array[Participant] = []
	for p in participants:
		if p.team == team:
			result.append(p)
	return result


## Смена стороны игроком в лобби (состав пересобирается).
func set_player_team(team: int) -> void:
	GameSettings.player_team = clampi(team, 0, 1)
	GameSettings.save_settings()
	prepare_lobby()


# --- Слоты ----------------------------------------------------------------------------------------------
func _reset_slots() -> void:
	slots = [{}, {}]
	for team in 2:
		for t: String in GameDB.VEHICLE_ORDER:
			slots[team][t] = []


func slot_count(team: int, type_id: String) -> int:
	if team < 0 or team > 1:
		return 0
	var holders: Array = slots[team].get(type_id, [])
	return holders.size()


func slot_max(type_id: String) -> int:
	return GameDB.max_slots(type_id)


## Число занятых слотов роли в команде.
func role_count(team: int, role: String) -> int:
	var n := 0
	for t in GameDB.types_with_role(role):
		n += slot_count(team, t)
	return n


func role_full(team: int, role: String) -> bool:
	return role_count(team, role) >= int(GameDB.ROLE_LIMITS.get(role, 99))


func is_available(type_id: String) -> bool:
	return GameDB.VEHICLES.has(type_id) and GameDB.in_era(type_id, air_era)


func is_slot_free(team: int, type_id: String) -> bool:
	if not is_available(type_id):
		return false
	return slot_count(team, type_id) < slot_max(type_id) and not role_full(team, GameDB.role_of(type_id))


func can_take_slot(p: Participant, type_id: String) -> bool:
	return p.vehicle_type == type_id or is_slot_free(p.team, type_id)


func free_slot_types(team: int) -> Array[String]:
	var result: Array[String] = []
	for t: String in GameDB.VEHICLE_ORDER:
		if is_slot_free(team, t):
			result.append(t)
	return result


func get_slot_holders(team: int, type_id: String) -> Array[Participant]:
	var result: Array[Participant] = []
	var holders: Array = slots[team].get(type_id, [])
	for id in holders:
		var p := get_participant(int(id))
		if p != null:
			result.append(p)
	return result


## Занять слот техники. Возвращает false, если все слоты этого класса в команде заняты.
func reserve_slot(p: Participant, type_id: String) -> bool:
	if p == null or not is_available(type_id):
		return false
	if p.vehicle_type == type_id:
		return true
	if p.has_live_vehicle():
		return false
	var role := GameDB.role_of(type_id)
	var same_role := p.vehicle_type != "" and GameDB.role_of(p.vehicle_type) == role
	var type_free := slot_count(p.team, type_id) < slot_max(type_id)
	if not type_free or (role_full(p.team, role) and not same_role):
		return false
	release_slot(p)
	var holders: Array = slots[p.team][type_id]
	holders.append(p.id)
	p.vehicle_type = type_id
	slots_changed.emit(p.team)
	roster_changed.emit()
	return true


func release_slot(p: Participant) -> void:
	if p == null or p.vehicle_type == "":
		return
	var holders: Array = slots[p.team].get(p.vehicle_type, [])
	holders.erase(p.id)
	p.vehicle_type = ""
	slots_changed.emit(p.team)
	roster_changed.emit()


## Выбор слота игроком. Если место занято ботом своей команды, бот уступает и выбирает другую технику.
func request_player_slot(type_id: String) -> bool:
	if player == null or not is_available(type_id):
		return false
	if reserve_slot(player, type_id):
		return true
	if player.has_live_vehicle():
		return false
	var role := GameDB.role_of(type_id)
	var bumped: Participant = null
	if slot_count(player.team, type_id) >= slot_max(type_id):
		for p in get_slot_holders(player.team, type_id):
			if not p.is_player and not p.has_live_vehicle():
				bumped = p
				break
	elif role_full(player.team, role):
		for t in GameDB.types_with_role(role):
			for p in get_slot_holders(player.team, t):
				if not p.is_player and not p.has_live_vehicle():
					bumped = p
					break
			if bumped != null:
				break
	if bumped == null:
		return false
	release_slot(bumped)
	if not reserve_slot(player, type_id):
		return false
	var alt := BotAI.choose_vehicle_type(self, bumped.team, rng)
	if alt != "":
		reserve_slot(bumped, alt)
	roster_changed.emit()
	return true


# --- Матч -------------------------------------------------------------------------------------------------
func start_battle() -> void:
	if player == null:
		prepare_lobby()
	if player.vehicle_type == "":
		var free := free_slot_types(player.team)
		if free.is_empty():
			return
		reserve_slot(player, free[0])
	scores = [0, 0]
	time_left = time_limit
	match_over = false
	match_running = false
	winner = -1
	map_seed = rng.randi_range(1, 999999)
	map_id = MapPresets.resolve(map_choice, rng)
	units.clear()
	structures.clear()
	for p in participants:
		p.kills = 0
		p.deaths = 0
		p.score = 0
		p.alive = false
		p.vehicle = null
	get_tree().paused = false
	get_tree().change_scene_to_file(BATTLE_SCENE)


## Вызывается уровнем после процедурной генерации карты: спавн всех участников.
func on_level_ready(p_level: BattleLevel) -> void:
	level = p_level
	match_running = true
	for p in participants:
		p.alive = false
		p.vehicle = null
		if p.vehicle_type != "":
			spawn_participant(p)
		else:
			p.respawn_timer = 0.5 if p.is_player else rng.randf_range(1.0, 3.0)
	match_started.emit()
	MusicPlayer.play_battle()
	_smoke_battle_time = 0.0
	announcement.emit("%s · ЛИМИТ %d ОЧКОВ" % [MapPresets.map_name(map_id).to_upper(), score_limit], Color(0.4, 0.95, 1.0))


func spawn_participant(p: Participant) -> Vehicle:
	if level == null or p.vehicle_type == "":
		return null
	var v := create_vehicle(p.vehicle_type)
	v.team = p.team
	v.participant_id = p.id
	v.pilot_name = p.name
	v.is_player = p.is_player
	v.transform = level.pick_spawn_transform(p.team, GameDB.category_of(p.vehicle_type))
	var bot_driven := not p.is_player or (smoke_test and not smoke_human)
	if bot_driven:
		v.add_child(BotAI.new())
	level.add_unit(v)
	p.vehicle = v
	p.alive = true
	p.respawn_timer = 0.0
	unit_spawned.emit(v)
	if p.is_player:
		level.on_player_spawned(v, bot_driven)
		player_spawned.emit(v)
	return v


static func create_vehicle(type_id: String) -> Vehicle:
	if GameDB.is_aircraft(type_id):
		var a := Aircraft.new()
		a.vehicle_type = type_id
		return a
	match type_id:
		"spaag":
			return AAGun.new()
		"sam":
			return SAMLauncher.new()
		"boat":
			return PatrolBoat.new()
	return AAGun.new()


func _process(delta: float) -> void:
	if smoke_test:
		_smoke_update(delta)
	if not match_running or match_over or level == null:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_finish_match(_leading_team())
		return
	for p in participants:
		if p.alive:
			continue
		p.respawn_timer -= delta
		if p.respawn_timer > 0.0:
			continue
		if p.is_player and not smoke_test:
			if p.vehicle_type != "":
				spawn_participant(p)
			continue
		if p.vehicle_type == "":
			var t := BotAI.choose_vehicle_type(self, p.team, rng)
			if t == "" or not reserve_slot(p, t):
				p.respawn_timer = 1.5
				continue
		spawn_participant(p)


## Техника уничтожена: освобождение слота, очки, лента событий, таймер возрождения.
func report_destroyed(v: Vehicle, killer: Dictionary) -> void:
	var victim_label := GameDB.vehicle_name(v.vehicle_type, v.team)
	var p := get_participant(v.participant_id)
	if p != null:
		p.deaths += 1
		p.alive = false
		p.vehicle = null
		release_slot(p)
		p.respawn_timer = PLAYER_RESPAWN_DELAY if p.is_player else BOT_RESPAWN_DELAY
	var value := GameDB.score_for_vehicle(v.vehicle_type)
	var killer_team := int(killer.get("team", -1))
	var killer_id := int(killer.get("attacker_id", -1))
	var text := ""
	var color := GameDB.team_color(GameDB.enemy_team(v.team))
	if killer_team >= 0 and killer_team != v.team:
		add_score(killer_team, value)
		var kp := get_participant(killer_id)
		if kp != null:
			kp.kills += 1
			kp.score += value
		text = "%s [%s]  »  %s [%s]" % [str(killer.get("attacker_name", "?")), str(killer.get("vehicle_label", "")), v.pilot_name, victim_label]
		color = GameDB.team_color(killer_team)
		if player != null and killer_id == player.id:
			player_hit.emit(v, 0.0, true)
	else:
		add_score(GameDB.enemy_team(v.team), int(value * 0.5))
		text = "%s [%s] потерян" % [v.pilot_name, victim_label]
	kill_feed.emit(text, color)
	if smoke_test:
		var pos := v.global_position
		var agl := pos.y - level.terrain.get_surface_height(pos.x, pos.z) if level != null else 0.0
		print("[SMOKE] t=%.1f %s | pos=(%d,%d,%d) agl=%.0f weapon=%s" % [_smoke_elapsed, text, int(pos.x), int(pos.y), int(pos.z), agl, str(killer.get("weapon", "-"))])
	if v.vehicle_type == "warship":
		announcement.emit("ЭСМИНЕЦ %s ПОТОПЛЕН" % GameDB.team_name(v.team), GameDB.team_color(GameDB.enemy_team(v.team)))
	unit_destroyed.emit(v, killer)
	if v.is_player:
		player_died.emit(killer)


## Техника отозвана игроком (смена класса): слот освобождается без начисления очков.
func report_recalled(v: Vehicle) -> void:
	var p := get_participant(v.participant_id)
	if p == null:
		return
	p.alive = false
	p.vehicle = null
	release_slot(p)
	p.respawn_timer = 2.0
	if v.is_player:
		player_died.emit({"recall": true})


func recall_player_vehicle() -> void:
	if player != null and player.has_live_vehicle():
		player.vehicle.despawn()


func report_structure_destroyed(b: Building, killer: Dictionary) -> void:
	var killer_team := int(killer.get("team", -1))
	var killer_id := int(killer.get("attacker_id", -1))
	var owner_name := "нейтр." if b.team < 0 else GameDB.team_name(b.team)
	if b.team >= 0 and killer_team >= 0 and killer_team != b.team:
		add_score(killer_team, b.score_value)
		var kp := get_participant(killer_id)
		if kp != null:
			kp.score += b.score_value
		if player != null and killer_id == player.id:
			player_hit.emit(b, 0.0, true)
	var who := str(killer.get("attacker_name", ""))
	var text := "%s  »  %s (%s)" % [who if who != "" else "Взрыв", b.display_name, owner_name]
	kill_feed.emit(text, GameDB.team_color(killer_team))
	structure_destroyed.emit(b, killer)


func report_damage(target: Node, amount: float, source: Dictionary) -> void:
	if smoke_test:
		smoke_count("damage_events")
		smoke_count("damage_by_" + str(source.get("weapon", "environment")), amount)
	if player != null and int(source.get("attacker_id", -1)) == player.id:
		player_hit.emit(target, amount, false)


## Счётчики автотеста (выводятся в конце прогона).
func smoke_count(key: String, amount: float = 1.0) -> void:
	if smoke_test:
		smoke_stats[key] = float(smoke_stats.get(key, 0.0)) + amount


func report_explosion(pos: Vector3, radius: float) -> void:
	explosion_event.emit(pos, radius)


func add_score(team: int, amount: int) -> void:
	if team < 0 or team > 1 or match_over or amount <= 0:
		return
	scores[team] += amount
	score_changed.emit(team, scores[team])
	if scores[team] >= score_limit:
		_finish_match(team)


func _leading_team() -> int:
	if scores[0] > scores[1]:
		return 0
	if scores[1] > scores[0]:
		return 1
	return -1


func _finish_match(w: int) -> void:
	if match_over:
		return
	match_over = true
	winner = w
	match_ended.emit(w)


func return_to_menu() -> void:
	match_running = false
	match_over = false
	level = null
	units.clear()
	structures.clear()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)


## Реванш: тот же размер команд, новая карта. Игрок сохраняет прежний класс, если слот свободен.
func restart_match() -> void:
	var previous := player.vehicle_type if player != null else ""
	prepare_lobby()
	if previous != "" and not reserve_slot(player, previous):
		var free := free_slot_types(player.team)
		if not free.is_empty():
			reserve_slot(player, free[0])
	start_battle()


# --- Реестр юнитов и сооружений -----------------------------------------------------------------------------
func register_unit(v: Vehicle) -> void:
	if not units.has(v):
		units.append(v)


func unregister_unit(v: Vehicle) -> void:
	units.erase(v)


func register_structure(b: Building) -> void:
	if not structures.has(b):
		structures.append(b)


func unregister_structure(b: Building) -> void:
	structures.erase(b)


func get_live_units() -> Array[Vehicle]:
	var result: Array[Vehicle] = []
	for v in units:
		if is_instance_valid(v) and not v.is_dead:
			result.append(v)
	return result


func count_units(team: int, type_id: String = "", category: int = -1) -> int:
	var n := 0
	for v in units:
		if not is_instance_valid(v) or v.is_dead or v.team != team:
			continue
		if type_id != "" and v.vehicle_type != type_id:
			continue
		if category >= 0 and v.category != category:
			continue
		n += 1
	return n


## Живые вражеские юниты в радиусе (category < 0 — любые).
func enemies_in_radius(team: int, pos: Vector3, radius: float, category: int = -1) -> Array[Vehicle]:
	var result: Array[Vehicle] = []
	var r2 := radius * radius
	for v in units:
		if not is_instance_valid(v) or v.is_dead or v.team == team or v.team < 0:
			continue
		if category >= 0 and v.category != category:
			continue
		if v.global_position.distance_squared_to(pos) <= r2:
			result.append(v)
	return result


func enemy_structures_in_radius(team: int, pos: Vector3, radius: float) -> Array[Building]:
	var result: Array[Building] = []
	var r2 := radius * radius
	for b in structures:
		if not is_instance_valid(b) or b.is_dead or b.team < 0 or b.team == team:
			continue
		if b.global_position.distance_squared_to(pos) <= r2:
			result.append(b)
	return result


func get_fx_parent() -> Node:
	if level != null and is_instance_valid(level) and level.fx_root != null:
		return level.fx_root
	return get_tree().current_scene


# --- Автотест ------------------------------------------------------------------------------------------------
func _smoke_update(delta: float) -> void:
	_smoke_elapsed += delta
	if match_running:
		_smoke_battle_time += delta
	if match_running and DisplayServer.get_name() != "headless":
		var fps := float(Engine.get_frames_per_second())
		smoke_count("fps_samples")
		smoke_count("fps_sum", fps)
		if fps > 0.0 and (not smoke_stats.has("fps_min") or fps < float(smoke_stats["fps_min"])) and _smoke_battle_time > 6.0:
			smoke_stats["fps_min"] = fps
	# Скриншоты: первый — в меню, остальные — по времени боя.
	if smoke_shots_dir != "" and DisplayServer.get_name() != "headless":
		if _smoke_shot_index == 0 and _smoke_elapsed >= 1.4 and not smoke_menu:
			_save_screenshot()
			_smoke_next_shot = 1.5
		elif _smoke_shot_index > 0 and match_running and _smoke_battle_time >= _smoke_next_shot:
			_save_screenshot()
			_smoke_next_shot += 2.5 if _smoke_shot_index <= 2 else 4.5
	if smoke_tactical and level != null and match_running:
		_smoke_tactical_director()
	if smoke_human and level != null and match_running:
		_smoke_human_input(delta)
	if not smoke_menu and (_smoke_battle_time >= smoke_seconds or _smoke_elapsed > smoke_seconds + 120.0):
		_print_smoke_summary()
		get_tree().quit(0)


## Автотест ручного управления: имитация нажатий клавиш и движения мыши игроком.
func _smoke_human_input(delta: float) -> void:
	var pc := level.player_controller
	if pc == null or not pc.has_vehicle():
		return
	var t := _smoke_battle_time
	_smoke_hold("move_forward", fmod(t, 6.0) < 4.0)
	_smoke_hold("move_right", fmod(t, 5.0) < 1.2)
	_smoke_hold("arrow_down", fmod(t, 8.0) < 0.8)
	_smoke_hold("yaw_left", fmod(t, 7.0) < 0.6)
	_smoke_hold("fire_primary", fmod(t, 2.0) < 1.0 and not pc.tactical_active)
	_smoke_hold("fire_secondary", fmod(t, 6.0) < 0.3 and not pc.tactical_active)
	_smoke_hold("flares", fmod(t, 9.0) < 0.1)
	_smoke_hold("zoom", fmod(t, 10.0) < 1.0)
	pc.set("_mouse_delta", Vector2(sin(t * 0.8) * 6.0, cos(t * 0.5) * 2.5) * delta * 60.0)


func _smoke_hold(action: String, pressed: bool) -> void:
	if pressed and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not pressed and Input.is_action_pressed(action):
		Input.action_release(action)


## Автотест тактического режима: открыть карту, поставить метку на ближайшее вражеское сооружение, пуск.
func _smoke_tactical_director() -> void:
	var pc := level.player_controller
	if pc == null or not pc.has_vehicle() or pc.vehicle.get_special_range() == Vector2.ZERO:
		return
	if _smoke_tactical_stage == 0 and _smoke_battle_time > 8.0:
		_smoke_tactical_stage = 1
		pc.enter_tactical()
		var r := pc.vehicle.get_special_range()
		var best: Vector3 = Vector3.ZERO
		var best_d := INF
		for b in structures:
			if b.is_dead or b.team == pc.vehicle.team:
				continue
			var d := GameDB.flat_distance(b.global_position, pc.vehicle.global_position)
			if d > r.x + 50.0 and d < r.y - 50.0 and d < best_d:
				best_d = d
				best = b.global_position
		if best_d == INF:
			best = pc.vehicle.global_position + pc.vehicle.get_forward() * (r.x + r.y) * 0.5
			best.y = level.terrain.get_surface_height(best.x, best.z)
		pc.set_tactical_point(best)
		print("[SMOKE] tactical target at %s, distance %.0f" % [str(best), GameDB.flat_distance(best, pc.vehicle.global_position)])
	elif _smoke_tactical_stage == 1 and _smoke_battle_time > 13.4:
		_smoke_tactical_stage = 2
		print("[SMOKE] tactical info: ", pc.tactical_info, " valid=", pc.tactical_valid)
		pc.tactical_launch()


func save_screenshot() -> void:
	_save_screenshot()


func _save_screenshot() -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	DirAccess.make_dir_recursive_absolute(smoke_shots_dir)
	var path := smoke_shots_dir.path_join("shot_%02d.png" % _smoke_shot_index)
	_smoke_shot_index += 1
	img.save_png(path)
	print("[SMOKE] screenshot: ", path)


func _print_smoke_summary() -> void:
	print("[SMOKE] map=%s era=%d elapsed=%.1f s (battle %.1f s), units alive=%d, structures=%d, score=%d:%d" % [map_id, air_era, _smoke_elapsed, _smoke_battle_time, get_live_units().size(), structures.size(), scores[0], scores[1]])
	for p in participants:
		print("[SMOKE]   %s team=%d vehicle=%s kills=%d deaths=%d score=%d" % [p.name, p.team, p.vehicle_type, p.kills, p.deaths, p.score])
	if smoke_stats.has("fps_samples"):
		print("[SMOKE]   fps avg=%.1f min=%.1f" % [float(smoke_stats["fps_sum"]) / maxf(float(smoke_stats["fps_samples"]), 1.0), float(smoke_stats.get("fps_min", 0.0))])
	var keys := smoke_stats.keys()
	keys.sort()
	for k in keys:
		print("[SMOKE]   stat %s = %.0f" % [str(k), float(smoke_stats[k])])
