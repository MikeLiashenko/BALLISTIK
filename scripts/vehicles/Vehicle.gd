class_name Vehicle
extends CharacterBody3D
## Базовый класс техники BALLISTIK: фракция (команда), здоровье, урон с модификаторами брони,
## оружие (Weapon), единый интерфейс управления (VehicleControls — игрок или бот), эффекты
## повреждений, уничтожение и регистрация в GlobalBattleManager. Подклассы переопределяют хуки
## _build / _after_build / _vehicle_physics / _handle_weapons / _on_destroyed.

signal destroyed(vehicle: Vehicle, killer: Dictionary)
signal health_changed(vehicle: Vehicle, health: float, max_health: float)

const OUT_OF_BOUNDS_GRACE := 8.0

var vehicle_type: String = ""
var category: int = GameDB.Category.GROUND
var team: int = 0
var participant_id: int = -1
var pilot_name: String = ""
var is_player: bool = false
var max_health: float = 100.0
var health: float = 100.0
var is_dead: bool = false
var hit_radius: float = 3.0
var speed: float = 0.0
var controls := VehicleControls.new()
var weapons: Array[Weapon] = []
var damage_modifiers: Dictionary = {}
var incoming_missiles: Array = []
var last_attacker: Dictionary = {}
var last_attack_time: float = -100.0
var spawn_protection: float = 3.0
var out_of_bounds_time: float = 0.0
var level: BattleLevel = null
var terrain: Terrain = null
var model: Node3D = null
var hud_hint: String = ""

var _damage_fx: Node3D = null
var _damage_stage: int = 0
var _engine_audio: AudioStreamPlayer3D = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	level = GlobalBattleManager.level
	if level != null:
		terrain = level.terrain
	collision_layer = GameDB.LAYER_UNITS
	collision_mask = 0
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	category = GameDB.category_of(vehicle_type)
	_build()
	health = max_health
	_after_build()
	add_to_group("vehicles")
	GlobalBattleManager.register_unit(self)
	_setup_engine_audio()
	reset_physics_interpolation()


func _exit_tree() -> void:
	GlobalBattleManager.unregister_unit(self)


# --- Хуки для подклассов ------------------------------------------------------------------------------
func _build() -> void:
	pass


func _after_build() -> void:
	pass


func _vehicle_physics(_delta: float) -> void:
	pass


func _handle_weapons(_delta: float) -> void:
	pass


func _engine_sound_key() -> String:
	return ""


func _engine_pitch() -> float:
	return 1.0


func damage_fx_offset() -> Vector3:
	return Vector3(0.0, 2.0, 0.0)


# --- Основной цикл --------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	spawn_protection = maxf(spawn_protection - delta, 0.0)
	for w in weapons:
		w.update(delta)
	_clean_missiles()
	_vehicle_physics(delta)
	if is_dead:
		return
	_handle_weapons(delta)
	_check_bounds(delta)
	if _engine_audio != null:
		_engine_audio.pitch_scale = _engine_pitch()
	controls.consume_triggers()


func _clean_missiles() -> void:
	for i in range(incoming_missiles.size() - 1, -1, -1):
		var m: Variant = incoming_missiles[i]
		if not is_instance_valid(m):
			incoming_missiles.remove_at(i)


func _check_bounds(delta: float) -> void:
	var p := global_position
	var b := GlobalBattleManager.bounds()
	if absf(p.x) > b or absf(p.z) > b:
		out_of_bounds_time += delta
		if out_of_bounds_time > OUT_OF_BOUNDS_GRACE:
			apply_damage(max_health * 0.12 * delta, "environment", {})
	else:
		out_of_bounds_time = 0.0


# --- Урон и уничтожение -----------------------------------------------------------------------------------
func get_team() -> int:
	return team


func get_hit_radius() -> float:
	return hit_radius


func is_alive() -> bool:
	return not is_dead


func apply_damage(amount: float, damage_type: String, source: Dictionary) -> void:
	if is_dead or amount <= 0.0:
		return
	var src_team := int(source.get("team", -1))
	if src_team == team:
		return
	if spawn_protection > 0.0 and damage_type != "environment":
		return
	var dmg := amount * float(damage_modifiers.get(damage_type, 1.0))
	if is_player and bool(source.get("bot", false)):
		dmg *= float(GameDB.difficulty(GlobalBattleManager.difficulty).get("damage", 1.0))
	if dmg <= 0.0:
		return
	health -= dmg
	if src_team >= 0:
		last_attacker = source
		last_attack_time = GameDB.now()
	health_changed.emit(self, health, max_health)
	GlobalBattleManager.report_damage(self, dmg, source)
	_update_damage_fx()
	if health <= 0.0:
		destroy(source)


