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

var target_point: Vector3 = Vector3.ZERO
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


func _build_visual() -> void:
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


func _integrate(delta: float) -> void:
	var g := GameDB.GRAVITY * gravity_scale
	velocity += BallisticSolver.acceleration(velocity, g, drag) * delta
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
