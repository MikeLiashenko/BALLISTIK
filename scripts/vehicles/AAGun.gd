class_name AAGun
extends GroundVehicle
## Зенитная самоходная установка «Гепард»: спаренные 35-мм автоматические пушки с высокой
## плотностью огня, яркие трассеры, снаряды с неконтактным взрывателем (подрыв рядом с самолётом),
## РЛС обнаружения (вращается) и РЛС сопровождения — индикатор упреждения по ближайшей воздушной цели.

const SHELL_SPEED := 1175.0
const SHELL_DRAG := 0.00022
const TRACK_RANGE := 3200.0

var cannon: Weapon
var tracked_target: Vehicle = null
var lead_point: Vector3 = Vector3.ZERO

var _muzzles: Array[Node3D] = []
var _flashes: Array[MeshInstance3D] = []
var _barrel: int = 0
var _radar: Node3D = null
var _flash_timer: float = 0.0
var _track_timer: float = 0.0


func _init() -> void:
	vehicle_type = "spaag"


func _build() -> void:
	max_health = 230.0
	hit_radius = 4.0
	damage_modifiers = {"bullet": 0.45, "flak": 0.6, "missile": 0.8}
	max_forward_speed = 17.0
	turn_rate = 1.1
	turret_yaw_rate = 2.4
	gun_pitch_rate = 1.8
	var parts := VehicleModels.build_spaag(team)
	model = parts["root"]
	add_child(model)
	turret = parts["turret"]
	gun_pivot = parts["gun_pivot"]
	_radar = parts["radar"]
	_muzzles.assign(parts["muzzles"])
	for m in _muzzles:
		var f := Effects.create_muzzle_flash(1.4)
		m.add_child(f)
		_flashes.append(f)
	_add_box_collision(Vector3(3.4, 3.2, 7.6), Vector3(0.0, 1.6, 0.0))
	cannon = Weapon.new("cannon35", "35-мм Oerlikon KDA", -1, 1.0 / 18.0, 4.5, 80)
	weapons = [cannon]


func _handle_weapons(delta: float) -> void:
	if _radar != null:
		_radar.rotate_y(delta * 3.5)
	_track_timer -= delta
	if _track_timer <= 0.0:
		_track_timer = 0.2
		tracked_target = find_target_in_cone(gun_direction(), 25.0, TRACK_RANGE, "air")
	if tracked_target != null and (not is_instance_valid(tracked_target) or tracked_target.is_dead):
		tracked_target = null
	if tracked_target != null:
		lead_point = BallisticSolver.compute_lead(gun_origin(), velocity, tracked_target.global_position, tracked_target.velocity, SHELL_SPEED, SHELL_DRAG, GameDB.GRAVITY)
		hud_hint = "РЛС: СОПРОВОЖДЕНИЕ — %s" % GameDB.format_distance(global_position.distance_to(tracked_target.global_position))
	else:
		hud_hint = "РЛС: ПОИСК ЦЕЛИ"
	if controls.fire_primary and cannon.can_fire():
		cannon.consume()
		_fire()
	_flash_timer -= delta
	for f in _flashes:
		if f.visible and _flash_timer <= 0.0:
			f.visible = false


func _fire() -> void:
	var muzzle := _muzzles[_barrel]
	var flash := _flashes[_barrel]
	_barrel = 1 - _barrel
	var dir := GameDB.spread_direction(gun_direction(), 0.3, _rng)
	var p := Projectile.new()
	p.velocity = dir * SHELL_SPEED + velocity
	p.drag = SHELL_DRAG
	p.damage = 8.0
	p.damage_type = "flak"
	p.proximity_radius = 5.0
	p.proximity_damage = 11.0
	p.max_lifetime = 3.4
	p.tracer_color = Color(1.0, 0.72, 0.25)
	p.tracer_width = 0.32
	p.setup(team, make_source("35-мм пушки"), self)
	p.position = muzzle.global_position
	level.spawn_projectile(p)
	flash.visible = true
	_flash_timer = 0.04
	SoundFX.play_3d("cannon", p.position, -3.0, 1.0, 28.0)


func get_lead_info() -> Dictionary:
	if tracked_target == null or not is_instance_valid(tracked_target):
		return {}
	return {"target": tracked_target, "point": lead_point}
