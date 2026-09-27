class_name Projectile
extends Node3D
## Физический снаряд: скорость, гравитация, квадратичное сопротивление воздуха (падение по оси Y).
## Попадание определяется лучом между положениями на соседних физических шагах — быстрые снаряды
## не «проскакивают» цели. Столкновение с рельефом и водой — по аналитической поверхности Terrain.
## Поддерживает трассер, неконтактный взрыватель и взрыв с зоной поражения (Explosion / Area3D).

var velocity: Vector3 = Vector3.ZERO
var gravity_scale: float = 1.0
var drag: float = 0.0
var damage: float = 10.0
var damage_type: String = "bullet"
var blast_radius: float = 0.0
var blast_damage: float = 0.0
var structure_multiplier: float = 1.0
var proximity_radius: float = 0.0
var proximity_damage: float = 0.0
var max_lifetime: float = 4.0
var team: int = -1
var source: Dictionary = {}
var shooter: Vehicle = null
var show_tracer: bool = true
var tracer_color: Color = Color(1.0, 0.8, 0.35)
var tracer_width: float = 0.22
var age: float = 0.0
var terrain: Terrain = null

var _exclude: Array[RID] = []
var _dead: bool = false


func setup(p_team: int, p_source: Dictionary, p_shooter: Vehicle) -> void:
	team = p_team
	source = p_source
	shooter = p_shooter


func _ready() -> void:
	var level := GlobalBattleManager.level
	if level != null:
		terrain = level.terrain
	if shooter != null and is_instance_valid(shooter):
		_exclude.append(shooter.get_rid())
	_build_visual()
	_orient()
	reset_physics_interpolation()


func _build_visual() -> void:
	if not show_tracer:
		return
	var length := clampf(velocity.length() * 0.011, 3.0, 14.0)
	var tracer := MeshInstance3D.new()
	tracer.name = "Tracer"
	tracer.mesh = MeshFactory.box(Vector3.ONE)
	tracer.material_override = MeshFactory.glow(tracer_color, 6.0)
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tracer.scale = Vector3(tracer_width, tracer_width, length)
	tracer.position = Vector3(0.0, 0.0, length * 0.5)
	add_child(tracer)


func _orient() -> void:
	if velocity.length_squared() > 0.01:
		global_basis = GameDB.basis_from_forward(velocity)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	age += delta
	var from := global_position
	_integrate(delta)
	if _dead:
		return
	var to := global_position
	if _check_collisions(from, to):
		return
	if age >= max_lifetime:
		_expire()
		return
	_orient()


## Шаг интегрирования (полуявный метод Эйлера): v += a·dt; p += v·dt.
func _integrate(delta: float) -> void:
	velocity += BallisticSolver.acceleration(velocity, GameDB.GRAVITY * gravity_scale, drag) * delta
	global_position += velocity * delta


func _check_collisions(from: Vector3, to: Vector3) -> bool:
	var hit := _ray_hit(from, to)
	var surface := _surface_hit(from, to)
	if not hit.is_empty():
		var hp: Vector3 = hit["position"]
		var closer := true
		if not surface.is_empty():
			var sp: Vector3 = surface["position"]
			closer = from.distance_squared_to(hp) <= from.distance_squared_to(sp)
		if closer:
			_on_hit_object(hit["collider"], hp)
			return true
	if not surface.is_empty():
		_on_hit_surface(surface["position"], bool(surface["water"]))
		return true
	if proximity_radius > 0.0 and age > 0.06:
		var target := _proximity_target(from, to)
		if target != null:
			_on_proximity(target, from, to)
			return true
	return false


## Луч по технике и сооружениям. Своя техника пропускается (без огня по своим).
func _ray_hit(from: Vector3, to: Vector3) -> Dictionary:
	if from.is_equal_approx(to):
		return {}
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, GameDB.MASK_DAMAGEABLE, _exclude)
	for attempt in 4:
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return {}
		var collider: Object = hit["collider"]
		if collider is Vehicle and (collider as Vehicle).team == team and team >= 0:
			_exclude.append(hit["rid"])
			query.exclude = _exclude
			continue
		return hit
	return {}


