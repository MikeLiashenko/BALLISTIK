class_name Cockpit
extends Node3D
## Процедурная кабина самолёта для вида от первого лица. Строится по данным AircraftSpecs (положение
## пилота, профиль фонаря, ширина фюзеляжа) и крепится к модели самолёта:
##  * приборная доска с козырьком: стрелочные приборы (скорость, высотомер, обороты/тяга, вариометр,
##    курс, боезапас) с живыми стрелками и авиагоризонт; у реактивных — два многофункциональных
##    экрана с вращающейся развёрткой РЛС;
##  * коллиматорный прицел (поршневые) или индикатор на лобовом стекле (реактивные);
##  * изнутри — переплёт фонаря, борта и пульты, ручка управления и РУД, движущиеся вместе с
##    управлением, бронеспинка; лёгкий блик остекления.

const ARC := 135.0

static var _textures: Dictionary = {}
static var _overlay_mats: Dictionary = {}

var aircraft: Aircraft = null
## Точка глаз пилота в координатах самолёта.
var eye: Vector3 = Vector3.ZERO

var _jet: bool = false
var _needles: Dictionary = {}
var _horizon: Node3D = null
var _sweeps: Array[Node3D] = []
var _stick: Node3D = null
var _throttle: Node3D = null
var _time: float = 0.0


