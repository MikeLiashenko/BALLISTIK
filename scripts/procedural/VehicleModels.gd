class_name VehicleModels
extends RefCounted
## Процедурные модели техники из примитивов Godot. Все модели смотрят вдоль -Z (вперёд), +Y — вверх.
## Статичные части собираются ModelBuilder'ом в один меш (кэш по типу и команде), подвижные
## части (башни, стволы, РЛС, пусковые, ракеты на подвесках) — отдельные узлы.


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


# --- Ракеты и бомбы (общие меши, также используются снарядами в полёте) --------------------------------
static func missile_mesh(kind: String) -> Mesh:
	var key := "munition_" + kind
	var cached := MeshFactory.cached_mesh(key)
	if cached != null:
		return cached
	var b := ModelBuilder.new()
	var light := MeshFactory.mat(Color(0.82, 0.83, 0.8), 0.45, 0.3)
	var dark := dark_mat()
	match kind:
		"aam":
			b.add(MeshFactory.cylinder(0.09, 0.09, 2.6), MeshFactory.along_z(Vector3(0.0, 0.0, 0.15)), light)
			b.add(MeshFactory.cylinder(0.01, 0.09, 0.4), MeshFactory.along_forward(Vector3(0.0, 0.0, -1.35)), dark)
			b.add(MeshFactory.box(Vector3(0.55, 0.02, 0.3)), MeshFactory.xf(Vector3(0.0, 0.0, 1.3)), dark)
			b.add(MeshFactory.box(Vector3(0.02, 0.55, 0.3)), MeshFactory.xf(Vector3(0.0, 0.0, 1.3)), dark)
			b.add(MeshFactory.box(Vector3(0.36, 0.02, 0.16)), MeshFactory.xf(Vector3(0.0, 0.0, -0.9)), dark)
		"sam":
			b.add(MeshFactory.cylinder(0.2, 0.2, 5.0), MeshFactory.along_z(Vector3(0.0, 0.0, 0.25)), light)
			b.add(MeshFactory.cylinder(0.01, 0.2, 0.8), MeshFactory.along_forward(Vector3(0.0, 0.0, -2.65)), light)
			b.add(MeshFactory.box(Vector3(1.0, 0.03, 0.9)), MeshFactory.xf(Vector3(0.0, 0.0, 1.0)), dark)
			b.add(MeshFactory.box(Vector3(0.03, 1.0, 0.9)), MeshFactory.xf(Vector3(0.0, 0.0, 1.0)), dark)
			b.add(MeshFactory.box(Vector3(0.6, 0.03, 0.35)), MeshFactory.xf(Vector3(0.0, 0.0, 2.6)), dark)
			b.add(MeshFactory.box(Vector3(0.03, 0.6, 0.35)), MeshFactory.xf(Vector3(0.0, 0.0, 2.6)), dark)
		"bomb":
			var olive := MeshFactory.mat(Color(0.3, 0.33, 0.26), 0.7)
			b.add(MeshFactory.cylinder(0.27, 0.27, 1.6), MeshFactory.along_z(Vector3(0.0, 0.0, 0.0)), olive)
			b.add(MeshFactory.cylinder(0.02, 0.27, 0.6), MeshFactory.along_forward(Vector3(0.0, 0.0, -1.1)), olive)
			b.add(MeshFactory.cylinder(0.27, 0.1, 0.6), MeshFactory.along_z(Vector3(0.0, 0.0, 1.1)), olive)
			b.add(MeshFactory.box(Vector3(0.7, 0.03, 0.4)), MeshFactory.xf(Vector3(0.0, 0.0, 1.35)), dark)
			b.add(MeshFactory.box(Vector3(0.03, 0.7, 0.4)), MeshFactory.xf(Vector3(0.0, 0.0, 1.35)), dark)
		"cruise":
			b.add(MeshFactory.cylinder(0.24, 0.24, 4.6), MeshFactory.along_z(Vector3(0.0, 0.0, 0.2)), light)
			b.add(MeshFactory.cylinder(0.02, 0.24, 0.7), MeshFactory.along_forward(Vector3(0.0, 0.0, -2.45)), dark)
			b.add(MeshFactory.box(Vector3(2.2, 0.04, 0.5)), MeshFactory.xf(Vector3(0.0, 0.0, 0.2)), light)
			b.add(MeshFactory.box(Vector3(0.04, 0.8, 0.5)), MeshFactory.xf(Vector3(0.0, 0.4, 2.2)), dark)
		"torpedo":
			var steel := MeshFactory.mat(Color(0.25, 0.27, 0.28), 0.5, 0.5)
			b.add(MeshFactory.cylinder(0.27, 0.27, 5.5), MeshFactory.along_z(Vector3.ZERO), steel)
			b.add(MeshFactory.sphere(0.27, 0.8), MeshFactory.along_z(Vector3(0.0, 0.0, -2.75)), steel)
			b.add(MeshFactory.box(Vector3(0.8, 0.03, 0.3)), MeshFactory.xf(Vector3(0.0, 0.0, 2.8)), dark)
			b.add(MeshFactory.box(Vector3(0.03, 0.8, 0.3)), MeshFactory.xf(Vector3(0.0, 0.0, 2.8)), dark)
		"ballistic":
			var white := MeshFactory.mat(Color(0.88, 0.88, 0.86), 0.4, 0.2)
			b.add(MeshFactory.cylinder(0.42, 0.42, 5.6), MeshFactory.along_z(Vector3(0.0, 0.0, 0.4)), white)
			b.add(MeshFactory.cylinder(0.02, 0.42, 1.6), MeshFactory.along_forward(Vector3(0.0, 0.0, -3.2)), white)
			b.add(MeshFactory.cylinder(0.43, 0.43, 0.5), MeshFactory.along_z(Vector3(0.0, 0.0, -1.2)), dark)
			b.add(MeshFactory.box(Vector3(1.8, 0.05, 0.9)), MeshFactory.xf(Vector3(0.0, 0.0, 2.8)), dark)
			b.add(MeshFactory.box(Vector3(0.05, 1.8, 0.9)), MeshFactory.xf(Vector3(0.0, 0.0, 2.8)), dark)
		"shell":
			b.add(MeshFactory.cylinder(0.16, 0.16, 1.0), MeshFactory.along_z(Vector3.ZERO), dark)
			b.add(MeshFactory.cylinder(0.01, 0.16, 0.4), MeshFactory.along_forward(Vector3(0.0, 0.0, -0.7)), dark)
	var mesh := b.build()
	MeshFactory.store_mesh(key, mesh)
	return mesh


