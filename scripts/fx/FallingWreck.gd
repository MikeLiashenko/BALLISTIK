class_name FallingWreck
extends Node3D
## Падающий горящий остов сбитого самолёта: летит по баллистической траектории, вращается,
## при ударе о землю или воду — взрыв и догорающие обломки.

var velocity: Vector3 = Vector3.ZERO
var spin: Vector3 = Vector3.ZERO
var terrain: Terrain = null
var _life: float = 30.0


static func spawn_from(model: Node3D, start_velocity: Vector3) -> void:
	var parent := GlobalBattleManager.get_fx_parent()
	if parent == null or model == null or not model.is_inside_tree():
		return
	var wreck := FallingWreck.new()
	wreck.name = "FallingWreck"
	wreck.velocity = start_velocity
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	wreck.spin = Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(-0.6, 0.6), rng.randf_range(-3.0, 3.0))
	parent.add_child(wreck)
	wreck.global_transform = model.global_transform
	model.reparent(wreck, true)
	Effects.char_model(model)
	var fire := Effects.create_fire()
	wreck.add_child(fire)


func _ready() -> void:
	var level := GlobalBattleManager.level
	if level != null:
		terrain = level.terrain


func _physics_process(delta: float) -> void:
	_life -= delta
	velocity += Vector3(0.0, -GameDB.GRAVITY, 0.0) * delta
	velocity *= maxf(1.0 - 0.12 * delta, 0.0)
	global_position += velocity * delta
	rotate_object_local(Vector3.RIGHT, spin.x * delta)
	rotate_object_local(Vector3.UP, spin.y * delta)
	rotate_object_local(Vector3.FORWARD, spin.z * delta)
	var ground := 0.0
	if terrain != null:
		ground = terrain.get_surface_height(global_position.x, global_position.z)
	if global_position.y <= ground + 1.0 or _life <= 0.0:
		var water := terrain != null and terrain.get_height(global_position.x, global_position.z) < 0.0
		var p := Vector3(global_position.x, ground + 1.0, global_position.z)
		Effects.explosion(p, 12.0, water)
		if not water:
			Effects.spawn_wreck(p, Basis(Vector3.UP, rotation.y), Vector3(7.0, 2.5, 12.0), false)
		queue_free()
