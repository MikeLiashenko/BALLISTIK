class_name VehicleModels
extends RefCounted
## Процедурные модели техники ПВО, кораблей и боеприпасов. Все модели смотрят вдоль -Z (вперёд), +Y — вверх.
## Наземную ПВО строит GroundModels, катера и корабли — NavalModels (детали из VehicleKit, сборка —
## ModelAsm), самолёты — AircraftBuilder. Здесь — единая точка входа build(), материалы окраски техники
## (шейдер «vehicle») и меши боеприпасов.

static var _paint_cache: Dictionary = {}


## Модель наземной или морской техники: {"root": Node3D, ...узлы и маркеры для механики, "aabb"}.
static func build(type_id: String, team: int) -> Dictionary:
	if GroundModels.has_model(type_id):
		return GroundModels.build(type_id, team)
	if NavalModels.has_model(type_id):
		return NavalModels.build(type_id, team)
	return _legacy(type_id, team)


## Упрощённые модели прежней версии — запасной вариант для типа без собственной модели.
static func _legacy(type_id: String, team: int) -> Dictionary:
	var out := {}
	match GameDB.role_of(type_id):
		"spaag", "flak":
			var p := build_spaag(team)
			out = {"root": p["root"], "turret": p["turret"], "gun_pivot": p["gun_pivot"], "muzzles": p["muzzles"], "radars": [{"node": p["radar"], "speed": 3.5}]}
		"sam":
			var p := build_sam(team)
			out = {"root": p["root"], "turret": p["turret"], "launcher": p["launcher"], "missiles": p["missiles"], "launch_points": p["launch_points"], "radars": [{"node": p["radar"], "speed": 2.5}]}
		"boat":
			var p := build_boat(team)
			out = {"root": p["root"], "hull": p["hull"], "mounts": [{"yaw": p["turret"], "pitch": p["gun_pivot"], "muzzles": [p["muzzle"]]}], "torpedo_tubes": p["torpedo_points"], "special_points": [p["ballistic_point"]], "wake_points": [p["wake_point"]]}
		_:
			var p := build_destroyer(team)
			var aa: Array = []
			for c: Dictionary in p["ciws"]:
				aa.append({"yaw": c["base"], "pitch": c["pivot"], "muzzles": [c["muzzle"]]})
			out = {"root": p["root"], "hull": p["root"], "main": [{"yaw": p["main_turret"], "pitch": p["main_pivot"], "muzzles": [p["main_muzzle"]]}], "aa": aa, "radars": [{"node": p["radar"], "speed": 1.5}]}
	var root: Node3D = out["root"]
	out["aabb"] = ModelAsm.model_aabb(root)
	out["body_aabb"] = out["aabb"]
	return out


static func has_model(type_id: String) -> bool:
	return GroundModels.has_model(type_id) or NavalModels.has_model(type_id)


## Материал окраски по описанию paint (цвета камуфляжа, рисунок, износ, режим корабля/машины).
static func paint_material(type_id: String, team: int, paint: Dictionary) -> ShaderMaterial:
	var key := "%s|%d" % [type_id, team]
	if _paint_cache.has(key):
		return _paint_cache[key]
	var m := ShaderLib.material("vehicle")
	m.set_shader_parameter("camo_a", paint.get("a", Color(0.3, 0.34, 0.24)))
	m.set_shader_parameter("camo_b", paint.get("b", Color(0.36, 0.3, 0.2)))
	m.set_shader_parameter("camo_c", paint.get("c", Color(0.0, 0.0, 0.0)))
	m.set_shader_parameter("id_color", GameDB.team_color(team).lerp(Color(0.8, 0.8, 0.8), 0.15))
	m.set_shader_parameter("pattern", int(paint.get("pattern", 1)))
	m.set_shader_parameter("pattern_scale", float(paint.get("scale", 1.0)))
	m.set_shader_parameter("roughness_base", float(paint.get("rough", 0.72)))
	m.set_shader_parameter("metallic_base", float(paint.get("metal", 0.05)))
	m.set_shader_parameter("wear", float(paint.get("wear", 0.5)))
	m.set_shader_parameter("panel_scale", float(paint.get("panel", 1.0)))
	m.set_shader_parameter("panel_strength", float(paint.get("panel_strength", 0.25)))
	m.set_shader_parameter("rivets", float(paint.get("rivets", 0.0)))
	m.set_shader_parameter("mode", 1 if str(paint.get("mode", "ground")) == "naval" else 0)
	m.set_shader_parameter("dust_color", paint.get("dust_color", Color(0.47, 0.42, 0.33)))
	m.set_shader_parameter("dust_height", float(paint.get("dust_height", 1.1)))
	m.set_shader_parameter("dust_amount", float(paint.get("dust", 0.5)))
	m.set_shader_parameter("waterline", float(paint.get("waterline", 0.0)))
	m.set_shader_parameter("antifoul", paint.get("antifoul", Color(0.42, 0.13, 0.1)))
	m.set_shader_parameter("boot_top", paint.get("boot", Color(0.07, 0.07, 0.08)))
	m.set_shader_parameter("deck_color", paint.get("deck", Color(0.3, 0.31, 0.33)))
	m.set_shader_parameter("rust", float(paint.get("rust", 0.25)))
	m.set_shader_parameter("measure_line", float(paint.get("measure", -1000.0)))
	_paint_cache[key] = m
	return m


# --- Общие материалы ---------------------------------------------------------------------------------
static func body_mat(kind: String, team: int) -> StandardMaterial3D:
	var c: Color
	match kind:
		"air":
			c = Color(0.42, 0.48, 0.55) if team == 0 else Color(0.5, 0.49, 0.43)
		"ground":
			c = Color(0.3, 0.36, 0.28) if team == 0 else Color(0.46, 0.41, 0.29)
		"naval":
			c = Color(0.37, 0.42, 0.49) if team == 0 else Color(0.42, 0.42, 0.44)
		_:
			c = Color(0.45, 0.45, 0.45)
	return MeshFactory.mat(c, 0.62, 0.25)