func setup(a: Aircraft) -> void:
	aircraft = a
	name = "Cockpit"
	_jet = a.engine_kind == "jet"
	var spec := AircraftSpecs.get_spec(a.vehicle_type)
	var cg := float(spec.get("cg", 3.0))
	var canopy: Dictionary = spec.get("canopy", {})
	var pilot: Array = canopy.get("pilot", [3.5, 0.7])
	var ps := float(pilot[0])
	eye = Vector3(0.0, float(pilot[1]) + 0.13, ps - cg - 0.03)
	if not canopy.is_empty():
		# Глаза — под остеклением (иначе камера выглядывает из фонаря наружу).
		var cp := AircraftBuilder._profile_at(canopy["stations"], ps)
		if not cp.is_empty():
			eye.y = minf(eye.y, cp[4] + cp[2] - 0.12)
	var hw := _cockpit_half_width(spec, ps)
	var interior := _mat(Color(0.1, 0.11, 0.12) if _jet else Color(0.16, 0.19, 0.17), 0.9)
	var panel_mat := _mat(Color(0.035, 0.035, 0.04), 0.7)
	var frame_mat := _mat(Color(0.03, 0.032, 0.035), 0.75, 0.2)
	var sill_y := eye.y - 0.42
	var panel_z := eye.z - 0.7
	var top_y := eye.y - 0.29
	# Борта, пульты, бронеспинка.
	var length := (eye.z + 0.45) - (panel_z - 0.05)
	var mid_z := (eye.z + 0.45 + panel_z - 0.05) * 0.5
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.03, 0.5, length), Vector3(side * hw, sill_y - 0.24, mid_z), interior)
		_box(Vector3(0.13, 0.07, 0.55), Vector3(side * (hw - 0.08), sill_y - 0.2, eye.z - 0.1), interior)
		_box(Vector3(0.05, 0.03, length), Vector3(side * (hw - 0.01), sill_y + 0.005, mid_z), frame_mat)
		for i in 3:
			var knob := _mesh(MeshFactory.cylinder(0.012, 0.012, 0.02, 8), MeshFactory.mat(Color(0.7, 0.15, 0.1) if i == 0 else Color(0.85, 0.8, 0.6), 0.5), Vector3(side * (hw - 0.08) + float(i - 1) * 0.035, sill_y - 0.155, eye.z - 0.25 + float(i) * 0.07))
			knob.rotation = Vector3.ZERO
	_box(Vector3(0.38, 0.55, 0.06), Vector3(0.0, eye.y - 0.2, eye.z + 0.3), interior)
	if not _jet:
		_box(Vector3(0.3, 0.32, 0.04), Vector3(0.0, eye.y - 0.06, eye.z + 0.26), _mat(Color(0.2, 0.2, 0.2), 0.4, 0.6))
	# Приборная доска с козырьком.
	var panel := Node3D.new()
	panel.name = "Panel"
	panel.position = Vector3(0.0, top_y - 0.18, panel_z)
	panel.rotation = Vector3(deg_to_rad(-14.0), 0.0, 0.0)
	add_child(panel)
	var pw := hw * 1.9
	_box(Vector3(pw, 0.62, 0.03), Vector3(0.0, -0.12, -0.016), panel_mat, panel)
	_box(Vector3(pw + 0.02, 0.022, 0.15), Vector3(0.0, top_y + 0.012, panel_z + 0.05), frame_mat)
	_box(Vector3(pw * 0.95, 0.5, 0.45), Vector3(0.0, top_y - 0.88, panel_z + 0.12), interior)
	_box(Vector3(0.16, 0.3, 0.3), Vector3(0.0, top_y - 0.6, panel_z + 0.2), panel_mat)
	_build_instruments(panel, pw)
	_build_sight(top_y, panel_z)
	# Ручка управления и РУД.
	_stick = Node3D.new()
	_stick.name = "Stick"
	_stick.position = Vector3(0.0, eye.y - 1.0, eye.z - 0.36)
	add_child(_stick)
	_mesh(MeshFactory.cylinder(0.014, 0.018, 0.5, 8), frame_mat, Vector3(0.0, 0.25, 0.0), _stick)
	_mesh(MeshFactory.cylinder(0.024, 0.022, 0.11, 10), _mat(Color(0.12, 0.1, 0.08), 0.8), Vector3(0.0, 0.53, 0.0), _stick)
	_mesh(MeshFactory.box(Vector3(0.012, 0.018, 0.012)), MeshFactory.mat(Color(0.75, 0.12, 0.08), 0.5), Vector3(0.0, 0.59, -0.012), _stick)
	_throttle = Node3D.new()
	_throttle.name = "Throttle"
	_throttle.position = Vector3(-(hw - 0.08), sill_y - 0.16, eye.z - 0.12)
	add_child(_throttle)
	_mesh(MeshFactory.box(Vector3(0.015, 0.16, 0.015)), frame_mat, Vector3(0.0, 0.08, 0.0), _throttle)
	_mesh(MeshFactory.sphere(0.022, -1.0, 10, 6), _mat(Color(0.1, 0.1, 0.1), 0.6), Vector3(0.0, 0.165, 0.0), _throttle)
	# Переплёт фонаря изнутри и остекление.
	if not canopy.is_empty():
		_build_canopy_frames(canopy, cg, frame_mat)
	_finalize(self, 0)


func _cockpit_half_width(spec: Dictionary, s: float) -> float:
	var bodies: Array = spec.get("bodies", [])
	if bodies.is_empty():
		return 0.42
	var prof := AircraftBuilder._profile_at((bodies[0] as Dictionary)["stations"], s)
	if prof.is_empty():
		return 0.42
	return clampf(prof[1] * 0.86, 0.32, 0.62)


