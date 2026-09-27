class_name StructureModels
extends RefCounted
## Процедурные модели сооружений (ангары, КДП, РЛС, топливные баки, штаб, бункеры, маяки, склады,
## дома, нефтяная платформа), а также статичные элементы баз: ВПП и причал.
## Каноническая ориентация: «фасад» смотрит на -Z, основание на y = 0.

const KINDS := {
	"hangar": {"name": "Ангар", "hp": 900.0, "score": 30, "size": Vector3(24.0, 12.0, 30.0)},
	"tower": {"name": "Командно-диспетчерский пункт", "hp": 520.0, "score": 25, "size": Vector3(9.0, 21.0, 9.0)},
	"radar": {"name": "РЛС дальнего обнаружения", "hp": 480.0, "score": 40, "size": Vector3(10.0, 22.0, 8.0)},
	"fuel": {"name": "Топливный резервуар", "hp": 260.0, "score": 20, "size": Vector3(11.0, 11.0, 11.0)},
	"hq": {"name": "Штаб", "hp": 1700.0, "score": 100, "size": Vector3(26.0, 15.0, 20.0)},
	"bunker": {"name": "Береговой бункер", "hp": 820.0, "score": 25, "size": Vector3(10.0, 4.6, 8.0)},
	"lighthouse": {"name": "Маяк", "hp": 420.0, "score": 15, "size": Vector3(5.4, 27.0, 5.4)},
	"warehouse": {"name": "Склад ВМБ", "hp": 640.0, "score": 15, "size": Vector3(20.0, 10.0, 14.0)},
	"house": {"name": "Жилой дом", "hp": 260.0, "score": 0, "size": Vector3(8.0, 7.6, 7.0)},
	"oil_rig": {"name": "Нефтяная платформа", "hp": 1300.0, "score": 0, "size": Vector3(30.0, 34.0, 30.0)},
}


static func info(kind: String) -> Dictionary:
	return KINDS.get(kind, KINDS["house"])


static func _concrete() -> StandardMaterial3D:
	return MeshFactory.mat(Color(0.5, 0.5, 0.47), 0.9)


static func _metal() -> StandardMaterial3D:
	return MeshFactory.mat(Color(0.55, 0.57, 0.58), 0.45, 0.5)


static func _team_glow(team: int, energy: float = 2.0) -> StandardMaterial3D:
	return MeshFactory.glow(GameDB.team_color(team), energy)


## Возвращает {root, spin (узел, вращающийся постоянно или null), light_pos (позиция огня/лампы или null)}.
static func build(kind: String, team: int, variant: int = 0) -> Dictionary:
	var root := Node3D.new()
	root.name = "Model"
	var spin: Node3D = null
	var key := "structure_%s_%d_%d" % [kind, team, variant % 4]
	var mesh := MeshFactory.cached_mesh(key)
	if mesh == null:
		var b := ModelBuilder.new()
		_build_static(b, kind, team, variant)
		mesh = b.build()
		MeshFactory.store_mesh(key, mesh)
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = mesh
	root.add_child(mi)
	match kind:
		"radar":
			spin = Node3D.new()
			spin.name = "Antenna"
			spin.position = Vector3(0.0, 19.6, 0.0)
			root.add_child(spin)
			var dish := MeshFactory.mesh_instance(MeshFactory.box(Vector3(9.0, 3.0, 0.5)), MeshFactory.mat(Color(0.75, 0.77, 0.78), 0.5, 0.4), "Dish")
			dish.rotation = Vector3(deg_to_rad(-12.0), 0.0, 0.0)
			spin.add_child(dish)
			var edge := MeshFactory.mesh_instance(MeshFactory.box(Vector3(9.1, 0.18, 0.55)), _team_glow(team, 2.5), "Edge")
			edge.position = Vector3(0.0, 1.55, 0.0)
			spin.add_child(edge)
		"lighthouse":
			spin = Node3D.new()
			spin.name = "Beam"
			spin.position = Vector3(0.0, 23.2, 0.0)
			root.add_child(spin)
			var beam := MeshFactory.mesh_instance(MeshFactory.cylinder(0.3, 2.8, 26.0, 10), MeshFactory.shared_fade_material("lighthouse_beam", Color(1.0, 0.95, 0.7, 0.18), true), "Beam")
			beam.transform = MeshFactory.along_forward(Vector3(0.0, 0.0, -13.0))
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			spin.add_child(beam)
	return {"root": root, "spin": spin}


