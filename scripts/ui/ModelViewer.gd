class_name ModelViewer
extends SubViewportContainer
## 3D-просмотр модели техники для лобби и ангара: собственный мир (небо для отражений, ключевой
## и заполняющий свет), поворотный стол с подсветкой, плавная автопрокрутка, вращение и наклон
## перетаскиванием мышью или пальцем, колесо — приближение.

var current_type: String = ""
var current_team: int = 0

var _vp: SubViewport = null
var _camera: Camera3D = null
var _holder: Node3D = null
var _props: Array = []
var _yaw: float = 0.7
var _pitch: float = -0.2
var _dist: float = 14.0
var _dist_target: float = 14.0
var _focus: Vector3 = Vector3.ZERO
var _dragging: bool = false
var _idle: float = 0.0


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X if GameSettings.quality >= 1 else Viewport.MSAA_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	var sky := Sky.new()
	sky.sky_material = Atmosphere.sky_material(MapPresets.get_map("coast"))
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.basis = GameDB.basis_from_forward(Vector3(0.5, -0.7, -0.45))
	key.light_energy = 1.5
	key.light_color = Color(1.0, 0.95, 0.88)
	key.shadow_enabled = GameSettings.quality >= 1
	key.directional_shadow_max_distance = 120.0
	_vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.basis = GameDB.basis_from_forward(Vector3(-0.6, -0.2, 0.7))
	fill.light_energy = 0.45
	fill.light_color = Color(0.7, 0.85, 1.0)
	_vp.add_child(fill)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.05
	cyl.radial_segments = 64
	disc.mesh = cyl
	disc.material_override = MeshFactory.mat(Color(0.035, 0.05, 0.065), 0.85, 0.0)
	disc.name = "Turntable"
	_vp.add_child(disc)
	var ring := MeshInstance3D.new()
	ring.mesh = MeshFactory.torus(0.985, 1.0, 96, 4)
	ring.material_override = MeshFactory.glow(UITheme.NEON, 2.0)
	ring.name = "Ring"
	disc.add_child(ring)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	_camera = Camera3D.new()
	_camera.fov = 34.0
	_camera.near = 0.1
	_camera.far = 800.0
	_vp.add_child(_camera)


func show_vehicle(type_id: String, team: int) -> void:
	if type_id == current_type and team == current_team:
		return
	current_type = type_id
	current_team = team
	for c in _holder.get_children():
		c.queue_free()
	_props.clear()
	var model: Node3D = null
	if GameDB.is_aircraft(type_id):
		var parts := AircraftBuilder.build(type_id, team)
		model = parts["root"]
		_props = parts["props"]
		for d: Node3D in parts["prop_discs"]:
			d.visible = false
		for f: Node3D in parts["afterburners"]:
			f.visible = false
	else:
		match type_id:
			"spaag":
				model = VehicleModels.build_spaag(team)["root"]
			"sam":
				model = VehicleModels.build_sam(team)["root"]
			"boat":
				model = VehicleModels.build_boat(team)["root"]
	if model == null:
		return
	_holder.add_child(model)
	var box := _aabb(model)
	var size := maxf(box.size.x, maxf(box.size.y, box.size.z))
	_focus = box.get_center()
	var floor_y := box.position.y - 0.05
	var disc := _vp.get_node("Turntable") as Node3D
	disc.position = Vector3(_focus.x, floor_y, _focus.z)
	disc.scale = Vector3(size * 0.42, 1.0, size * 0.42)
	_dist_target = size * 1.55
	_dist = _dist_target * 1.3


func _aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for child in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var mi := child as MeshInstance3D
			var box := mi.transform * mi.get_aabb()
			result = box if first else result.merge(box)
			first = false
		elif child is Node3D and not (child is Decal):
			var sub := _aabb(child)
			if sub.size != Vector3.ZERO:
				sub = (child as Node3D).transform * sub
				result = sub if first else result.merge(sub)
				first = false
	return result


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist_target *= 0.9
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist_target *= 1.1
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.01
		_pitch = clampf(_pitch - mm.relative.y * 0.006, -1.1, 0.35)
		_idle = 0.0
		accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_yaw -= sd.relative.x * 0.01
		_pitch = clampf(_pitch - sd.relative.y * 0.006, -1.1, 0.35)
		_idle = 0.0
		accept_event()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_idle += delta
	if not _dragging and _idle > 1.5:
		_yaw += delta * 0.25
	_dist = lerpf(_dist, _dist_target, clampf(delta * 4.0, 0.0, 1.0))
	var dir := Vector3(sin(_yaw) * cos(_pitch), -sin(_pitch), cos(_yaw) * cos(_pitch))
	_camera.position = _focus + dir * _dist
	_camera.look_at(_focus, Vector3.UP)
	for hub: Node3D in _props:
		if is_instance_valid(hub):
			hub.rotate_object_local(Vector3.FORWARD, delta * 2.5)