# --- Приборы ------------------------------------------------------------------------------------------------
func _build_instruments(panel: Node3D, pw: float) -> void:
	var r := 0.047
	var dx := minf(0.165, pw * 0.5 - 0.07)
	if _jet:
		_mfd(panel, Vector3(-dx - 0.02, 0.02, 0.0))
		_mfd(panel, Vector3(dx + 0.02, 0.02, 0.0))
		_attitude(panel, Vector3(0.0, 0.085, 0.0), r * 0.95)
		_gauge(panel, "speed", Vector3(0.0, -0.035, 0.0), r * 0.8)
		_gauge(panel, "alt", Vector3(-dx - 0.02, -0.13, 0.0), r * 0.75)
		_gauge(panel, "rpm", Vector3(dx + 0.02, -0.13, 0.0), r * 0.75)
		_gauge(panel, "vario", Vector3(0.0, -0.13, 0.0), r * 0.7)
	else:
		_gauge(panel, "speed", Vector3(-dx, 0.075, 0.0), r)
		_attitude(panel, Vector3(0.0, 0.075, 0.0), r)
		_gauge(panel, "alt", Vector3(dx, 0.075, 0.0), r)
		_gauge(panel, "vario", Vector3(-dx, -0.07, 0.0), r * 0.9)
		_gauge(panel, "heading", Vector3(0.0, -0.07, 0.0), r * 0.9)
		_gauge(panel, "rpm", Vector3(dx, -0.07, 0.0), r * 0.9)
		if pw > 0.72:
			_gauge(panel, "ammo", Vector3(-dx - 0.11, 0.0, 0.0), r * 0.7)
			_gauge(panel, "fuel", Vector3(dx + 0.11, 0.0, 0.0), r * 0.7)


func _bezel(parent: Node3D, pos: Vector3, r: float) -> void:
	var bezel := _mesh(MeshFactory.cylinder(r * 1.12, r * 1.12, 0.012, 24), _mat(Color(0.09, 0.09, 0.1), 0.35, 0.6), pos + Vector3(0.0, 0.0, 0.003), parent)
	bezel.rotation = Vector3(PI * 0.5, 0.0, 0.0)


func _gauge(parent: Node3D, kind: String, pos: Vector3, r: float) -> void:
	_bezel(parent, pos, r)
	var face := _mesh(MeshFactory.quad(Vector2(r * 2.0, r * 2.0)), _face_material(kind), pos + Vector3(0.0, 0.0, 0.0105), parent)
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hands: Array[Node3D] = [_needle(parent, pos, r * 0.82, 0.0045, Color(0.95, 0.95, 0.88))]
	if kind == "alt":
		hands.append(_needle(parent, pos, r * 0.5, 0.007, Color(0.95, 0.95, 0.88)))
	_needles[kind] = hands


