class_name AircraftBuilder
extends RefCounted
## Параметрический генератор моделей самолётов по описаниям AircraftSpecs.
##  * тела (фюзеляж, мотогондолы, коки, обтекатели) — лофт по сечениям-суперэллипсам со сплайновой
##    интерполяцией; гладкие нормали, развёртка в метрах для панельных линий шейдера;
##  * несущие поверхности (крылья, стабилизаторы, кили, ПГО, наплывы) — профиль NACA 00xx,
##    трапециевидные / скруглённые / эллиптические / треугольные в плане, стреловидность, V, развал;
##  * фонарь (стекло) с переплётами и пилотом, винты (кок, лопасти, диск), звездообразные моторы,
##    сопла с форсажным пламенем, воздухозаборники, выхлопные патрубки, стволы, антенны;
##  * опознавательные знаки — проекционные декали (повторяют кривизну обшивки).
## Модель смотрит вдоль -Z, начало координат — в центре масс (spec.cg по оси s от носа).

const PART_FUSELAGE := 0.0
const PART_WING := 1.0
const PART_STAB := 2.0
const PART_FIN := 3.0
const PART_COWL := 4.0
const PART_SPINNER := 5.0
const PART_NACELLE := 6.0

static var _mesh_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}
static var _prop_cache: Dictionary = {}


# --- Материалы -------------------------------------------------------------------------------------------
static func body_material(type_id: String, team: int) -> ShaderMaterial:
	var key := "body|%s|%d" % [type_id, team]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var spec := AircraftSpecs.get_spec(type_id)
	var paint: Dictionary = spec.get("paint", {})
	var cg := float(spec.get("cg", 3.0))
	var m := ShaderLib.material("aircraft")
	m.set_shader_parameter("camo_a", paint.get("a", Color(0.45, 0.47, 0.5)))
	m.set_shader_parameter("camo_b", paint.get("b", Color(0.32, 0.35, 0.38)))
	m.set_shader_parameter("camo_c", paint.get("c", Color(0.0, 0.0, 0.0)))
	m.set_shader_parameter("under_color", paint.get("under", Color(0.62, 0.68, 0.74)))
	m.set_shader_parameter("nose_color", paint.get("nose", Color(0.9, 0.75, 0.1)))
	m.set_shader_parameter("id_color", GameDB.team_color(team).lerp(Color(0.85, 0.85, 0.85), 0.12))
	m.set_shader_parameter("pattern", int(paint.get("pattern", 1)))
	m.set_shader_parameter("pattern_scale", float(paint.get("scale", 1.0)))
	m.set_shader_parameter("use_under", float(paint.get("use_under", 1.0)))
	var nose: Array = paint.get("nose_range", [])
	m.set_shader_parameter("nose_range", Vector2(float(nose[0]) - cg, float(nose[1]) - cg) if nose.size() == 2 else Vector2(-1000.0, -1000.0))
	var band: Array = paint.get("band", [])
	m.set_shader_parameter("band_range", Vector2(float(band[0]) - cg, float(band[1]) - cg) if band.size() == 2 else Vector2(1000.0, 1000.0))
	m.set_shader_parameter("tip_start", float(paint.get("tips", 1000.0)))
	m.set_shader_parameter("metallic_base", float(paint.get("metal", 0.0)))
	m.set_shader_parameter("roughness_base", float(paint.get("rough", 0.55)))
	m.set_shader_parameter("wear", float(paint.get("wear", 0.4)))
	m.set_shader_parameter("panel_scale", float(paint.get("panel", 1.0)))
	var ex: Array = paint.get("exhaust", [])
	m.set_shader_parameter("exhaust", Vector4(float(ex[0]) - cg, float(ex[1]) - cg, float(ex[2]), 1.0) if ex.size() == 3 else Vector4.ZERO)
	_mat_cache[key] = m
	return m


static func glass_material(tint: Color) -> StandardMaterial3D:
	var key := "glass|%s" % tint.to_html()
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = tint
	m.roughness = 0.04
	m.metallic = 0.35
	m.metallic_specular = 0.9
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6
	_mat_cache[key] = m
	return m


static func _dark() -> StandardMaterial3D:
	return MeshFactory.mat(Color(0.045, 0.047, 0.05), 0.7, 0.2)