static func dark_mat() -> StandardMaterial3D:
	return MeshFactory.mat(Color(0.1, 0.11, 0.12), 0.55, 0.4)


static func glass_mat() -> StandardMaterial3D:
	return MeshFactory.mat(Color(0.05, 0.17, 0.26), 0.08, 0.8, 0.35)


static func accent_mat(team: int) -> StandardMaterial3D:
	return MeshFactory.glow(GameDB.team_color(team), 2.2)


static func _node(node_name: String, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	return n


static func _cached_instance(key: String, builder_func: Callable, node_name: String = "Body") -> MeshInstance3D:
	var mesh := MeshFactory.cached_mesh(key)
	if mesh == null:
		var b: ModelBuilder = builder_func.call()
		mesh = b.build()
		MeshFactory.store_mesh(key, mesh)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	return mi


# --- Ракеты, торпеды и бомбы (общие меши, также используются снарядами в полёте) ----------------------------
## Расстояние от центра меша боеприпаса до сопла (для факела и дымового следа).
static func missile_tail(kind: String) -> float:
	match kind:
		"sam":
			return 2.8
		"sam_big":
			return 3.7
		"cruise":
			return 2.4
	return 1.5


static func missile_mesh(kind: String) -> Mesh:
	var key := "munition2_" + kind
	var cached := MeshFactory.cached_mesh(key)
	if cached != null:
		return cached
	var k := VehicleKit.new()
	var body_color := Color(0.84, 0.85, 0.82)
	match kind:
		"aam":
			VehicleKit.missile(k.body, k.dark, Vector3(0.0, 0.0, 1.45), 2.9, 0.085, 4, 0.36, 0.12, true)
		"sam":
			VehicleKit.missile(k.body, k.dark, Vector3(0.0, 0.0, 2.75), 5.5, 0.2, 4, 0.95, 0.16)
		"sam_small":
			body_color = Color(0.32, 0.36, 0.27)
			VehicleKit.missile(k.body, k.dark, Vector3(0.0, 0.0, 1.45), 2.9, 0.1, 4, 0.42, 0.14, true)
		"sam_big":
			VehicleKit.missile(k.body, k.dark, Vector3(0.0, 0.0, 3.6), 7.2, 0.26, 4, 1.1, 0.15)
		"cruise":
			VehicleKit.missile(k.body, k.dark, Vector3(0.0, 0.0, 2.3), 4.6, 0.21, 4, 0.55, 0.12)
			k.body.add_prism(PackedVector2Array([Vector2(0.45, -0.018), Vector2(-0.25, -0.018), Vector2(-0.18, 0.018), Vector2(0.42, 0.018)]), 1.05)
		"torpedo":
			body_color = Color(0.24, 0.26, 0.27)
			k.body.xform = VehicleKit.forward_xform(Vector3(0.0, 0.0, 2.75))
			k.body.add_lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, 0.08), Vector2(0.3, 0.2), Vector2(0.65, 0.27), Vector2(5.0, 0.27), Vector2(5.28, 0.22), Vector2(5.44, 0.12), Vector2(5.5, 0.0)]), 16)
			k.body.xform = Transform3D.IDENTITY
			for i in 4:
				var a := float(i) * PI * 0.5
				VehicleKit.box(k.dark, Vector3(cos(a) * 0.2, sin(a) * 0.2, 2.55), Vector3(0.02 + absf(cos(a)) * 0.3, 0.02 + absf(sin(a)) * 0.3, 0.3))
			VehicleKit.cyl(k.dark, Vector3(0.0, 0.0, 2.72), Vector3(0.0, 0.0, 2.84), 0.16, 8)
		"ballistic":
			body_color = Color(0.88, 0.88, 0.86)
			VehicleKit.missile(k.body, k.dark, Vector3(0.0, 0.0, 3.2), 6.4, 0.42, 4, 1.4, 0.26)
			VehicleKit.cyl(k.dark, Vector3(0.0, 0.0, -0.7), Vector3(0.0, 0.0, -1.2), 0.43, 16)
		"rocket":
			body_color = Color(0.5, 0.52, 0.48)
			VehicleKit.missile(k.body, k.dark, Vector3(0.0, 0.0, 0.8), 1.6, 0.065, 4, 0.22, 0.14)
		"bomb":
			body_color = Color(0.3, 0.33, 0.26)
			k.body.xform = VehicleKit.forward_xform(Vector3(0.0, 0.0, 1.25))
			k.body.add_lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, 0.1), Vector2(0.55, 0.27), Vector2(1.45, 0.27), Vector2(2.05, 0.19), Vector2(2.35, 0.06), Vector2(2.4, 0.0)]), 16)
			k.body.xform = Transform3D.IDENTITY
			for i in 4:
				var a := float(i) * PI * 0.5 + PI * 0.25
				VehicleKit.box(k.dark, Vector3(cos(a) * 0.2, sin(a) * 0.2, 1.1), Vector3(0.02 + absf(cos(a)) * 0.22, 0.02 + absf(sin(a)) * 0.22, 0.42))
		"shell":
			body_color = Color(0.22, 0.22, 0.2)
			k.body.xform = VehicleKit.forward_xform(Vector3(0.0, 0.0, 0.55))
			k.body.add_lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, 0.14), Vector2(0.7, 0.16), Vector2(0.95, 0.1), Vector2(1.15, 0.0)]), 12)
			k.body.xform = Transform3D.IDENTITY
	var mesh := k.commit(MeshFactory.mat(body_color, 0.45, 0.25))
	MeshFactory.store_mesh(key, mesh)
	return mesh