func _needle(parent: Node3D, pos: Vector3, length: float, width: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos + Vector3(0.0, 0.0, 0.0135)
	parent.add_child(pivot)
	var n := _mesh(MeshFactory.box(Vector3(width, length, 0.002)), MeshFactory.glow(color, 0.9), Vector3(0.0, length * 0.38, 0.0), pivot)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh(MeshFactory.cylinder(width * 1.4, width * 1.4, 0.003, 10), MeshFactory.mat(Color(0.05, 0.05, 0.05), 0.5), Vector3(0.0, 0.0, 0.001), pivot).rotation = Vector3(PI * 0.5, 0.0, 0.0)
	return pivot


func _attitude(parent: Node3D, pos: Vector3, r: float) -> void:
	_bezel(parent, pos, r)
	_horizon = Node3D.new()
	_horizon.position = pos + Vector3(0.0, 0.0, 0.0102)
	parent.add_child(_horizon)
	var disc := _mesh(MeshFactory.quad(Vector2(r * 2.0, r * 2.0)), _face_material("horizon"), Vector3.ZERO, _horizon)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := _mesh(MeshFactory.quad(Vector2(r * 2.0, r * 2.0)), _face_material("attitude_ring"), pos + Vector3(0.0, 0.0, 0.0125), parent)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _mfd(parent: Node3D, pos: Vector3) -> void:
	var size := Vector2(0.135, 0.115)
	_box(Vector3(size.x + 0.025, size.y + 0.025, 0.012), pos + Vector3(0.0, 0.0, 0.004), _mat(Color(0.07, 0.07, 0.075), 0.45, 0.3), parent)
	var screen := _mesh(MeshFactory.quad(size), _face_material("mfd"), pos + Vector3(0.0, 0.0, 0.0105), parent)
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sweep := Node3D.new()
	sweep.position = pos + Vector3(0.0, -size.y * 0.42, 0.0115)
	parent.add_child(sweep)
	var line := _mesh(MeshFactory.box(Vector3(0.0018, size.y * 0.78, 0.001)), MeshFactory.glow(Color(0.35, 1.0, 0.45), 2.2), Vector3(0.0, size.y * 0.39, 0.0), sweep)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sweeps.append(sweep)
	for i in 5:
		var b := _mesh(MeshFactory.box(Vector3(0.012, 0.008, 0.008)), _mat(Color(0.2, 0.2, 0.21), 0.5), pos + Vector3(-size.x * 0.4 + float(i) * size.x * 0.2, -size.y * 0.5 - 0.022, 0.006), parent)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Коллиматорный прицел (поршневые) или индикатор на лобовом стекле (реактивные).
func _build_sight(top_y: float, panel_z: float) -> void:
	var dark := _mat(Color(0.07, 0.07, 0.08), 0.5, 0.4)
	if _jet:
		for side: float in [-1.0, 1.0]:
			_box(Vector3(0.012, 0.15, 0.012), Vector3(side * 0.085, top_y + 0.1, panel_z + 0.1), dark)
		_box(Vector3(0.19, 0.04, 0.1), Vector3(0.0, top_y + 0.045, panel_z + 0.1), dark)
		var glass := _mesh(MeshFactory.quad(Vector2(0.17, 0.15)), _face_material("hud"), Vector3(0.0, top_y + 0.14, panel_z + 0.12))
		glass.rotation = Vector3(deg_to_rad(-12.0), 0.0, 0.0)
		glass.set_meta("prio", 2)
	else:
		_box(Vector3(0.06, 0.07, 0.11), Vector3(0.0, top_y + 0.06, panel_z + 0.08), dark)
		_mesh(MeshFactory.cylinder(0.022, 0.022, 0.06, 12), _mat(Color(0.05, 0.05, 0.05), 0.3, 0.5), Vector3(0.0, top_y + 0.1, panel_z + 0.06))
		var plate := _mesh(MeshFactory.quad(Vector2(0.1, 0.085)), _face_material("reflector"), Vector3(0.0, top_y + 0.15, panel_z + 0.09))
		plate.rotation = Vector3(deg_to_rad(-30.0), 0.0, 0.0)
		plate.set_meta("prio", 2)


# --- Фонарь -------------------------------------------------------------------------------------------------
func _build_canopy_frames(c: Dictionary, cg: float, _frame_mat: Material) -> void:
	var stations: Array = c["stations"]
	var n := float(c.get("n", 2.2))
	var frames: Array = [float((stations[1] as Array)[0])]
	frames.append_array(c.get("frames", []))
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.025, 0.027, 0.03)
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	for fs: Variant in frames:
		var prof := AircraftBuilder._profile_at(stations, float(fs))
		if prof.is_empty():
			continue
		var z := float(fs) - cg
		# Рамы вплотную у лица (и за спиной) не строятся — они закрыли бы обзор.
		if z > eye.z - 0.32 and z < eye.z + 0.2:
			continue
		var pts: Array[Vector3] = []
		var segs := 12
		for k in segs + 1:
			var ang := lerpf(-PI * 0.5, PI * 0.5, float(k) / float(segs))
			var sx := sin(ang)
			var cy := cos(ang)
			var x := prof[1] * signf(sx) * pow(absf(sx), 2.0 / n) * 0.95
			var y := prof[4] + prof[2] * pow(absf(cy), 2.0 / n) * 0.95
			pts.append(Vector3(x, y, z))
		for k in segs:
			var a := pts[k]
			var b := pts[k + 1]
			var d := b - a
			var bar := _mesh(MeshFactory.box(Vector3(d.length() + 0.01, 0.02, 0.03)), dark, (a + b) * 0.5)
			bar.rotation = Vector3(0.0, 0.0, atan2(d.y, d.x))


