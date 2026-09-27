class_name Rocket
extends Projectile
## Неуправляемая авиационная ракета (РС-82, HVAR): короткий разгон двигателем по линии пуска,
## затем баллистический полёт с сопротивлением; при ударе — взрыв с зоной поражения.

var motor_speed: float = 400.0
var burn_time: float = 0.8

var _trail: GPUParticles3D = null
var _flame: MeshInstance3D = null


func _init() -> void:
	show_tracer = false
	gravity_scale = 1.0
	drag = 0.00012
	damage = 0.0
	damage_type = "missile"
	blast_radius = 9.0
	blast_damage = 100.0
	structure_multiplier = 1.25
	max_lifetime = 9.0


func _build_visual() -> void:
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = VehicleModels.missile_mesh("rocket")
	add_child(body)
	_flame = MeshInstance3D.new()
	_flame.mesh = MeshFactory.cylinder(0.03, 0.14, 1.2, 8)
	_flame.material_override = MeshFactory.glow(Color(1.0, 0.72, 0.35), 6.0)
	_flame.transform = MeshFactory.along_z(Vector3(0.0, 0.0, 1.3))
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flame)
	_trail = Effects.create_trail("small")
	_trail.amount = maxi(int(40.0 * GameSettings.particle_scale()), 8)
	_trail.position = Vector3(0.0, 0.0, 0.9)
	add_child(_trail)


func _integrate(delta: float) -> void:
	if age < burn_time:
		var dir := velocity.normalized() if velocity.length() > 1.0 else -global_basis.z
		velocity += dir * (motor_speed / burn_time) * delta
	elif _flame != null and _flame.visible:
		_flame.visible = false
		_trail.emitting = false
	super._integrate(delta)


func _on_finish() -> void:
	Effects.detach_trail(_trail)
	_trail = null
