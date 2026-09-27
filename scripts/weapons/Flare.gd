class_name Flare
extends Node3D
## Тепловая ловушка (ЛТЦ): яркая горящая частица, падающая с сопротивлением. Отвлекает ракеты с ИК ГСН.

var velocity: Vector3 = Vector3.ZERO
var life: float = 3.5


func _ready() -> void:
	var core := MeshInstance3D.new()
	core.mesh = MeshFactory.sphere(0.6, -1.0, 8, 4)
	core.material_override = MeshFactory.glow(Color(1.0, 0.85, 0.5), 8.0)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	var halo := MeshInstance3D.new()
	halo.mesh = MeshFactory.sphere(1.6, -1.0, 8, 4)
	halo.material_override = MeshFactory.shared_fade_material("flare_halo", Color(1.0, 0.6, 0.2, 0.35), true)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	velocity += Vector3(0.0, -GameDB.GRAVITY * 0.6, 0.0) * delta
	velocity *= maxf(1.0 - 1.4 * delta, 0.0)
	global_position += velocity * delta
	scale = Vector3.ONE * clampf(life / 1.5, 0.3, 1.0)