static func _metal() -> StandardMaterial3D:
	return MeshFactory.mat(Color(0.34, 0.32, 0.3), 0.38, 0.85)


static func _vertex_color_mat() -> StandardMaterial3D:
	var key := "vcol"
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.55
	m.metallic = 0.2
	_mat_cache[key] = m
	return m


# --- Сборка модели ---------------------------------------------------------------------------------------
## Возвращает {root, props, prop_blades, prop_discs, afterburners, muzzles, hardpoints, rails,
## bomb_bay, wingtips, nozzles, length, span}.
static func build(type_id: String, team: int) -> Dictionary:
	var spec := AircraftSpecs.get_spec(type_id)
	var cg := float(spec.get("cg", 3.0))
	var root := Node3D.new()
	root.name = "Model"
	var key := "%s|%d" % [type_id, team]
	var mesh: ArrayMesh = _mesh_cache.get(key)
	if mesh == null:
		mesh = _build_static(type_id, spec, team, cg)
		_mesh_cache[key] = mesh
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = mesh
	root.add_child(body)
	var result := {"root": root, "props": [], "prop_blades": [], "prop_discs": [], "afterburners": [], "muzzles": [], "hardpoints": [], "rails": [], "wingtips": [], "nozzles": []}
	for p: Dictionary in spec.get("props", []):
		_add_prop(root, result, type_id, p, team, cg)
	for nz: Dictionary in spec.get("nozzles", []):
		for side: float in _sides(nz):
			var exit := _p(float(nz["s"]) + float(nz["len"]), float(nz["x"]) * side, float(nz["y"]), cg)
			var marker := Node3D.new()
			marker.name = "Nozzle"
			marker.position = exit
			root.add_child(marker)
			(result["nozzles"] as Array).append(marker)
			if not bool(nz.get("flame", true)):
				continue
			var flame := MeshFactory.mesh_instance(MeshFactory.cylinder(0.04, float(nz["r"]) * 0.82, float(nz["r"]) * 5.5, 12), MeshFactory.shared_fade_material("afterburner", Color(1.0, 0.55, 0.2, 0.85), true), "Afterburner")
			flame.transform = MeshFactory.along_z(exit + Vector3(0.0, 0.0, float(nz["r"]) * 2.7))
			flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(flame)
			(result["afterburners"] as Array).append(flame)
	for g: Array in spec.get("guns", []):
		(result["muzzles"] as Array).append(_marker(root, "Muzzle", _p(float(g[2]), float(g[0]), float(g[1]), cg)))
	for h: Array in spec.get("hardpoints", []):
		(result["hardpoints"] as Array).append(_marker(root, "Hardpoint", _p(float(h[2]), float(h[0]), float(h[1]), cg)))
	for r: Array in spec.get("rails", []):
		(result["rails"] as Array).append(_marker(root, "Rail", _p(float(r[2]), float(r[0]), float(r[1]), cg)))
	var bay: Array = spec.get("bomb_bay", [0.0, -1.0, cg])
	result["bomb_bay"] = _p(float(bay[2]), float(bay[0]), float(bay[1]), cg)
	var wing: Dictionary = _main_wing(spec)
	if not wing.is_empty():
		var semi := float(wing["span"]) * 0.5
		var tip_s := float(wing["s"]) + (semi - float(wing.get("x", 0.0))) * tan(deg_to_rad(float(wing.get("sweep", 0.0)))) + float(wing["tip"]) * 0.5
		var tip_y := float(wing.get("y", 0.0)) + (semi - float(wing.get("x", 0.0))) * tan(deg_to_rad(float(wing.get("dihedral", 0.0))))
		for side: float in GameDB.SIDES:
			(result["wingtips"] as Array).append(_marker(root, "WingTip", _p(tip_s, semi * side * 0.98, tip_y, cg)))
		_add_nav_lights(root, semi, tip_s, tip_y, cg)
	_add_insignia(root, spec, cg)
	result["length"] = float(spec.get("length", 10.0))
	result["span"] = float(wing.get("span", 10.0)) if not wing.is_empty() else 10.0
	return result


static func _main_wing(spec: Dictionary) -> Dictionary:
	for s: Dictionary in spec.get("surfaces", []):
		if str(s.get("part", "wing")) == "wing" and bool(s.get("mirror", true)) and not bool(s.get("vertical", false)):
			return s
	return {}