## Пересечение отрезка с поверхностью рельефа/воды.
func _surface_hit(from: Vector3, to: Vector3) -> Dictionary:
	if terrain == null:
		return {}
	if to.y > terrain.get_surface_height(to.x, to.z):
		var seg := from.distance_to(to)
		if seg > 25.0:
			var steps := int(seg / 25.0)
			for i in range(1, steps + 1):
				var p := from.lerp(to, float(i) / float(steps + 1))
				if p.y <= terrain.get_surface_height(p.x, p.z):
					return _refine_surface(from, p)
		return {}
	return _refine_surface(from, to)


func _refine_surface(a: Vector3, b: Vector3) -> Dictionary:
	var lo := a
	var hi := b
	for i in 8:
		var mid := (lo + hi) * 0.5
		if mid.y <= terrain.get_surface_height(mid.x, mid.z):
			hi = mid
		else:
			lo = mid
	return {"position": hi, "water": terrain.get_height(hi.x, hi.z) < 0.0}


func _proximity_target(from: Vector3, to: Vector3) -> Vehicle:
	var best: Vehicle = null
	var best_d := proximity_radius
	for v in GlobalBattleManager.units:
		if not is_instance_valid(v) or v.is_dead or v.team == team or v.category != GameDB.Category.AIR:
			continue
		var d := segment_distance(from, to, v.global_position) - v.hit_radius * 0.5
		if d < best_d:
			best_d = d
			best = v
	return best


static func segment_distance(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _on_hit_object(collider: Object, pos: Vector3) -> void:
	global_position = pos
	GlobalBattleManager.smoke_count("hit_" + str(get_script().get_global_name()))
	if blast_radius > 0.0:
		_explode(pos)
	else:
		if collider != null and collider.has_method("apply_damage"):
			collider.call("apply_damage", damage, damage_type, source)
		Effects.bullet_impact(pos, false, true)
		if randf() < 0.35:
			SoundFX.play_3d("hit", pos, -8.0, 1.0, 14.0)
	_finish()


func _on_hit_surface(pos: Vector3, water: bool) -> void:
	global_position = pos
	if blast_radius > 0.0:
		_explode(pos)
	else:
		Effects.bullet_impact(pos, water, false)
	_finish()


func _on_proximity(target: Vehicle, from: Vector3, to: Vector3) -> void:
	GlobalBattleManager.smoke_count("proximity_" + str(get_script().get_global_name()))
	var ab := to - from
	var t := clampf((target.global_position - from).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	var pos := from + ab * t
	global_position = pos
	if blast_radius > 0.0:
		_explode(pos)
	else:
		target.apply_damage(proximity_damage, "flak", source)
		Effects.flak_burst(pos)
	_finish()


func _explode(pos: Vector3) -> void:
	var over_water := terrain != null and terrain.get_height(pos.x, pos.z) < 0.0 and pos.y < 4.0
	Explosion.spawn(pos, blast_radius, blast_damage, damage_type, team, source, structure_multiplier, over_water)


## Перехват средствами ПРО/ЗАК: ракета разрушается в воздухе без нанесения урона.
func intercept() -> void:
	if _dead:
		return
	Effects.explosion(global_position, 6.0, false)
	GlobalBattleManager.smoke_count("intercepted_" + str(get_script().get_global_name()))
	_finish()


## Истечение времени жизни: зенитные снаряды самоликвидируются в воздухе, ракеты — подрыв.
func _expire() -> void:
	GlobalBattleManager.smoke_count("expired_" + str(get_script().get_global_name()))
	if blast_radius > 0.0:
		_explode(global_position)
	elif proximity_radius > 0.0:
		Effects.flak_burst(global_position)
	_finish()


func _finish() -> void:
	if _dead and not is_inside_tree():
		return
	_dead = true
	_on_finish()
	queue_free()


## Переопределяется наследниками (отцепить дымовой шлейф, снять регистрацию с цели).
func _on_finish() -> void:
	pass
