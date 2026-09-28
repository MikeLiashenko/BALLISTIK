class_name BallisticMissile
extends Projectile
## Баллистическая ракета. Запускается в указанную на карте точку по параболической траектории:
## начальная скорость подбирается решателем (BallisticSolver) с учётом гравитации и сопротивления.
## На нисходящем участке — небольшая коррекция (манёвренная головная часть) для точного попадания.
## При ударе о землю, воду или объект — мощный взрыв с большим радиусом (Explosion / Area3D),
## наносящий повышенный урон зданиям и кораблям.

const ELEVATION_DEG := 42.0
const GRAVITY_SCALE := 4.0
const DRAG := 0.00002
const MIN_RANGE := 600.0
const MAX_RANGE := 9000.0
const BOOST_TIME := 1.6
## Неуправляемый реактивный снаряд залпа (М-8, Mk 50): пологая траектория, без коррекции на спуске.
const ROCKET_ELEVATION_DEG := 32.0
const ROCKET_GRAVITY_SCALE := 2.2
const ROCKET_DRAG := 0.00005
const ROCKET_BOOST := 0.7

var target_point: Vector3 = Vector3.ZERO
## Реактивный снаряд залпа вместо баллистической ракеты (задаётся до добавления в сцену).
var rocket: bool = false
var _trail: GPUParticles3D = null
var _flame: MeshInstance3D = null
var _marker: TacticalMarker = null


func _init() -> void:
	show_tracer = false
	gravity_scale = GRAVITY_SCALE
	drag = DRAG
	damage = 0.0
	damage_type = "ballistic"
	blast_radius = 38.0
	blast_damage = 430.0
	structure_multiplier = 1.6
	max_lifetime = 60.0


## Начальная скорость для попадания из from в target (Vector3.ZERO — вне досягаемости).
static func solve(from: Vector3, target: Vector3) -> Vector3:
	var flat_dist := GameDB.flat_distance(from, target)
	if flat_dist < MIN_RANGE or flat_dist > MAX_RANGE:
		return Vector3.ZERO
	return BallisticSolver.solve_launch_velocity(from, target, ELEVATION_DEG, GameDB.GRAVITY * GRAVITY_SCALE, DRAG, 60.0, 1400.0)


static func predict(from: Vector3, v0: Vector3, terrain_ref: Terrain) -> PackedVector3Array:
	return BallisticSolver.predict_path(from, v0, GameDB.GRAVITY * GRAVITY_SCALE, DRAG, 40.0, terrain_ref)


static func flight_time(from: Vector3, v0: Vector3, target_y: float) -> float:
	return BallisticSolver.estimate_flight_time(from, v0, target_y, GameDB.GRAVITY * GRAVITY_SCALE, DRAG)


static func solve_rocket(from: Vector3, target: Vector3) -> Vector3:
	var flat_dist := GameDB.flat_distance(from, target)
	if flat_dist < 300.0 or flat_dist > 6000.0:
		return Vector3.ZERO
	return BallisticSolver.solve_launch_velocity(from, target, ROCKET_ELEVATION_DEG, GameDB.GRAVITY * ROCKET_GRAVITY_SCALE, ROCKET_DRAG, 40.0, 900.0)


static func predict_rocket(from: Vector3, v0: Vector3, terrain_ref: Terrain) -> PackedVector3Array:
	return BallisticSolver.predict_path(from, v0, GameDB.GRAVITY * ROCKET_GRAVITY_SCALE, ROCKET_DRAG, 40.0, terrain_ref)


static func flight_time_rocket(from: Vector3, v0: Vector3, target_y: float) -> float:
	return BallisticSolver.estimate_flight_time(from, v0, target_y, GameDB.GRAVITY * ROCKET_GRAVITY_SCALE, ROCKET_DRAG)


func _build_visual() -> void:
	if rocket:
		_build_rocket_visual()
		return
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = VehicleModels.missile_mesh("ballistic")
	add_child(body)
	_flame = MeshInstance3D.new()
	_flame.name = "Flame"
	_flame.mesh = MeshFactory.cylinder(0.08, 0.6, 5.0, 10)
	_flame.material_override = MeshFactory.glow(Color(1.0, 0.72, 0.35), 7.0)
	_flame.transform = MeshFactory.along_z(Vector3(0.0, 0.0, 5.7))
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flame)
	_trail = Effects.create_trail("large")
	_trail.position = Vector3(0.0, 0.0, 3.4)
	add_child(_trail)
	_marker = TacticalMarker.create_impact_marker(target_point, blast_radius)
	SoundFX.play_3d("launch_heavy", global_position, 4.0, 1.0, 60.0)


func _build_rocket_visual() -> void:
	gravity_scale = ROCKET_GRAVITY_SCALE
	drag = ROCKET_DRAG
	structure_multiplier = 1.3
	max_lifetime = 30.0
	damage_type = "missile"
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = VehicleModels.missile_mesh("rocket")
	add_child(body)
	_flame = MeshInstance3D.new()
	_flame.mesh = MeshFactory.cylinder(0.03, 0.14, 1.4, 8)
	_flame.material_override = MeshFactory.glow(Color(1.0, 0.72, 0.35), 6.0)
	_flame.transform = MeshFactory.along_z(Vector3(0.0, 0.0, 1.5))
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flame)
	_trail = Effects.create_trail("small")
	_trail.amount = maxi(int(40.0 * GameSettings.particle_scale()), 8)
	_trail.position = Vector3(0.0, 0.0, 0.9)
	add_child(_trail)
	SoundFX.play_3d("missile", global_position, -4.0, 1.3, 30.0)


func _integrate(delta: float) -> void:
	var g := GameDB.GRAVITY * gravity_scale
	velocity += BallisticSolver.acceleration(velocity, g, drag) * delta
	if rocket:
		global_position += velocity * delta
		if _flame != null:
			_flame.visible = age < ROCKET_BOOST
		if _trail != null and age > ROCKET_BOOST + 0.6:
			_trail.emitting = false
		return
	if velocity.y < 0.0:
		var h := global_position.y - target_point.y
		if h > 1.0:
			var vy := -velocity.y
			var t_left := maxf((-vy + sqrt(vy * vy + 2.0 * g * h)) / g, 0.05)
			var desired := Vector2(target_point.x - global_position.x, target_point.z - global_position.z) / t_left
			var correction := (desired - Vector2(velocity.x, velocity.z)).limit_length(30.0 * delta)
			velocity.x += correction.x
			velocity.z += correction.y
	global_position += velocity * delta
	if _flame != null:
		_flame.visible = age < BOOST_TIME


func _on_finish() -> void:
	Effects.detach_trail(_trail)
	_trail = null
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