# --- Истребитель МиГ-29 --------------------------------------------------------------------------------
static func build_fighter(team: int) -> Dictionary:
	var root := _node("Model")
	var body := _cached_instance("fighter_%d" % team, func() -> ModelBuilder:
		var bm := body_mat("air", team)
		var dark := dark_mat()
		var accent := accent_mat(team)
		var b := ModelBuilder.new()
		b.add(MeshFactory.cylinder(0.8, 0.8, 9.6), MeshFactory.along_z(Vector3(0.0, 0.0, 0.6)), bm)
		b.add(MeshFactory.cylinder(0.05, 0.8, 4.4), MeshFactory.along_forward(Vector3(0.0, 0.0, -6.4)), bm)
		b.add(MeshFactory.sphere(0.56, 2.8), MeshFactory.along_z(Vector3(0.0, 0.72, -3.4)), glass_mat())
		b.add(MeshFactory.prism(Vector3(4.6, 5.6, 0.18)), MeshFactory.flat_wing(Vector3(0.0, 0.05, -1.4)), bm)
		b.add(MeshFactory.prism(Vector3(11.4, 6.2, 0.22)), MeshFactory.flat_wing(Vector3(0.0, -0.05, 1.8)), bm)
		b.add(MeshFactory.prism(Vector3(7.4, 3.2, 0.14)), MeshFactory.flat_wing(Vector3(0.0, -0.1, 6.3)), bm)
		b.add(MeshFactory.box(Vector3(0.12, 0.06, 7.0)), MeshFactory.xf(Vector3(0.0, 0.81, 1.8)), accent)
		for sx: float in GameDB.SIDES:
			b.add(MeshFactory.box(Vector3(1.0, 0.9, 3.6)), MeshFactory.xf(Vector3(0.95 * sx, -0.65, -0.4)), dark)
			b.add(MeshFactory.cylinder(0.58, 0.58, 6.6), MeshFactory.along_z(Vector3(0.92 * sx, -0.28, 3.4)), bm)
			b.add(MeshFactory.cylinder(0.5, 0.56, 1.0), MeshFactory.along_z(Vector3(0.92 * sx, -0.28, 7.2)), dark)
			b.add(MeshFactory.prism(Vector3(3.4, 3.4, 0.14), 0.15), MeshFactory.xf(Vector3(1.35 * sx, 1.6, 5.2), Vector3(9.0 * sx, 90.0, 0.0)), bm)
			b.add(MeshFactory.box(Vector3(0.16, 0.45, 1.5)), MeshFactory.xf(Vector3(1.55 * sx, 2.25, 5.7), Vector3(0.0, 0.0, -9.0 * sx)), accent)
			var nav := MeshFactory.glow(Color(1.0, 0.15, 0.1) if sx < 0.0 else Color(0.1, 1.0, 0.3), 5.0)
			b.add(MeshFactory.sphere(0.13), MeshFactory.xf(Vector3(5.65 * sx, -0.05, 4.8)), nav)
		b.add(MeshFactory.sphere(0.12), MeshFactory.xf(Vector3(0.0, 0.3, 7.9)), MeshFactory.glow(Color(1.0, 1.0, 1.0), 4.0))
		return b
	)
	root.add_child(body)
	var afterburners: Array[MeshInstance3D] = []
	for sx: float in GameDB.SIDES:
		var ab := MeshFactory.mesh_instance(MeshFactory.cylinder(0.04, 0.46, 2.6, 10), MeshFactory.shared_fade_material("afterburner", Color(1.0, 0.55, 0.2, 0.85), true), "Afterburner")
		ab.transform = MeshFactory.along_z(Vector3(0.92 * sx, -0.28, 9.0))
		ab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ab)
		afterburners.append(ab)
	var missiles: Array[Node3D] = []
	for x: float in [-3.6, -2.3, 2.3, 3.6]:
		var m := MeshFactory.mesh_instance(missile_mesh("aam"), null, "AAM")
		m.position = Vector3(x, -0.42, 2.6)
		root.add_child(m)
		missiles.append(m)
	var muzzle := _node("GunMuzzle", Vector3(-1.05, 0.3, -3.6))
	root.add_child(muzzle)
	return {"root": root, "afterburners": afterburners, "missiles": missiles, "muzzle": muzzle}