# --- Камуфляж наземной техники и кораблей -----------------------------------------------------------------
static var _camo_cache: Dictionary = {}


## Окраска корпуса тем же шейдером, что и у самолётов: пятнистый камуфляж, панели, износ.
static func camo_material(kind: String, team: int) -> ShaderMaterial:
	var key := "%s|%d" % [kind, team]
	if _camo_cache.has(key):
		return _camo_cache[key]
	var m := ShaderLib.material("aircraft")
	m.set_shader_parameter("id_color", GameDB.team_color(team))
	m.set_shader_parameter("use_under", 0.0)
	match kind:
		"ground":
			if team == 0:
				m.set_shader_parameter("camo_a", Color(0.27, 0.31, 0.2))
				m.set_shader_parameter("camo_b", Color(0.33, 0.27, 0.18))
				m.set_shader_parameter("camo_c", Color(0.11, 0.11, 0.1))
			else:
				m.set_shader_parameter("camo_a", Color(0.46, 0.4, 0.27))
				m.set_shader_parameter("camo_b", Color(0.3, 0.33, 0.21))
				m.set_shader_parameter("camo_c", Color(0.2, 0.17, 0.12))
			m.set_shader_parameter("pattern", 1)
			m.set_shader_parameter("pattern_scale", 0.9)
			m.set_shader_parameter("roughness_base", 0.78)
			m.set_shader_parameter("wear", 0.65)
			m.set_shader_parameter("panel_scale", 1.6)
		"boat":
			m.set_shader_parameter("camo_a", Color(0.36, 0.4, 0.44) if team == 0 else Color(0.42, 0.43, 0.42))
			m.set_shader_parameter("camo_b", Color(0.27, 0.3, 0.33) if team == 0 else Color(0.33, 0.34, 0.33))
			m.set_shader_parameter("pattern", 1)
			m.set_shader_parameter("pattern_scale", 1.4)
			m.set_shader_parameter("roughness_base", 0.6)
			m.set_shader_parameter("wear", 0.5)
		_:
			m.set_shader_parameter("camo_a", Color(0.5, 0.54, 0.58) if team == 0 else Color(0.5, 0.51, 0.52))
			m.set_shader_parameter("camo_b", Color(0.47, 0.5, 0.54) if team == 0 else Color(0.47, 0.48, 0.49))
			m.set_shader_parameter("pattern", 4)
			m.set_shader_parameter("pattern_scale", 1.0)
			m.set_shader_parameter("roughness_base", 0.62)
			m.set_shader_parameter("wear", 0.45)
			m.set_shader_parameter("panel_scale", 3.0)
	_camo_cache[key] = m
	return m


## Меш из набора комплектов (корпус, тёмные детали, металл, стекло), кэшируется по ключу.
static func _kits_instance(key: String, builder: Callable, node_name: String, body_material: Material) -> MeshInstance3D:
	var mesh := MeshFactory.cached_mesh(key)
	if mesh == null:
		var kits: Array = builder.call()
		var am: ArrayMesh = (kits[0] as MeshKit).commit(null, body_material)
		(kits[1] as MeshKit).commit(am, dark_mat())
		(kits[2] as MeshKit).commit(am, MeshFactory.mat(Color(0.34, 0.33, 0.31), 0.45, 0.75))
		if kits.size() > 3:
			(kits[3] as MeshKit).commit(am, glass_mat())
		mesh = am
		MeshFactory.store_mesh(key, mesh)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	return mi


## Цилиндр вдоль оси X (колёса, катки) — в заданном комплекте.
static func _wheel(kit: MeshKit, center: Vector3, radius: float, width: float, segs: int = 14) -> void:
	kit.xform = Transform3D(Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5), center)
	kit.add_cylinder(Vector3.ZERO, -width * 0.5, width * 0.5, radius, radius, segs, Color.WHITE, Color.WHITE)
	kit.xform = Transform3D.IDENTITY
	for side: float in [-1.0, 1.0]:
		var c := center + Vector3(side * width * 0.5, 0.0, 0.0)
		var ci := kit.add_vertex(c, Vector3(side, 0.0, 0.0))
		var ring := PackedInt32Array()
		for i in segs:
			var a := float(i) / float(segs) * TAU
			ring.append(kit.add_vertex(c + Vector3(0.0, cos(a) * radius, sin(a) * radius), Vector3(side, 0.0, 0.0)))
		for i in segs:
			if side > 0.0:
				kit.tri(ci, ring[(i + 1) % segs], ring[i])
			else:
				kit.tri(ci, ring[i], ring[(i + 1) % segs])


## Ствол вдоль -Z от точки start длиной length (с дульным тормозом).
static func _barrel(kit: MeshKit, start: Vector3, length: float, radius: float, brake: bool = true) -> void:
	kit.xform = Transform3D(Basis(Vector3(1.0, 0.0, 0.0), -PI * 0.5), start)
	kit.add_cylinder(Vector3.ZERO, 0.0, length, radius, radius * 0.85, 10, Color.WHITE, Color.WHITE)
	if brake:
		kit.add_cylinder(Vector3.ZERO, length - radius * 3.0, length, radius * 1.6, radius * 1.6, 10, Color.WHITE, Color.WHITE)
	kit.xform = Transform3D.IDENTITY