# --- Анимация -----------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not visible or aircraft == null or not is_instance_valid(aircraft):
		return
	_time += delta
	var a := aircraft
	var alt := a.global_position.y
	_set_hand("speed", 0, clampf(a.speed / maxf(a.max_speed * 1.3, 1.0), 0.0, 1.0))
	_set_hand("rpm", 0, clampf(a.throttle, 0.0, 1.0))
	_set_hand("vario", 0, clampf(0.5 + a.velocity.y / 80.0, 0.0, 1.0))
	_set_angle("alt", 0, fposmod(alt, 1000.0) / 1000.0 * TAU)
	_set_angle("alt", 1, fposmod(alt, 10000.0) / 10000.0 * TAU)
	_set_angle("heading", 0, -GameDB.yaw_of(a.get_forward()))
	var guns := a.weapon_of_type("guns")
	if not guns.is_empty():
		var w: Weapon = guns["weapon"]
		_set_hand("ammo", 0, float(w.magazine) / maxf(float(w.magazine_size), 1.0))
	_set_hand("fuel", 0, clampf(a.health / maxf(a.max_health, 1.0), 0.0, 1.0) * 0.7 + 0.25)
	if _horizon != null:
		var b := a.global_basis
		var bank := atan2(b.x.y, b.y.y)
		_horizon.rotation = Vector3(0.0, 0.0, -bank)
	for s in _sweeps:
		s.rotation = Vector3(0.0, 0.0, sin(_time * 1.6) * 1.0)
	if _stick != null:
		_stick.rotation = Vector3(a.stick_input.x * 0.28, 0.0, -a.stick_input.y * 0.28)
	if _throttle != null:
		_throttle.rotation = Vector3(lerpf(0.45, -0.45, clampf(a.throttle, 0.0, 1.0)), 0.0, 0.0)


func _set_hand(kind: String, idx: int, v: float) -> void:
	_set_angle(kind, idx, deg_to_rad(lerpf(-ARC, ARC, v)))


func _set_angle(kind: String, idx: int, ang: float) -> void:
	var hands: Array = _needles.get(kind, [])
	if idx < hands.size():
		(hands[idx] as Node3D).rotation = Vector3(0.0, 0.0, -ang)