static func _marker(root: Node3D, marker_name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = marker_name
	n.position = pos
	root.add_child(n)
	return n


static func _p(s: float, x: float, y: float, cg: float) -> Vector3:
	return Vector3(x, y, s - cg)


static func _sides(d: Dictionary) -> Array[float]:
	var result: Array[float] = [1.0]
	if bool(d.get("mirror", false)) and absf(float(d.get("x", 0.0))) > 0.001:
		result.append(-1.0)
	return result


static func _build_static(type_id: String, spec: Dictionary, team: int, cg: float) -> ArrayMesh:
	var body := MeshKit.new()
	var glass := MeshKit.new()
	var dark := MeshKit.new()
	var metal := MeshKit.new()
	for b: Dictionary in spec.get("bodies", []):
		var kit := body
		match str(b.get("material", "body")):
			"dark":
				kit = dark
			"metal":
				kit = metal
			"glass":
				kit = glass
		var part := {"fuselage": PART_FUSELAGE, "cowl": PART_COWL, "nacelle": PART_NACELLE}.get(str(b.get("part", "fuselage")), PART_FUSELAGE) as float
		for side: float in _sides(b):
			kit.add_loft(b["stations"], float(b.get("n", 2.0)), int(b.get("segs", 28)), cg, part, Vector3(float(b.get("x", 0.0)) * side, float(b.get("y", 0.0)), 0.0), bool(b.get("cap_front", false)), bool(b.get("cap_back", true)))
	for s: Dictionary in spec.get("surfaces", []):
		_surface(body, s, cg)
	var canopy: Dictionary = spec.get("canopy", {})
	if not canopy.is_empty():
		_canopy(glass, body, dark, canopy, cg)
	for f: Dictionary in spec.get("radials", []):
		for side: float in _sides(f):
			_radial_face(dark, metal, f, side, cg)
	for i: Dictionary in spec.get("intakes", []):
		for side: float in _sides(i):
			_intake_face(dark, i, side, cg)
	for nz: Dictionary in spec.get("nozzles", []):
		for side: float in _sides(nz):
			_nozzle(metal, dark, nz, side, cg)
	for e: Dictionary in spec.get("exhausts", []):
		_exhaust_stubs(metal, e, cg)
	for g: Dictionary in spec.get("barrels", []):
		for side: float in _sides(g):
			var p := _p(float(g["s"]), float(g["x"]) * side, float(g["y"]), cg)
			dark.xform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-90.0), 0.0, 0.0)), p - Vector3(0.0, 0.0, float(g["len"]) * 0.5))
			dark.add_cylinder(Vector3.ZERO, -float(g["len"]) * 0.5, float(g["len"]) * 0.5, float(g.get("r", 0.035)), float(g.get("r", 0.035)), 8, Color.WHITE, Color.WHITE)
			dark.xform = Transform3D.IDENTITY
	var ant: Dictionary = spec.get("antenna", {})
	if not ant.is_empty():
		var base := _p(float(ant["s"]), 0.0, float(ant["y"]), cg)
		dark.add_cylinder(base, 0.0, float(ant["h"]), 0.03, 0.012, 5, Color.WHITE, Color.WHITE)
	var pitot: Array = spec.get("pitot", [])
	if pitot.size() == 4:
		var p := _p(float(pitot[2]), float(pitot[0]), float(pitot[1]), cg)
		metal.xform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-90.0), 0.0, 0.0)), p)
		metal.add_cylinder(Vector3.ZERO, 0.0, float(pitot[3]), 0.035, 0.012, 6, Color.WHITE, Color.WHITE)
		metal.xform = Transform3D.IDENTITY
	for r: Array in spec.get("rails", []):
		var rp := _p(float(r[2]), float(r[0]), float(r[1]) + 0.12, cg)
		dark.add_box(rp + Vector3(0.0, 0.0, 0.2), Vector3(0.12, 0.1, 2.2))
	var mesh := body.commit(null, body_material(type_id, team))
	var tint: Color = canopy.get("tint", Color(0.1, 0.16, 0.2, 0.42))
	glass.commit(mesh, glass_material(tint))
	dark.commit(mesh, _dark())
	metal.commit(mesh, _metal())
	return mesh


