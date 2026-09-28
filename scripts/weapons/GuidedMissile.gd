class_name GuidedMissile
extends Projectile
## Управляемая ракета — «воздух-воздух» (Р-73) или зенитная (ЗУР Бук/Patriot).
## Физика: разгон маршевым двигателем (тяга в течение burn_time), сопротивление, гравитация.
## Наведение: пропорциональная навигация с ограничением перегрузки (max_g), ГСН с конусом обзора,
## неконтактный взрыватель, дымовой шлейф GPUParticles3D. Может быть отвлечена тепловыми ловушками.

var target: Node3D = null
var thrust: float = 220.0
var burn_time: float = 2.5
var sustain_thrust: float = 0.0
var sustain_time: float = 0.0
var max_speed: float = 950.0
var max_g: float = 30.0
var nav_constant: float = 4.0
var seeker_fov_deg: float = 110.0
var flare_resistance: float = 0.5
var mesh_kind: String = "aam"
var trail_kind: String = "small"
var tail_offset: float = 1.5
## Время от пуска до включения наведения (вертикальный старт: ракета сначала уходит вверх).
var guidance_delay: float = 0.12
## Сколько секунд после включения наведения цель не теряется из поля зрения ГСН (разворот после
## вертикального старта).
var fov_grace: float = 0.0

var _trail: GPUParticles3D = null
var _flame: MeshInstance3D = null
var _registered: Vehicle = null


func _init() -> void:
	show_tracer = false
	drag = 0.00004
	damage = 0.0
	damage_type = "missile"
	max_lifetime = 12.0


func _build_visual() -> void:
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = VehicleModels.missile_mesh(mesh_kind)
	add_child(body)
	_flame = MeshInstance3D.new()
	_flame.name = "Flame"
	_flame.mesh = MeshFactory.cylinder(0.05, 0.35 if mesh_kind.begins_with("sam") else 0.2, 2.2, 8)
	_flame.material_override = MeshFactory.glow(Color(1.0, 0.7, 0.35), 6.0)
	_flame.transform = MeshFactory.along_z(Vector3(0.0, 0.0, tail_offset + 1.0))
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flame)
	_trail = Effects.create_trail(trail_kind)
	_trail.position = Vector3(0.0, 0.0, tail_offset)
	add_child(_trail)
	_register_on_target()
	SoundFX.play_3d("missile", global_position, 0.0, 1.0 if mesh_kind == "aam" else 0.8, 35.0)


func _register_on_target() -> void:
	if target is Vehicle:
		_registered = target as Vehicle
		_registered.incoming_missiles.append(self)


func _unregister() -> void:
	if _registered != null and is_instance_valid(_registered):
		_registered.incoming_missiles.erase(self)
	_registered = null


func _integrate(delta: float) -> void:
	var speed := velocity.length()
	var fwd := velocity / speed if speed > 1.0 else -global_basis.z
	var accel := BallisticSolver.acceleration(velocity, GameDB.GRAVITY * gravity_scale, drag)
	var engine_on := age < burn_time + sustain_time
	if age < burn_time:
		accel += fwd * thrust
	elif engine_on:
		accel += fwd * sustain_thrust
	if _flame != null:
		_flame.visible = engine_on
	if _trail != null and not engine_on and _trail.emitting and age > burn_time + sustain_time + 1.5:
		_trail.emitting = false
	_validate_target()
	if target != null and age > guidance_delay:
		var to_t := target.global_position - global_position
		var dist := to_t.length()
		if age > guidance_delay + fov_grace and rad_to_deg(fwd.angle_to(to_t)) > seeker_fov_deg * 0.5:
			_lose_target()
		elif dist > 0.5:
			var los := to_t / dist
			var rel := _target_velocity() - velocity
			var omega := to_t.cross(rel) / maxf(dist * dist, 1.0)
			var closing := maxf(-rel.dot(los), 80.0)
			var cmd := omega.cross(los) * (nav_constant * closing)
			cmd += Vector3.UP * GameDB.GRAVITY * gravity_scale
			var off := fwd.angle_to(los)
			if off > 0.3:
				cmd += (los - fwd).normalized() * max_g * GameDB.GRAVITY * 0.6
			cmd -= fwd * cmd.dot(fwd)
			accel += cmd.limit_length(max_g * GameDB.GRAVITY)
			if target is Flare and dist < 10.0:
				_expire()
				return
	velocity += accel * delta
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	global_position += velocity * delta


func _validate_target() -> void:
	if target == null:
		return
	if not is_instance_valid(target):
		_lose_target()
	elif target is Vehicle and (target as Vehicle).is_dead:
		_lose_target()


func _target_velocity() -> Vector3:
	if target is Vehicle:
		return (target as Vehicle).velocity
	if target is Flare:
		return (target as Flare).velocity
	return Vector3.ZERO


func _lose_target() -> void:
	if target != null:
		GlobalBattleManager.smoke_count("missile_lost_target")
	_unregister()
	target = null


## Реакция на отстрел тепловых ловушек целью.
func consider_decoy(flare: Node3D) -> void:
	if target == null or flare == null:
		return
	var to_flare := flare.global_position - global_position
	if velocity.length() > 1.0 and rad_to_deg(velocity.angle_to(to_flare)) > seeker_fov_deg * 0.5:
		return
	if randf() < (1.0 - flare_resistance) * 0.7:
		_unregister()
		target = flare
		GlobalBattleManager.smoke_count("missile_decoyed")


func _on_finish() -> void:
	_unregister()
	Effects.detach_trail(_trail)
	_trail = null