# --- Бомбардировщик Су-24М ------------------------------------------------------------------------------
static func build_bomber(team: int) -> Dictionary:
	var root := _node("Model")
	var body := _cached_instance("bomber_%d" % team, func() -> ModelBuilder:
		var bm := body_mat("air", team)
		var dark := dark_mat()
		var accent := accent_mat(team)
		var b := ModelBuilder.new()
		b.add(MeshFactory.box(Vector3(2.3, 1.7, 14.0)), MeshFactory.xf(Vector3(0.0, 0.0, 0.5)), bm)
		b.add(MeshFactory.cylinder(0.1, 1.05, 5.5), MeshFactory.along_forward(Vector3(0.0, 0.0, -9.25)), bm)
		b.add(MeshFactory.sphere(0.95, 3.4), MeshFactory.along_z(Vector3(0.0, 0.95, -5.0)), glass_mat())
		b.add(MeshFactory.prism(Vector3(6.2, 6.4, 0.3)), MeshFactory.flat_wing(Vector3(0.0, 0.2, 0.2)), bm)
		b.add(MeshFactory.prism(Vector3(5.6, 4.6, 0.25), 0.15), MeshFactory.xf(Vector3(0.0, 3.0, 7.4), Vector3(0.0, 90.0, 0.0)), bm)
		b.add(MeshFactory.prism(Vector3(8.8, 3.8, 0.18)), MeshFactory.flat_wing(Vector3(0.0, 0.35, 8.3)), bm)
		b.add(MeshFactory.box(Vector3(0.2, 0.6, 2.8)), MeshFactory.xf(Vector3(0.0, 3.4, 7.8)), accent)
		for sx: float in GameDB.SIDES:
			b.add(MeshFactory.box(Vector3(1.0, 1.5, 4.5)), MeshFactory.xf(Vector3(1.55 * sx, -0.1, -1.8)), dark)
			b.add(MeshFactory.box(Vector3(6.8, 0.22, 2.3)), MeshFactory.xf(Vector3(5.0 * sx, 0.15, 2.4), Vector3(0.0, -40.0 * sx, 0.0)), bm)
			b.add(MeshFactory.cylinder(0.62, 0.62, 5.0), MeshFactory.along_z(Vector3(0.72 * sx, -0.1, 6.2)), bm)
			b.add(MeshFactory.cylinder(0.52, 0.58, 0.8), MeshFactory.along_z(Vector3(0.72 * sx, -0.1, 9.1)), dark)
			var nav := MeshFactory.glow(Color(1.0, 0.15, 0.1) if sx < 0.0 else Color(0.1, 1.0, 0.3), 5.0)
			b.add(MeshFactory.sphere(0.16), MeshFactory.xf(Vector3(7.6 * sx, 0.15, 4.6)), nav)
			b.add(MeshFactory.box(Vector3(0.06, 0.18, 4.0)), MeshFactory.xf(Vector3(1.16 * sx, 0.45, 1.0)), accent)
		b.add(MeshFactory.sphere(0.14), MeshFactory.xf(Vector3(0.0, 5.2, 9.6)), MeshFactory.glow(Color(1.0, 1.0, 1.0), 4.0))
		return b
	)
	root.add_child(body)
	var afterburners: Array[MeshInstance3D] = []
	for sx: float in GameDB.SIDES:
		var ab := MeshFactory.mesh_instance(MeshFactory.cylinder(0.04, 0.52, 2.8, 10), MeshFactory.shared_fade_material("afterburner", Color(1.0, 0.55, 0.2, 0.85), true), "Afterburner")
		ab.transform = MeshFactory.along_z(Vector3(0.72 * sx, -0.1, 10.9))
		ab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ab)
		afterburners.append(ab)
	var bombs: Array[Node3D] = []
	for p: Vector3 in [Vector3(-0.6, -1.15, -0.8), Vector3(0.6, -1.15, -0.8), Vector3(-0.6, -1.15, 2.4), Vector3(0.6, -1.15, 2.4)]:
		var m := MeshFactory.mesh_instance(missile_mesh("bomb"), null, "Bomb")
		m.position = p
		root.add_child(m)
		bombs.append(m)
	var cruise: Array[Node3D] = []
	for sx: float in GameDB.SIDES:
		var c := MeshFactory.mesh_instance(missile_mesh("cruise"), null, "Cruise")
		c.position = Vector3(2.7 * sx, -0.6, 0.8)
		root.add_child(c)
		cruise.append(c)
	return {"root": root, "afterburners": afterburners, "bombs": bombs, "cruise": cruise, "bomb_bay": Vector3(0.0, -1.6, 0.8)}