# --- Лофт тел -------------------------------------------------------------------------------------------
# --- Несущие поверхности ---------------------------------------------------------------------------------
## Крыло/оперение: профиль NACA 00xx, форма в плане, стреловидность, V; зеркальная пара и вертикальные кили.
static func _surface(kit: MeshKit, s: Dictionary, cg: float) -> void:
	var vertical := bool(s.get("vertical", false))
	var mirror := bool(s.get("mirror", not vertical))
	var x_root := float(s.get("x", 0.0))
	var semi: float
	if vertical:
		semi = float(s.get("height", s.get("span", 1.5)))
	else:
		semi = float(s["span"]) * 0.5 - (x_root if mirror else 0.0)
	var root := float(s["root"])
	var tip := float(s["tip"])
	var sweep := tan(deg_to_rad(float(s.get("sweep", 0.0))))
	var dih := deg_to_rad(float(s.get("dihedral", 0.0)))
	var gull: Array = s.get("gull", [])
	var thick := float(s.get("thick", 0.12))
	var tip_thick := float(s.get("tip_thick", thick))
	var shape := str(s.get("shape", "trapezoid"))
	var round_k := float(s.get("round", 0.16))
	var s_le := float(s["s"])
	var y0 := float(s.get("y", 0.0))
	var part: float = {"wing": PART_WING, "stab": PART_STAB, "fin": PART_FIN, "canard": PART_STAB, "lerx": PART_WING}.get(str(s.get("part", "wing")), PART_WING)
	var ns := int(s.get("sections", 16 if shape in ["rounded", "elliptical"] else 8))
	var m := int(s.get("chord_pts", 11))
	var xs := PackedFloat32Array()
	for i in m:
		xs.append(0.5 * (1.0 - cos(PI * float(i) / float(m - 1))))
	var loop := 2 * m - 1
	var grid := PackedVector3Array()
	grid.resize((ns + 1) * loop)
	var uvs := PackedVector2Array()
	uvs.resize((ns + 1) * loop)
	var fracs := PackedFloat32Array()
	fracs.resize((ns + 1) * loop)
	var centers := PackedVector3Array()
	for k in ns + 1:
		var u := float(k) / float(ns)
		var eta := u if shape == "trapezoid" or shape == "delta" else 1.0 - pow(1.0 - u, 1.35)
		var span_pos := eta * semi
		var c := lerpf(root, tip, eta)
		var z_le := s_le + span_pos * sweep
		match shape:
			"rounded":
				var t0 := 1.0 - round_k
				if eta > t0:
					var f := sqrt(maxf(1.0 - pow((eta - t0) / round_k, 2.0), 0.0))
					var cf := c * maxf(f, 0.12)
					z_le += (c - cf) * 0.55
					c = cf
			"elliptical":
				var cf := root * maxf(sqrt(maxf(1.0 - eta * eta, 0.0)), 0.1)
				z_le = s_le + 0.3 * root + span_pos * sweep - 0.3 * cf
				c = cf
		var lift := span_pos * tan(dih)
		if gull.size() == 2:
			var brk := float(gull[0]) * semi
			var inner := tan(deg_to_rad(float(gull[1])))
			lift = minf(span_pos, brk) * inner + maxf(span_pos - brk, 0.0) * tan(dih)
		var t := lerpf(thick, tip_thick, eta) * c
		centers.append(Vector3(span_pos, lift, z_le + c * 0.5))
		for r in loop:
			var upper := r < m
			var xi := xs[m - 1 - r] if upper else xs[r - m + 1]
			var yt := 5.0 * t * (0.2969 * sqrt(xi) - 0.126 * xi - 0.3516 * xi * xi + 0.2843 * xi * xi * xi - 0.1036 * xi * xi * xi * xi)
			var yy := lift + (yt if upper else -yt)
			grid[k * loop + r] = Vector3(span_pos, yy, z_le + xi * c)
			uvs[k * loop + r] = Vector2(span_pos, xi * c)
			fracs[k * loop + r] = xi
	var normals := PackedVector3Array()
	normals.resize(grid.size())
	for k in ns + 1:
		for r in loop:
			var t_r := grid[k * loop + mini(r + 1, loop - 1)] - grid[k * loop + maxi(r - 1, 0)]
			var t_k := grid[mini(k + 1, ns) * loop + r] - grid[maxi(k - 1, 0) * loop + r]
			var nv := t_k.cross(t_r)
			var ref := grid[k * loop + r] - centers[k]
			ref.x = 0.0
			if nv.dot(ref) < 0.0:
				nv = -nv
			normals[k * loop + r] = nv.normalized()
	var copies: Array[float] = [1.0]
	if mirror:
		copies.append(-1.0)
	var cant := deg_to_rad(float(s.get("cant", 0.0)))
	for side in copies:
		var basis: Basis
		if vertical:
			basis = Basis(Vector3(0.0, 1.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0))
			basis = Basis(Vector3(0.0, 0.0, 1.0), -cant) * basis
		else:
			basis = Basis.IDENTITY
		var shift := Vector3(x_root, y0, -cg)
		if side < 0.0:
			basis = Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0)) * basis
			shift.x = -shift.x
		var flip := basis.determinant() < 0.0
		var base := kit.vertex_count()
		for i in grid.size():
			kit.uv2 = Vector2(fracs[i], part)
			kit.add_vertex(basis * grid[i] + shift, (basis * normals[i]).normalized(), uvs[i])
		for k in ns:
			for r in loop - 1:
				var a := base + k * loop + r
				var b := a + 1
				var d := a + loop
				var f := d + 1
				if flip:
					kit.quad(a, d, f, b)
				else:
					kit.quad(a, b, f, d)
		var tip_center := basis * centers[ns] + shift
		var tn := (basis * Vector3(1.0, 0.0, 0.0)).normalized()
		kit.uv2 = Vector2(0.5, part)
		var ci := kit.add_vertex(tip_center, tn, Vector2(semi, 0.0))
		var ring_start := kit.vertex_count()
		for r in loop:
			kit.add_vertex(basis * grid[ns * loop + r] + shift, tn, uvs[ns * loop + r])
		for r in loop - 1:
			if flip:
				kit.tri(ci, ring_start + r + 1, ring_start + r)
			else:
				kit.tri(ci, ring_start + r, ring_start + r + 1)


