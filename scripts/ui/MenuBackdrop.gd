class_name MenuBackdrop
extends Node3D
## Кинематографичный 3D-фон главного меню: случайная карта (упрощённый рельеф, море, небо, облака,
## леса), над которой по кругу летит звено из трёх самолётов; камера плавно облетает строй и
## периодически меняет ракурс. Рельеф генерируется в фоновом потоке — меню не подвисает.

const RESOLUTION := 256
const ALTITUDE := 620.0
const RADIUS := 2600.0
const SPEED := 110.0
const SHOT_TIME := 14.0

var camera: Camera3D = null
var map_id: String = "coast"

var _layout: MapLayout = null
var _terrain: Terrain = null
var _thread: Thread = null
var _planes: Array[Dictionary] = []
var _center: Vector3 = Vector3.ZERO
var _angle: float = 0.0
var _time: float = 0.0
var _shot: int = 0
var _shot_time: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_rng.randomize()
	map_id = MapPresets.ORDER[_rng.randi() % MapPresets.ORDER.size()]
	_layout = MapLayout.new(map_id)
	var quality := mini(GameSettings.quality, 2)
	var atmo := Atmosphere.create(self, _layout.preset, quality)
	(atmo["env"] as Environment).ssao_enabled = false
	camera = Camera3D.new()
	camera.fov = 48.0
	camera.near = 0.5
	camera.far = 50000.0
	add_child(camera)
	camera.make_current()
	_center = _pick_center()
	_spawn_formation()
	_update_flight(0.0)
	_terrain = Terrain.new(_layout, _rng.randi_range(1, 99999), RESOLUTION)
	_thread = Thread.new()
	_thread.start(_generate.bind(quality))
	set_process(true)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
		_thread = null


## Центр круга полёта — над береговой линией своей базы, чтобы в кадре были и суша, и море.
func _pick_center() -> Vector3:
	var p := _layout.pier_root[0].lerp(_layout.airfield[0], 0.35)
	return Vector3(p.x, ALTITUDE, p.y)


func _generate(quality: int) -> Dictionary:
	_terrain.generate()
	var builder := TerrainMeshBuilder.new(_terrain, 8, 2)
	var meshes := builder.build_all(4)
	var veg := Vegetation.plan(_terrain, maxi(quality - 1, 0), 7)
	var clouds := CloudField.plan(_layout, maxi(quality - 1, 0), 11)
	return {"builder": builder, "meshes": meshes, "veg": veg, "clouds": clouds}


func _finish_generation() -> void:
	var data: Dictionary = _thread.wait_to_finish()
	_thread = null
	var quality := mini(GameSettings.quality, 2)
	var sun_dir := Atmosphere.sun_direction(_layout.preset.get("sky", {}))
	var sun_color: Color = (_layout.preset.get("sky", {}) as Dictionary).get("sun_color", Color.WHITE)
	var clouds := CloudField.new()
	add_child(clouds)
	clouds.build(data["clouds"], _layout, sun_dir, sun_color, maxi(quality - 1, 0))
	var renderer := TerrainRenderer.new()
	add_child(renderer)
	renderer.setup_material(_layout, clouds.shadow_texture, clouds.shadow_params, sun_dir, quality)
	renderer.commit(data["builder"], data["meshes"], 0)
	var water := WaterSurface.new()
	add_child(water)
	water.setup(_terrain, clouds.shadow_texture, clouds.shadow_params, sun_dir)
	var veg := Vegetation.new()
	add_child(veg)
	veg.build(data["veg"], _layout)
	var ground := _terrain.get_surface_height(_center.x, _center.z)
	_center.y = maxf(ALTITUDE, ground + 450.0)


func _spawn_formation() -> void:
	var era := _rng.randi_range(0, 2)
	var pool: Array[String] = []
	for t in GameDB.types_with_role("fighter", era):
		pool.append(t)
	if pool.is_empty():
		pool.append("p40")
	var lead_type := pool[_rng.randi() % pool.size()]
	var offsets := [Vector3.ZERO, Vector3(-17.0, -3.0, 20.0), Vector3(19.0, -5.0, 24.0)]
	var team := _rng.randi() % 2
	for i in 3:
		var type_id := lead_type if i == 0 or _rng.randf() < 0.7 else pool[_rng.randi() % pool.size()]
		var parts := AircraftBuilder.build(type_id, team)
		var model: Node3D = parts["root"]
		add_child(model)
		for b: Node3D in parts["prop_blades"]:
			b.visible = false
		for d: Node3D in parts["prop_discs"]:
			d.visible = true
		var scale_k := float(AircraftSpecs.get_spec(type_id).get("length", 10.0)) / 10.0
		_planes.append({"node": model, "offset": offsets[i] * maxf(scale_k, 1.0), "props": parts["props"], "phase": _rng.randf() * TAU})


func _process(delta: float) -> void:
	_time += delta
	if _thread != null and not _thread.is_alive():
		_finish_generation()
	_update_flight(delta)


func _update_flight(delta: float) -> void:
	_angle += delta * SPEED / RADIUS
	var pos := _center + Vector3(cos(_angle), 0.0, sin(_angle)) * RADIUS
	var tangent := Vector3(-sin(_angle), 0.0, cos(_angle))
	var bank := 0.28
	var lead_basis := GameDB.basis_from_forward(tangent).rotated(tangent, -bank)
	for p in _planes:
		var node: Node3D = p["node"]
		var off: Vector3 = p["offset"]
		var bob := Vector3(0.0, sin(_time * 0.9 + float(p["phase"])) * 0.8, 0.0)
		node.global_position = pos + lead_basis * off + bob
		node.global_basis = lead_basis.rotated(tangent, sin(_time * 0.7 + float(p["phase"])) * 0.03)
		for hub: Node3D in p["props"]:
			hub.rotate_object_local(Vector3.FORWARD, delta * 40.0)
	_shot_time += delta
	if _shot_time > SHOT_TIME:
		_shot_time = 0.0
		_shot = (_shot + 1) % 4
	var t := _shot_time / SHOT_TIME
	var cam_off: Vector3
	match _shot:
		0:
			cam_off = Vector3(-38.0 + t * 20.0, 6.0, -32.0 + t * 10.0)
		1:
			cam_off = Vector3(30.0, -4.0 + t * 6.0, 55.0 - t * 15.0)
		2:
			cam_off = Vector3(-60.0 + t * 110.0, 14.0, 18.0)
		_:
			cam_off = Vector3(12.0, 26.0 - t * 10.0, -70.0 + t * 30.0)
	var focus := pos + lead_basis * Vector3(0.0, -2.0, 12.0)
	var level_basis := GameDB.basis_from_forward(tangent)
	var target_pos := focus + level_basis * cam_off
	if camera.global_position == Vector3.ZERO or _shot_time < delta * 1.5:
		camera.global_position = target_pos
	else:
		camera.global_position = camera.global_position.lerp(target_pos, clampf(delta * 3.0, 0.0, 1.0))
	camera.global_basis = GameDB.basis_from_forward(focus - camera.global_position)