# --- Гусеничное шасси (общая часть ЗСУ и Бук) --------------------------------------------------------------
static func _tracked_chassis(b: ModelBuilder, team: int, length: float) -> void:
	var bm := body_mat("ground", team)
	var dark := dark_mat()
	var wheel := MeshFactory.mat(Color(0.16, 0.17, 0.16), 0.8, 0.2)
	b.add(MeshFactory.box(Vector3(3.2, 1.2, length)), MeshFactory.xf(Vector3(0.0, 1.1, 0.0)), bm)
	b.add(MeshFactory.box(Vector3(3.2, 0.3, 1.8)), MeshFactory.xf(Vector3(0.0, 1.55, -length * 0.5 + 0.35), Vector3(28.0, 0.0, 0.0)), bm)
	var wheels := int(length / 1.15)
	for sx: float in GameDB.SIDES:
		b.add(MeshFactory.box(Vector3(0.62, 1.0, length + 0.3)), MeshFactory.xf(Vector3(1.5 * sx, 0.55, 0.0)), dark)
		b.add(MeshFactory.box(Vector3(0.1, 0.5, length - 0.4)), MeshFactory.xf(Vector3(1.84 * sx, 1.05, 0.0)), bm)
		for i in wheels:
			var z := -length * 0.5 + 0.7 + float(i) * (length - 1.4) / float(maxi(wheels - 1, 1))
			b.add(MeshFactory.cylinder(0.38, 0.38, 0.66, 12), MeshFactory.along_x(Vector3(1.5 * sx, 0.42, z)), wheel)
	b.add(MeshFactory.box(Vector3(2.4, 0.5, 0.9)), MeshFactory.xf(Vector3(0.0, 1.45, length * 0.5 - 0.6)), dark)


