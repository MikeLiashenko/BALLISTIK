extends SceneTree
## Рендер моделей техники для визуальной проверки (запуск с окном — на скрытом рабочем столе):
## godot --path . --script res://tests/hangar_shots.gd -- --out=DIR [--types=a,b] [--team=0] [--sheet]
## По умолчанию — все самолёты. --sheet — четыре ракурса одной машины на одном листе (TYPE.png).

const VIEWS := [Vector3(-0.8, 0.34, -0.95), Vector3(0.95, 0.5, 0.6), Vector3(-1.0, 0.06, 0.02), Vector3(0.55, 1.1, -0.7)]

var out_dir := "user://hangar"
var types: Array[String] = []
var team := 0
var sheet := false
var index := -1
var frames := 0
var cam: Camera3D
var holder: Node3D
var ground: MeshInstance3D
var view := 0
var focus := Vector3.ZERO
var extent := 10.0
var images: Array[Image] = []
## Множитель дистанции камеры (--dist=0.5 — вдвое ближе) и смещение точки обзора по длине (--focus=-20).
var dist_k := 1.0
var focus_z := 0.0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--types="):
			for t in arg.get_slice("=", 1).split(","):
				types.append(t)
		elif arg.begins_with("--team="):
			team = int(arg.get_slice("=", 1))
		elif arg == "--sheet":
			sheet = true
		elif arg.begins_with("--dist="):
			dist_k = float(arg.get_slice("=", 1))
		elif arg.begins_with("--focus="):
			focus_z = float(arg.get_slice("=", 1))
	if types.is_empty():
		for t: String in GameDB.VEHICLE_ORDER:
			if GameDB.is_aircraft(t):
				types.append(t)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var world := Node3D.new()
	root.add_child(world)
	Atmosphere.create(world, MapPresets.get_map("coast"), 2)
	ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	ground.mesh = pm
	ground.material_override = MeshFactory.mat(Color(0.3, 0.34, 0.26), 0.95)
	world.add_child(ground)
	holder = Node3D.new()
	world.add_child(holder)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 4000.0
	world.add_child(cam)
	cam.make_current()
	_next()


func _next() -> void:
	for c in holder.get_children():
		c.queue_free()
	index += 1
	view = 0
	frames = 0
	images.clear()
	if index >= types.size():
		quit()
		return
	var t := types[index]
	var model: Node3D
	if GameDB.is_aircraft(t):
		var parts := AircraftBuilder.build(t, team)
		model = parts["root"]
		for d in parts["prop_discs"] + parts["afterburners"]:
			(d as Node3D).visible = false
	else:
		var parts := VehicleModels.build(t, team)
		if parts.is_empty():
			push_error("Нет модели: " + t)
			_next()
			return
		model = parts["root"]
	holder.add_child(model)
	var box := ModelAsm.model_aabb(model)
	focus = box.get_center() + Vector3(0.0, 0.0, focus_z)
	extent = maxf(box.size.x, maxf(box.size.y, box.size.z))
	ground.position = Vector3(0.0, (box.position.y if not GameDB.is_aircraft(t) else -6.0) - 0.02, 0.0)
	_place_camera()


func _place_camera() -> void:
	var views_n := VIEWS.size() if sheet else 3
	var d: Vector3 = VIEWS[view % views_n].normalized()
	var dist := extent * (1.2 if sheet else 1.55) * dist_k
	cam.look_at_from_position(focus + d * dist, focus, Vector3.UP)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 8:
		var img := root.get_viewport().get_texture().get_image()
		if sheet:
			images.append(img)
		else:
			img.save_png(out_dir.path_join("%s_%d.png" % [types[index], view]))
		view += 1
		frames = 0
		if view >= (VIEWS.size() if sheet else 3):
			if sheet:
				_save_sheet()
			_next()
		else:
			_place_camera()
	return false


func _save_sheet() -> void:
	var w := images[0].get_width() / 2
	var h := images[0].get_height() / 2
	var out := Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	for i in images.size():
		var img := images[i]
		img.convert(Image.FORMAT_RGBA8)
		img.resize(w, h, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
	out.save_png(out_dir.path_join("%s.png" % types[index]))
