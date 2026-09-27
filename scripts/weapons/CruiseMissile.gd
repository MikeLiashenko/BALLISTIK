class_name CruiseMissile
extends Projectile
## Крылатая ракета (Х-59): маршевый полёт на малой высоте с огибанием рельефа к точке цели,
## при подходе — довыбор цели рядом с точкой и пикирование. Предназначена для ударов по кораблям
## и береговой ПВО.

var target_point: Vector3 = Vector3.ZERO
var target_node: Node3D = null
var cruise_speed: float = 250.0
var cruise_altitude: float = 40.0
var turn_rate: float = 1.1

var _trail: GPUParticles3D = null
var _marker: TacticalMarker = null


func _init() -> void:
	show_tracer = false
	gravity_scale = 0.0
	drag = 0.0
	damage = 0.0
	damage_type = "cruise"
	blast_radius = 24.0
	blast_damage = 390.0
	structure_multiplier = 1.5
	max_lifetime = 45.0


func _build_visual() -> void:
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = VehicleModels.missile_mesh("cruise")
	add_child(body)
	var flame := MeshInstance3D.new()
	flame.mesh = MeshFactory.cylinder(0.05, 0.22, 1.8, 8)
	flame.material_override = MeshFactory.glow(Color(1.0, 0.7, 0.35), 5.0)
	flame.transform = MeshFactory.along_z(Vector3(0.0, 0.0, 3.4))
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame)
	_trail = Effects.create_trail("small")
	_trail.position = Vector3(0.0, 0.0, 2.6)
	add_child(_trail)
	if target_node == null:
		target_node = _acquire_near(target_point)
	_marker = TacticalMarker.create_impact_marker(target_point, blast_radius)
	SoundFX.play_3d("missile", global_position, 2.0, 0.7, 40.0)


## Ищет вражескую цель рядом с точкой прицеливания (корабли и ПВО — в приоритете).
func _acquire_near(point: Vector3) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	for v in GlobalBattleManager.enemies_in_radius(team, point, 160.0):
		if v.category == GameDB.Category.AIR:
			continue
		var s := v.global_position.distance_to(point)
		if v.vehicle_type == "warship" or v.vehicle_type == "sam":
			s *= 0.5
		if s < best_score:
			best_score = s
			best = v
	if best == null:
		for b in GlobalBattleManager.enemy_structures_in_radius(team, point, 120.0):
			var s := b.global_position.distance_to(point)
			if s < best_score:
				best_score = s
				best = b
	return best


func _integrate(delta: float) -> void:
	var pos := global_position
	if target_node != null:
		if not is_instance_valid(target_node):
			target_node = null
		elif target_node is Vehicle and (target_node as Vehicle).is_dead:
			target_node = null
		elif target_node is Building and (target_node as Building).is_dead:
			target_node = null
	var aim := target_point
	if target_node != null:
		aim = target_node.global_position + Vector3(0.0, 2.0, 0.0)
		target_point = aim
		if _marker != null and is_instance_valid(_marker):
			_marker.global_position = Vector3(aim.x, aim.y + 0.5, aim.z)
	var flat_dist := GameDB.flat_distance(aim, pos)
	var desired: Vector3
	if flat_dist > 450.0 and terrain != null:
		var ahead := pos + GameDB.flat(velocity).normalized() * 220.0
		var ground := maxf(terrain.get_surface_height(ahead.x, ahead.z), terrain.get_surface_height(pos.x, pos.z))
		var alt := ground + cruise_altitude
		desired = Vector3(aim.x - pos.x, 0.0, aim.z - pos.z).normalized()
		desired.y = clampf((alt - pos.y) / 120.0, -0.5, 0.7)
		desired = desired.normalized()
	else:
		desired = (aim - pos).normalized()
	var cur := velocity.normalized() if velocity.length() > 1.0 else -global_basis.z
	var rate := turn_rate * (2.2 if flat_dist < 450.0 else 1.0)
	var new_dir := GameDB.rotate_toward(cur, desired, rate * delta)
	var spd := move_toward(velocity.length(), cruise_speed, 80.0 * delta)
	velocity = new_dir * spd
	global_position += velocity * delta


func _on_finish() -> void:
	Effects.detach_trail(_trail)
	_trail = null
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
