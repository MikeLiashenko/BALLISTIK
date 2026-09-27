class_name SAMLauncher
extends GroundVehicle
## Зенитный ракетный комплекс (Бук-М1 / Patriot): РЛС обнаружения и захвата (7 км), пусковая
## установка с четырьмя ЗУР. Цель захватывается за LOCK_TIME при удержании в зоне захвата;
## после захвата пусковая автоматически разворачивается на цель. Ракеты — управляемые,
## с физикой разгона (стартовый и маршевый двигатель) и пропорциональным наведением.

const RADAR_RANGE := 7000.0
const LOCK_TIME := 1.8
const LOCK_CONE := 16.0

var missiles: Weapon
var lock_target: Vehicle = null
var lock_progress: float = 0.0
## Множитель времени захвата (боты на лёгких уровнях захватывают дольше).
var lock_time_scale: float = 1.0

var _launcher: Node3D = null
var _missile_nodes: Array[Node3D] = []
var _launch_points: Array[Node3D] = []
var _radar: Node3D = null
var _scan_timer: float = 0.0
var _beep_timer: float = 0.0


func _init() -> void:
	vehicle_type = "sam"


func _build() -> void:
	max_health = 240.0
	hit_radius = 5.0
	damage_modifiers = {"bullet": 0.5, "flak": 0.6, "missile": 0.85}
	max_forward_speed = 12.0
	max_reverse_speed = 5.0
	turn_rate = 0.8
	turret_yaw_rate = 1.3
	var parts := VehicleModels.build_sam(team)
	model = parts["root"]
	add_child(model)
	turret = parts["turret"]
	gun_pivot = null
	_launcher = parts["launcher"]
	_radar = parts["radar"]
	_missile_nodes.assign(parts["missiles"])
	_launch_points.assign(parts["launch_points"])
	_add_box_collision(Vector3(3.4, 3.8, 10.0), Vector3(0.0, 1.9, 0.0))
	var missile_name := "ЗУР PAC-2" if team == GameDB.TEAM_BLUE else "ЗУР 9М38"
	missiles = Weapon.new("sam", missile_name, 4, 2.0, 9.0)
	weapons = [missiles]


func _turret_aim_point() -> Variant:
	if lock_target != null and is_instance_valid(lock_target):
		return lock_target.global_position
	return super._turret_aim_point()


func _handle_weapons(delta: float) -> void:
	if _radar != null:
		_radar.rotate_y(delta * 2.5)
	_update_lock(delta)
	if controls.fire_primary and missiles.can_fire() and lock_progress >= 1.0 and lock_target != null and _launcher_aligned():
		missiles.consume()
		_launch()
	for i in _missile_nodes.size():
		_missile_nodes[i].visible = i < missiles.ammo


func _aim_direction() -> Vector3:
	if controls.has_aim:
		return (controls.aim_point - (global_position + Vector3.UP * 3.0)).normalized()
	return -turret.global_basis.z


func _update_lock(delta: float) -> void:
	if lock_target != null and (not is_instance_valid(lock_target) or lock_target.is_dead):
		lock_target = null
		lock_progress = 0.0
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.2
		var desired: Vehicle = null
		if is_instance_valid(controls.lock_target) and controls.lock_target is Vehicle:
			var preferred := controls.lock_target as Vehicle
			if not preferred.is_dead and preferred.category == GameDB.Category.AIR and preferred.team != team:
				var eye := global_position + Vector3.UP * 3.0
				if eye.distance_to(preferred.global_position) < RADAR_RANGE and terrain.line_of_sight(eye, preferred.global_position):
					desired = preferred
		if desired == null:
			desired = find_target_in_cone(_aim_direction(), LOCK_CONE, RADAR_RANGE, "air", Vector3.UP * 3.0)
		if desired == null and lock_target != null:
			var eye := global_position + Vector3.UP * 3.0
			if eye.distance_to(lock_target.global_position) < RADAR_RANGE and terrain.line_of_sight(eye, lock_target.global_position):
				desired = lock_target
		if desired != lock_target:
			lock_target = desired
			lock_progress = 0.0
	if lock_target != null:
		var before := lock_progress
		lock_progress = minf(lock_progress + delta / (LOCK_TIME * lock_time_scale), 1.0)
		if is_player:
			_beep_timer -= delta
			if lock_progress >= 1.0 and before < 1.0:
				SoundFX.play_ui("locked", -8.0)
			elif lock_progress < 1.0 and _beep_timer <= 0.0:
				_beep_timer = 0.3
				SoundFX.play_ui("beep", -14.0)
		hud_hint = "РЛС: ЦЕЛЬ ЗАХВАЧЕНА — ПУСК РАЗРЕШЁН" if lock_progress >= 1.0 else "РЛС: ЗАХВАТ %d%%" % int(lock_progress * 100.0)
	else:
		hud_hint = "РЛС: НАВЕДИТЕ ПРИЦЕЛ НА ВОЗДУШНУЮ ЦЕЛЬ"


func _launcher_aligned() -> bool:
	if lock_target == null:
		return false
	var fwd := GameDB.flat(-_launcher.global_basis.z)
	var to_t := GameDB.flat(lock_target.global_position - _launcher.global_position)
	return rad_to_deg(fwd.angle_to(to_t)) < 25.0


func _launch() -> void:
	var idx := clampi(missiles.ammo, 0, _launch_points.size() - 1)
	var lp := _launch_points[idx]
	var m := GuidedMissile.new()
	m.target = lock_target
	m.mesh_kind = "sam"
	m.trail_kind = "large"
	m.tail_offset = 2.9
	m.thrust = 170.0
	m.burn_time = 3.0
	m.sustain_thrust = 45.0
	m.sustain_time = 5.0
	m.max_speed = 1000.0
	m.max_g = 26.0
	m.drag = 0.00003
	m.blast_radius = 17.0
	m.blast_damage = 220.0
	m.proximity_radius = 12.0
	m.max_lifetime = 20.0
	m.seeker_fov_deg = 140.0
	m.flare_resistance = 0.75
	m.velocity = -_launcher.global_basis.z * 40.0
	m.position = lp.global_position
	m.setup(team, make_source("ЗУР"), self)
	level.spawn_projectile(m)


func get_lock_info() -> Dictionary:
	if lock_target == null or not is_instance_valid(lock_target):
		return {}
	return {"target": lock_target, "progress": lock_progress}