# --- Гусеничное шасси -------------------------------------------------------------------------------------
## Корпус с наклонным лобовым листом, гусеницы, катки, ленивец и ведущее колесо, бортовые экраны.
static func _tracked_hull(body: MeshKit, dark: MeshKit, metal: MeshKit, length: float, width: float) -> void:
	var cg := length * 0.5
	var hw := width * 0.5 - 0.42
	body.add_loft([[0.0, hw * 0.92, 0.16, 0.22, 1.02], [0.9, hw, 0.52, 0.34, 1.08], [length - 0.7, hw, 0.54, 0.36, 1.1], [length, hw * 0.94, 0.36, 0.32, 1.1]], 7.0, 24, cg, 0.0, Vector3.ZERO, true, true)
	var tx := width * 0.5 - 0.33
	for side: float in [-1.0, 1.0]:
		dark.add_loft([[0.05, 0.3, 0.3, 0.3, 0.58], [0.45, 0.31, 0.46, 0.46, 0.52], [length - 0.45, 0.31, 0.46, 0.46, 0.52], [length - 0.05, 0.3, 0.3, 0.3, 0.58]], 2.4, 14, cg, 0.0, Vector3(side * tx, 0.0, 0.0), true, true)
		var wheels := int(length / 1.1)
		for i in wheels:
			var z := -cg + 0.85 + float(i) * (length - 1.7) / float(maxi(wheels - 1, 1))
			_wheel(metal, Vector3(side * (tx + 0.02), 0.42, z), 0.33, 0.66)
		_wheel(metal, Vector3(side * (tx + 0.02), 0.72, -cg + 0.4), 0.26, 0.6)
		_wheel(metal, Vector3(side * (tx + 0.02), 0.72, cg - 0.4), 0.28, 0.6)
		body.add_box(Vector3(side * (tx + 0.3), 1.02, 0.1), Vector3(0.06, 0.42, length - 0.9))
		for k in 3:
			metal.add_box(Vector3(side * (tx - 0.1), 1.2, -cg + 1.3 + float(k) * 2.2), Vector3(0.5, 0.08, 0.5))
	dark.add_box(Vector3(0.0, 1.45, cg - 0.35), Vector3(width * 0.5, 0.12, 0.5))
	for side: float in [-1.0, 1.0]:
		metal.add_box(Vector3(side * (hw - 0.25), 1.28, -cg + 0.25), Vector3(0.22, 0.14, 0.12))


# --- ЗСУ «Гепард» ----------------------------------------------------------------------------------------
static func build_spaag(team: int) -> Dictionary:
	var root := _node("Model")
	var mat := camo_material("ground", team)
	root.add_child(_kits_instance("spaag3_hull_%d" % team, func() -> Array:
		var body := MeshKit.new()
		var dark := MeshKit.new()
		var metal := MeshKit.new()
		_tracked_hull(body, dark, metal, 7.3, 3.3)
		return [body, dark, metal]
	, "Hull", mat))
	var turret := _node("Turret", Vector3(0.0, 1.62, 0.35))
	root.add_child(turret)
	turret.add_child(_kits_instance("spaag3_turret_%d" % team, func() -> Array:
		var body := MeshKit.new()
		var dark := MeshKit.new()
		var metal := MeshKit.new()
		body.add_loft([[0.0, 0.95, 0.3, 0.05, 0.4], [0.5, 1.12, 0.56, 0.05, 0.48], [2.7, 1.18, 0.62, 0.05, 0.52], [3.3, 1.05, 0.46, 0.05, 0.5]], 5.5, 22, 1.7, 0.0, Vector3.ZERO, true, true)
		dark.add_cylinder(Vector3(0.45, 1.1, 0.5), 0.0, 0.14, 0.34, 0.34, 12, Color.WHITE, Color.WHITE)
		dark.add_cylinder(Vector3(-0.35, 1.1, 0.9), 0.0, 0.1, 0.26, 0.26, 12, Color.WHITE, Color.WHITE)
		for side: float in [-1.0, 1.0]:
			for k in 4:
				_barrel(dark, Vector3(side * (0.9 - float(k) * 0.12), 0.95, -1.35), 0.28, 0.06, false)
		dark.add_cylinder(Vector3(0.7, 1.12, 1.2), 0.0, 1.4, 0.02, 0.012, 5, Color.WHITE, Color.WHITE)
		dark.add_blob(Vector3(0.0, 0.85, -1.55), Vector3(0.42, 0.36, 0.2), 1, 0.0, 1, Color(0.2, 0.2, 0.2), Color(0.3, 0.3, 0.3))
		return [body, dark, metal]
	, "TurretBody", mat))
	for side: float in [-1.0, 1.0]:
		var stripe := MeshFactory.mesh_instance(MeshFactory.box(Vector3(0.04, 0.16, 2.2)), accent_mat(team), "TeamStripe")
		stripe.position = Vector3(side * 1.19, 0.72, 0.1)
		turret.add_child(stripe)
	var radar := _node("SearchRadar", Vector3(0.0, 1.95, 1.3))
	turret.add_child(radar)
	var dish := MeshFactory.mesh_instance(MeshFactory.sphere(0.95, 0.22, 20, 6), MeshFactory.mat(Color(0.2, 0.22, 0.2), 0.6, 0.3), "Dish")
	dish.transform = MeshFactory.xf(Vector3(0.0, 0.25, 0.0), Vector3(78.0, 0.0, 0.0))
	radar.add_child(dish)
	radar.add_child(MeshFactory.mesh_instance(MeshFactory.cylinder(0.06, 0.08, 0.5, 8), dark_mat(), "Mast"))
	var gun_pivot := _node("GunPivot", Vector3(0.0, 0.8, -0.3))
	turret.add_child(gun_pivot)
	gun_pivot.add_child(_kits_instance("spaag3_guns_%d" % team, func() -> Array:
		var body := MeshKit.new()
		var dark := MeshKit.new()
		var metal := MeshKit.new()
		for side: float in [-1.0, 1.0]:
			body.add_loft([[0.0, 0.22, 0.28, 0.28, 0.0], [0.4, 0.27, 0.32, 0.32, 0.0], [2.4, 0.27, 0.32, 0.32, 0.0], [2.7, 0.22, 0.26, 0.26, 0.0]], 4.0, 12, 1.6, 0.0, Vector3(side * 1.56, 0.0, 0.0), true, true)
			_barrel(dark, Vector3(side * 1.56, 0.05, -1.6), 3.55, 0.075, true)
			metal.add_box(Vector3(side * 1.56, -0.36, -0.3), Vector3(0.36, 0.1, 1.4))
		return [body, dark, metal]
	, "Guns", mat))
	var muzzles: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		var m := _node("Muzzle", Vector3(side * 1.56, 0.05, -5.2))
		gun_pivot.add_child(m)
		muzzles.append(m)
	return {"root": root, "turret": turret, "gun_pivot": gun_pivot, "muzzles": muzzles, "radar": radar}