# --- ЗСУ «Гепард» ----------------------------------------------------------------------------------------
static func build_spaag(team: int) -> Dictionary:
	var root := _node("Model")
	root.add_child(_cached_instance("spaag_hull_%d" % team, func() -> ModelBuilder:
		var b := ModelBuilder.new()
		_tracked_chassis(b, team, 7.2)
		return b
	))
	var turret := _node("Turret", Vector3(0.0, 1.7, 0.4))
	root.add_child(turret)
	turret.add_child(_cached_instance("spaag_turret_%d" % team, func() -> ModelBuilder:
		var bm := body_mat("ground", team)
		var dark := dark_mat()
		var accent := accent_mat(team)
		var b := ModelBuilder.new()
		b.add(MeshFactory.box(Vector3(2.5, 1.15, 3.3)), MeshFactory.xf(Vector3(0.0, 0.58, 0.0)), bm)
		b.add(MeshFactory.box(Vector3(2.5, 0.25, 1.0)), MeshFactory.xf(Vector3(0.0, 1.05, -1.75), Vector3(24.0, 0.0, 0.0)), bm)
		b.add(MeshFactory.cylinder(0.35, 0.35, 0.3), MeshFactory.xf(Vector3(0.45, 1.3, 0.4)), dark)
		b.add(MeshFactory.cylinder(0.08, 0.08, 0.7), MeshFactory.xf(Vector3(0.0, 1.5, 1.3)), dark)
		for sx: float in GameDB.SIDES:
			b.add(MeshFactory.box(Vector3(0.06, 0.18, 2.6)), MeshFactory.xf(Vector3(1.28 * sx, 0.72, 0.0)), accent)
		return b
	, "TurretBody"))
	var radar := _node("SearchRadar", Vector3(0.0, 1.9, 1.3))
	turret.add_child(radar)
	var dish := MeshFactory.mesh_instance(MeshFactory.cylinder(0.95, 0.95, 0.1, 18), dark_mat(), "Dish")
	dish.transform = MeshFactory.xf(Vector3(0.0, 0.2, 0.0), Vector3(75.0, 0.0, 0.0))
	radar.add_child(dish)
	var dish_edge := MeshFactory.mesh_instance(MeshFactory.torus(0.9, 1.0, 24, 4), accent_mat(team), "DishEdge")
	dish_edge.transform = MeshFactory.xf(Vector3(0.0, 0.2, 0.0), Vector3(75.0, 0.0, 0.0))
	radar.add_child(dish_edge)
	var gun_pivot := _node("GunPivot", Vector3(0.0, 0.8, -0.3))
	turret.add_child(gun_pivot)
	gun_pivot.add_child(_cached_instance("spaag_guns_%d" % team, func() -> ModelBuilder:
		var bm := body_mat("ground", team)
		var dark := dark_mat()
		var b := ModelBuilder.new()
		for sx: float in GameDB.SIDES:
			b.add(MeshFactory.box(Vector3(0.52, 0.62, 2.4)), MeshFactory.xf(Vector3(1.56 * sx, 0.0, -0.3)), bm)
			b.add(MeshFactory.cylinder(0.075, 0.075, 3.4, 10), MeshFactory.along_forward(Vector3(1.56 * sx, 0.05, -3.2)), dark)
			b.add(MeshFactory.cylinder(0.12, 0.12, 0.35, 10), MeshFactory.along_forward(Vector3(1.56 * sx, 0.05, -4.95)), dark)
		b.add(MeshFactory.sphere(0.4), MeshFactory.xf(Vector3(0.0, 0.25, -1.6)), dark)
		return b
	, "Guns"))
	var muzzles: Array[Node3D] = []
	for sx: float in GameDB.SIDES:
		var m := _node("Muzzle", Vector3(1.56 * sx, 0.05, -5.2))
		gun_pivot.add_child(m)
		muzzles.append(m)
	return {"root": root, "turret": turret, "gun_pivot": gun_pivot, "muzzles": muzzles, "radar": radar}


