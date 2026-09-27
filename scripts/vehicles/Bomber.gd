class_name Bomber
extends Aircraft
## Бомбардировщик Су-24М: медленнее истребителя, но несёт тяжёлые бомбы ФАБ-500 (прицел CCIP —
## непрерывно вычисляемая точка падения) и крылатые ракеты Х-59 для уничтожения кораблей
## и береговой ПВО — по цели перед носом или по тактической метке на карте.

const BOMB_DRAG := 0.00006
const CRUISE_MIN_RANGE := 600.0
const CRUISE_MAX_RANGE := 6000.0

var bombs: Weapon
var cruise: Weapon
var ccip_point: Vector3 = Vector3.ZERO
var ccip_valid: bool = false
var designated_target: Node3D = null

var _bomb_visuals: Array[Node3D] = []
var _cruise_visuals: Array[Node3D] = []
var _bomb_bay: Vector3 = Vector3(0.0, -1.6, 0.8)
var _ccip_timer: float = 0.0
var _designate_timer: float = 0.0


func _init() -> void:
	vehicle_type = "bomber"


func _build() -> void:
	max_health = 270.0
	hit_radius = 9.0
	damage_modifiers = {"bullet": 0.85, "flak": 0.9}
	min_speed = 65.0
	cruise_speed = 140.0
	max_speed = 215.0
	thrust_accel = 34.0
	pitch_rate = 1.0
	roll_rate = 2.1
	yaw_rate = 0.35
	var parts := VehicleModels.build_bomber(team)
	model = parts["root"]
	add_child(model)
	_afterburners.assign(parts["afterburners"])
	_bomb_visuals.assign(parts["bombs"])
	_cruise_visuals.assign(parts["cruise"])
	_bomb_bay = parts["bomb_bay"]
	_add_box_collision(Vector3(15.0, 3.6, 22.0), Vector3(0.0, 0.3, 0.5))
	bombs = Weapon.new("bombs", "ФАБ-500", 8, 0.35, 11.0)
	cruise = Weapon.new("cruise", "Х-59", 2, 1.5, 32.0)
	flares = Weapon.new("flares", "ЛТЦ", 5, 0.8, 10.0)
	weapons = [bombs, cruise, flares]


func camera_offset() -> Vector2:
	return Vector2(34.0, 8.0)


func _handle_weapons(delta: float) -> void:
	_handle_flares(delta)
	_ccip_timer -= delta
	if _ccip_timer <= 0.0:
		_ccip_timer = 0.1
		_update_ccip()
	_designate_timer -= delta
	if _designate_timer <= 0.0:
		_designate_timer = 0.3
		designated_target = find_target_in_cone(get_forward(), 22.0, CRUISE_MAX_RANGE, "surface", Vector3.ZERO)
		if designated_target == null:
			designated_target = _structure_in_cone(22.0, CRUISE_MAX_RANGE)
	if controls.fire_primary and bombs.can_fire():
		bombs.consume()
		_drop_bomb()
	if controls.fire_secondary and cruise.can_fire() and designated_target != null and is_instance_valid(designated_target):
		cruise.consume()
		_launch_cruise(designated_target.global_position, designated_target)
	if controls.fire_special and cruise.can_fire():
		var d := GameDB.flat_distance(global_position, controls.special_target)
		if d >= CRUISE_MIN_RANGE and d <= CRUISE_MAX_RANGE:
			cruise.consume()
			_launch_cruise(controls.special_target, null)
	for i in _bomb_visuals.size():
		_bomb_visuals[i].visible = i * 2 < bombs.ammo
	for i in _cruise_visuals.size():
		_cruise_visuals[i].visible = i < cruise.ammo
	hud_hint = ""
	if designated_target != null and is_instance_valid(designated_target):
		hud_hint = "Х-59: ЦЕЛЬ ВЫБРАНА — %s" % GameDB.format_distance(global_position.distance_to(designated_target.global_position))


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


func _drop_bomb() -> void:
	var b := Bomb.new()
	b.velocity = velocity - global_basis.y * 2.0
	b.position = global_position + global_basis * _bomb_bay
	b.setup(team, make_source("ФАБ-500"), self)
	level.spawn_projectile(b)
	SoundFX.play_3d("bomb_release", b.position, -4.0, 1.0, 20.0)


func _launch_cruise(point: Vector3, node: Node3D) -> void:
	var m := CruiseMissile.new()
	m.target_point = point
	m.target_node = node
	var side := 1.0 if cruise.ammo % 2 == 0 else -1.0
	m.position = global_position + global_basis * Vector3(2.7 * side, -1.0, 0.8)
	m.velocity = velocity - global_basis.y * 6.0
	m.setup(team, make_source("Х-59"), self)
	level.spawn_projectile(m)


func get_special_range() -> Vector2:
	return Vector2(CRUISE_MIN_RANGE, CRUISE_MAX_RANGE)


func special_ready() -> bool:
	return cruise.can_fire()


func get_lock_info() -> Dictionary:
	if designated_target == null or not is_instance_valid(designated_target):
		return {}
	return {"target": designated_target, "progress": 1.0}