# --- ЗРК: Бук-М1 (гусеничный) / Patriot (колёсный) ----------------------------------------------------------
static func build_sam(team: int) -> Dictionary:
	var root := _node("Model")
	var is_patriot := team == GameDB.TEAM_BLUE
	var mat := camo_material("ground", team)
	var turret: Node3D
	var launcher: Node3D
	var missiles: Array[Node3D] = []
	var launch_points: Array[Node3D] = []
	if is_patriot:
		root.add_child(_kits_instance("sam3_truck_%d" % team, func() -> Array:
			var body := MeshKit.new()
			var dark := MeshKit.new()
			var metal := MeshKit.new()
			var glass := MeshKit.new()
			body.add_loft([[0.0, 1.2, 0.95, 0.35, 2.0], [0.5, 1.25, 1.05, 0.4, 2.0], [2.2, 1.25, 1.05, 0.4, 2.0], [2.35, 1.2, 0.95, 0.4, 2.0]], 6.0, 20, 5.6, 0.0, Vector3.ZERO, true, true)
			glass.add_box(Vector3(0.0, 2.45, -5.52), Vector3(2.15, 0.62, 0.05))
			dark.add_box(Vector3(0.0, 1.15, 0.3), Vector3(1.9, 0.45, 10.4))
			body.add_box(Vector3(0.0, 1.45, 0.9), Vector3(2.5, 0.16, 8.6))
			for side: float in [-1.0, 1.0]:
				for z: float in [-4.3, -2.9, 1.9, 3.3, 4.7]:
					_wheel(dark, Vector3(side * 1.15, 0.62, z), 0.6, 0.48, 16)
					_wheel(metal, Vector3(side * 1.4, 0.62, z), 0.3, 0.04, 10)
				body.add_box(Vector3(side * 1.2, 1.25, -3.6), Vector3(0.1, 0.5, 1.9))
				body.add_box(Vector3(side * 1.2, 1.25, 3.3), Vector3(0.1, 0.5, 3.8))
			metal.add_box(Vector3(0.0, 1.05, -5.75), Vector3(2.3, 0.28, 0.2))
			return [body, dark, metal, glass]
		, "Truck", mat))
		turret = _node("Turret", Vector3(0.0, 1.55, 2.2))
		root.add_child(turret)
		turret.add_child(_kits_instance("sam3_turret_p_%d" % team, func() -> Array:
			var body := MeshKit.new()
			body.add_box(Vector3(0.0, 0.15, 0.0), Vector3(2.3, 0.3, 2.3))
			return [body, MeshKit.new(), MeshKit.new()]
		, "Base", mat))
		launcher = _node("Launcher", Vector3(0.0, 0.62, 1.0))
		launcher.rotation = Vector3(deg_to_rad(38.0), 0.0, 0.0)
		turret.add_child(launcher)
		launcher.add_child(_kits_instance("sam3_canisters_%d" % team, func() -> Array:
			var body := MeshKit.new()
			var dark := MeshKit.new()
			for cx: float in [-0.5, 0.5]:
				for cy: float in [0.0, 0.98]:
					body.add_loft([[0.0, 0.46, 0.46, 0.46, cy], [5.4, 0.46, 0.46, 0.46, cy]], 8.0, 12, 4.6, 0.0, Vector3(cx, 0.0, 0.0), true, true)
			dark.add_box(Vector3(0.0, 0.5, 0.9), Vector3(2.1, 2.0, 0.2))
			return [body, dark, MeshKit.new()]
		, "Canisters", mat))
		for cx: float in [-0.5, 0.5]:
			for cy: float in [0.0, 0.98]:
				var cap := MeshFactory.mesh_instance(MeshFactory.box(Vector3(0.78, 0.78, 0.05)), accent_mat(team), "Cap")
				cap.position = Vector3(cx, cy, -4.64)
				launcher.add_child(cap)
				missiles.append(cap)
				var lp := _node("LaunchPoint", Vector3(cx, cy, -4.9))
				launcher.add_child(lp)
				launch_points.append(lp)
	else:
		root.add_child(_kits_instance("sam3_tracked_%d" % team, func() -> Array:
			var body := MeshKit.new()
			var dark := MeshKit.new()
			var metal := MeshKit.new()
			_tracked_hull(body, dark, metal, 8.8, 3.3)
			return [body, dark, metal]
		, "Hull", mat))
		turret = _node("Turret", Vector3(0.0, 1.66, 0.4))
		root.add_child(turret)
		turret.add_child(_kits_instance("sam3_turret_b_%d" % team, func() -> Array:
			var body := MeshKit.new()
			var dark := MeshKit.new()
			var metal := MeshKit.new()
			body.add_cylinder(Vector3(0.0, 0.0, 0.0), 0.0, 0.5, 1.45, 1.5, 24, Color.WHITE, Color.WHITE)
			body.add_loft([[0.0, 0.7, 0.4, 0.05, 0.85], [0.3, 0.75, 0.45, 0.05, 0.85], [1.6, 0.75, 0.45, 0.05, 0.85], [1.9, 0.7, 0.4, 0.05, 0.85]], 6.0, 16, 0.25, 0.0, Vector3.ZERO, true, true)
			dark.add_box(Vector3(0.0, 1.1, -1.55), Vector3(2.3, 1.7, 0.3))
			return [body, dark, metal]
		, "TurretBody", mat))
		var panel := MeshFactory.mesh_instance(MeshFactory.box(Vector3(2.0, 1.4, 0.08)), MeshFactory.glow(GameDB.team_color(team).darkened(0.4), 1.1), "RadarFace")
		panel.position = Vector3(0.0, 1.1, -1.73)
		turret.add_child(panel)
		launcher = _node("Launcher", Vector3(0.0, 1.0, 0.7))
		launcher.rotation = Vector3(deg_to_rad(40.0), 0.0, 0.0)
		turret.add_child(launcher)
		launcher.add_child(MeshFactory.mesh_instance(MeshFactory.box(Vector3(1.9, 0.22, 5.8)), dark_mat(), "Rail"))
		for x: float in [-0.68, -0.23, 0.23, 0.68]:
			var m := MeshFactory.mesh_instance(missile_mesh("sam"), null, "Missile")
			m.position = Vector3(x, 0.38, -1.4)
			launcher.add_child(m)
			missiles.append(m)
			var lp := _node("LaunchPoint", Vector3(x, 0.38, -4.4))
			launcher.add_child(lp)
			launch_points.append(lp)
	var radar := _node("Radar", Vector3(0.0, 2.3, 0.5))
	turret.add_child(radar)
	var dish := MeshFactory.mesh_instance(MeshFactory.box(Vector3(1.6, 0.8, 0.12)), MeshFactory.mat(Color(0.22, 0.24, 0.22), 0.6, 0.3), "RadarPanel")
	radar.add_child(dish)
	radar.add_child(MeshFactory.mesh_instance(MeshFactory.cylinder(0.05, 0.07, 0.5, 8), dark_mat(), "Mast"))
	return {"root": root, "turret": turret, "launcher": launcher, "missiles": missiles, "launch_points": launch_points, "radar": radar}


