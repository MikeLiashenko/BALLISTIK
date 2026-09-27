class_name Fighter
extends Aircraft
## Истребитель МиГ-29: высокая скорость и манёвренность, курсовая автопушка ГШ-30-1
## и ракеты «воздух-воздух» Р-73 с ИК ГСН (захват цели в конусе перед носом).
## Задача — перехват бомбардировщиков и защита неба.

const GUN_SPEED := 900.0
const GUN_DRAG := 0.00028
const AAM_RANGE := 3200.0
const AAM_LOCK_CONE := 28.0
const AAM_LOCK_TIME := 1.0

var cannon: Weapon
var aam: Weapon
var lock_target: Vehicle = null
var lock_progress: float = 0.0
var gun_target: Vehicle = null

var _muzzle: Node3D = null
var _muzzle_flash: MeshInstance3D = null
var _flash_timer: float = 0.0
var _missile_visuals: Array[Node3D] = []
var _target_timer: float = 0.0
var _lock_tone_timer: float = 0.0


func _init() -> void:
	vehicle_type = "fighter"


func _build() -> void:
	max_health = 160.0
	hit_radius = 7.0
	damage_modifiers = {"bullet": 1.0, "flak": 1.0, "missile": 1.0}
	min_speed = 75.0
	cruise_speed = 170.0
	max_speed = 280.0
	thrust_accel = 50.0
	pitch_rate = 1.55
	roll_rate = 3.4
	yaw_rate = 0.5
	var parts := VehicleModels.build_fighter(team)
	model = parts["root"]
	add_child(model)
	_afterburners.assign(parts["afterburners"])
	_missile_visuals.assign(parts["missiles"])
	_muzzle = parts["muzzle"]
	_muzzle_flash = Effects.create_muzzle_flash(1.2)
	_muzzle.add_child(_muzzle_flash)
	_add_box_collision(Vector3(11.0, 2.8, 17.0), Vector3(0.0, 0.2, 0.3))
	cannon = Weapon.new("cannon", "ГШ-30-1", -1, 0.05, 3.5, 150)
	aam = Weapon.new("aam", "Р-73", 4, 0.9, 22.0)
	flares = Weapon.new("flares", "ЛТЦ", 6, 0.8, 9.0)
	weapons = [cannon, aam, flares]


func _handle_weapons(delta: float) -> void:
	_handle_flares(delta)
	_update_targeting(delta)
	if controls.fire_primary and cannon.can_fire():
		cannon.consume()
		_fire_cannon()
	if controls.fire_secondary and aam.can_fire() and lock_progress >= 1.0 and lock_target != null:
		aam.consume()
		_launch_aam()
	_flash_timer -= delta
	if _muzzle_flash != null:
		_muzzle_flash.visible = _flash_timer > 0.0
	for i in _missile_visuals.size():
		_missile_visuals[i].visible = i < aam.ammo


func _update_targeting(delta: float) -> void:
	_target_timer -= delta
	if lock_target != null and (not is_instance_valid(lock_target) or lock_target.is_dead):
		lock_target = null
		lock_progress = 0.0
	if gun_target != null and (not is_instance_valid(gun_target) or gun_target.is_dead):
		gun_target = null
	if _target_timer <= 0.0:
		_target_timer = 0.15
		var desired: Vehicle = null
		var preferred: Vehicle = null
		if is_instance_valid(controls.lock_target) and controls.lock_target is Vehicle:
			preferred = controls.lock_target as Vehicle
		if preferred != null and not preferred.is_dead and preferred.category == GameDB.Category.AIR:
			var to_p := preferred.global_position - global_position
			if to_p.length() < AAM_RANGE and rad_to_deg(get_forward().angle_to(to_p)) < AAM_LOCK_CONE:
				desired = preferred
		if desired == null:
			desired = find_target_in_cone(get_forward(), AAM_LOCK_CONE, AAM_RANGE, "air", Vector3.ZERO)
		if desired != lock_target:
			lock_target = desired
			lock_progress = 0.0
		gun_target = find_target_in_cone(get_forward(), 18.0, 1800.0, "any", Vector3.ZERO)
	if lock_target != null:
		var before := lock_progress
		lock_progress = minf(lock_progress + delta / AAM_LOCK_TIME, 1.0)
		if is_player:
			_lock_tone_timer -= delta
			if lock_progress >= 1.0 and before < 1.0:
				SoundFX.play_ui("locked", -8.0)
			elif lock_progress < 1.0 and _lock_tone_timer <= 0.0:
				_lock_tone_timer = 0.25
				SoundFX.play_ui("beep", -14.0)
	hud_hint = ""
	if lock_target != null:
		hud_hint = "Р-73: ЦЕЛЬ ЗАХВАЧЕНА" if lock_progress >= 1.0 else "Р-73: ЗАХВАТ %d%%" % int(lock_progress * 100.0)


func _fire_cannon() -> void:
	var p := Projectile.new()
	var dir := GameDB.spread_direction(get_forward(), 0.35, _rng)
	p.velocity = velocity + dir * GUN_SPEED
	p.drag = GUN_DRAG
	p.damage = 11.0
	p.damage_type = "bullet"
	p.max_lifetime = 2.2
	p.tracer_color = Color(1.0, 0.85, 0.4)
	p.tracer_width = 0.28
	p.setup(team, make_source("ГШ-30-1"), self)
	p.position = _muzzle.global_position
	level.spawn_projectile(p)
	_flash_timer = 0.035
	SoundFX.play_3d("cannon_air", p.position, -4.0, 1.0, 22.0)


func _launch_aam() -> void:
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
	var hardpoint: Node3D = _missile_visuals[clampi(aam.ammo, 0, _missile_visuals.size() - 1)]
	m.position = hardpoint.global_position
	m.velocity = velocity - global_basis.y * 6.0
	m.setup(team, make_source("Р-73"), self)
	level.spawn_projectile(m)


func get_lock_info() -> Dictionary:
	if lock_target == null or not is_instance_valid(lock_target):
		return {}
	return {"target": lock_target, "progress": lock_progress}


func get_lead_info() -> Dictionary:
	if gun_target == null or not is_instance_valid(gun_target):
		return {}
	var lead := BallisticSolver.compute_lead(global_position, velocity, gun_target.global_position, gun_target.velocity, GUN_SPEED, GUN_DRAG, GameDB.GRAVITY)
	return {"target": gun_target, "point": lead}