func destroy(killer: Dictionary = {}) -> void:
	if is_dead:
		return
	is_dead = true
	health = 0.0
	var k := killer
	if int(k.get("team", -1)) < 0 and GameDB.now() - last_attack_time < 15.0:
		k = last_attacker
	collision_layer = 0
	for m in incoming_missiles:
		if is_instance_valid(m) and m.has_method("_lose_target"):
			m.call("_lose_target")
	incoming_missiles.clear()
	_on_destroyed()
	destroyed.emit(self, k)
	GlobalBattleManager.report_destroyed(self, k)
	GlobalBattleManager.unregister_unit(self)
	queue_free()


## Отзыв техники без уничтожения (смена класса игроком): слот освобождается, очки не начисляются.
func despawn() -> void:
	if is_dead:
		return
	is_dead = true
	collision_layer = 0
	for m in incoming_missiles:
		if is_instance_valid(m) and m.has_method("_lose_target"):
			m.call("_lose_target")
	incoming_missiles.clear()
	var info := {"recall": true}
	destroyed.emit(self, info)
	GlobalBattleManager.report_recalled(self)
	GlobalBattleManager.unregister_unit(self)
	Effects.puff(global_position + Vector3.UP * 2.0, Color(0.4, 0.9, 1.0, 0.8), 12.0, 0.6)
	queue_free()


## Визуальные последствия уничтожения (по умолчанию — взрыв и обугленный остов на месте).
func _on_destroyed() -> void:
	var p := global_position
	var over_water := terrain != null and terrain.get_height(p.x, p.z) < 0.0
	Effects.explosion(p + Vector3(0.0, 1.5, 0.0), 14.0, over_water)
	if model != null:
		Effects.spawn_model_wreck(model, over_water)


func _update_damage_fx() -> void:
	var ratio := health / max_health
	var stage := 0
	if ratio < 0.25:
		stage = 2
	elif ratio < 0.55:
		stage = 1
	if stage == _damage_stage or is_dead:
		return
	_damage_stage = stage
	if _damage_fx != null and is_instance_valid(_damage_fx):
		_damage_fx.queue_free()
	_damage_fx = null
	if stage == 1:
		_damage_fx = Effects.create_smoke()
	elif stage == 2:
		_damage_fx = Effects.create_fire()
	if _damage_fx != null:
		_damage_fx.position = damage_fx_offset()
		add_child(_damage_fx)


## Описание источника урона для очков и ленты событий.
func make_source(weapon_name: String) -> Dictionary:
	return {
		"team": team,
		"attacker_id": participant_id,
		"attacker_name": pilot_name,
		"vehicle_label": GameDB.vehicle_name(vehicle_type, team),
		"weapon": weapon_name,
		"bot": not is_player,
	}


# --- Утилиты для оружия, ИИ и интерфейса ------------------------------------------------------------------
func get_display_name() -> String:
	return GameDB.vehicle_name(vehicle_type, team)


func get_forward() -> Vector3:
	return -global_basis.z


## Лучшая вражеская цель в конусе dir (mode: "air", "surface", "any") с проверкой прямой видимости.
func find_target_in_cone(dir: Vector3, cone_deg: float, max_range: float, mode: String = "any", origin_offset: Vector3 = Vector3(0.0, 2.0, 0.0)) -> Vehicle:
	var origin := global_position + origin_offset
	var best: Vehicle = null
	var best_score := INF
	for v in GlobalBattleManager.enemies_in_radius(team, origin, max_range):
		if mode == "air" and v.category != GameDB.Category.AIR:
			continue
		if mode == "surface" and v.category == GameDB.Category.AIR:
			continue
		var to_v := v.global_position - origin
		var ang := rad_to_deg(dir.angle_to(to_v))
		if ang > cone_deg:
			continue
		if terrain != null and not terrain.line_of_sight(origin, v.global_position + Vector3(0.0, 2.0, 0.0)):
			continue
		var score := ang * 40.0 + to_v.length() * 0.02
		if score < best_score:
			best_score = score
			best = v
	return best


func _add_box_collision(size: Vector3, offset: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = offset
	add_child(cs)


func _setup_engine_audio() -> void:
	var key := _engine_sound_key()
	if key == "" or not SoundFX.has_sound(key):
		return
	_engine_audio = SoundFX.create_loop_player(key, -3.0 if is_player else -9.0, 18.0 if is_player else 9.0)
	add_child(_engine_audio)
	_engine_audio.play()


## Строки состояния для HUD (скорость, высота и т.п.).
func get_hud_lines() -> PackedStringArray:
	return PackedStringArray(["СКОРОСТЬ  %d км/ч" % int(absf(speed) * 3.6)])


## Цель захвата (для рамки захвата в HUD) и прогресс 0..1.
func get_lock_info() -> Dictionary:
	return {}


## Точка упреждения для HUD (пустой словарь — нет).
func get_lead_info() -> Dictionary:
	return {}


## Дальность тактического удара по метке: Vector2(min, max); Vector2.ZERO — нет такого оружия.
func get_special_range() -> Vector2:
	return Vector2.ZERO


func get_special_origin() -> Vector3:
	return global_position


func special_ready() -> bool:
	return false


func camera_offset() -> Vector2:
	return Vector2(16.0, 4.0)