# --- Фонарь кабины -------------------------------------------------------------------------------------
static func _canopy(glass: MeshKit, body: MeshKit, dark: MeshKit, c: Dictionary, cg: float) -> void:
	var stations: Array = c["stations"]
	glass.add_loft(stations, float(c.get("n", 2.2)), 24, cg, PART_FUSELAGE, Vector3.ZERO, true, true)
	for fs in c.get("frames", []):
		var s := float(fs)
		var prof := _profile_at(stations, s)
		if prof.is_empty():
			continue
		var k := 1.04
		var ring := [
			[s - 0.03, prof[1] * k, prof[2] * k + 0.01, prof[3] * k, prof[4]],
			[s + 0.03, prof[1] * k, prof[2] * k + 0.01, prof[3] * k, prof[4]],
		]
		body.add_loft(ring, float(c.get("n", 2.2)), 20, cg, PART_FUSELAGE, Vector3.ZERO, false, false)
	if bool(c.get("spine", false)):
		var first: Array = stations[1]
		var last: Array = stations[stations.size() - 2]
		var spine: Array = []
		for st: Array in stations:
			if float(st[0]) < float(first[0]) or float(st[0]) > float(last[0]):
				continue
			spine.append([float(st[0]), 0.03, 0.025, 0.025, float(st[4]) + float(st[2]) + 0.005])
		if spine.size() >= 2:
			body.add_loft(spine, 2.0, 6, cg, PART_FUSELAGE, Vector3.ZERO, true, true)
	var pilot: Array = c.get("pilot", [])
	if pilot.size() >= 2:
		var head := _p(float(pilot[0]), 0.0, float(pilot[1]), cg)
		var helmet := Color(0.16, 0.14, 0.12) if bool(c.get("leather", true)) else Color(0.78, 0.8, 0.82)
		dark.add_blob(head, Vector3(0.14, 0.16, 0.16), 1, 0.02, 1, helmet, helmet)
		dark.add_blob(head + Vector3(0.0, -0.3, 0.08), Vector3(0.26, 0.18, 0.18), 0, 0.02, 2, Color(0.1, 0.1, 0.1), Color(0.2, 0.2, 0.18))