# --- Бронекатер: Sea Baby (безэкипажный) / G-5 (торпедный катер) ---------------------------------------------
static func build_boat(team: int) -> Dictionary:
	var root := _node("Model")
	var hull := _node("Hull")
	root.add_child(hull)
	var sea_baby := team == GameDB.TEAM_BLUE
	var length := 9.0 if sea_baby else 12.0
	var mat := camo_material("boat", team)
	hull.add_child(_kits_instance("boat3_%d" % team, func() -> Array:
		var body := MeshKit.new()
		var dark := MeshKit.new()
		var metal := MeshKit.new()
		var glass := MeshKit.new()
		var L := length
		# Глиссирующий корпус: острый форштевень, V-образное днище, плоский транец.
		body.add_loft([[0.0, 0.04, 0.55, 0.05, 0.75], [L * 0.12, 0.85, 0.5, 0.62, 0.55], [L * 0.32, 1.45, 0.48, 0.72, 0.45], [L * 0.8, 1.6, 0.46, 0.7, 0.42], [L, 1.52, 0.46, 0.62, 0.44]], 2.3, 24, L * 0.5 + 0.5, 0.0, Vector3.ZERO, false, true)
		dark.add_box(Vector3(0.0, 0.92, 0.9), Vector3(2.7, 0.06, L * 0.62))
		for side: float in [-1.0, 1.0]:
			metal.add_loft([[L * 0.2, 0.03, 0.03, 0.03, 1.12], [L * 0.95, 0.03, 0.03, 0.03, 1.12]], 2.0, 6, L * 0.5 + 0.5, 0.0, Vector3(side * 1.45, 0.0, 0.0), true, true)
			body.add_loft([[L * 0.45, 0.26, 0.26, 0.26, 0.95], [L * 0.52, 0.28, 0.28, 0.28, 0.95], [L * 0.86, 0.28, 0.28, 0.28, 0.95], [L * 0.9, 0.22, 0.22, 0.22, 0.95]], 2.0, 12, L * 0.5 + 0.5, 0.0, Vector3(side * 1.92, 0.0, 0.0), true, true)
		if sea_baby:
			body.add_loft([[L * 0.34, 0.5, 0.22, 0.05, 1.0], [L * 0.44, 0.62, 0.3, 0.05, 1.0], [L * 0.62, 0.6, 0.3, 0.05, 1.0], [L * 0.7, 0.45, 0.18, 0.05, 1.0]], 5.0, 16, L * 0.5 + 0.5, 0.0, Vector3.ZERO, true, true)
			metal.add_cylinder(Vector3(0.0, 1.25, -0.9), 0.0, 1.6, 0.06, 0.05, 8, Color.WHITE, Color.WHITE)
			glass.add_blob(Vector3(0.0, 2.95, -0.9), Vector3(0.26, 0.26, 0.26), 1, 0.0, 1, Color.WHITE, Color.WHITE)
			dark.add_box(Vector3(0.0, 1.25, 3.4), Vector3(1.4, 0.5, 1.3))
		else:
			body.add_loft([[L * 0.3, 0.8, 0.9, 0.05, 1.0], [L * 0.36, 0.95, 1.2, 0.05, 1.0], [L * 0.52, 0.95, 1.2, 0.05, 1.0], [L * 0.56, 0.8, 0.9, 0.05, 1.0]], 4.5, 16, L * 0.5 + 0.5, 0.0, Vector3.ZERO, true, true)
			glass.add_box(Vector3(0.0, 1.95, -2.2), Vector3(1.75, 0.42, 0.06))
			metal.add_cylinder(Vector3(0.0, 2.1, -0.9), 0.0, 2.6, 0.06, 0.04, 8, Color.WHITE, Color.WHITE)
			metal.add_box(Vector3(0.0, 4.2, -0.9), Vector3(1.2, 0.06, 0.06))
			for side: float in [-1.0, 1.0]:
				dark.add_loft([[L * 0.62, 0.27, 0.27, 0.27, 1.25], [L * 0.99, 0.27, 0.27, 0.27, 1.25]], 2.0, 10, L * 0.5 + 0.5, 0.0, Vector3(side * 0.95, 0.0, 0.0), true, true)
		dark.add_box(Vector3(0.0, 1.35, length * 0.5 - 1.3), Vector3(1.3, 0.8, 2.2))
		return [body, dark, metal, glass]
	, "HullBody", mat))
	for side: float in [-1.0, 1.0]:
		var stripe := MeshFactory.mesh_instance(MeshFactory.box(Vector3(0.05, 0.12, length * 0.7)), accent_mat(team), "TeamStripe")
		stripe.position = Vector3(side * 1.63, 0.62, 0.6)
		hull.add_child(stripe)
	var nav := MeshFactory.mesh_instance(MeshFactory.sphere(0.12), MeshFactory.glow(Color(1.0, 1.0, 1.0), 4.0), "Light")
	nav.position = Vector3(0.0, 1.4, length * 0.5 + 0.2)
	hull.add_child(nav)
	var turret := _node("GunTurret", Vector3(0.0, 1.05, -length * 0.5 + 2.2))
	hull.add_child(turret)
	turret.add_child(MeshFactory.mesh_instance(MeshFactory.cylinder(0.42, 0.5, 0.35, 16), dark_mat(), "TurretBase"))
	var gun_pivot := _node("GunPivot", Vector3(0.0, 0.4, 0.0))
	turret.add_child(gun_pivot)
	gun_pivot.add_child(MeshFactory.mesh_instance(MeshFactory.box(Vector3(0.42, 0.36, 0.85)), dark_mat(), "GunBox"))
	var barrel := MeshFactory.mesh_instance(MeshFactory.cylinder(0.045, 0.05, 1.5, 8), dark_mat(), "Barrel")
	barrel.transform = MeshFactory.along_forward(Vector3(0.0, 0.05, -1.1))
	gun_pivot.add_child(barrel)
	var muzzle := _node("Muzzle", Vector3(0.0, 0.05, -1.95))
	gun_pivot.add_child(muzzle)
	var torpedo_points: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		var tp := _node("TorpedoTube", Vector3(1.9 * side, 0.6, -1.2))
		hull.add_child(tp)
		torpedo_points.append(tp)
	var ballistic_point := _node("BallisticLauncher", Vector3(0.0, 2.2, length * 0.5 - 2.4))
	hull.add_child(ballistic_point)
	var wake_point := _node("WakePoint", Vector3(0.0, 0.15, length * 0.5 + 1.0))
	root.add_child(wake_point)
	return {"root": root, "hull": hull, "turret": turret, "gun_pivot": gun_pivot, "muzzle": muzzle, "torpedo_points": torpedo_points, "ballistic_point": ballistic_point, "wake_point": wake_point, "length": length}