# --- ЗРК: Бук-М1 (гусеничный) / Patriot (колёсный) ----------------------------------------------------------
static func build_sam(team: int) -> Dictionary:
	var root := _node("Model")
	var is_patriot := team == GameDB.TEAM_BLUE
	var turret: Node3D
	var launcher: Node3D
	var missiles: Array[Node3D] = []
	var launch_points: Array[Node3D] = []
	if is_patriot:
		root.add_child(_cached_instance("sam_truck_%d" % team, func() -> ModelBuilder:
			var bm := body_mat("ground", team)
			var dark := dark_mat()
			var wheel := MeshFactory.mat(Color(0.13, 0.13, 0.13), 0.85)
			var b := ModelBuilder.new()
			b.add(MeshFactory.box(Vector3(2.5, 0.6, 10.2)), MeshFactory.xf(Vector3(0.0, 1.15, 0.3)), bm)
			b.add(MeshFactory.box(Vector3(2.5, 2.1, 2.3)), MeshFactory.xf(Vector3(0.0, 2.25, -4.3)), bm)
			b.add(MeshFactory.box(Vector3(2.3, 0.7, 0.1)), MeshFactory.xf(Vector3(0.0, 2.7, -5.46)), glass_mat())
			b.add(MeshFactory.box(Vector3(2.6, 0.3, 1.2)), MeshFactory.xf(Vector3(0.0, 1.0, -5.2)), dark)
			for sx: float in GameDB.SIDES:
				for z: float in [-4.1, -2.6, 2.3, 3.8]:
					b.add(MeshFactory.cylinder(0.62, 0.62, 0.5, 14), MeshFactory.along_x(Vector3(1.3 * sx, 0.62, z)), wheel)
				b.add(MeshFactory.box(Vector3(0.06, 0.16, 3.0)), MeshFactory.xf(Vector3(1.27 * sx, 1.35, 1.5)), accent_mat(team))
			return b
		))
		turret = _node("Turret", Vector3(0.0, 1.5, 2.0))
		root.add_child(turret)
		turret.add_child(MeshFactory.mesh_instance(MeshFactory.box(Vector3(2.2, 0.4, 2.2)), body_mat("ground", team), "Base"))
		launcher = _node("Launcher", Vector3(0.0, 0.6, 0.9))
		launcher.rotation = Vector3(deg_to_rad(38.0), 0.0, 0.0)
		turret.add_child(launcher)
		launcher.add_child(_cached_instance("sam_canisters_%d" % team, func() -> ModelBuilder:
			var bm := body_mat("ground", team)
			var b := ModelBuilder.new()
			for cx: float in [-0.5, 0.5]:
				for cy: float in [0.0, 0.98]:
					b.add(MeshFactory.box(Vector3(0.95, 0.95, 5.4)), MeshFactory.xf(Vector3(cx, cy, -1.9)), bm)
			return b
		, "Canisters"))
		for cx: float in [-0.5, 0.5]:
			for cy: float in [0.0, 0.98]:
				var cap := MeshFactory.mesh_instance(MeshFactory.box(Vector3(0.75, 0.75, 0.06)), accent_mat(team), "Cap")
				cap.position = Vector3(cx, cy, -4.63)
				launcher.add_child(cap)
				missiles.append(cap)
				var lp := _node("LaunchPoint", Vector3(cx, cy, -4.9))
				launcher.add_child(lp)
				launch_points.append(lp)
	else:
		root.add_child(_cached_instance("sam_tracked_%d" % team, func() -> ModelBuilder:
			var b := ModelBuilder.new()
			_tracked_chassis(b, team, 8.8)
			return b
		))
		turret = _node("Turret", Vector3(0.0, 1.75, 0.4))
		root.add_child(turret)
		turret.add_child(_cached_instance("sam_turret_%d" % team, func() -> ModelBuilder:
			var bm := body_mat("ground", team)
			var dark := dark_mat()
			var b := ModelBuilder.new()
			b.add(MeshFactory.cylinder(1.45, 1.45, 0.5, 20), MeshFactory.xf(Vector3(0.0, 0.25, 0.0)), bm)
			b.add(MeshFactory.box(Vector3(2.3, 1.7, 0.35)), MeshFactory.xf(Vector3(0.0, 1.1, -1.55)), dark)
			b.add(MeshFactory.box(Vector3(2.0, 1.4, 0.1)), MeshFactory.xf(Vector3(0.0, 1.1, -1.76)), MeshFactory.glow(GameDB.team_color(team).darkened(0.35), 1.2))
			b.add(MeshFactory.box(Vector3(1.4, 0.8, 1.6)), MeshFactory.xf(Vector3(0.0, 0.8, 0.7)), bm)
			return b
		, "TurretBody"))
		launcher = _node("Launcher", Vector3(0.0, 1.0, 0.7))
		launcher.rotation = Vector3(deg_to_rad(40.0), 0.0, 0.0)
		turret.add_child(launcher)
		launcher.add_child(MeshFactory.mesh_instance(MeshFactory.box(Vector3(1.9, 0.25, 5.8)), dark_mat(), "Rail"))
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
	var dish := MeshFactory.mesh_instance(MeshFactory.box(Vector3(1.6, 0.8, 0.12)), dark_mat(), "RadarPanel")
	radar.add_child(dish)
	return {"root": root, "turret": turret, "launcher": launcher, "missiles": missiles, "launch_points": launch_points, "radar": radar}