static func _build_static(b: ModelBuilder, kind: String, team: int, variant: int) -> void:
	var dark := MeshFactory.mat(Color(0.12, 0.12, 0.13), 0.7, 0.2)
	match kind:
		"hangar":
			var roof := MeshFactory.mat(Color(0.36, 0.4, 0.36) if team == 0 else Color(0.44, 0.41, 0.34), 0.75, 0.3)
			b.add(MeshFactory.cylinder(12.0, 12.0, 30.0, 24), MeshFactory.along_z(Vector3(0.0, 0.0, 0.0)), roof)
			b.add(MeshFactory.box(Vector3(18.0, 9.0, 0.4)), MeshFactory.xf(Vector3(0.0, 4.5, -15.1)), dark)
			b.add(MeshFactory.box(Vector3(19.0, 0.35, 0.35)), MeshFactory.xf(Vector3(0.0, 9.3, -15.25)), _team_glow(team))
			b.add(MeshFactory.box(Vector3(0.35, 9.0, 0.35)), MeshFactory.xf(Vector3(-9.3, 4.5, -15.25)), _team_glow(team))
			b.add(MeshFactory.box(Vector3(0.35, 9.0, 0.35)), MeshFactory.xf(Vector3(9.3, 4.5, -15.25)), _team_glow(team))
		"tower":
			b.add(MeshFactory.box(Vector3(6.0, 14.0, 6.0)), MeshFactory.xf(Vector3(0.0, 7.0, 0.0)), _concrete())
			b.add(MeshFactory.box(Vector3(8.5, 4.0, 8.5)), MeshFactory.xf(Vector3(0.0, 16.0, 0.0)), dark)
			b.add(MeshFactory.box(Vector3(8.7, 1.1, 8.7)), MeshFactory.xf(Vector3(0.0, 16.4, 0.0)), MeshFactory.glow(Color(0.45, 0.9, 1.0), 1.8))
			b.add(MeshFactory.box(Vector3(9.2, 0.5, 9.2)), MeshFactory.xf(Vector3(0.0, 18.25, 0.0)), _concrete())
			b.add(MeshFactory.cylinder(0.12, 0.12, 5.0, 6), MeshFactory.xf(Vector3(2.5, 21.0, 2.5)), dark)
			b.add(MeshFactory.sphere(0.35), MeshFactory.xf(Vector3(2.5, 23.6, 2.5)), MeshFactory.glow(Color(1.0, 0.15, 0.1), 5.0))
		"radar":
			b.add(MeshFactory.box(Vector3(10.0, 5.0, 8.0)), MeshFactory.xf(Vector3(0.0, 2.5, 0.0)), _concrete())
			b.add(MeshFactory.box(Vector3(1.4, 14.0, 1.4)), MeshFactory.xf(Vector3(0.0, 12.0, 0.0)), dark)
			for sx: float in GameDB.SIDES:
				b.add(MeshFactory.box(Vector3(0.3, 14.5, 0.3)), MeshFactory.xf(Vector3(1.6 * sx, 11.8, 1.6), Vector3(0.0, 0.0, 6.0 * sx)), dark)
				b.add(MeshFactory.box(Vector3(0.3, 14.5, 0.3)), MeshFactory.xf(Vector3(1.6 * sx, 11.8, -1.6), Vector3(0.0, 0.0, 6.0 * sx)), dark)
			b.add(MeshFactory.box(Vector3(10.1, 0.4, 8.1)), MeshFactory.xf(Vector3(0.0, 4.2, 0.0)), _team_glow(team, 1.5))
		"fuel":
			var tank := MeshFactory.mat(Color(0.78, 0.78, 0.74), 0.5, 0.4)
			b.add(MeshFactory.cylinder(5.5, 5.5, 9.0, 24), MeshFactory.xf(Vector3(0.0, 4.5, 0.0)), tank)
			b.add(MeshFactory.sphere(5.5, 3.2, 24, 8), MeshFactory.xf(Vector3(0.0, 9.0, 0.0)), tank)
			b.add(MeshFactory.cylinder(5.6, 5.6, 0.5, 24), MeshFactory.xf(Vector3(0.0, 7.2, 0.0)), MeshFactory.glow(Color(1.0, 0.55, 0.1), 1.8))
			b.add(MeshFactory.box(Vector3(0.5, 9.5, 0.3)), MeshFactory.xf(Vector3(0.0, 4.75, -5.6)), dark)
		"hq":
			b.add(MeshFactory.box(Vector3(26.0, 10.0, 18.0)), MeshFactory.xf(Vector3(0.0, 5.0, 0.0)), _concrete())
			b.add(MeshFactory.box(Vector3(16.0, 5.0, 12.0)), MeshFactory.xf(Vector3(0.0, 12.5, 1.0)), _concrete())
			b.add(MeshFactory.box(Vector3(22.0, 0.8, 0.2)), MeshFactory.xf(Vector3(0.0, 7.0, -9.1)), MeshFactory.glow(Color(0.45, 0.9, 1.0), 1.4))
			b.add(MeshFactory.box(Vector3(22.0, 0.8, 0.2)), MeshFactory.xf(Vector3(0.0, 3.5, -9.1)), MeshFactory.glow(Color(0.45, 0.9, 1.0), 1.4))
			b.add(MeshFactory.box(Vector3(6.0, 4.0, 3.0)), MeshFactory.xf(Vector3(0.0, 2.0, -10.3)), dark)
			b.add(MeshFactory.cylinder(0.15, 0.15, 12.0, 6), MeshFactory.xf(Vector3(10.0, 16.0, -6.0)), dark)
			b.add(MeshFactory.box(Vector3(3.2, 1.9, 0.1)), MeshFactory.xf(Vector3(11.7, 21.0, -6.0)), _team_glow(team, 2.5))
			for x: float in [-4.0, 0.0, 4.0]:
				b.add(MeshFactory.cylinder(0.1, 0.1, 6.0, 6), MeshFactory.xf(Vector3(x, 18.0, 4.0)), dark)
			b.add(MeshFactory.cylinder(1.6, 1.6, 0.3, 16), MeshFactory.xf(Vector3(-5.0, 15.2, 4.0), Vector3(60.0, 0.0, 0.0)), _metal())
		"bunker":
			b.add(MeshFactory.box(Vector3(10.0, 3.2, 8.0)), MeshFactory.xf(Vector3(0.0, 1.6, 0.0)), _concrete())
			b.add(MeshFactory.prism(Vector3(10.0, 1.4, 8.0)), MeshFactory.xf(Vector3(0.0, 3.9, 0.0)), _concrete())
			b.add(MeshFactory.box(Vector3(6.0, 0.5, 0.3)), MeshFactory.xf(Vector3(0.0, 2.3, -4.05)), dark)
			b.add(MeshFactory.box(Vector3(6.2, 0.1, 0.1)), MeshFactory.xf(Vector3(0.0, 2.6, -4.2)), _team_glow(team))
		"lighthouse":
			var white := MeshFactory.mat(Color(0.92, 0.92, 0.9), 0.6)
			var red := MeshFactory.mat(Color(0.75, 0.12, 0.1), 0.6)
			for i in 6:
				var r_bottom := 2.6 - float(i) * 0.14
				var r_top := r_bottom - 0.14
				b.add(MeshFactory.cylinder(r_top, r_bottom, 3.5, 16), MeshFactory.xf(Vector3(0.0, 1.75 + float(i) * 3.5, 0.0)), red if i % 2 == 1 else white)
			b.add(MeshFactory.cylinder(1.7, 1.7, 2.6, 16), MeshFactory.xf(Vector3(0.0, 22.3, 0.0)), MeshFactory.glow(Color(1.0, 0.93, 0.65), 3.0))
			b.add(MeshFactory.cylinder(0.1, 2.0, 2.0, 16), MeshFactory.xf(Vector3(0.0, 24.6, 0.0)), red)
			b.add(MeshFactory.cylinder(2.3, 2.3, 0.25, 16), MeshFactory.xf(Vector3(0.0, 21.0, 0.0)), dark)
		"warehouse":
			var wall := MeshFactory.mat(Color(0.44, 0.47, 0.5) if team == 0 else Color(0.5, 0.46, 0.4), 0.8)
			b.add(MeshFactory.box(Vector3(20.0, 7.0, 14.0)), MeshFactory.xf(Vector3(0.0, 3.5, 0.0)), wall)
			b.add(MeshFactory.prism(Vector3(14.0, 3.0, 20.0)), MeshFactory.xf(Vector3(0.0, 8.5, 0.0), Vector3(0.0, 90.0, 0.0)), dark)
			b.add(MeshFactory.box(Vector3(8.0, 5.0, 0.2)), MeshFactory.xf(Vector3(0.0, 2.5, -7.05)), dark)
			b.add(MeshFactory.box(Vector3(8.4, 0.25, 0.25)), MeshFactory.xf(Vector3(0.0, 5.2, -7.2)), _team_glow(team))
		"house":
			var walls: Array[Color] = [Color(0.82, 0.8, 0.72), Color(0.72, 0.68, 0.6), Color(0.78, 0.74, 0.62), Color(0.66, 0.7, 0.72)]
			var roofs: Array[Color] = [Color(0.48, 0.2, 0.15), Color(0.3, 0.3, 0.32), Color(0.4, 0.28, 0.18), Color(0.28, 0.34, 0.3)]
			b.add(MeshFactory.box(Vector3(8.0, 5.0, 7.0)), MeshFactory.xf(Vector3(0.0, 2.5, 0.0)), MeshFactory.mat(walls[variant % 4], 0.9))
			b.add(MeshFactory.prism(Vector3(7.4, 2.6, 8.6)), MeshFactory.xf(Vector3(0.0, 6.3, 0.0), Vector3(0.0, 90.0, 0.0)), MeshFactory.mat(roofs[variant % 4], 0.8))
			b.add(MeshFactory.box(Vector3(0.8, 2.0, 0.8)), MeshFactory.xf(Vector3(2.2, 7.0, 1.5)), MeshFactory.mat(Color(0.35, 0.3, 0.28), 0.9))
			b.add(MeshFactory.box(Vector3(1.4, 1.1, 0.1)), MeshFactory.xf(Vector3(-2.0, 3.0, -3.55)), MeshFactory.glow(Color(1.0, 0.85, 0.5), 1.2))
		"oil_rig":
			var steel := MeshFactory.mat(Color(0.35, 0.33, 0.3), 0.6, 0.5)
			for lx: float in [-12.0, 12.0]:
				for lz: float in [-12.0, 12.0]:
					b.add(MeshFactory.cylinder(1.2, 1.4, 30.0, 12), MeshFactory.xf(Vector3(lx, -5.0, lz)), steel)
			b.add(MeshFactory.box(Vector3(30.0, 2.0, 30.0)), MeshFactory.xf(Vector3(0.0, 11.0, 0.0)), MeshFactory.mat(Color(0.3, 0.3, 0.3), 0.8))
			b.add(MeshFactory.box(Vector3(12.0, 6.0, 10.0)), MeshFactory.xf(Vector3(-7.0, 15.0, -7.0)), MeshFactory.mat(Color(0.8, 0.8, 0.78), 0.7))
			b.add(MeshFactory.prism(Vector3(6.0, 20.0, 6.0)), MeshFactory.xf(Vector3(6.0, 22.0, 5.0)), steel)
			b.add(MeshFactory.cylinder(0.5, 0.5, 14.0, 8), MeshFactory.xf(Vector3(13.0, 19.0, -13.0), Vector3(0.0, 0.0, -20.0)), steel)
			b.add(MeshFactory.sphere(0.9), MeshFactory.xf(Vector3(15.4, 25.6, -13.0)), MeshFactory.glow(Color(1.0, 0.55, 0.15), 5.0))
			b.add(MeshFactory.cylinder(5.0, 5.0, 0.2, 24), MeshFactory.xf(Vector3(-7.0, 18.2, -7.0)), MeshFactory.glow(Color(1.0, 0.8, 0.2), 1.2))
			b.add(MeshFactory.box(Vector3(30.2, 0.3, 0.3)), MeshFactory.xf(Vector3(0.0, 12.1, -15.1)), MeshFactory.glow(Color(1.0, 0.3, 0.2), 2.0))


