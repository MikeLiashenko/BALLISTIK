extends SceneTree
## Рендер моделей самолётов для визуальной проверки (запуск с окном — на скрытом рабочем столе):
## godot --path . --script res://tests/hangar_shots.gd -- --out=DIR [--types=a,b] [--team=0]

var out_dir := "user://hangar"
var types: Array[String] = []
var team := 0
var index := -1
var frames := 0
var cam: Camera3D
var holder: Node3D
var view := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--types="):
			for t in arg.get_slice("=", 1).split(","):
				types.append(t)
		elif arg.begins_with("--team="):
			team = int(arg.get_slice("=", 1))
	if types.is_empty():
		for t: String in GameDB.VEHICLE_ORDER:
			if GameDB.is_aircraft(t):
				types.append(t)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var world := Node3D.new()
	root.add_child(world)
	Atmosphere.create(world, MapPresets.get_map("coast"), 2)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	ground.position = Vector3(0, -6, 0)
	ground.material_override = MeshFactory.mat(Color(0.3, 0.34, 0.26), 0.95)
	world.add_child(ground)
	holder = Node3D.new()
	world.add_child(holder)
	cam = Camera3D.new()
	cam.fov = 40.0
	world.add_child(cam)
	cam.make_current()
	_next()

func _next() -> void:
	for c in holder.get_children():
		c.queue_free()
	index += 1
	view = 0
	frames = 0
	if index >= types.size():
		quit()
		return
	var t := types[index]
	var model: Node3D
	if GameDB.is_aircraft(t):
		var parts := AircraftBuilder.build(t, team)
		model = parts["root"]
		for d in parts["prop_discs"]:
			(d as Node3D).visible = false
	else:
		match t:
			"spaag":
				model = VehicleModels.build_spaag(team)["root"]
			"sam":
				model = VehicleModels.build_sam(team)["root"]
			"boat":
				model = VehicleModels.build_boat(team)["root"]
			_:
				model = VehicleModels.build_destroyer(team)["root"]
	holder.add_child(model)
	_place_camera()

func _place_camera() -> void:
	var t := types[index]
	var L := float(AircraftSpecs.get_spec(t).get("length", 10.0)) if GameDB.is_aircraft(t) else float({"spaag": 8.0, "sam": 11.0, "boat": 12.0}.get(t, 90.0))
	var dist := L * 1.55
	var dirs := [Vector3(-0.75, 0.32, -0.9), Vector3(0.9, 0.55, 0.5), Vector3(0.0, 1.0, 0.02)]
	var d: Vector3 = dirs[view].normalized()
	cam.look_at_from_position(d * dist, Vector3.ZERO, Vector3.UP if view < 2 else Vector3.FORWARD)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 8:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out_dir.path_join("%s_%d.png" % [types[index], view]))
		view += 1
		frames = 0
		if view >= 3:
			_next()
		else:
			_place_camera()
	return false