# --- Бронекатер: Sea Baby (безэкипажный) / G-5 (торпедный катер) ---------------------------------------------
static func build_boat(team: int) -> Dictionary:
	var root := _node("Model")
	var hull := _node("Hull")
	root.add_child(hull)
	var sea_baby := team == GameDB.TEAM_BLUE
	var length := 9.0 if sea_baby else 12.0
	var height := 1.2 if sea_baby else 1.5
	hull.add_child(_cached_instance("boat_%d" % team, func() -> ModelBuilder:
		var bm := body_mat("naval", team) if not sea_baby else MeshFactory.mat(Color(0.3, 0.34, 0.38), 0.55, 0.3)
		var dark := dark_mat()
		var accent := accent_mat(team)
		var b := ModelBuilder.new()
		b.add(MeshFactory.box(Vector3(3.2, height, length)), MeshFactory.xf(Vector3(0.0, 0.25, 0.5)), bm)
		b.add(MeshFactory.prism(Vector3(3.2, 4.2, height)), MeshFactory.flat_wing(Vector3(0.0, 0.25, -length * 0.5 - 1.6)), bm)
		b.add(MeshFactory.box(Vector3(2.8, 0.18, length - 0.6)), MeshFactory.xf(Vector3(0.0, 0.25 + height * 0.5 + 0.05, 0.6)), dark)
		for sx: float in GameDB.SIDES:
			b.add(MeshFactory.box(Vector3(0.05, 0.14, length - 1.0)), MeshFactory.xf(Vector3(1.62 * sx, 0.55, 0.4)), accent)
			b.add(MeshFactory.cylinder(0.28, 0.28, 3.6, 12), MeshFactory.along_z(Vector3(1.9 * sx, 0.65, 1.0)), bm)
		if sea_baby:
			b.add(MeshFactory.cylinder(0.07, 0.07, 1.6, 8), MeshFactory.xf(Vector3(0.0, 1.8, -0.8)), dark)
			b.add(MeshFactory.sphere(0.24), MeshFactory.xf(Vector3(0.0, 2.65, -0.8)), glass_mat())
			b.add(MeshFactory.box(Vector3(1.4, 0.7, 1.4)), MeshFactory.xf(Vector3(0.0, 1.2, 4.2)), dark)
		else:
			b.add(MeshFactory.box(Vector3(1.9, 1.4, 2.6)), MeshFactory.xf(Vector3(0.0, 1.75, -1.2)), bm)
			b.add(MeshFactory.box(Vector3(1.95, 0.4, 0.1)), MeshFactory.xf(Vector3(0.0, 2.05, -2.52)), glass_mat())
			b.add(MeshFactory.cylinder(0.06, 0.06, 2.4, 8), MeshFactory.xf(Vector3(0.0, 3.4, -0.6)), dark)
			b.add(MeshFactory.box(Vector3(1.2, 0.08, 0.08)), MeshFactory.xf(Vector3(0.0, 4.2, -0.6)), dark)
		b.add(MeshFactory.box(Vector3(1.3, 0.9, 2.4)), MeshFactory.xf(Vector3(0.0, 1.35, length * 0.5 - 1.3), Vector3(25.0, 0.0, 0.0)), dark)
		b.add(MeshFactory.sphere(0.12), MeshFactory.xf(Vector3(0.0, 1.0, length * 0.5 + 0.9)), MeshFactory.glow(Color(1.0, 1.0, 1.0), 4.0))
		return b
	))
	var turret := _node("GunTurret", Vector3(0.0, 0.25 + height * 0.5 + 0.2, -length * 0.5 + 1.8))
	hull.add_child(turret)
	turret.add_child(MeshFactory.mesh_instance(MeshFactory.cylinder(0.42, 0.48, 0.35, 12), dark_mat(), "TurretBase"))
	var gun_pivot := _node("GunPivot", Vector3(0.0, 0.4, 0.0))
	turret.add_child(gun_pivot)
	gun_pivot.add_child(MeshFactory.mesh_instance(MeshFactory.box(Vector3(0.4, 0.35, 0.8)), dark_mat(), "GunBox"))
	var barrel := MeshFactory.mesh_instance(MeshFactory.cylinder(0.05, 0.05, 1.5, 8), dark_mat(), "Barrel")
	barrel.transform = MeshFactory.along_forward(Vector3(0.0, 0.05, -1.1))
	gun_pivot.add_child(barrel)
	var muzzle := _node("Muzzle", Vector3(0.0, 0.05, -1.95))
	gun_pivot.add_child(muzzle)
	var torpedo_points: Array[Node3D] = []
	for sx: float in GameDB.SIDES:
		var tp := _node("TorpedoTube", Vector3(1.9 * sx, 0.3, -1.2))
		hull.add_child(tp)
		torpedo_points.append(tp)
	var ballistic_point := _node("BallisticLauncher", Vector3(0.0, 2.3, length * 0.5 - 2.4))
	hull.add_child(ballistic_point)
	var wake_point := _node("WakePoint", Vector3(0.0, 0.15, length * 0.5 + 1.0))
	root.add_child(wake_point)
	return {"root": root, "hull": hull, "turret": turret, "gun_pivot": gun_pivot, "muzzle": muzzle, "torpedo_points": torpedo_points, "ballistic_point": ballistic_point, "wake_point": wake_point, "length": length}