static func _profile_at(stations: Array, s: float) -> PackedFloat32Array:
	for i in stations.size() - 1:
		var a: Array = stations[i]
		var b: Array = stations[i + 1]
		if s >= float(a[0]) and s <= float(b[0]):
			var t := (s - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
			return MeshKit.interp_station(stations, i, t)
	return PackedFloat32Array()


# --- Детали -----------------------------------------------------------------------------------------------
## Передняя часть звездообразного мотора: тёмная полость за капотом и головки цилиндров.
static func _radial_face(dark: MeshKit, metal: MeshKit, f: Dictionary, side: float, cg: float) -> void:
	var s := float(f["s"])
	var r := float(f["r"])
	var y := float(f.get("y", 0.0))
	var center := _p(s + 0.12, float(f.get("x", 0.0)) * side, y, cg)
	var segs := 20
	var ci := dark.add_vertex(center, Vector3(0.0, 0.0, -1.0))
	var ring := PackedInt32Array()
	for i in segs:
		var a := float(i) / float(segs) * TAU
		ring.append(dark.add_vertex(center + Vector3(cos(a) * r, sin(a) * r, 0.0), Vector3(0.0, 0.0, -1.0)))
	for i in segs:
		dark.tri(ci, ring[i], ring[(i + 1) % segs])
	var cyl := int(f.get("cylinders", 9))
	for i in cyl:
		var a := float(i) / float(cyl) * TAU
		var dir := Vector3(cos(a), sin(a), 0.0)
		metal.xform = Transform3D(Basis(Vector3(0.0, 0.0, 1.0), a - PI * 0.5), center + dir * r * 0.55 + Vector3(0.0, 0.0, -0.03))
		metal.add_cylinder(Vector3.ZERO, -r * 0.3, r * 0.3, r * 0.14, r * 0.11, 8, Color.WHITE, Color.WHITE)
		metal.xform = Transform3D.IDENTITY


## Тёмная полость воздухозаборника.
static func _intake_face(dark: MeshKit, i: Dictionary, side: float, cg: float) -> void:
	var c := _p(float(i["s"]), float(i["x"]) * side, float(i["y"]), cg)
	var w := float(i["w"]) * 0.5
	var h := float(i["h"]) * 0.5
	var nv := Vector3(0.0, 0.0, -1.0)
	var a := dark.add_vertex(c + Vector3(-w, -h, 0.0), nv)
	var b := dark.add_vertex(c + Vector3(w, -h, 0.0), nv)
	var d := dark.add_vertex(c + Vector3(w, h, 0.0), nv)
	var e := dark.add_vertex(c + Vector3(-w, h, 0.0), nv)
	dark.quad(a, e, d, b)
	dark.quad(a, b, d, e)


## Сопло: металлический срез и тёмная глубина.
static func _nozzle(metal: MeshKit, dark: MeshKit, nz: Dictionary, side: float, cg: float) -> void:
	var r := float(nz["r"])
	var s0 := float(nz["s"])
	var ln := float(nz["len"])
	var st := [[s0, r * 1.02, r * 1.02, r * 1.02, 0.0], [s0 + ln * 0.5, r, r, r, 0.0], [s0 + ln, r * 0.9, r * 0.9, r * 0.9, 0.0]]
	metal.add_loft(st, 2.0, 18, cg, PART_NACELLE, Vector3(float(nz["x"]) * side, float(nz["y"]), 0.0), false, false)
	var center := _p(s0 + ln * 0.55, float(nz["x"]) * side, float(nz["y"]), cg)
	var segs := 16
	var ci := dark.add_vertex(center, Vector3(0.0, 0.0, 1.0))
	var ring := PackedInt32Array()
	for i in segs:
		var a := float(i) / float(segs) * TAU
		ring.append(dark.add_vertex(center + Vector3(cos(a) * r * 0.9, sin(a) * r * 0.9, 0.0), Vector3(0.0, 0.0, 1.0)))
	for i in segs:
		dark.tri(ci, ring[(i + 1) % segs], ring[i])


static func _exhaust_stubs(metal: MeshKit, e: Dictionary, cg: float) -> void:
	var count := int(e.get("count", 6))
	var step := float(e.get("step", 0.16))
	for side: float in GameDB.SIDES:
		for i in count:
			var s := float(e["s"]) + float(i) * step
			metal.add_box(_p(s, float(e["x"]) * side, float(e["y"]), cg), Vector3(0.1, 0.07, 0.09))


static func _add_nav_lights(root: Node3D, semi: float, tip_s: float, tip_y: float, cg: float) -> void:
	for side: float in GameDB.SIDES:
		var col := Color(1.0, 0.15, 0.1) if side < 0.0 else Color(0.1, 1.0, 0.3)
		var l := MeshFactory.mesh_instance(MeshFactory.sphere(0.07, -1.0, 8, 4), MeshFactory.glow(col, 5.0), "NavLight")
		l.position = _p(tip_s - 0.1, semi * side * 0.995, tip_y, cg)
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(l)


# --- Винты -------------------------------------------------------------------------------------------------
static func _add_prop(root: Node3D, result: Dictionary, type_id: String, p: Dictionary, team: int, cg: float) -> void:
	for side: float in _sides(p):
		var sp_len := float(p.get("spinner_len", 0.55))
		var hub := Node3D.new()
		hub.name = "PropHub"
		hub.position = _p(float(p["s"]) + sp_len * 0.72, float(p.get("x", 0.0)) * side, float(p.get("y", 0.0)), cg)
		root.add_child(hub)
		var key := "%s|%d" % [type_id, team]
		var meshes: Dictionary = _prop_cache.get(key, {})
		if meshes.is_empty():
			meshes = _build_prop_meshes(type_id, p, team)
			_prop_cache[key] = meshes
		var spinner := MeshInstance3D.new()
		spinner.name = "Spinner"
		spinner.mesh = meshes["spinner"]
		hub.add_child(spinner)
		var blades := MeshInstance3D.new()
		blades.name = "Blades"
		blades.mesh = meshes["blades"]
		hub.add_child(blades)
		var disc := MeshInstance3D.new()
		disc.name = "Disc"
		disc.mesh = meshes["disc"]
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.visible = false
		hub.add_child(disc)
		(result["props"] as Array).append(hub)
		(result["prop_blades"] as Array).append(blades)
		(result["prop_discs"] as Array).append(disc)


static func _build_prop_meshes(type_id: String, p: Dictionary, team: int) -> Dictionary:
	var radius := float(p["radius"])
	var sp_len := float(p.get("spinner_len", 0.55))
	var sp_r := float(p.get("spinner_r", 0.2))
	var blades_n := int(p.get("blades", 3))
	var sk := MeshKit.new()
	var off := -sp_len * 0.72
	var st := [
		[off, 0.01, 0.01, 0.01, 0.0], [off + sp_len * 0.2, sp_r * 0.52, sp_r * 0.52, sp_r * 0.52, 0.0],
		[off + sp_len * 0.55, sp_r * 0.88, sp_r * 0.88, sp_r * 0.88, 0.0], [off + sp_len, sp_r, sp_r, sp_r, 0.0],
	]
	sk.add_loft(st, 2.0, 18, 0.0, PART_SPINNER, Vector3.ZERO, false, true)
	var spinner := sk.commit(null, body_material(type_id, team))
	var bk := MeshKit.new()
	var tip_col := Color(0.95, 0.78, 0.12)
	var blade_col := Color(0.06, 0.06, 0.06)
	for b in blades_n:
		var ang := float(b) / float(blades_n) * TAU
		var rot := Basis(Vector3(0.0, 0.0, 1.0), ang)
		var steps := 6
		var prev := PackedInt32Array()
		for i in steps + 1:
			var t := float(i) / float(steps)
			var rr := lerpf(sp_r * 0.6, radius, t)
			var chord := lerpf(0.2, 0.26, sin(t * PI)) * (1.0 - 0.45 * t * t) * radius / 1.6
			var pitch := deg_to_rad(lerpf(58.0, 18.0, t))
			var cdir := Vector3(cos(pitch), 0.0, sin(pitch))
			var tdir := Vector3(-sin(pitch), 0.0, cos(pitch)) * 0.02
			var col := tip_col if t > 0.9 else blade_col
			var center := Vector3(0.0, rr, 0.0)
			var ids := PackedInt32Array()
			for q: Vector3 in [center + cdir * chord * 0.5 + tdir, center - cdir * chord * 0.5 + tdir, center - cdir * chord * 0.5 - tdir, center + cdir * chord * 0.5 - tdir]:
				ids.append(bk.add_vertex(rot * q, (rot * (q - center)).normalized(), Vector2.ZERO, col))
			if not prev.is_empty():
				for k in 4:
					var k2 := (k + 1) % 4
					bk.quad(prev[k], ids[k], ids[k2], prev[k2])
					bk.quad(prev[k], prev[k2], ids[k2], ids[k])
			prev = ids
	var blades := bk.commit(null, _vertex_color_mat())
	var disc_mesh := QuadMesh.new()
	disc_mesh.size = Vector2(radius * 2.0, radius * 2.0)
	var dm := ShaderLib.material("prop_disc")
	dm.set_shader_parameter("blades", float(blades_n))
	disc_mesh.material = dm
	return {"spinner": spinner, "blades": blades, "disc": disc_mesh}


# --- Опознавательные знаки ---------------------------------------------------------------------------------
static func _add_insignia(root: Node3D, spec: Dictionary, cg: float) -> void:
	var ins: Dictionary = spec.get("insignia", {})
	if ins.is_empty():
		return
	var nation := str(spec.get("nation", "su"))
	var tex := Insignia.texture(nation, "wing")
	var fus_tex := Insignia.texture(nation, "fuselage")
	var wing: Array = ins.get("wing", [])
	if wing.size() == 4:
		for side: float in GameDB.SIDES:
			var pos := _p(float(wing[0]), float(wing[1]) * side, float(wing[2]), cg)
			_decal(root, tex, pos, Basis.IDENTITY, float(wing[3]), 1.2)
			if bool(ins.get("under", true)):
				_decal(root, tex, pos, Basis(Vector3(1.0, 0.0, 0.0), PI), float(wing[3]), 1.2)
	var fus: Array = ins.get("fuselage", [])
	if fus.size() == 4:
		for side: float in GameDB.SIDES:
			var pos := _p(float(fus[0]), float(fus[1]) * side * 0.5, float(fus[2]), cg)
			var x_axis := Vector3(0.0, 0.0, -side)
			var z_axis := Vector3(0.0, -1.0, 0.0)
			var y_axis := z_axis.cross(x_axis)
			_decal(root, fus_tex, pos, Basis(x_axis, y_axis, z_axis), float(fus[3]), absf(float(fus[1])) + 0.2)
	var fin: Array = ins.get("fin", [])
	if fin.size() == 4:
		var fin_tex := Insignia.texture(nation, "fin")
		for side: float in GameDB.SIDES:
			var pos := _p(float(fin[0]), float(fin[1]) * side * 0.5, float(fin[2]), cg)
			var x_axis := Vector3(0.0, 0.0, -side)
			var z_axis := Vector3(0.0, -1.0, 0.0)
			_decal(root, fin_tex, pos, Basis(x_axis, z_axis.cross(x_axis), z_axis), float(fin[3]), absf(float(fin[1])) + 0.2)
	var extra: Array = ins.get("nose_art", [])
	if extra.size() == 4:
		var art := Insignia.texture(str(ins.get("art", "shark")), "art")
		for side: float in GameDB.SIDES:
			var pos := _p(float(extra[0]), float(extra[1]) * side * 0.5, float(extra[2]), cg)
			var x_axis := Vector3(0.0, 0.0, -side)
			var z_axis := Vector3(0.0, -1.0, 0.0)
			_decal(root, art, pos, Basis(x_axis, z_axis.cross(x_axis), z_axis), float(extra[3]), absf(float(extra[1])) + 0.3)


static func _decal(root: Node3D, tex: Texture2D, pos: Vector3, basis: Basis, size: float, depth: float) -> void:
	if tex == null:
		return
	var d := Decal.new()
	d.name = "Insignia"
	d.texture_albedo = tex
	d.size = Vector3(size, depth, size)
	d.normal_fade = 0.35
	d.upper_fade = 0.05
	d.lower_fade = 0.05
	d.albedo_mix = 1.0
	d.distance_fade_enabled = true
	d.distance_fade_begin = 700.0
	d.distance_fade_length = 300.0
	d.transform = Transform3D(basis, pos)
	root.add_child(d)