# --- Эсминец (стратегическая цель команды) -----------------------------------------------------------------
static func build_destroyer(team: int) -> Dictionary:
	var root := _node("Model")
	var mat := camo_material("naval", team)
	root.add_child(_kits_instance("destroyer3_%d" % team, func() -> Array:
		var body := MeshKit.new()
		body.ring_step = 1.0
		var dark := MeshKit.new()
		var metal := MeshKit.new()
		var glass := MeshKit.new()
		var cg := 48.0
		# Корпус с развалом бортов и приподнятым баком; ниже ватерлинии скрыт водой.
		body.add_loft([[0.0, 0.25, 6.0, 1.0, 0.0], [4.0, 2.4, 5.6, 3.6, 0.0], [12.0, 4.6, 5.0, 4.4, 0.0], [26.0, 5.9, 4.45, 4.6, 0.0], [34.0, 6.1, 4.2, 4.6, 0.0], [70.0, 6.1, 4.2, 4.4, 0.0], [86.0, 5.7, 4.2, 3.8, 0.0], [92.0, 5.2, 4.2, 2.8, 0.0]], 2.7, 32, cg, 0.0, Vector3.ZERO, false, true)
		dark.add_box(Vector3(0.0, 4.23, 8.0), Vector3(11.0, 0.06, 50.0))
		# Надстройка: мостик, основной блок, ангар.
		body.add_loft([[34.0, 3.4, 4.2, 0.1, 5.4], [36.0, 4.2, 5.4, 0.1, 5.4], [52.0, 4.4, 5.2, 0.1, 5.4], [54.0, 4.0, 3.6, 0.1, 5.4]], 7.0, 20, cg, 0.0, Vector3.ZERO, true, true)
		body.add_loft([[36.5, 2.6, 1.5, 0.1, 10.9], [37.5, 3.6, 2.0, 0.1, 10.9], [43.0, 3.6, 2.0, 0.1, 10.9], [44.0, 3.2, 1.6, 0.1, 10.9]], 6.0, 16, cg, 0.0, Vector3.ZERO, true, true)
		glass.add_box(Vector3(0.0, 11.9, -11.2), Vector3(6.2, 0.9, 0.08))
		body.add_loft([[62.0, 4.0, 3.0, 0.1, 5.4], [63.0, 4.6, 3.4, 0.1, 5.4], [72.0, 4.6, 3.4, 0.1, 5.4], [73.0, 4.2, 3.0, 0.1, 5.4]], 7.0, 16, cg, 0.0, Vector3.ZERO, true, true)
		# Дымовые трубы.
		for s: float in [49.0, 58.5]:
			body.add_loft([[s, 1.4, 3.6, 0.1, 9.0], [s + 1.0, 1.6, 4.0, 0.1, 9.0], [s + 3.6, 1.6, 4.0, 0.1, 9.0], [s + 4.4, 1.3, 3.4, 0.1, 9.0]], 3.0, 14, cg, 0.0, Vector3.ZERO, true, true)
			dark.add_box(Vector3(0.0, 13.05, s + 2.2 - cg), Vector3(2.4, 0.1, 3.0))
		# Мачта с реями.
		metal.add_cylinder(Vector3(0.0, 12.5, -7.0), 0.0, 13.0, 0.5, 0.25, 10, Color.WHITE, Color.WHITE)
		metal.add_box(Vector3(0.0, 20.5, -7.0), Vector3(7.0, 0.2, 0.2))
		metal.add_box(Vector3(0.0, 17.0, -7.0), Vector3(4.6, 0.2, 0.2))
		metal.add_cylinder(Vector3(0.0, 13.0, 12.0), 0.0, 8.0, 0.3, 0.15, 8, Color.WHITE, Color.WHITE)
		# Пусковые установки вертикального пуска (крышки ячеек) на баке.
		for i in 4:
			for j in 3:
				metal.add_box(Vector3(-1.9 + float(j) * 1.9, 4.62, -24.0 + float(i) * 1.6), Vector3(1.6, 0.14, 1.3))
		# Шлюпки и леерные стойки (упрощённо).
		for side: float in [-1.0, 1.0]:
			body.add_loft([[55.0, 0.02, 0.4, 0.3, 7.6], [55.8, 0.6, 0.45, 0.4, 7.6], [60.0, 0.6, 0.45, 0.4, 7.6], [60.6, 0.4, 0.4, 0.3, 7.6]], 2.4, 10, cg, 0.0, Vector3(side * 4.9, 0.0, 0.0), true, true)
		dark.add_box(Vector3(0.0, 4.4, 38.0), Vector3(9.4, 0.08, 10.0))
		return [body, dark, metal, glass]
	, "Hull", mat))
	var pad := MeshFactory.mesh_instance(MeshFactory.torus(4.0, 4.3, 32, 4), accent_mat(team), "HelipadRing")
	pad.position = Vector3(0.0, 4.46, 38.0)
	root.add_child(pad)
	for side: float in [-1.0, 1.0]:
		var stripe := MeshFactory.mesh_instance(MeshFactory.box(Vector3(0.08, 0.5, 60.0)), accent_mat(team), "TeamStripe")
		stripe.position = Vector3(side * 6.12, 2.6, 4.0)
		root.add_child(stripe)
	var lamp := MeshFactory.mesh_instance(MeshFactory.sphere(0.3), MeshFactory.glow(Color(1.0, 0.2, 0.15), 5.0), "MastLight")
	lamp.position = Vector3(0.0, 25.6, -7.0)
	root.add_child(lamp)
	var radar := _node("Radar", Vector3(0.0, 22.2, -7.0))
	root.add_child(radar)
	radar.add_child(MeshFactory.mesh_instance(MeshFactory.box(Vector3(5.2, 1.1, 0.3)), MeshFactory.mat(Color(0.32, 0.34, 0.36), 0.6, 0.4), "RadarBar"))
	var main_turret := _node("MainTurret", Vector3(0.0, 4.75, -32.0))
	root.add_child(main_turret)
	var turret_body := MeshInstance3D.new()
	turret_body.name = "TurretBody"
	var tk := MeshKit.new()
	tk.add_loft([[0.0, 1.4, 1.1, 0.05, 0.5], [0.9, 1.9, 1.9, 0.05, 0.5], [4.2, 2.1, 2.0, 0.05, 0.5], [5.0, 1.9, 1.7, 0.05, 0.5]], 3.2, 20, 2.3, 0.0, Vector3.ZERO, true, true)
	turret_body.mesh = tk.commit(null, mat)
	main_turret.add_child(turret_body)
	var main_pivot := _node("GunPivot", Vector3(0.0, 1.3, -2.2))
	main_turret.add_child(main_pivot)
	var main_barrel := MeshFactory.mesh_instance(MeshFactory.cylinder(0.18, 0.24, 7.5, 12), dark_mat(), "Barrel")
	main_barrel.transform = MeshFactory.along_forward(Vector3(0.0, 0.0, -3.75))
	main_pivot.add_child(main_barrel)
	var main_muzzle := _node("Muzzle", Vector3(0.0, 0.0, -7.7))
	main_pivot.add_child(main_muzzle)
	var ciws_list: Array[Dictionary] = []
	for p: Vector3 in [Vector3(0.0, 8.85, 23.0), Vector3(0.0, 13.2, -9.5)]:
		var ciws := _node("CIWS", p)
		root.add_child(ciws)
		ciws.add_child(MeshFactory.mesh_instance(MeshFactory.cylinder(0.9, 1.1, 0.8, 16), MeshFactory.mat(Color(0.8, 0.82, 0.84), 0.5), "Base"))
		var dome := MeshFactory.mesh_instance(MeshFactory.sphere(1.05, 2.8), MeshFactory.mat(Color(0.9, 0.91, 0.92), 0.4), "Dome")
		dome.position = Vector3(0.0, 1.7, 0.2)
		ciws.add_child(dome)
		var pivot := _node("GunPivot", Vector3(0.0, 0.9, -0.5))
		ciws.add_child(pivot)
		var gun := MeshFactory.mesh_instance(MeshFactory.cylinder(0.22, 0.26, 2.2, 10), dark_mat(), "Gatling")
		gun.transform = MeshFactory.along_forward(Vector3(0.0, 0.0, -1.2))
		pivot.add_child(gun)
		var muzzle := _node("Muzzle", Vector3(0.0, 0.0, -2.5))
		pivot.add_child(muzzle)
		ciws_list.append({"base": ciws, "pivot": pivot, "muzzle": muzzle})
	return {"root": root, "radar": radar, "main_turret": main_turret, "main_pivot": main_pivot, "main_muzzle": main_muzzle, "ciws": ciws_list}
