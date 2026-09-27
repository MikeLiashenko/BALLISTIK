class_name Torpedo
extends Projectile
## Торпеда: идёт под водой на глубине хода, оставляет пенный след на поверхности,
## самонаводится на вражеские корабли в конусе акустической ГСН. Взрывается о корпус, дно или берег.

const RUN_DEPTH := -1.3

var run_speed: float = 34.0
var homing_range: float = 480.0
var homing_cone_deg: float = 50.0
var turn_rate: float = 0.45
var target: Vehicle = null

var _wake: GPUParticles3D = null


func _init() -> void:
	show_tracer = false
	gravity_scale = 0.0
	drag = 0.0
	damage = 0.0
	damage_type = "torpedo"
	blast_radius = 9.0
	blast_damage = 560.0
	structure_multiplier = 1.0
	max_lifetime = 55.0


func _build_visual() -> void:
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = VehicleModels.missile_mesh("torpedo")
	add_child(body)
	_wake = Effects.create_wake()
	_wake.amount = maxi(int(40.0 * GameSettings.particle_scale()), 8)
	_wake.position = Vector3(0.0, 1.4, 3.0)
	add_child(_wake)
	Effects.water_splash(global_position, 5.0)
	SoundFX.play_3d("torpedo", global_position, 0.0, 1.0, 25.0)


func _integrate(delta: float) -> void:
	var pos := global_position
	var dir := GameDB.flat(velocity)
	if dir.length_squared() < 0.01:
		dir = GameDB.flat(-global_basis.z)
	dir = dir.normalized()
	if target == null or not is_instance_valid(target) or target.is_dead:
		target = _find_target(pos, dir)
	if target != null:
		dir = GameDB.rotate_toward(dir, GameDB.flat(target.global_position - pos), turn_rate * delta)
	velocity = dir * run_speed
	var y := move_toward(pos.y, RUN_DEPTH, 3.0 * delta)
	global_position = Vector3(pos.x + velocity.x * delta, y, pos.z + velocity.z * delta)


func _find_target(pos: Vector3, dir: Vector3) -> Vehicle:
	var best: Vehicle = null
	var best_d := homing_range
	for v in GlobalBattleManager.enemies_in_radius(team, pos, homing_range, GameDB.Category.NAVAL):
		var to_t := GameDB.flat(v.global_position - pos)
		if rad_to_deg(dir.angle_to(to_t)) > homing_cone_deg * 0.5:
			continue
		var d := to_t.length() * (0.6 if v.vehicle_type == "warship" else 1.0)
		if d < best_d:
			best_d = d
			best = v
	return best


## Под водой торпеда «видит» только дно и берег.
func _surface_hit(_from: Vector3, to: Vector3) -> Dictionary:
	if terrain == null:
		return {}
	if terrain.get_height(to.x, to.z) > to.y - 0.3:
		return {"position": to, "water": true}
	return {}


func _explode(pos: Vector3) -> void:
	Explosion.spawn(Vector3(pos.x, 0.4, pos.z), blast_radius, blast_damage, damage_type, team, source, structure_multiplier, true)


func _on_finish() -> void:
	Effects.detach_trail(_wake)
	_wake = null