# --- Эсминец (стратегическая цель команды) -----------------------------------------------------------------
static func build_destroyer(team: int) -> Dictionary:
	var root := _node("Model")
	root.add_child(_cached_instance("destroyer_%d" % team, func() -> ModelBuilder:
		var bm := body_mat("naval", team)
		var deck := MeshFactory.mat(Color(0.2, 0.22, 0.25), 0.8, 0.1)
		var dark := dark_mat()
		var accent := accent_mat(team)
		var b := ModelBuilder.new()
		b.add(MeshFactory.box(Vector3(12.0, 7.0, 84.0)), MeshFactory.xf(Vector3(0.0, 0.5, 4.0)), bm)
		b.add(MeshFactory.prism(Vector3(12.0, 22.0, 7.0)), MeshFactory.flat_wing(Vector3(0.0, 0.5, -49.0)), bm)
		b.add(MeshFactory.box(Vector3(11.2, 0.3, 82.0)), MeshFactory.xf(Vector3(0.0, 4.1, 4.0)), deck)
		b.add(MeshFactory.box(Vector3(9.0, 6.0, 22.0)), MeshFactory.xf(Vector3(0.0, 7.2, -4.0)), bm)
		b.add(MeshFactory.box(Vector3(8.0, 3.2, 7.0)), MeshFactory.xf(Vector3(0.0, 11.8, -11.0)), bm)
		b.add(MeshFactory.box(Vector3(8.1, 0.6, 0.2)), MeshFactory.xf(Vector3(0.0, 12.3, -14.55)), MeshFactory.glow(Color(0.5, 0.95, 1.0), 2.5))
		b.add(MeshFactory.cylinder(0.45, 0.45, 14.0, 10), MeshFactory.xf(Vector3(0.0, 19.5, -7.0)), dark)
		b.add(MeshFactory.box(Vector3(6.0, 0.2, 0.2)), MeshFactory.xf(Vector3(0.0, 23.0, -7.0)), dark)
		b.add(MeshFactory.box(Vector3(4.0, 5.0, 4.5)), MeshFactory.xf(Vector3(0.0, 9.5, 8.0)), dark)
		b.add(MeshFactory.box(Vector3(3.6, 4.2, 4.0)), MeshFactory.xf(Vector3(0.0, 9.0, 14.5)), dark)
		b.add(MeshFactory.box(Vector3(10.0, 5.0, 12.0)), MeshFactory.xf(Vector3(0.0, 6.6, 24.0)), bm)
		b.add(MeshFactory.cylinder(4.6, 4.6, 0.06, 28), MeshFactory.xf(Vector3(0.0, 4.3, 37.0)), accent)
		b.add(MeshFactory.cylinder(4.3, 4.3, 0.08, 28), MeshFactory.xf(Vector3(0.0, 4.32, 37.0)), deck)
		for sx: float in GameDB.SIDES:
			b.add(MeshFactory.box(Vector3(0.1, 0.5, 70.0)), MeshFactory.xf(Vector3(6.05 * sx, 2.6, 2.0)), accent)
			b.add(MeshFactory.box(Vector3(1.6, 1.6, 6.0)), MeshFactory.xf(Vector3(3.2 * sx, 5.2, 4.0)), dark)
		b.add(MeshFactory.sphere(0.3), MeshFactory.xf(Vector3(0.0, 26.6, -7.0)), MeshFactory.glow(Color(1.0, 0.2, 0.15), 5.0))
		return b
	))
	var radar := _node("Radar", Vector3(0.0, 24.0, -7.0))
	root.add_child(radar)
	radar.add_child(MeshFactory.mesh_instance(MeshFactory.box(Vector3(5.0, 1.2, 0.3)), dark_mat(), "RadarBar"))
	var main_turret := _node("MainTurret", Vector3(0.0, 4.3, -32.0))
	root.add_child(main_turret)
	var turret_body := MeshFactory.mesh_instance(MeshFactory.box(Vector3(4.2, 2.2, 5.0)), body_mat("naval", team), "TurretBody")
	turret_body.position = Vector3(0.0, 1.1, 0.0)
	main_turret.add_child(turret_body)
	var main_pivot := _node("GunPivot", Vector3(0.0, 1.3, -2.2))
	main_turret.add_child(main_pivot)
	var main_barrel := MeshFactory.mesh_instance(MeshFactory.cylinder(0.22, 0.22, 7.5, 10), dark_mat(), "Barrel")
	main_barrel.transform = MeshFactory.along_forward(Vector3(0.0, 0.0, -3.75))
	main_pivot.add_child(main_barrel)
	var main_muzzle := _node("Muzzle", Vector3(0.0, 0.0, -7.7))
	main_pivot.add_child(main_muzzle)
	var ciws_list: Array[Dictionary] = []
	for p: Vector3 in [Vector3(0.0, 9.1, 27.0), Vector3(0.0, 13.4, -9.0)]:
		var ciws := _node("CIWS", p)
		root.add_child(ciws)
		var dome := MeshFactory.mesh_instance(MeshFactory.sphere(1.1, 2.6), MeshFactory.mat(Color(0.85, 0.86, 0.88), 0.5), "Dome")
		dome.position = Vector3(0.0, 1.3, 0.0)
		ciws.add_child(dome)
		var pivot := _node("GunPivot", Vector3(0.0, 0.9, -0.5))
		ciws.add_child(pivot)
		var gun := MeshFactory.mesh_instance(MeshFactory.cylinder(0.25, 0.25, 2.2, 10), dark_mat(), "Gatling")
		gun.transform = MeshFactory.along_forward(Vector3(0.0, 0.0, -1.2))
		pivot.add_child(gun)
		var muzzle := _node("Muzzle", Vector3(0.0, 0.0, -2.5))
		pivot.add_child(muzzle)
		ciws_list.append({"base": ciws, "pivot": pivot, "muzzle": muzzle})
	return {"root": root, "radar": radar, "main_turret": main_turret, "main_pivot": main_pivot, "main_muzzle": main_muzzle, "ciws": ciws_list}