## Руины уничтоженного сооружения.
static func build_rubble(size: Vector3, seed_value: int) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var charred := MeshFactory.mat(Color(0.14, 0.13, 0.12), 0.95)
	var concrete := MeshFactory.mat(Color(0.32, 0.31, 0.3), 0.95)
	var b := ModelBuilder.new()
	var pieces := clampi(int(size.x * size.z / 40.0), 5, 16)
	for i in pieces:
		var s := Vector3(rng.randf_range(0.15, 0.4) * size.x, rng.randf_range(0.08, 0.3) * size.y, rng.randf_range(0.15, 0.4) * size.z)
		s.y = minf(s.y, 5.0)
		var p := Vector3(rng.randf_range(-0.4, 0.4) * size.x, s.y * 0.4, rng.randf_range(-0.4, 0.4) * size.z)
		var rot := Vector3(rng.randf_range(-20.0, 20.0), rng.randf_range(0.0, 360.0), rng.randf_range(-20.0, 20.0))
		b.add(MeshFactory.box(s), MeshFactory.xf(p, rot), charred if i % 2 == 0 else concrete)
	return b.build_instance("Rubble")


## Взлётно-посадочная полоса вдоль оси X с разметкой и огнями.
static func build_runway(team: int, length: float, width: float) -> MeshInstance3D:
	var key := "runway_%d_%d" % [team, int(length)]
	var mesh := MeshFactory.cached_mesh(key)
	if mesh == null:
		var b := ModelBuilder.new()
		var asphalt := MeshFactory.mat(Color(0.13, 0.135, 0.14), 0.95)
		var paint := MeshFactory.mat(Color(0.85, 0.85, 0.82), 0.8)
		var lights := MeshFactory.glow(GameDB.team_color(team), 3.0)
		b.add(MeshFactory.box(Vector3(length, 0.3, width)), MeshFactory.xf(Vector3.ZERO), asphalt)
		b.add(MeshFactory.box(Vector3(length * 0.55, 0.3, 22.0)), MeshFactory.xf(Vector3(0.0, 0.0, -width * 0.5 - 40.0)), asphalt)
		b.add(MeshFactory.box(Vector3(22.0, 0.3, 40.0)), MeshFactory.xf(Vector3(-length * 0.2, 0.0, -width * 0.5 - 20.0)), asphalt)
		b.add(MeshFactory.box(Vector3(22.0, 0.3, 40.0)), MeshFactory.xf(Vector3(length * 0.2, 0.0, -width * 0.5 - 20.0)), asphalt)
		var dashes := int(length / 40.0)
		for i in dashes:
			var x := -length * 0.5 + 30.0 + float(i) * 40.0
			b.add(MeshFactory.box(Vector3(18.0, 0.05, 0.9)), MeshFactory.xf(Vector3(x, 0.17, 0.0)), paint)
		for sx: float in GameDB.SIDES:
			for k in 8:
				b.add(MeshFactory.box(Vector3(30.0, 0.05, 1.6)), MeshFactory.xf(Vector3(sx * (length * 0.5 - 25.0), 0.17, -width * 0.4 + float(k) * width * 0.8 / 7.0)), paint)
		var n_lights := int(length / 50.0)
		for i in n_lights + 1:
			var x := -length * 0.5 + float(i) * length / float(n_lights)
			for sz: float in GameDB.SIDES:
				b.add(MeshFactory.sphere(0.35, -1.0, 8, 4), MeshFactory.xf(Vector3(x, 0.4, sz * (width * 0.5 + 1.5))), lights)
		mesh = b.build()
		MeshFactory.store_mesh(key, mesh)
	var mi := MeshInstance3D.new()
	mi.name = "Runway"
	mi.mesh = mesh
	return mi