# --- Построение ---------------------------------------------------------------------------------------------
func _mat(color: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := MeshFactory.mat(color, rough, metal).duplicate() as StandardMaterial3D
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _mesh(mesh: Mesh, material: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func _box(size: Vector3, pos: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	return _mesh(MeshFactory.box(size), material, pos, parent)


static func _face_material(kind: String) -> StandardMaterial3D:
	var key := "mat_" + kind
	if _textures.has(key):
		return _textures[key]
	var tex := _face_texture(kind)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.3
	m.roughness = 0.35
	m.emission_enabled = true
	m.emission_texture = tex
	m.emission_energy_multiplier = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	match kind:
		"mfd":
			m.emission_energy_multiplier = 1.4
			m.roughness = 0.15
		"hud", "reflector":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.emission_energy_multiplier = 1.0
	_textures[key] = m
	return m


## Текстуры шкал, авиагоризонта, экранов и прицельных марок (Image, генерируются один раз).
static func _face_texture(kind: String) -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(size, size) * 0.5
	var r := size * 0.49
	var ink := Color(0.92, 0.92, 0.86)
	match kind:
		"horizon":
			for y in size:
				for x in size:
					var p := Vector2(x, y)
					if p.distance_to(c) > r:
						continue
					var col := Color(0.18, 0.42, 0.78) if y < size / 2 else Color(0.42, 0.27, 0.13)
					if absi(y - size / 2) <= 2:
						col = Color.WHITE
					img.set_pixel(x, y, col)
			for i: int in [-2, -1, 1, 2]:
				_line(img, Vector2(c.x - 26 + absi(i) * 6, c.y - i * 26), Vector2(c.x + 26 - absi(i) * 6, c.y - i * 26), Color(1, 1, 1, 0.9), 2)
		"attitude_ring":
			_ring(img, c, r, r * 0.88, Color(0.06, 0.06, 0.07))
			for i in 9:
				var a := deg_to_rad(-60.0 + i * 15.0)
				var d := Vector2(sin(a), -cos(a))
				_line(img, c + d * r * 0.78, c + d * r * 0.88, ink, 3)
			_line(img, Vector2(c.x - 70, c.y), Vector2(c.x - 24, c.y), Color(1.0, 0.62, 0.1), 6)
			_line(img, Vector2(c.x + 24, c.y), Vector2(c.x + 70, c.y), Color(1.0, 0.62, 0.1), 6)
			_disc(img, c, 6, Color(1.0, 0.62, 0.1))
		"mfd":
			for y in size:
				for x in size:
					img.set_pixel(x, y, Color(0.01, 0.05, 0.03))
			var g := Color(0.2, 0.85, 0.35, 0.9)
			var base := Vector2(c.x, size * 0.92)
			for k in 4:
				_arc(img, base, size * (0.2 + k * 0.2), -60.0, 60.0, Color(g, 0.55), 2)
			for a in [-60.0, -30.0, 0.0, 30.0, 60.0]:
				var d := Vector2(sin(deg_to_rad(a)), -cos(deg_to_rad(a)))
				_line(img, base, base + d * size * 0.8, Color(g, 0.35), 1)
			_line(img, Vector2(12, 12), Vector2(70, 12), g, 3)
			_line(img, Vector2(size - 70, 12), Vector2(size - 12, 12), g, 3)
			_disc(img, Vector2(c.x + 30, size * 0.35), 5, Color(1.0, 0.35, 0.25))
			_disc(img, Vector2(c.x - 50, size * 0.5), 4, Color(0.3, 1.0, 0.45))
		"hud":
			var g := Color(0.3, 1.0, 0.45, 0.9)
			_arc(img, c, size * 0.2, 0.0, 360.0, g, 3)
			_disc(img, c, 4, g)
			for i: int in [-2, -1, 1, 2]:
				var y: float = c.y - float(i) * 44.0
				_line(img, Vector2(c.x - 90, y), Vector2(c.x - 40, y), Color(g, 0.7), 2)
				_line(img, Vector2(c.x + 40, y), Vector2(c.x + 90, y), Color(g, 0.7), 2)
			_line(img, Vector2(20, c.y), Vector2(70, c.y), g, 2)
			_line(img, Vector2(size - 70, c.y), Vector2(size - 20, c.y), g, 2)
		"reflector":
			var o := Color(1.0, 0.55, 0.15, 0.95)
			_arc(img, c, size * 0.3, 0.0, 360.0, o, 3)
			_disc(img, c, 5, o)
			_line(img, Vector2(c.x, c.y - size * 0.42), Vector2(c.x, c.y - size * 0.12), o, 2)
			_line(img, Vector2(c.x - size * 0.42, c.y), Vector2(c.x - size * 0.12, c.y), o, 2)
			_line(img, Vector2(c.x + size * 0.12, c.y), Vector2(c.x + size * 0.42, c.y), o, 2)
		_:
			_disc(img, c, int(r), Color(0.035, 0.035, 0.04))
			_ring(img, c, r, r * 0.95, Color(0.3, 0.3, 0.32))
			var full := kind == "alt" or kind == "heading"
			var from := 0.0 if full else -ARC
			var to := 360.0 if full else ARC
			match kind:
				"speed":
					_arc(img, c, r * 0.8, -ARC + 40.0, ARC * 0.5, Color(0.2, 0.75, 0.3), 6)
					_arc(img, c, r * 0.8, ARC * 0.85, ARC, Color(0.9, 0.2, 0.15), 6)
				"rpm":
					_arc(img, c, r * 0.8, 20.0, ARC * 0.8, Color(0.2, 0.75, 0.3), 6)
					_arc(img, c, r * 0.8, ARC * 0.85, ARC, Color(0.9, 0.2, 0.15), 6)
				"ammo", "fuel":
					_arc(img, c, r * 0.8, -ARC, -ARC * 0.7, Color(0.9, 0.2, 0.15), 6)
			var majors := 12 if full else 10
			for i in majors * 5 + (0 if full else 1):
				var t := float(i) / float(majors * 5)
				var a := deg_to_rad(lerpf(from, to, t))
				var d := Vector2(sin(a), -cos(a))
				var major := i % 5 == 0
				_line(img, c + d * r * (0.72 if major else 0.82), c + d * r * 0.9, ink, 4 if major else 2)
			if kind == "heading":
				for i in 4:
					var a := deg_to_rad(i * 90.0)
					var d := Vector2(sin(a), -cos(a))
					_disc(img, c + d * r * 0.6, 7 if i == 0 else 5, Color(1.0, 0.55, 0.15) if i == 0 else ink)
			if kind == "vario":
				_line(img, c + Vector2(-r * 0.72, 0), c + Vector2(-r * 0.5, 0), Color(1.0, 0.55, 0.15), 4)
			_disc(img, c, 5, Color(0.3, 0.3, 0.3))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_textures[kind] = tex
	return tex


static func _disc(img: Image, c: Vector2, r: int, col: Color) -> void:
	for y in range(int(c.y) - r, int(c.y) + r + 1):
		for x in range(int(c.x) - r, int(c.x) + r + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and Vector2(x, y).distance_to(c) <= r:
				img.set_pixel(x, y, col)


static func _ring(img: Image, c: Vector2, r_out: float, r_in: float, col: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var d := Vector2(x, y).distance_to(c)
			if d <= r_out and d >= r_in:
				img.set_pixel(x, y, col)


static func _line(img: Image, a: Vector2, b: Vector2, col: Color, width: int) -> void:
	var steps := int(maxf(a.distance_to(b), 1.0))
	var half := width / 2
	for i in steps + 1:
		var p := a.lerp(b, float(i) / float(steps))
		for oy in range(-half, half + 1):
			for ox in range(-half, half + 1):
				var x := int(p.x) + ox
				var y := int(p.y) + oy
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
					img.set_pixel(x, y, col)


static func _arc(img: Image, c: Vector2, r: float, from_deg: float, to_deg: float, col: Color, width: int) -> void:
	var steps := int(absf(to_deg - from_deg) * r / 40.0) + 8
	var prev := Vector2.ZERO
	for i in steps + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(i) / float(steps)))
		var p := c + Vector2(sin(a), -cos(a)) * r
		if i > 0:
			_line(img, prev, p, col, width)
		prev = p


## Кабина рисуется поверх внешней модели (её фюзеляж цельный и закрыл бы приборы): материалы без
## теста глубины в прозрачном проходе, порядок — по удалённости от глаз, ручка и РУД — поверх доски,
## стёкла прицела — последними.
func _finalize(node: Node, prio: int) -> void:
	for child in node.get_children():
		var p := prio
		if child == _stick or child == _throttle:
			p = 1
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var own := int(mi.get_meta("prio", p))
			var m := mi.material_override as BaseMaterial3D
			if m != null:
				var key := "%d|%d" % [m.get_instance_id(), own]
				var d: BaseMaterial3D = _overlay_mats.get(key)
				if d == null:
					d = m.duplicate() as BaseMaterial3D
					d.no_depth_test = true
					if d.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED or d.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
						d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					d.render_priority = own
					_overlay_mats[key] = d
				mi.material_override = d
		_finalize(child, p)
