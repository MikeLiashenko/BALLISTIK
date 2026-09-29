class_name ModelAsm
extends RefCounted
## Сборка модели техники из деталей: иерархия узлов (корпус, башня, люлька орудий, антенны, пусковые),
## меши деталей (строятся один раз на тип и кэшируются; окраска другой команды подменяет только
## материал корпуса), итоговый словарь маркеров для механики. После сборки finish() задаёт каждой
## детали высоту над основанием модели (шейдер: пыль на нижних частях, ватерлиния) и считает габариты.

var type_id: String = ""
var team: int = 0
var paint: Dictionary = {}
var mat: ShaderMaterial = null
var root: Node3D = null
var out: Dictionary = {}


func _init(p_type: String, p_team: int, p_paint: Dictionary) -> void:
	type_id = p_type
	team = p_team
	paint = p_paint
	mat = VehicleModels.paint_material(type_id, team, paint)
	root = Node3D.new()
	root.name = "Model"
	out["root"] = root


## Узел иерархии (подвижная часть или маркер).
func node(parent: Node3D, node_name: String, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	n.rotation_degrees = rot_deg
	parent.add_child(n)
	return n


## Деталь-меш: build(k: VehicleKit) вызывается только при первой сборке типа.
func mesh(parent: Node3D, part_name: String, build: Callable) -> MeshInstance3D:
	var key := "vm|%s|%s" % [type_id, part_name]
	var m := MeshFactory.cached_mesh(key) as ArrayMesh
	if m == null:
		var k := VehicleKit.new()
		build.call(k)
		m = k.commit(VehicleModels.paint_material(type_id, 0, paint))
		MeshFactory.store_mesh(key, m)
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = m
	if team != 0 and m.has_meta("body_surface"):
		mi.set_surface_override_material(int(m.get_meta("body_surface")), mat)
	# Мелкие детали (установки, антенны) не рисуются дальше ~500 своих размеров — там они меньше пикселя;
	# у кораблей это основная часть вызовов отрисовки.
	var detail := m.get_aabb().get_longest_axis_size()
	if detail < 6.0:
		mi.visibility_range_end = maxf(detail * 500.0, 300.0)
		mi.visibility_range_end_margin = detail * 40.0
	parent.add_child(mi)
	return mi


## Светящийся элемент (огни, фонари) — отдельный узел без теней.
func glow(parent: Node3D, pos: Vector3, radius: float, color: Color, energy: float = 4.0) -> MeshInstance3D:
	var l := MeshFactory.mesh_instance(MeshFactory.sphere(radius, -1.0, 8, 4), MeshFactory.glow(color, energy), "Light")
	l.position = pos
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(l)
	return l


## Опознавательный знак — проекционная декаль на поверхность с нормалью normal (размер в метрах).
func decal(parent: Node3D, tex: Texture2D, pos: Vector3, normal: Vector3, size: float, depth: float = 0.6) -> void:
	if tex == null:
		return
	var y := normal.normalized()
	var x := Vector3.UP.cross(y)
	if x.length_squared() < 1e-4:
		x = Vector3(1.0, 0.0, 0.0)
	x = x.normalized()
	var z := x.cross(y).normalized()
	var d := Decal.new()
	d.name = "Insignia"
	d.texture_albedo = tex
	d.size = Vector3(size, depth, size)
	d.normal_fade = 0.35
	d.upper_fade = 0.05
	d.lower_fade = 0.05
	d.albedo_mix = 1.0
	d.distance_fade_enabled = true
	d.distance_fade_begin = 500.0
	d.distance_fade_length = 250.0
	d.transform = Transform3D(Basis(x, y, z), pos)
	parent.add_child(d)


func finish() -> Dictionary:
	_apply_heights(root, Transform3D.IDENTITY)
	out["aabb"] = model_aabb(root)
	if out.has("body_aabb"):
		return out
	# Габариты неподвижного корпуса (для формы столкновений): только меши прямо под корнем.
	var body := AABB()
	var first := true
	for c in root.get_children():
		if c is MeshInstance3D and c.name != "Light" and (c as MeshInstance3D).mesh != null:
			var mi := c as MeshInstance3D
			var box := mi.transform * mi.get_aabb()
			body = box if first else body.merge(box)
			first = false
	out["body_aabb"] = body if not first else out["aabb"]
	return out


func _apply_heights(n: Node, parent_xf: Transform3D) -> void:
	for c in n.get_children():
		if not (c is Node3D):
			continue
		var xf := parent_xf * (c as Node3D).transform
		if c is MeshInstance3D:
			(c as MeshInstance3D).set_instance_shader_parameter(&"base_height", xf.origin.y)
		_apply_heights(c, xf)


## Габариты модели в её собственных координатах (без декалей и огней).
static func model_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for child in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null and child.name != "Light":
			var mi := child as MeshInstance3D
			var box := mi.transform * mi.get_aabb()
			result = box if first else result.merge(box)
			first = false
		elif child is Node3D and not (child is Decal):
			var sub := model_aabb(child)
			if sub.size != Vector3.ZERO:
				sub = (child as Node3D).transform * sub
				result = sub if first else result.merge(sub)
				first = false
	return result