## Причал вдоль оси Z (от берега в море), настил на высоте deck_height.
static func build_pier(team: int, length: float, deck_height: float) -> MeshInstance3D:
	var key := "pier_%d_%d" % [team, int(length)]
	var mesh := MeshFactory.cached_mesh(key)
	if mesh == null:
		var b := ModelBuilder.new()
		var concrete := _concrete()
		var dark := MeshFactory.mat(Color(0.2, 0.2, 0.2), 0.8)
		var lights := MeshFactory.glow(GameDB.team_color(team), 3.0)
		b.add(MeshFactory.box(Vector3(14.0, 1.0, length)), MeshFactory.xf(Vector3(0.0, deck_height - 0.5, length * 0.5)), concrete)
		var pillars := int(length / 22.0)
		for i in pillars + 1:
			var z := float(i) * length / float(pillars)
			for sx: float in GameDB.SIDES:
				b.add(MeshFactory.cylinder(0.6, 0.6, 12.0, 10), MeshFactory.xf(Vector3(6.0 * sx, deck_height - 6.5, z)), dark)
				b.add(MeshFactory.cylinder(0.3, 0.35, 0.6, 8), MeshFactory.xf(Vector3(6.4 * sx, deck_height + 0.3, z)), dark)
				b.add(MeshFactory.sphere(0.25, -1.0, 8, 4), MeshFactory.xf(Vector3(6.9 * sx, deck_height + 0.2, z + 5.0)), lights)
		b.add(MeshFactory.box(Vector3(1.2, 14.0, 1.2)), MeshFactory.xf(Vector3(-4.5, deck_height + 7.0, length * 0.35)), MeshFactory.mat(Color(0.85, 0.6, 0.1), 0.6, 0.3))
		b.add(MeshFactory.box(Vector3(1.0, 1.0, 18.0)), MeshFactory.xf(Vector3(-4.5, deck_height + 14.0, length * 0.35 + 6.0)), MeshFactory.mat(Color(0.85, 0.6, 0.1), 0.6, 0.3))
		mesh = b.build()
		MeshFactory.store_mesh(key, mesh)
	var mi := MeshInstance3D.new()
	mi.name = "Pier"
	mi.mesh = mesh
	return mi
