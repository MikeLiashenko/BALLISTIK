class_name GroundModels
extends RefCounted
## Процедурные модели наземной ПВО (размеры по реальным образцам, метры; -Z — вперёд, начало координат —
## на земле под центром машины). Каждая модель возвращает узлы для механики:
##  * "turret" (азимут), "gun_pivot" (угол места орудий), "muzzles" — дульные срезы;
##  * "launcher" (угол места пусковой), "launch_points" и "missiles" (видимые ракеты);
##  * "radars" — вращающиеся антенны [{"node", "speed"}]; "aabb" — габариты.

const PAINT := {
	"gepard": {"pattern": 1, "a": Color(0.235, 0.265, 0.185), "b": Color(0.3, 0.235, 0.16), "c": Color(0.085, 0.085, 0.08), "scale": 2.3, "wear": 0.45, "dust": 0.4, "dust_height": 0.9, "panel_strength": 0.15},
	"shilka": {"pattern": 0, "a": Color(0.27, 0.31, 0.19), "scale": 1.0, "wear": 0.55, "dust": 0.45, "dust_height": 0.9, "panel_strength": 0.2},
	"m163": {"pattern": 1, "a": Color(0.25, 0.28, 0.19), "b": Color(0.31, 0.25, 0.17), "c": Color(0.09, 0.09, 0.085), "scale": 2.6, "wear": 0.4, "dust": 0.45, "dust_height": 0.85, "panel_strength": 0.15},
	"tunguska": {"pattern": 1, "a": Color(0.28, 0.31, 0.2), "b": Color(0.2, 0.22, 0.15), "c": Color(0.36, 0.33, 0.24), "scale": 1.6, "wear": 0.45, "dust": 0.4, "dust_height": 0.9, "panel_strength": 0.15},
	"pantsir": {"pattern": 1, "a": Color(0.3, 0.33, 0.22), "b": Color(0.39, 0.35, 0.25), "c": Color(0.11, 0.11, 0.1), "scale": 1.3, "wear": 0.4, "dust": 0.35, "dust_height": 1.1, "panel_strength": 0.15},
	"patriot": {"pattern": 1, "a": Color(0.25, 0.28, 0.19), "b": Color(0.31, 0.25, 0.17), "c": Color(0.09, 0.09, 0.085), "scale": 1.5, "wear": 0.4, "dust": 0.35, "dust_height": 1.1, "panel_strength": 0.15},
	"buk": {"pattern": 1, "a": Color(0.29, 0.32, 0.21), "b": Color(0.42, 0.38, 0.27), "c": Color(0.17, 0.15, 0.11), "scale": 1.2, "wear": 0.45, "dust": 0.4, "dust_height": 0.9, "panel_strength": 0.15},
	"s300": {"pattern": 0, "a": Color(0.27, 0.31, 0.2), "scale": 1.0, "wear": 0.5, "dust": 0.35, "dust_height": 1.2, "panel_strength": 0.18},
	"tor": {"pattern": 1, "a": Color(0.3, 0.33, 0.22), "b": Color(0.45, 0.41, 0.3), "c": Color(0.16, 0.14, 0.1), "scale": 1.3, "wear": 0.45, "dust": 0.4, "dust_height": 0.9, "panel_strength": 0.15},
	"avenger": {"pattern": 1, "a": Color(0.25, 0.28, 0.19), "b": Color(0.31, 0.25, 0.17), "c": Color(0.09, 0.09, 0.085), "scale": 2.4, "wear": 0.4, "dust": 0.4, "dust_height": 0.8, "panel_strength": 0.12},
	"wirbelwind": {"pattern": 3, "a": Color(0.66, 0.57, 0.38), "b": Color(0.29, 0.31, 0.19), "c": Color(0.38, 0.22, 0.14), "scale": 1.6, "wear": 0.55, "dust": 0.45, "dust_height": 0.8, "panel_strength": 0.2},
	"m16": {"pattern": 0, "a": Color(0.29, 0.29, 0.19), "scale": 1.0, "wear": 0.55, "dust": 0.45, "dust_height": 0.8, "panel_strength": 0.15, "rivets": 0.4},
	"zsu37": {"pattern": 0, "a": Color(0.27, 0.31, 0.19), "scale": 1.0, "wear": 0.6, "dust": 0.45, "dust_height": 0.8, "panel_strength": 0.2},
	"flak88": {"pattern": 1, "a": Color(0.66, 0.57, 0.38), "b": Color(0.33, 0.34, 0.22), "scale": 1.4, "wear": 0.5, "dust": 0.3, "dust_height": 0.6, "panel_strength": 0.1},
	"k52": {"pattern": 0, "a": Color(0.27, 0.31, 0.19), "scale": 1.0, "wear": 0.55, "dust": 0.3, "dust_height": 0.6, "panel_strength": 0.1},
}


static func has_model(type_id: String) -> bool:
	return PAINT.has(type_id)


static func build(type_id: String, team: int) -> Dictionary:
	var a := ModelAsm.new(type_id, team, PAINT[type_id])
	match type_id:
		"gepard":
			_gepard(a)
		"shilka":
			_shilka(a)
		"m163":
			_m163(a)
		"tunguska":
			_tunguska(a)
		"pantsir":
			_pantsir(a)
		"patriot":
			_patriot(a)
		"buk":
			_buk(a)
		"s300":
			_s300(a)
		"tor":
			_tor(a)
		"avenger":
			_avenger(a)
		"wirbelwind":
			_wirbelwind(a)
		"m16":
			_m16(a)
		"zsu37":
			_zsu37(a)
		"flak88":
			_flak88(a)
		"k52":
			_k52(a)
	return a.finish()


# --- Общие узлы ------------------------------------------------------------------------------------------
## Гусеничная ходовая часть с обеих сторон: катки (одинарные или сдвоенные), ленивец, ведущее колесо,
## поддерживающие ролики и лента по их выпуклой оболочке.
static func _running_gear(k: VehicleKit, cfg: Dictionary) -> void:
	var tx: float = cfg["track_x"]
	var tw: float = cfg["track_w"]
	var wr: float = cfg["wheel_r"]
	var thick := float(cfg.get("track_t", 0.07))
	var wy := wr + thick
	var wheels: Array = cfg["wheels"]
	var dual := bool(cfg.get("dual", true))
	var idler: Vector3 = cfg["idler"]
	var spr: Vector3 = cfg["sprocket"]
	var rollers: Array = cfg.get("rollers", [])
	var ry := float(cfg.get("roller_y", 1.0))
	var rr := float(cfg.get("roller_r", 0.09))
	for side: float in [-1.0, 1.0]:
		var x := side * tx
		var circles: Array = []
		for z: float in wheels:
			if dual:
				VehicleKit.road_wheel(k, Vector3(x - side * tw * 0.24, wy, z), wr, tw * 0.42, side, int(cfg.get("spokes", 0)))
				VehicleKit.road_wheel(k, Vector3(x + side * tw * 0.24, wy, z), wr, tw * 0.42, side, int(cfg.get("spokes", 0)))
			else:
				VehicleKit.road_wheel(k, Vector3(x, wy, z), wr, tw * 0.9, side, int(cfg.get("spokes", 0)))
			circles.append(Vector3(z, wy, wr))
		VehicleKit.road_wheel(k, Vector3(x, idler.y, idler.x), idler.z, tw * 0.85, side)
		circles.append(Vector3(idler.x, idler.y, idler.z))
		VehicleKit.sprocket(k, Vector3(x, spr.y, spr.x), spr.z, tw * 0.9, side, int(cfg.get("teeth", 13)))
		circles.append(Vector3(spr.x, spr.y, spr.z * 0.96))
		for z: float in rollers:
			VehicleKit.roller(k, Vector3(x - side * tw * 0.1, ry, z), rr, tw * 0.55, side)
			circles.append(Vector3(z, ry, rr))
		VehicleKit.track_belt(k, x, tw, circles, thick)


## Бортовой лючок/панель на наклонном борту (наклон taper): накладка в цвет корпуса с тёмным швом по периметру.
static func _side_panel(k: VehicleKit, x: float, y: float, z: float, h: float, l: float, side: float, taper: float) -> void:
	var lean := atan(taper)
	var old_b := k.body.xform
	k.body.xform = old_b * Transform3D(Basis(Vector3(0.0, 0.0, 1.0), side * lean), Vector3(x, y, z))
	k.body.add_box(Vector3.ZERO, Vector3(0.025, h, l))
	k.body.xform = old_b
	var old_d := k.dark.xform
	k.dark.xform = old_d * Transform3D(Basis(Vector3(0.0, 0.0, 1.0), side * lean), Vector3(x + side * 0.014, y, z))
	var hh := h * 0.5
	var hl := l * 0.5
	k.dark.add_tube(PackedVector3Array([Vector3(0.0, -hh, -hl), Vector3(0.0, hh, -hl), Vector3(0.0, hh, hl), Vector3(0.0, -hh, hl), Vector3(0.0, -hh, -hl)]), 0.012, 4)
	k.dark.xform = old_d
	VehicleKit.box(k.metal, Vector3(x + side * 0.03, y, z - hl * 0.7), Vector3(0.03, 0.05, 0.08))


## Колёсная база: мосты по осям zs, полуколея half_track, колёса радиуса r и ширины w, мосты и редукторы.
static func _axles(k: VehicleKit, zs: Array, half_track: float, r: float, w: float, rim_k: float = 0.55) -> void:
	for z: float in zs:
		for s: float in [-1.0, 1.0]:
			VehicleKit.wheel(k, Vector3(s * half_track, r, z), r, w, s, rim_k)
		VehicleKit.cyl(k.dark, Vector3(-half_track + w * 0.45, r, z), Vector3(half_track - w * 0.45, r, z), 0.09, 8)
		k.dark.add_blob(Vector3(0.0, r, z), Vector3(0.24, 0.2, 0.22), 1, 0.0, 3, Color.WHITE, Color.WHITE)


## Крыло над колесом: дуга радиуса r (внутренний) вокруг центра колеса (z, y), ширина w, угол от a0 до a1.
static func _fender(kit: MeshKit, x: float, z: float, y: float, r: float, w: float, a0: float = 20.0, a1: float = 160.0, thickness: float = 0.04) -> void:
	var prof := PackedVector2Array()
	var n := 10
	for i in n + 1:
		var a := deg_to_rad(lerpf(a0, a1, float(i) / float(n)))
		prof.append(Vector2(z + cos(a) * (r + thickness), y + sin(a) * (r + thickness)))
	for i in range(n, -1, -1):
		var a := deg_to_rad(lerpf(a0, a1, float(i) / float(n)))
		prof.append(Vector2(z + cos(a) * r, y + sin(a) * r))
	kit.add_prism(prof, w * 0.5, 0.0, 0.0, 30.0, x)


## Окно (стекло) — четырёхугольник по точкам в порядке обхода, чуть вынесенный наружу по нормали.
static func _window(k: VehicleKit, pts: Array, normal: Vector3, frame: bool = true) -> void:
	var n := normal.normalized()
	var q := PackedVector3Array()
	var c := Vector3.ZERO
	for p: Vector3 in pts:
		c += p
	c /= float(pts.size())
	for p: Vector3 in pts:
		q.append(p + n * 0.012)
	k.glass.add_polygon(q, n)
	if frame:
		var ring := PackedVector3Array()
		for p: Vector3 in pts:
			ring.append(p + n * 0.02 + (p - c).normalized() * 0.02)
		ring.append(ring[0])
		k.dark.add_tube(ring, 0.018, 4)


## Кабина грузовика: боковой профиль (z, y), полуширина, сужение кверху; окна по бокам и лобовое стекло.
static func _cab(k: VehicleKit, profile: PackedVector2Array, hw: float, taper: float, windshield: Array, side_window: Rect2, x_offset: float = 0.0) -> void:
	var old_b := k.body.xform
	var old_g := k.glass.xform
	var old_d := k.dark.xform
	var shift := Transform3D(Basis(), Vector3(x_offset, 0.0, 0.0))
	k.body.xform = old_b * shift
	k.glass.xform = old_g * shift
	k.dark.xform = old_d * shift
	_cab_local(k, profile, hw, taper, windshield, side_window)
	k.body.xform = old_b
	k.glass.xform = old_g
	k.dark.xform = old_d


static func _cab_local(k: VehicleKit, profile: PackedVector2Array, hw: float, taper: float, windshield: Array, side_window: Rect2) -> void:
	k.body.add_prism(profile, hw, taper, 0.0, 12.0)
	# Лобовое стекло: две половины по наклонной плоскости windshield = [z0, y0, z1, y1].
	var z0: float = windshield[0]
	var y0: float = windshield[1]
	var z1: float = windshield[2]
	var y1: float = windshield[3]
	var n := Vector3(0.0, z1 - z0, -(y1 - y0)).normalized()
	if n.z > 0.0:
		n = -n
	var hw0 := hw - taper * y0 - 0.12
	var hw1 := hw - taper * y1 - 0.12
	for s: float in [-1.0, 1.0]:
		var xa := s * 0.05
		_window(k, [Vector3(xa, y0 + 0.06, z0 + 0.01), Vector3(s * hw0, y0 + 0.06, z0 + 0.01), Vector3(s * hw1, y1 - 0.06, z1 - 0.01), Vector3(xa, y1 - 0.06, z1 - 0.01)], n)
	# Боковые окна дверей: side_window — прямоугольник (z, y, длина, высота).
	for s: float in [-1.0, 1.0]:
		var zc := side_window.position.x
		var yc := side_window.position.y
		var zl := side_window.size.x
		var yl := side_window.size.y
		var xb := s * (hw - taper * yc)
		var xt := s * (hw - taper * (yc + yl))
		_window(k, [Vector3(xb, yc, zc), Vector3(xb, yc, zc + zl), Vector3(xt, yc + yl, zc + zl), Vector3(xt, yc + yl, zc)], Vector3(s, taper, 0.0))


## Кривой отражатель антенны (параболический цилиндр) шириной w и высотой h, вогнутостью вперёд (-Z).
static func _reflector(kit: MeshKit, center: Vector3, w: float, h: float, depth: float, cols: int = 10, rows: int = 3) -> void:
	var grid: Array = []
	for r in rows + 1:
		var row := PackedVector3Array()
		var y := center.y + (float(r) / float(rows) - 0.5) * h
		for c in cols + 1:
			var t := float(c) / float(cols) * 2.0 - 1.0
			row.append(Vector3(center.x + t * w * 0.5, y, center.z + depth * (1.0 - t * t)))
		grid.append(row)
	kit.add_patch(grid, false, true)


# --- Flakpanzer Gepard (ФРГ) ------------------------------------------------------------------------------
## Шасси Leopard 1: 7 сдвоенных катков, 4 поддерживающих ролика, ведущее колесо сзади; борта прикрыты
## экранами. Башня с двумя 35-мм автоматами Oerlikon KDA по бортам (снаружи), РЛС сопровождения на лобовой
## части и складывающаяся РЛС обнаружения на корме башни.
static func _gepard(a: ModelAsm) -> void:
	var root := a.root
	a.mesh(root, "Hull", func(k: VehicleKit) -> void:
		_running_gear(k, {
			"track_x": 1.33, "track_w": 0.55, "wheel_r": 0.34, "track_t": 0.07,
			"wheels": [-2.45, -1.62, -0.79, 0.04, 0.87, 1.7, 2.53], "dual": true, "spokes": 6,
			"idler": Vector3(-3.3, 0.62, 0.3), "sprocket": Vector3(3.3, 0.66, 0.33), "teeth": 11,
			"rollers": [-1.95, -0.6, 0.75, 2.1], "roller_y": 1.0, "roller_r": 0.085,
		})
		k.part(VehicleKit.P_HULL)
		# Нижняя часть корпуса между гусеницами и верхняя — над гусеницами (надгусеничные полки).
		k.body.add_prism(PackedVector2Array([Vector2(-2.9, 0.45), Vector2(3.05, 0.45), Vector2(3.52, 0.95), Vector2(3.52, 1.21), Vector2(-3.4, 1.21), Vector2(-3.64, 1.08)]), 1.02)
		k.body.add_prism(PackedVector2Array([Vector2(-3.4, 1.2), Vector2(3.52, 1.2), Vector2(3.52, 1.6), Vector2(3.36, 1.72), Vector2(-2.0, 1.72), Vector2(-3.66, 1.08)]), 1.62)
		# Бортовые экраны с резиновой кромкой.
		for s: float in [-1.0, 1.0]:
			k.body.add_prism(PackedVector2Array([Vector2(-3.2, 0.8), Vector2(3.0, 0.8), Vector2(3.1, 1.22), Vector2(-3.45, 1.22)]), 0.018, 0.0, 0.0, 15.0, s * 1.655)
			VehicleKit.box(k.dark, Vector3(s * 1.655, 0.76, -0.1), Vector3(0.03, 0.08, 6.2))
			for i in 6:
				VehicleKit.box(k.metal, Vector3(s * 1.68, 1.0, -2.9 + float(i) * 1.15), Vector3(0.02, 0.05, 0.05))
		# Фары с защитными дугами, буксирные крюки, люк механика-водителя.
		for s: float in [-1.0, 1.0]:
			VehicleKit.headlight(k, Vector3(s * 1.28, 1.52, -2.98), Vector3(0.0, 0.15, -1.0), 0.09)
			k.metal.add_tube(PackedVector3Array([Vector3(s * 1.12, 1.44, -3.02), Vector3(s * 1.14, 1.6, -3.14), Vector3(s * 1.42, 1.6, -3.14), Vector3(s * 1.44, 1.44, -3.02)]), 0.018, 5)
			VehicleKit.box(k.dark, Vector3(s * 0.75, 0.98, -3.6), Vector3(0.14, 0.2, 0.18))
			VehicleKit.box(k.dark, Vector3(s * 0.75, 1.1, 3.54), Vector3(0.14, 0.2, 0.12))
		VehicleKit.hatch(k, Vector3(0.62, 1.72, -1.55), 0.34)
		for i in 3:
			VehicleKit.periscope(k, Vector3(0.62 + (float(i) - 1.0) * 0.22, 1.72, -1.95), Vector3(0.0, 0.0, -1.0), 0.14)
		# Моторное отделение: решётки, выхлоп, ящики ЗИП, трос.
		VehicleKit.grille(k, Vector3(-0.62, 1.73, 2.3), Vector2(0.9, 1.6), 9)
		VehicleKit.grille(k, Vector3(0.62, 1.73, 2.3), Vector2(0.9, 1.6), 9)
		VehicleKit.grille(k, Vector3(0.0, 1.73, 1.1), Vector2(2.2, 0.55), 12, false)
		for s: float in [-1.0, 1.0]:
			VehicleKit.box(k.dark, Vector3(s * 1.2, 1.62, 3.47), Vector3(0.6, 0.18, 0.08))
			VehicleKit.cbox(k.body, Vector3(s * 1.35, 1.82, 0.9), Vector3(0.5, 0.2, 1.6), 0.03)
			k.metal.add_tube(PackedVector3Array([Vector3(s * 1.63, 1.62, -1.2), Vector3(s * 1.64, 1.64, 0.2), Vector3(s * 1.63, 1.58, 1.8), Vector3(s * 1.6, 1.45, 3.1)]), 0.025, 6)
		VehicleKit.box(k.dark, Vector3(0.0, 1.35, 3.53), Vector3(1.6, 0.25, 0.03))
		for s: float in [-1.0, 1.0]:
			k.lamp.add_disc(Vector3(s * 1.4, 1.45, 3.535), Vector3(0.0, 0.0, 1.0), 0.05, 8)
		# Опознавательная панель на крыше моторного отделения.
		k.part(VehicleKit.P_ID)
		k.body.add_box(Vector3(0.0, 1.735, 3.05), Vector3(0.9, 0.012, 0.42))
		k.part(VehicleKit.P_HULL)
	)
	var turret := a.node(root, "Turret", Vector3(0.0, 1.72, -0.35))
	a.out["turret"] = turret
	a.mesh(turret, "TurretBody", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_prism(PackedVector2Array([Vector2(-1.3, 0.02), Vector2(1.72, 0.02), Vector2(1.92, 0.24), Vector2(1.92, 0.86), Vector2(1.72, 1.02), Vector2(-0.85, 1.06), Vector2(-1.5, 0.62), Vector2(-1.52, 0.2)]), 1.14, 0.1, 0.0)
		k.dark.xform = Transform3D.IDENTITY
		k.dark.add_lathe(PackedVector2Array([Vector2(-0.06, 1.12), Vector2(0.03, 1.12)]), 32, false, false)
		# Командирская башенка с приборами, люк наводчика, прицелы.
		k.body.xform = Transform3D(Basis(), Vector3(-0.5, 1.04, 0.25))
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 0.42), Vector2(0.2, 0.4), Vector2(0.24, 0.3), Vector2(0.25, 0.0)]), 16, false, true, 40.0)
		k.body.xform = Transform3D.IDENTITY
		for i in 6:
			var ang := float(i) / 6.0 * TAU
			VehicleKit.periscope(k, Vector3(-0.5 + sin(ang) * 0.36, 1.18, 0.25 + cos(ang) * 0.36), Vector3(sin(ang), 0.0, cos(ang)), 0.12)
		VehicleKit.hatch(k, Vector3(0.55, 1.05, 0.35), 0.3)
		for s: float in [-1.0, 1.0]:
			VehicleKit.cbox(k.body, Vector3(s * 0.62, 1.2, -0.45), Vector3(0.32, 0.32, 0.5), 0.05)
			k.glass.add_box(Vector3(s * 0.62, 1.22, -0.71), Vector3(0.24, 0.16, 0.01))
		# Корзина и ящики на корме, дымовые гранатомёты, антенны.
		VehicleKit.cbox(k.body, Vector3(0.0, 0.52, 2.08), Vector3(2.0, 0.55, 0.3), 0.04)
		for s: float in [-1.0, 1.0]:
			VehicleKit.smoke_launchers(k, Vector3(s * 1.08, 0.72, 1.3), Vector3(s * 0.8, 0.0, -1.0), 4, 14.0)
			VehicleKit.whip(k, Vector3(s * 0.85, 1.0, 1.62), 2.4, Vector3(0.0, 0.0, 0.25))
			VehicleKit.box(k.dark, Vector3(s * 1.05, 0.9, -1.0), Vector3(0.1, 0.1, 0.6))
		# Опора РЛС обнаружения.
		VehicleKit.cyl(k.body, Vector3(0.0, 1.0, 1.45), Vector3(0.0, 1.32, 1.45), 0.22, 14)
		VehicleKit.box(k.body, Vector3(0.0, 1.05, 1.45), Vector3(0.7, 0.12, 0.5))
		k.part(VehicleKit.P_ID)
		k.body.add_box(Vector3(0.0, 1.07, -0.45), Vector3(0.5, 0.012, 0.3))
	)
	# РЛС обнаружения MPDR 12: вращающийся отражатель на опоре.
	var radar := a.node(turret, "SearchRadar", Vector3(0.0, 1.35, 1.45))
	a.out["radars"] = [{"node": radar, "speed": 3.2}]
	a.mesh(radar, "Antenna", func(k: VehicleKit) -> void:
		VehicleKit.cyl(k.dark, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.3, 0.0), 0.1, 10)
		VehicleKit.box(k.dark, Vector3(0.0, 0.34, 0.1), Vector3(0.18, 0.12, 0.5))
		k.part(VehicleKit.P_PLAIN)
		_reflector(k.body, Vector3(0.0, 0.62, 0.34), 1.95, 0.7, 0.2)
		k.dark.add_tube(PackedVector3Array([Vector3(-0.9, 0.3, 0.3), Vector3(0.0, 0.34, 0.1), Vector3(0.9, 0.3, 0.3)]), 0.025, 5)
		VehicleKit.box(k.dark, Vector3(0.0, 0.5, -0.12), Vector3(0.28, 0.14, 0.14))
		k.dark.add_tube(PackedVector3Array([Vector3(0.0, 0.4, 0.1), Vector3(0.0, 0.5, -0.1)]), 0.03, 5)
	)
	# Люлька орудий: два автомата KDA в бронированных кожухах по бортам башни и антенна РЛС сопровождения.
	var pivot := a.node(turret, "GunPivot", Vector3(0.0, 0.55, -0.55))
	a.out["gun_pivot"] = pivot
	a.mesh(pivot, "Guns", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		for s: float in [-1.0, 1.0]:
			k.body.add_prism(PackedVector2Array([Vector2(-1.32, -0.3), Vector2(0.95, -0.3), Vector2(1.05, -0.15), Vector2(1.05, 0.32), Vector2(-0.95, 0.34), Vector2(-1.38, 0.12)]), 0.23, 0.04, 0.0, 15.0, s * 1.42)
			VehicleKit.cyl(k.dark, Vector3(s * 1.1, 0.0, 0.0), Vector3(s * 1.2, 0.0, 0.0), 0.16, 12)
			VehicleKit.cyl(k.gun, Vector3(s * 1.42, 0.02, -1.3), Vector3(s * 1.42, 0.02, -1.78), 0.1, 14)
			VehicleKit.barrel(k, Vector3(s * 1.42, 0.02, -1.35), 3.15, 0.07, 0.048, "brake", 12)
			VehicleKit.box(k.dark, Vector3(s * 1.42, 0.02, -4.1), Vector3(0.16, 0.16, 0.14))
			# Лента подачи снарядов.
			k.dark.add_tube(PackedVector3Array([Vector3(s * 1.2, -0.1, 0.4), Vector3(s * 1.25, -0.18, 0.1), Vector3(s * 1.28, -0.12, -0.3)]), 0.06, 6)
		# РЛС сопровождения на лобовой части.
		VehicleKit.cbox(k.body, Vector3(0.0, 0.02, -1.02), Vector3(0.5, 0.5, 0.4), 0.06)
		k.part(VehicleKit.P_PLAIN)
		VehicleKit.dish(k.body, Vector3(0.0, 0.02, -1.22), Vector3(0.0, 0.0, -1.0), 0.52, 0.17, 0.035, 26)
		VehicleKit.dish_feed(k.dark, Vector3(0.0, 0.02, -1.22), Vector3(0.0, 0.0, -1.0), 0.52, 0.32)
	)
	var muzzles: Array[Node3D] = []
	for s: float in [-1.0, 1.0]:
		muzzles.append(a.node(pivot, "Muzzle", Vector3(s * 1.42, 0.02, -4.58)))
	a.out["muzzles"] = muzzles


# --- ЗСУ-23-4 «Шилка» (СССР) ------------------------------------------------------------------------------
## Шасси ГМ-575: 6 одинарных катков без поддерживающих роликов, ведущее колесо сзади; низкий корпус и
## широкая плоская башня с четырьмя 23-мм автоматами АЗП-23 (2×2) в лобовой установке и антенной РЛС
## «Тобол» на мачте за кормой башни.
static func _shilka(a: ModelAsm) -> void:
	var root := a.root
	a.mesh(root, "Hull", func(k: VehicleKit) -> void:
		_running_gear(k, {
			"track_x": 1.3, "track_w": 0.38, "wheel_r": 0.335, "track_t": 0.06,
			"wheels": [-2.1, -1.32, -0.54, 0.24, 1.02, 1.8], "dual": false, "spokes": 8,
			"idler": Vector3(-2.9, 0.56, 0.26), "sprocket": Vector3(2.78, 0.6, 0.29), "teeth": 12,
		})
		k.part(VehicleKit.P_HULL)
		k.body.add_prism(PackedVector2Array([Vector2(-2.5, 0.42), Vector2(2.6, 0.42), Vector2(3.0, 0.9), Vector2(3.0, 1.1), Vector2(-2.98, 1.1), Vector2(-3.15, 0.98)]), 1.1)
		k.body.add_prism(PackedVector2Array([Vector2(-2.98, 1.08), Vector2(3.0, 1.08), Vector2(3.02, 1.34), Vector2(2.86, 1.47), Vector2(-1.95, 1.5), Vector2(-3.17, 0.98)]), 1.55)
		for s: float in [-1.0, 1.0]:
			VehicleKit.cbox(k.body, Vector3(s * 1.38, 1.6, 1.2), Vector3(0.3, 0.2, 1.1), 0.02)
			VehicleKit.cbox(k.body, Vector3(s * 1.38, 1.6, -0.1), Vector3(0.3, 0.2, 0.7), 0.02)
			VehicleKit.headlight(k, Vector3(s * 1.2, 1.36, -2.55), Vector3(0.0, 0.1, -1.0), 0.08)
			k.metal.add_tube(PackedVector3Array([Vector3(s * 1.08, 1.3, -2.62), Vector3(s * 1.09, 1.44, -2.7), Vector3(s * 1.32, 1.44, -2.7), Vector3(s * 1.33, 1.3, -2.62)]), 0.016, 5)
			VehicleKit.box(k.dark, Vector3(s * 0.7, 0.92, -3.12), Vector3(0.12, 0.16, 0.14))
			VehicleKit.box(k.dark, Vector3(s * 0.7, 1.0, 3.02), Vector3(0.12, 0.16, 0.1))
			VehicleKit.box(k.dark, Vector3(s * 1.1, 1.25, 3.1), Vector3(0.06, 0.26, 0.24))
		# Бревно для самовытаскивания на корме.
		VehicleKit.cyl(k.cloth, Vector3(-1.45, 1.25, 3.13), Vector3(1.45, 1.25, 3.13), 0.11, 10)
		VehicleKit.hatch(k, Vector3(-0.65, 1.5, -1.62), 0.3)
		for i in 2:
			VehicleKit.periscope(k, Vector3(-0.8 + float(i) * 0.3, 1.5, -1.92), Vector3(0.0, 0.0, -1.0), 0.13)
		VehicleKit.grille(k, Vector3(0.0, 1.5, 2.3), Vector2(1.9, 0.8), 10)
		VehicleKit.box(k.dark, Vector3(1.56, 1.28, 2.3), Vector3(0.02, 0.18, 0.7))
		k.part(VehicleKit.P_ID)
		k.body.add_box(Vector3(0.0, 1.505, 2.86), Vector3(0.8, 0.01, 0.26))
		k.part(VehicleKit.P_HULL)
	)
	var turret := a.node(root, "Turret", Vector3(0.0, 1.5, 0.15))
	a.out["turret"] = turret
	a.mesh(turret, "TurretBody", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_prism(PackedVector2Array([Vector2(-1.45, 0.0), Vector2(1.6, 0.0), Vector2(1.66, 0.48), Vector2(1.44, 0.72), Vector2(-0.95, 0.74), Vector2(-1.62, 0.42)]), 1.4, 0.22, 0.0)
		k.dark.add_lathe(PackedVector2Array([Vector2(-0.05, 1.05), Vector2(0.02, 1.05)]), 28, false, false)
		VehicleKit.hatch(k, Vector3(-0.55, 0.74, 0.55), 0.3)
		VehicleKit.hatch(k, Vector3(0.55, 0.74, 0.5), 0.28)
		for i in 3:
			VehicleKit.periscope(k, Vector3(-0.55 + (float(i) - 1.0) * 0.25, 0.74, 0.2), Vector3(0.0, 0.0, -1.0), 0.12)
		VehicleKit.cbox(k.body, Vector3(0.38, 0.86, -0.35), Vector3(0.3, 0.26, 0.4), 0.04)
		k.glass.add_box(Vector3(0.38, 0.88, -0.56), Vector3(0.22, 0.12, 0.01))
		for s: float in [-1.0, 1.0]:
			for i in 2:
				_side_panel(k, s * 1.33, 0.33, -0.55 + float(i) * 0.95, 0.36, 0.62, s, 0.22)
		VehicleKit.box(k.body, Vector3(0.0, 0.9, 1.2), Vector3(0.36, 0.34, 0.36))
		VehicleKit.cyl(k.dark, Vector3(0.0, 1.05, 1.2), Vector3(0.0, 1.36, 1.2), 0.1, 10)
		VehicleKit.whip(k, Vector3(-1.05, 0.7, 1.25), 2.2, Vector3(0.0, 0.0, 0.2))
		k.part(VehicleKit.P_ID)
		k.body.add_box(Vector3(0.0, 0.745, -0.6), Vector3(0.5, 0.01, 0.3))
	)
	var radar := a.node(turret, "Radar", Vector3(0.0, 1.38, 1.2))
	a.out["radars"] = [{"node": radar, "speed": 1.6}]
	a.mesh(radar, "Dish", func(k: VehicleKit) -> void:
		VehicleKit.box(k.dark, Vector3(0.0, 0.05, 0.0), Vector3(0.3, 0.12, 0.3))
		k.dark.add_tube(PackedVector3Array([Vector3(0.0, 0.1, 0.0), Vector3(0.0, 0.6, 0.1)]), 0.05, 6)
		k.part(VehicleKit.P_PLAIN)
		VehicleKit.dish(k.body, Vector3(0.0, 0.62, -0.02), Vector3(0.0, 0.15, -1.0), 0.6, 0.2, 0.03, 24)
		VehicleKit.dish_feed(k.dark, Vector3(0.0, 0.62, -0.02), Vector3(0.0, 0.15, -1.0), 0.6, 0.38)
	)
	var pivot := a.node(turret, "GunPivot", Vector3(0.0, 0.42, -1.5))
	a.out["gun_pivot"] = pivot
	a.mesh(pivot, "Guns", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		VehicleKit.cbox(k.body, Vector3(0.0, 0.02, 0.1), Vector3(1.05, 0.66, 0.6), 0.08)
		for x: float in [-0.2, 0.2]:
			for y: float in [-0.15, 0.17]:
				VehicleKit.cyl(k.gun, Vector3(x, y, -0.15), Vector3(x, y, -0.4), 0.075, 10)
				VehicleKit.barrel(k, Vector3(x, y, -0.35), 2.05, 0.05, 0.028, "jacket", 10)
	)
	var muzzles: Array[Node3D] = []
	for x: float in [-0.2, 0.2]:
		for y: float in [-0.15, 0.17]:
			muzzles.append(a.node(pivot, "Muzzle", Vector3(x, y, -2.45)))
	a.out["muzzles"] = muzzles


# --- M163 VADS (США) ---------------------------------------------------------------------------------------
## Шасси бронетранспортёра M113: 5 сдвоенных катков, ведущее колесо спереди, коробчатый корпус с наклонным
## лобовым листом, волноотражательным щитком и понтонами на бортах. Башня с 20-мм шестиствольной пушкой
## M61 Vulcan, дальномерной РЛС AN/VPS-2 и бронированной кабиной наводчика.
static func _m163(a: ModelAsm) -> void:
	var root := a.root
	a.mesh(root, "Hull", func(k: VehicleKit) -> void:
		_running_gear(k, {
			"track_x": 1.19, "track_w": 0.38, "wheel_r": 0.3, "track_t": 0.06,
			"wheels": [-1.55, -0.77, 0.0, 0.77, 1.54], "dual": true,
			"idler": Vector3(2.22, 0.52, 0.25), "sprocket": Vector3(-2.2, 0.62, 0.27), "teeth": 10,
		})
		k.part(VehicleKit.P_HULL)
		k.body.add_prism(PackedVector2Array([Vector2(-2.1, 0.42), Vector2(2.3, 0.42), Vector2(2.46, 0.62), Vector2(2.46, 1.0), Vector2(-2.5, 1.0), Vector2(-2.66, 0.86)]), 0.97)
		k.body.add_prism(PackedVector2Array([Vector2(-2.5, 0.98), Vector2(2.46, 0.98), Vector2(2.46, 1.8), Vector2(-1.96, 1.8), Vector2(-2.66, 0.86)]), 1.38)
		# Волноотражательный щиток на лобовом листе.
		k.body.add_prism(PackedVector2Array([Vector2(-2.604, 0.968), Vector2(-2.049, 1.714), Vector2(-2.077, 1.735), Vector2(-2.632, 0.989)]), 1.2)
		# Понтоны на бортах.
		for s: float in [-1.0, 1.0]:
			k.body.add_prism(PackedVector2Array([Vector2(-1.7, 1.02), Vector2(2.3, 1.02), Vector2(2.3, 1.72), Vector2(-1.5, 1.72)]), 0.07, 0.0, 0.0, 15.0, s * 1.45)
			for i in 5:
				VehicleKit.box(k.dark, Vector3(s * 1.522, 1.37, -1.2 + float(i) * 0.8), Vector3(0.01, 0.66, 0.025))
			VehicleKit.headlight(k, Vector3(s * 1.05, 1.52, -2.3), Vector3(0.0, 0.35, -1.0), 0.08)
			VehicleKit.box(k.dark, Vector3(s * 0.8, 0.8, -2.62), Vector3(0.12, 0.18, 0.14))
			k.lamp.add_disc(Vector3(s * 1.2, 1.6, 2.465), Vector3(0.0, 0.0, 1.0), 0.05, 8)
		VehicleKit.hatch(k, Vector3(-0.8, 1.8, -1.6), 0.3)
		VehicleKit.periscope(k, Vector3(-0.8, 1.8, -1.95), Vector3(0.0, 0.0, -1.0), 0.14)
		VehicleKit.box(k.dark, Vector3(1.39, 1.42, -1.55), Vector3(0.02, 0.34, 0.5))
		# Кормовая аппарель с дверью.
		VehicleKit.box(k.body, Vector3(0.0, 1.22, 2.48), Vector3(1.9, 1.3, 0.03))
		VehicleKit.box(k.dark, Vector3(0.35, 1.25, 2.497), Vector3(0.62, 1.0, 0.005))
		VehicleKit.grille(k, Vector3(-0.6, 1.8, -1.0), Vector2(0.7, 0.5), 7)
		k.part(VehicleKit.P_ID)
		k.body.add_box(Vector3(0.0, 1.805, 1.95), Vector3(0.8, 0.01, 0.36))
		k.part(VehicleKit.P_HULL)
	)
	var turret := a.node(root, "Turret", Vector3(0.0, 1.8, 0.45))
	a.out["turret"] = turret
	a.mesh(turret, "TurretBody", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 0.98), Vector2(0.18, 0.96)]), 32, false, true, 40.0)
		# Бронированная кабина наводчика с остеклением.
		k.body.add_prism(PackedVector2Array([Vector2(-0.55, 0.18), Vector2(0.55, 0.18), Vector2(0.55, 1.05), Vector2(0.1, 1.12), Vector2(-0.45, 0.8)]), 0.34, 0.0, 0.0, 15.0, -0.25)
		k.glass.xform = MeshFactory.xf(Vector3(-0.25, 0.97, -0.175), Vector3(-30.0, 0.0, 0.0))
		k.glass.add_box(Vector3.ZERO, Vector3(0.52, 0.01, 0.52))
		k.glass.xform = Transform3D.IDENTITY
		for s: float in [-1.0, 1.0]:
			k.glass.add_box(Vector3(-0.25 + s * 0.345, 0.72, -0.1), Vector3(0.01, 0.3, 0.5))
		VehicleKit.cyl(k.body, Vector3(0.25, 0.52, 0.55), Vector3(0.82, 0.52, 0.55), 0.3, 18)
		VehicleKit.box(k.dark, Vector3(0.52, 0.3, 0.3), Vector3(0.5, 0.2, 0.3))
		VehicleKit.whip(k, Vector3(-0.7, 0.18, 0.6), 2.2, Vector3(0.0, 0.0, 0.2))
	)
	var pivot := a.node(turret, "GunPivot", Vector3(0.55, 0.62, -0.1))
	a.out["gun_pivot"] = pivot
	a.mesh(pivot, "Gun", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		VehicleKit.cbox(k.body, Vector3(0.0, 0.0, 0.1), Vector3(0.32, 0.36, 1.0), 0.05)
		VehicleKit.cyl(k.gun, Vector3(0.0, 0.0, -0.4), Vector3(0.0, 0.0, -0.62), 0.12, 14)
		for i in 6:
			var ang := float(i) / 6.0 * TAU
			var o := Vector3(cos(ang) * 0.065, sin(ang) * 0.065, 0.0)
			VehicleKit.cyl(k.gun, o + Vector3(0.0, 0.0, -0.55), o + Vector3(0.0, 0.0, -2.0), 0.017, 6)
		for z: float in [-1.05, -1.93]:
			VehicleKit.cyl(k.gun, Vector3(0.0, 0.0, z + 0.04), Vector3(0.0, 0.0, z - 0.04), 0.1, 14)
		# Дальномерная РЛС AN/VPS-2.
		VehicleKit.box(k.dark, Vector3(0.24, 0.02, -0.2), Vector3(0.18, 0.08, 0.2))
		VehicleKit.cyl(k.body, Vector3(0.36, 0.12, -0.05), Vector3(0.36, 0.12, -0.42), 0.17, 16)
		k.dark.add_disc(Vector3(0.36, 0.12, -0.425), Vector3(0.0, 0.0, -1.0), 0.15, 16)
	)
	a.out["muzzles"] = [a.node(pivot, "Muzzle", Vector3(0.0, 0.0, -2.02))]


# --- 2К22 «Тунгуска» (СССР) ---------------------------------------------------------------------------------
## Шасси ГМ-352: 6 сдвоенных катков, 3 поддерживающих ролика, резиновые экраны. Башня с двумя
## двуствольными 30-мм автоматами 2А38 по бортам, пакетами по четыре ЗУР 9М311 снаружи, РЛС
## сопровождения на лобовой части и вращающейся РЛС обнаружения на корме.
static func _tunguska(a: ModelAsm) -> void:
	var root := a.root
	a.mesh(root, "Hull", func(k: VehicleKit) -> void:
		_running_gear(k, {
			"track_x": 1.34, "track_w": 0.46, "wheel_r": 0.33, "track_t": 0.07,
			"wheels": [-2.55, -1.62, -0.69, 0.24, 1.17, 2.1], "dual": true,
			"idler": Vector3(-3.3, 0.6, 0.27), "sprocket": Vector3(3.05, 0.64, 0.3), "teeth": 12,
			"rollers": [-1.9, -0.2, 1.5], "roller_y": 1.02, "roller_r": 0.085,
		})
		k.part(VehicleKit.P_HULL)
		k.body.add_prism(PackedVector2Array([Vector2(-2.95, 0.45), Vector2(2.85, 0.45), Vector2(3.3, 0.95), Vector2(3.3, 1.2), Vector2(-3.35, 1.2), Vector2(-3.62, 1.02)]), 1.05)
		k.body.add_prism(PackedVector2Array([Vector2(-3.35, 1.18), Vector2(3.3, 1.18), Vector2(3.32, 1.58), Vector2(3.1, 1.72), Vector2(-2.1, 1.72), Vector2(-3.64, 1.02)]), 1.6)
		for s: float in [-1.0, 1.0]:
			k.dark.add_prism(PackedVector2Array([Vector2(-3.1, 0.84), Vector2(2.9, 0.84), Vector2(3.0, 1.2), Vector2(-3.35, 1.2)]), 0.015, 0.0, 0.0, 15.0, s * 1.63)
			VehicleKit.headlight(k, Vector3(s * 1.3, 1.5, -2.95), Vector3(0.0, 0.2, -1.0), 0.09)
			k.metal.add_tube(PackedVector3Array([Vector3(s * 1.15, 1.42, -3.02), Vector3(s * 1.16, 1.58, -3.12), Vector3(s * 1.44, 1.58, -3.12), Vector3(s * 1.45, 1.42, -3.02)]), 0.016, 5)
			VehicleKit.box(k.dark, Vector3(s * 0.75, 0.98, -3.58), Vector3(0.13, 0.18, 0.16))
			VehicleKit.cbox(k.body, Vector3(s * 1.36, 1.82, 1.5), Vector3(0.44, 0.2, 1.4), 0.03)
			VehicleKit.box(k.dark, Vector3(s * 1.2, 1.58, 3.32), Vector3(0.5, 0.16, 0.04))
		VehicleKit.hatch(k, Vector3(-0.6, 1.72, -1.95), 0.32)
		for i in 3:
			VehicleKit.periscope(k, Vector3(-0.85 + float(i) * 0.25, 1.72, -2.3), Vector3(0.0, 0.0, -1.0), 0.13)
		VehicleKit.grille(k, Vector3(0.0, 1.72, 2.5), Vector2(2.2, 1.0), 12)
		VehicleKit.cyl(k.cloth, Vector3(-1.4, 1.3, 3.36), Vector3(1.4, 1.3, 3.36), 0.11, 10)
		k.part(VehicleKit.P_ID)
		k.body.add_box(Vector3(0.0, 1.725, 3.05), Vector3(0.9, 0.01, 0.3))
		k.part(VehicleKit.P_HULL)
	)
	var turret := a.node(root, "Turret", Vector3(0.0, 1.72, 0.15))
	a.out["turret"] = turret
	a.mesh(turret, "TurretBody", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_prism(PackedVector2Array([Vector2(-1.55, 0.0), Vector2(1.7, 0.0), Vector2(1.8, 0.42), Vector2(1.62, 0.95), Vector2(-0.9, 1.0), Vector2(-1.62, 0.55)]), 1.0, 0.12, 0.0)
		k.dark.add_lathe(PackedVector2Array([Vector2(-0.05, 1.02), Vector2(0.02, 1.02)]), 28, false, false)
		VehicleKit.hatch(k, Vector3(-0.45, 1.0, 0.45), 0.3)
		VehicleKit.hatch(k, Vector3(0.45, 1.0, 0.5), 0.28)
		for i in 3:
			VehicleKit.periscope(k, Vector3(-0.45 + (float(i) - 1.0) * 0.24, 1.0, 0.1), Vector3(0.0, 0.0, -1.0), 0.12)
		VehicleKit.cbox(k.body, Vector3(0.4, 1.12, -0.4), Vector3(0.3, 0.26, 0.4), 0.04)
		k.glass.add_box(Vector3(0.4, 1.14, -0.61), Vector3(0.22, 0.12, 0.01))
		VehicleKit.cbox(k.body, Vector3(0.0, 0.5, 1.85), Vector3(1.7, 0.6, 0.3), 0.04)
		for s: float in [-1.0, 1.0]:
			VehicleKit.smoke_launchers(k, Vector3(s * 0.95, 0.7, 1.25), Vector3(s * 0.8, 0.0, -1.0), 3, 16.0)
			VehicleKit.whip(k, Vector3(s * 0.7, 0.98, 1.55), 2.0, Vector3(0.0, 0.0, 0.25))
		VehicleKit.cyl(k.body, Vector3(0.0, 0.98, 1.3), Vector3(0.0, 1.3, 1.3), 0.2, 14)
		k.part(VehicleKit.P_ID)
		k.body.add_box(Vector3(0.0, 1.005, -0.4), Vector3(0.44, 0.01, 0.28))
	)
	var radar := a.node(turret, "SearchRadar", Vector3(0.0, 1.3, 1.3))
	a.out["radars"] = [{"node": radar, "speed": 3.0}]
	a.mesh(radar, "Antenna", func(k: VehicleKit) -> void:
		VehicleKit.cyl(k.dark, Vector3.ZERO, Vector3(0.0, 0.22, 0.0), 0.12, 10)
		VehicleKit.box(k.dark, Vector3(0.0, 0.3, 0.05), Vector3(0.5, 0.16, 0.3))
		k.part(VehicleKit.P_PLAIN)
		_reflector(k.body, Vector3(0.0, 0.62, 0.12), 2.3, 0.72, 0.07, 12, 3)
		for s: float in [-1.0, 1.0]:
			k.dark.add_tube(PackedVector3Array([Vector3(s * 0.2, 0.34, 0.1), Vector3(s * 0.95, 0.42, 0.15)]), 0.025, 5)
	)
	var pivot := a.node(turret, "GunPivot", Vector3(0.0, 0.55, -0.45))
	a.out["gun_pivot"] = pivot
	a.mesh(pivot, "Weapons", func(k: VehicleKit) -> void:
		for s: float in [-1.0, 1.0]:
			k.part(VehicleKit.P_UPPER)
			k.body.add_prism(PackedVector2Array([Vector2(-0.95, -0.22), Vector2(0.7, -0.22), Vector2(0.78, 0.2), Vector2(-0.8, 0.24)]), 0.14, 0.0, 0.0, 15.0, s * 1.14)
			VehicleKit.cyl(k.dark, Vector3(s * 0.98, 0.0, 0.0), Vector3(s * 1.02, 0.0, 0.0), 0.14, 12)
			for y: float in [-0.08, 0.1]:
				VehicleKit.barrel(k, Vector3(s * 1.14, y, -0.95), 2.45, 0.05, 0.034, "brake", 10)
			VehicleKit.box(k.body, Vector3(s * 1.3, 0.04, -0.2), Vector3(0.2, 0.3, 0.5))
			k.part(VehicleKit.P_PLAIN)
			for x: float in [1.42, 1.64]:
				for y: float in [-0.08, 0.16]:
					VehicleKit.cyl(k.body, Vector3(s * x, y, 0.85), Vector3(s * x, y, -2.0), 0.1, 12)
					k.dark.add_disc(Vector3(s * x, y, -2.005), Vector3(0.0, 0.0, -1.0), 0.085, 10)
			for z: float in [0.4, -0.6, -1.6]:
				VehicleKit.box(k.dark, Vector3(s * 1.53, 0.04, z), Vector3(0.46, 0.5, 0.06))
		k.part(VehicleKit.P_UPPER)
		VehicleKit.cbox(k.body, Vector3(0.0, 0.0, -1.02), Vector3(0.6, 0.6, 0.3), 0.06)
		k.part(VehicleKit.P_PLAIN)
		VehicleKit.dish(k.body, Vector3(0.0, 0.0, -1.2), Vector3(0.0, 0.0, -1.0), 0.5, 0.16, 0.03, 24)
		VehicleKit.dish_feed(k.dark, Vector3(0.0, 0.0, -1.2), Vector3(0.0, 0.0, -1.0), 0.5, 0.3)
	)
	var muzzles: Array[Node3D] = []
	var points: Array[Node3D] = []
	for s: float in [-1.0, 1.0]:
		for y: float in [-0.08, 0.1]:
			muzzles.append(a.node(pivot, "Muzzle", Vector3(s * 1.14, y, -3.45)))
		for x: float in [1.42, 1.64]:
			for y: float in [-0.08, 0.16]:
				points.append(a.node(pivot, "LaunchPoint", Vector3(s * x, y, -2.1)))
	a.out["muzzles"] = muzzles
	a.out["launch_points"] = points


# --- «Панцирь-С1» (Россия) ------------------------------------------------------------------------------------
## Шасси КАМАЗ-6560 8×8: кабина над передним мостом, отсек энергоустановки, платформа с боевым модулем:
## РЛС сопровождения (круглая ФАР) спереди, вращающаяся РЛС обнаружения сверху, по бортам — спаренные
## 30-мм автоматы 2А38М и пакеты по шесть ТПК ЗУР 57Э6.
static func _pantsir(a: ModelAsm) -> void:
	var root := a.root
	a.mesh(root, "Hull", func(k: VehicleKit) -> void:
		_axles(k, [-4.1, -2.65, 1.45, 2.9], 1.02, 0.6, 0.4)
		for s: float in [-1.0, 1.0]:
			VehicleKit.box(k.dark, Vector3(s * 0.45, 1.1, 0.0), Vector3(0.2, 0.3, 10.3))
		k.part(VehicleKit.P_HULL)
		# Кабина с лобовым стеклом, фарами и решёткой.
		_cab(k, PackedVector2Array([Vector2(-5.52, 0.95), Vector2(-3.4, 0.95), Vector2(-3.4, 3.0), Vector2(-5.0, 3.05), Vector2(-5.45, 2.05), Vector2(-5.52, 1.2)]), 1.25, 0.03, [-5.45, 2.05, -5.0, 3.05], Rect2(-4.95, 2.05, 0.95, 0.7))
		VehicleKit.box(k.dark, Vector3(0.0, 1.55, -5.53), Vector3(1.6, 0.45, 0.04))
		for i in 6:
			VehicleKit.box(k.body, Vector3(0.0, 1.36 + float(i) * 0.07, -5.545), Vector3(1.5, 0.025, 0.02))
		VehicleKit.cbox(k.body, Vector3(0.0, 0.98, -5.58), Vector3(2.46, 0.26, 0.2), 0.04)
		for s: float in [-1.0, 1.0]:
			VehicleKit.headlight(k, Vector3(s * 0.95, 1.05, -5.69), Vector3(0.0, 0.0, -1.0), 0.08)
			VehicleKit.headlight(k, Vector3(s * 0.75, 1.05, -5.69), Vector3(0.0, 0.0, -1.0), 0.06)
			VehicleKit.box(k.dark, Vector3(s * 1.38, 2.55, -5.2), Vector3(0.05, 0.3, 0.2))
			k.dark.add_tube(PackedVector3Array([Vector3(s * 1.22, 2.6, -4.9), Vector3(s * 1.38, 2.6, -5.2)]), 0.015, 4)
			VehicleKit.box(k.dark, Vector3(s * 1.18, 1.25, -3.55), Vector3(0.14, 0.5, 0.12))
			for z: float in [-4.1, -2.65, 1.45, 2.9]:
				_fender(k.body, s * 1.02, z, 0.6, 0.66, 0.46, 15.0, 165.0)
			# Топливный бак и ящики за кабиной.
			VehicleKit.cyl(k.body, Vector3(s * 1.1, 1.35, -1.75), Vector3(s * 1.1, 1.35, -0.6), 0.28, 14)
		VehicleKit.cbox(k.body, Vector3(0.0, 2.1, -2.55), Vector3(2.4, 1.7, 1.45), 0.08)
		VehicleKit.grille(k, Vector3(0.0, 2.96, -2.55), Vector2(1.9, 1.1), 8)
		VehicleKit.box(k.body, Vector3(0.0, 1.4, 1.5), Vector3(2.5, 0.3, 7.2))
		for s: float in [-1.0, 1.0]:
			for z: float in [-1.4, 4.7]:
				VehicleKit.box(k.dark, Vector3(s * 1.25, 1.0, z), Vector3(0.22, 0.6, 0.22))
				VehicleKit.cyl(k.dark, Vector3(s * 1.25, 0.1, z), Vector3(s * 1.25, 0.7, z), 0.08, 8)
		for s: float in [-1.0, 1.0]:
			k.lamp.add_disc(Vector3(s * 1.0, 1.25, 5.11), Vector3(0.0, 0.0, 1.0), 0.05, 8)
		k.part(VehicleKit.P_ID)
		k.body.add_box(Vector3(0.0, 3.06, -4.3), Vector3(1.4, 0.012, 0.8))
		k.part(VehicleKit.P_HULL)
	)
	var turret := a.node(root, "Turret", Vector3(0.0, 1.55, 1.4))
	a.out["turret"] = turret
	a.mesh(turret, "Module", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 1.2), Vector2(0.24, 1.16)]), 32, false, true, 40.0)
		k.body.add_prism(PackedVector2Array([Vector2(-1.25, 0.2), Vector2(1.45, 0.2), Vector2(1.55, 1.25), Vector2(1.3, 1.55), Vector2(-0.85, 1.6), Vector2(-1.35, 1.0)]), 0.78, 0.04, 0.0)
		VehicleKit.hatch(k, Vector3(0.35, 1.6, 0.2), 0.28)
		VehicleKit.cyl(k.body, Vector3(0.0, 1.58, 0.9), Vector3(0.0, 1.9, 0.9), 0.18, 12)
		VehicleKit.cbox(k.body, Vector3(0.0, 0.8, 1.6), Vector3(1.4, 0.8, 0.3), 0.05)
		VehicleKit.whip(k, Vector3(-0.55, 1.58, 1.1), 2.2, Vector3(0.0, 0.0, 0.2))
		for s: float in [-1.0, 1.0]:
			VehicleKit.box(k.dark, Vector3(s * 0.82, 0.95, -0.4), Vector3(0.1, 0.5, 0.5))
	)
	var radar := a.node(turret, "SearchRadar", Vector3(0.0, 1.9, 0.9))
	a.out["radars"] = [{"node": radar, "speed": 2.6}]
	a.mesh(radar, "Antenna", func(k: VehicleKit) -> void:
		VehicleKit.box(k.dark, Vector3(0.0, 0.12, 0.0), Vector3(0.4, 0.24, 0.4))
		k.part(VehicleKit.P_PLAIN)
		k.body.xform = MeshFactory.xf(Vector3(0.0, 0.62, -0.05), Vector3(-12.0, 0.0, 0.0))
		k.body.add_box(Vector3.ZERO, Vector3(1.9, 0.8, 0.14))
		k.body.xform = Transform3D.IDENTITY
		k.dark.xform = MeshFactory.xf(Vector3(0.0, 0.62, -0.13), Vector3(-12.0, 0.0, 0.0))
		k.dark.add_box(Vector3.ZERO, Vector3(1.78, 0.68, 0.02))
		k.dark.xform = Transform3D.IDENTITY
	)
	var pivot := a.node(turret, "GunPivot", Vector3(0.0, 0.95, -0.4))
	a.out["gun_pivot"] = pivot
	a.mesh(pivot, "Weapons", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		VehicleKit.cyl(k.body, Vector3(0.0, 0.05, -1.0), Vector3(0.0, 0.05, -1.3), 0.62, 24)
		k.dark.add_disc(Vector3(0.0, 0.05, -1.305), Vector3(0.0, 0.0, -1.0), 0.56, 24)
		for s: float in [-1.0, 1.0]:
			VehicleKit.cyl(k.dark, Vector3(s * 0.76, 0.0, 0.0), Vector3(s * 0.96, 0.0, 0.0), 0.16, 12)
			k.part(VehicleKit.P_UPPER)
			VehicleKit.cbox(k.body, Vector3(s * 1.18, -0.32, -0.2), Vector3(0.32, 0.36, 1.4), 0.05)
			for dx: float in [-0.08, 0.08]:
				VehicleKit.barrel(k, Vector3(s * 1.18 + dx, -0.3, -0.9), 2.4, 0.045, 0.032, "brake", 10)
			k.part(VehicleKit.P_PLAIN)
			for x: float in [1.08, 1.28]:
				for y: float in [0.1, 0.32, 0.54]:
					VehicleKit.cyl(k.body, Vector3(s * x, y, 1.0), Vector3(s * x, y, -2.2), 0.095, 12)
					k.dark.add_disc(Vector3(s * x, y, -2.205), Vector3(0.0, 0.0, -1.0), 0.08, 10)
			for z: float in [0.6, -0.6, -1.8]:
				VehicleKit.box(k.dark, Vector3(s * 1.18, 0.32, z), Vector3(0.44, 0.7, 0.05))
	)
	var muzzles: Array[Node3D] = []
	var points: Array[Node3D] = []
	for s: float in [-1.0, 1.0]:
		for dx: float in [-0.08, 0.08]:
			muzzles.append(a.node(pivot, "Muzzle", Vector3(s * 1.18 + dx, -0.3, -3.35)))
		for x: float in [1.08, 1.28]:
			for y: float in [0.1, 0.32, 0.54]:
				points.append(a.node(pivot, "LaunchPoint", Vector3(s * x, y, -2.3)))
	a.out["muzzles"] = muzzles
	a.out["launch_points"] = points


# --- Patriot PAC-2 (США) ---------------------------------------------------------------------------------------
## Пусковая установка M901 на тяжёлом грузовике 8×8 (по мотивам HEMTT): кабина над передними мостами,
## поворотное основание и пакет из четырёх контейнеров ЗУР, поднимаемый на фиксированный угол 38°.
static func _patriot(a: ModelAsm) -> void:
	var root := a.root
	a.mesh(root, "Hull", func(k: VehicleKit) -> void:
		_axles(k, [-4.3, -2.8, 1.8, 3.3], 1.0, 0.62, 0.42)
		for s: float in [-1.0, 1.0]:
			VehicleKit.box(k.dark, Vector3(s * 0.46, 1.12, 0.0), Vector3(0.22, 0.32, 10.2))
		k.part(VehicleKit.P_HULL)
		_cab(k, PackedVector2Array([Vector2(-5.48, 0.98), Vector2(-3.3, 0.98), Vector2(-3.3, 2.95), Vector2(-4.55, 3.0), Vector2(-4.95, 2.05), Vector2(-5.4, 1.95), Vector2(-5.48, 1.7)]), 1.22, 0.02, [-4.95, 2.05, -4.55, 3.0], Rect2(-4.45, 2.0, 0.9, 0.72))
		# Решётка радиатора, бампер, фары, зеркала.
		VehicleKit.box(k.dark, Vector3(0.0, 1.45, -5.49), Vector3(1.7, 0.42, 0.03))
		for i in 7:
			VehicleKit.box(k.body, Vector3(-0.75 + float(i) * 0.25, 1.45, -5.5), Vector3(0.05, 0.4, 0.02))
		VehicleKit.cbox(k.body, Vector3(0.0, 1.02, -5.56), Vector3(2.44, 0.24, 0.24), 0.04)
		for s: float in [-1.0, 1.0]:
			VehicleKit.headlight(k, Vector3(s * 0.98, 1.72, -5.43), Vector3(0.0, 0.0, -1.0), 0.09)
			VehicleKit.box(k.dark, Vector3(s * 1.36, 2.5, -4.8), Vector3(0.05, 0.34, 0.22))
			k.dark.add_tube(PackedVector3Array([Vector3(s * 1.2, 2.55, -4.5), Vector3(s * 1.36, 2.55, -4.8)]), 0.015, 4)
			for z: float in [-4.3, -2.8, 1.8, 3.3]:
				_fender(k.body, s * 1.0, z, 0.62, 0.68, 0.48, 12.0, 168.0)
			VehicleKit.cyl(k.body, Vector3(s * 1.12, 1.4, -2.0), Vector3(s * 1.12, 1.4, -0.7), 0.3, 14)
			VehicleKit.box(k.dark, Vector3(s * 1.2, 1.1, 5.08), Vector3(0.3, 0.12, 0.05))
		# Кожух двигателя и генератор за кабиной, платформа.
		VehicleKit.cbox(k.body, Vector3(-0.4, 2.1, -2.6), Vector3(1.5, 1.6, 1.3), 0.08)
		VehicleKit.grille(k, Vector3(-0.4, 2.91, -2.6), Vector2(1.2, 1.0), 7)
		VehicleKit.cyl(k.dark, Vector3(0.72, 1.6, -2.4), Vector3(0.72, 3.25, -2.4), 0.08, 8)
		VehicleKit.cbox(k.body, Vector3(0.0, 1.48, 1.7), Vector3(2.45, 0.34, 6.8), 0.04)
		VehicleKit.cbox(k.body, Vector3(0.75, 2.05, -1.2), Vector3(0.9, 0.8, 1.0), 0.05)
		k.part(VehicleKit.P_ID)
		k.body.add_box(Vector3(0.0, 3.01, -3.95), Vector3(1.3, 0.012, 0.7))
		k.part(VehicleKit.P_HULL)
	)
	var turret := a.node(root, "Turret", Vector3(0.0, 1.65, 1.9))
	a.out["turret"] = turret
	a.mesh(turret, "Base", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 1.05), Vector2(0.18, 1.0)]), 28, false, true, 40.0)
		VehicleKit.cbox(k.body, Vector3(0.0, 0.3, 0.6), Vector3(2.3, 0.25, 2.6), 0.04)
		for s: float in [-1.0, 1.0]:
			k.dark.add_tube(PackedVector3Array([Vector3(s * 0.9, 0.4, -0.2), Vector3(s * 0.95, 0.5, 1.6)]), 0.06, 6)
			VehicleKit.box(k.dark, Vector3(s * 0.95, 0.5, 1.6), Vector3(0.2, 0.3, 0.3))
		VehicleKit.cbox(k.body, Vector3(0.0, 0.62, 1.95), Vector3(1.2, 0.6, 0.5), 0.05)
	)
	var launcher := a.node(turret, "Launcher", Vector3(0.0, 0.52, 1.7))
	a.out["launcher"] = launcher
	a.mesh(launcher, "Canisters", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		for x: float in [-0.46, 0.46]:
			for y: float in [0.46, 1.34]:
				VehicleKit.cbox(k.body, Vector3(x, y, -2.4), Vector3(5.4, 0.86, 0.86), 0.05, Vector3(0.0, 90.0, 0.0))
				for z: float in [-0.5, -2.4, -4.3]:
					VehicleKit.box(k.dark, Vector3(x, y, z), Vector3(0.9, 0.9, 0.06))
		VehicleKit.box(k.dark, Vector3(0.0, 0.9, 0.35), Vector3(1.9, 1.85, 0.12))
		VehicleKit.box(k.dark, Vector3(0.0, 0.0, -2.4), Vector3(1.8, 0.1, 5.2))
	)
	var caps: Array[Node3D] = []
	var points: Array[Node3D] = []
	for x: float in [-0.46, 0.46]:
		for y: float in [0.46, 1.34]:
			var cap := a.mesh(launcher, "Cap", func(k: VehicleKit) -> void:
				k.part(VehicleKit.P_PLAIN)
				k.body.add_box(Vector3.ZERO, Vector3(0.78, 0.78, 0.04))
			)
			cap.position = Vector3(x, y, -5.12)
			caps.append(cap)
			points.append(a.node(launcher, "LaunchPoint", Vector3(x, y, -5.3)))
	a.out["missiles"] = caps
	a.out["launch_points"] = points


# --- «Бук-М1» (СССР) --------------------------------------------------------------------------------------------
## Самоходная огневая установка 9А310М1 на шасси ГМ-569: длинный корпус с наклонным лобовым листом,
## поворотная платформа с РЛС подсвета 9С35 («Fire Dome») спереди и пусковой с четырьмя ЗУР 9М38,
## поднимающейся за целью.
static func _buk(a: ModelAsm) -> void:
	var root := a.root
	a.mesh(root, "Hull", func(k: VehicleKit) -> void:
		_running_gear(k, {
			"track_x": 1.33, "track_w": 0.5, "wheel_r": 0.33, "track_t": 0.07,
			"wheels": [-2.9, -1.75, -0.6, 0.55, 1.7, 2.85], "dual": true,
			"idler": Vector3(-4.05, 0.62, 0.3), "sprocket": Vector3(3.95, 0.66, 0.32), "teeth": 12,
			"rollers": [-2.3, 0.0, 2.3], "roller_y": 1.04, "roller_r": 0.085,
		})
		k.part(VehicleKit.P_HULL)
		k.body.add_prism(PackedVector2Array([Vector2(-3.9, 0.45), Vector2(3.75, 0.45), Vector2(4.3, 0.95), Vector2(4.3, 1.2), Vector2(-4.3, 1.2), Vector2(-4.62, 1.0)]), 1.05)
		k.body.add_prism(PackedVector2Array([Vector2(-4.3, 1.18), Vector2(4.3, 1.18), Vector2(4.32, 1.62), Vector2(4.1, 1.78), Vector2(-2.9, 1.78), Vector2(-4.64, 1.0)]), 1.62)
		for s: float in [-1.0, 1.0]:
			k.dark.add_prism(PackedVector2Array([Vector2(-3.9, 0.84), Vector2(3.8, 0.84), Vector2(3.9, 1.2), Vector2(-4.2, 1.2)]), 0.015, 0.0, 0.0, 15.0, s * 1.635)
			VehicleKit.headlight(k, Vector3(s * 1.3, 1.52, -3.72), Vector3(0.0, 0.25, -1.0), 0.09)
			k.metal.add_tube(PackedVector3Array([Vector3(s * 1.15, 1.44, -3.82), Vector3(s * 1.16, 1.6, -3.92), Vector3(s * 1.44, 1.6, -3.92), Vector3(s * 1.45, 1.44, -3.82)]), 0.016, 5)
			VehicleKit.box(k.dark, Vector3(s * 0.8, 0.98, -4.58), Vector3(0.13, 0.18, 0.16))
			VehicleKit.cbox(k.body, Vector3(s * 1.36, 1.86, 2.9), Vector3(0.44, 0.2, 1.6), 0.03)
		# Рубка механика-водителя с приборами наблюдения, люки, решётки моторного отделения.
		VehicleKit.cbox(k.body, Vector3(-0.65, 1.92, -2.55), Vector3(0.9, 0.32, 0.9), 0.06)
		for i in 3:
			VehicleKit.periscope(k, Vector3(-0.95 + float(i) * 0.3, 2.08, -3.0), Vector3(0.0, 0.0, -1.0), 0.13)
		VehicleKit.hatch(k, Vector3(-0.65, 2.08, -2.45), 0.3)
		VehicleKit.hatch(k, Vector3(0.65, 1.78, -2.4), 0.28)
		VehicleKit.grille(k, Vector3(0.0, 1.78, 3.5), Vector2(2.2, 0.9), 12)
		VehicleKit.cyl(k.cloth, Vector3(-1.4, 1.3, 4.36), Vector3(1.4, 1.3, 4.36), 0.11, 10)
		k.part(VehicleKit.P_ID)
		k.body.add_box(Vector3(0.0, 1.785, -1.8), Vector3(1.0, 0.012, 0.5))
		k.part(VehicleKit.P_HULL)
	)
	var turret := a.node(root, "Turret", Vector3(0.0, 1.78, 0.6))
	a.out["turret"] = turret
	a.mesh(turret, "Platform", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(-0.06, 1.2), Vector2(0.05, 1.2)]), 28, false, false)
		k.body.add_prism(PackedVector2Array([Vector2(-1.6, 0.0), Vector2(1.95, 0.0), Vector2(2.0, 0.45), Vector2(-1.55, 0.5)]), 1.3, 0.1, 0.0)
		# Блок РЛС подсвета спереди: корпус и плоская антенна.
		k.body.add_prism(PackedVector2Array([Vector2(-1.95, 0.4), Vector2(-1.05, 0.4), Vector2(-1.05, 1.55), Vector2(-1.55, 1.6), Vector2(-1.98, 1.4)]), 1.15, 0.04, 0.0)
		k.dark.xform = MeshFactory.xf(Vector3(0.0, 1.0, -1.99), Vector3(-90.0, 0.0, 0.0))
		k.dark.add_lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, 0.52), Vector2(0.03, 0.54), Vector2(0.03, 0.0)]), 8, false, false, 20.0)
		k.dark.xform = Transform3D.IDENTITY
		for s: float in [-1.0, 1.0]:
			VehicleKit.box(k.dark, Vector3(s * 0.85, 1.0, -1.99), Vector3(0.28, 0.9, 0.04))
			# Опоры пусковой.
			k.dark.add_tube(PackedVector3Array([Vector3(s * 0.7, 0.5, 0.4), Vector3(s * 0.55, 1.5, 1.4)]), 0.07, 6)
			k.dark.add_tube(PackedVector3Array([Vector3(s * 0.7, 0.5, 1.85), Vector3(s * 0.55, 1.5, 1.4)]), 0.07, 6)
		VehicleKit.cbox(k.body, Vector3(0.0, 0.75, 1.6), Vector3(1.8, 0.55, 0.7), 0.05)
		VehicleKit.hatch(k, Vector3(0.6, 0.5, 0.2), 0.26)
		VehicleKit.whip(k, Vector3(-1.0, 0.5, 1.7), 2.0, Vector3(0.0, 0.0, 0.2))
		k.part(VehicleKit.P_ID)
		k.body.add_box(Vector3(0.0, 1.61, -1.5), Vector3(0.6, 0.012, 0.4))
	)
	var launcher := a.node(turret, "Launcher", Vector3(0.0, 1.55, 1.4))
	a.out["launcher"] = launcher
	a.mesh(launcher, "Rails", func(k: VehicleKit) -> void:
		VehicleKit.cyl(k.dark, Vector3(-0.7, 0.0, 0.0), Vector3(0.7, 0.0, 0.0), 0.1, 10)
		for x: float in [-0.93, -0.31, 0.31, 0.93]:
			VehicleKit.box(k.dark, Vector3(x, 0.14, -2.2), Vector3(0.14, 0.12, 5.0))
		for z: float in [-0.3, -2.4, -4.5]:
			VehicleKit.box(k.dark, Vector3(0.0, 0.08, z), Vector3(2.2, 0.1, 0.14))
	)
	var missiles: Array[Node3D] = []
	var points: Array[Node3D] = []
	for x: float in [-0.93, -0.31, 0.31, 0.93]:
		var mi := a.mesh(launcher, "Missile9M38", func(k: VehicleKit) -> void:
			k.part(VehicleKit.P_WHITE)
			VehicleKit.missile(k.body, k.dark, Vector3(0.0, 0.0, 0.0), 5.5, 0.2, 4, 0.95, 0.16)
		)
		mi.position = Vector3(x, 0.4, 0.6)
		missiles.append(mi)
		points.append(a.node(launcher, "LaunchPoint", Vector3(x, 0.4, -5.1)))
	a.out["missiles"] = missiles
	a.out["launch_points"] = points


# --- С-300ПС (СССР) -------------------------------------------------------------------------------------------
## Пусковая 5П85С на шасси МАЗ-543М: две раздельные кабины по бокам моторного отсека, аппаратный отсек,
## длинная платформа с пакетом из четырёх ТПК, которые на стоянке поднимаются вертикально за кормой.
static func _s300(a: ModelAsm) -> void:
	var root := a.root
	a.mesh(root, "Hull", func(k: VehicleKit) -> void:
		_axles(k, [-4.9, -2.7, 0.9, 3.1], 1.08, 0.78, 0.6, 0.5)
		for s: float in [-1.0, 1.0]:
			VehicleKit.box(k.dark, Vector3(s * 0.5, 1.25, -0.2), Vector3(0.26, 0.36, 11.8))
		k.part(VehicleKit.P_HULL)
		# Две кабины по бокам моторного отсека.
		for s: float in [-1.0, 1.0]:
			_cab(k, PackedVector2Array([Vector2(-6.4, 1.05), Vector2(-4.55, 1.05), Vector2(-4.55, 3.0), Vector2(-5.55, 3.05), Vector2(-6.15, 2.15), Vector2(-6.45, 1.6)]), 0.46, 0.02, [-6.15, 2.15, -5.55, 3.05], Rect2(-5.3, 2.1, 0.6, 0.7), s * 0.98)
			VehicleKit.headlight(k, Vector3(s * 1.2, 1.35, -6.46), Vector3(0.0, 0.0, -1.0), 0.1)
			VehicleKit.box(k.dark, Vector3(s * 1.48, 2.6, -6.0), Vector3(0.05, 0.3, 0.2))
			for z: float in [-4.9, -2.7, 0.9, 3.1]:
				_fender(k.body, s * 1.08, z, 0.78, 0.86, 0.66, 10.0, 170.0)
		k.body.add_prism(PackedVector2Array([Vector2(-6.3, 1.05), Vector2(-4.55, 1.05), Vector2(-4.55, 2.35), Vector2(-5.8, 2.3), Vector2(-6.3, 1.8)]), 0.5)
		VehicleKit.grille(k, Vector3(0.0, 2.33, -5.2), Vector2(0.8, 1.0), 7)
		VehicleKit.box(k.dark, Vector3(0.0, 1.45, -6.31), Vector3(0.9, 0.6, 0.03))
		VehicleKit.cbox(k.body, Vector3(0.0, 1.05, -6.55), Vector3(2.9, 0.26, 0.22), 0.04)
		# Аппаратный отсек за кабинами и платформа.
		VehicleKit.cbox(k.body, Vector3(0.0, 2.1, -3.85), Vector3(2.95, 1.7, 1.35), 0.08)
		VehicleKit.hatch(k, Vector3(0.6, 2.95, -3.85), 0.3)
		VehicleKit.cbox(k.body, Vector3(0.0, 1.68, 1.2), Vector3(3.0, 0.32, 8.8), 0.04)
		for z: float in [-2.5, 0.2, 2.9]:
			VehicleKit.box(k.dark, Vector3(0.0, 2.0, z), Vector3(1.9, 0.35, 0.3))
		# Опора и гидродомкраты у кормы, выносные опоры.
		for s: float in [-1.0, 1.0]:
			VehicleKit.box(k.dark, Vector3(s * 1.0, 2.1, 5.3), Vector3(0.3, 0.9, 0.5))
			VehicleKit.cyl(k.dark, Vector3(s * 1.3, 0.12, 5.4), Vector3(s * 1.3, 1.5, 5.4), 0.1, 8)
			VehicleKit.box(k.dark, Vector3(s * 1.3, 0.06, 5.4), Vector3(0.5, 0.12, 0.5))
			k.dark.add_tube(PackedVector3Array([Vector3(s * 0.5, 1.6, 3.3), Vector3(s * 0.7, 2.3, 5.3)]), 0.08, 6)
		k.part(VehicleKit.P_ID)
		k.body.add_box(Vector3(0.0, 2.96, -3.6), Vector3(1.2, 0.012, 0.6))
		k.part(VehicleKit.P_HULL)
	)
	var launcher := a.node(root, "Launcher", Vector3(0.0, 2.35, 5.4))
	a.out["launcher"] = launcher
	a.mesh(launcher, "TLC", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		for x: float in [-0.37, 0.37]:
			for y: float in [0.37, 1.1]:
				VehicleKit.cyl(k.body, Vector3(x, y, 0.3), Vector3(x, y, -7.4), 0.35, 16)
				for z: float in [-0.6, -3.6, -6.6]:
					VehicleKit.cyl(k.dark, Vector3(x, y, z + 0.08), Vector3(x, y, z - 0.08), 0.37, 16)
				k.dark.add_disc(Vector3(x, y, -7.405), Vector3(0.0, 0.0, -1.0), 0.33, 16)
		for z: float in [-0.5, -3.6, -6.7]:
			VehicleKit.box(k.dark, Vector3(0.0, 0.72, z), Vector3(1.6, 1.5, 0.1))
		VehicleKit.box(k.dark, Vector3(0.0, 0.0, -3.5), Vector3(1.2, 0.12, 7.2))
		VehicleKit.cyl(k.dark, Vector3(-0.8, 0.0, 0.0), Vector3(0.8, 0.0, 0.0), 0.12, 10)
	)
	var points: Array[Node3D] = []
	for x: float in [-0.37, 0.37]:
		for y: float in [0.37, 1.1]:
			points.append(a.node(launcher, "LaunchPoint", Vector3(x, y, -7.6)))
	a.out["launch_points"] = points


# --- «Тор-М1» (СССР) --------------------------------------------------------------------------------------------
## Боевая машина 9А331 на шасси ГМ-355: высокая башня с ФАР сопровождения на лобовой части, восемь ЗУР
## в ячейках вертикального пуска и вращающаяся РЛС обнаружения на корме башни.
static func _tor(a: ModelAsm) -> void:
	var root := a.root
	a.mesh(root, "Hull", func(k: VehicleKit) -> void:
		_running_gear(k, {
			"track_x": 1.36, "track_w": 0.5, "wheel_r": 0.33, "track_t": 0.07,
			"wheels": [-2.5, -1.5, -0.5, 0.5, 1.5, 2.5], "dual": true,
			"idler": Vector3(-3.4, 0.62, 0.28), "sprocket": Vector3(3.3, 0.66, 0.31), "teeth": 12,
			"rollers": [-2.0, 0.0, 2.0], "roller_y": 1.04, "roller_r": 0.085,
		})
		k.part(VehicleKit.P_HULL)
		k.body.add_prism(PackedVector2Array([Vector2(-3.1, 0.45), Vector2(3.1, 0.45), Vector2(3.6, 0.95), Vector2(3.6, 1.2), Vector2(-3.55, 1.2), Vector2(-3.8, 1.0)]), 1.05)
		k.body.add_prism(PackedVector2Array([Vector2(-3.55, 1.18), Vector2(3.6, 1.18), Vector2(3.62, 1.6), Vector2(3.4, 1.75), Vector2(-2.4, 1.78), Vector2(-3.82, 1.0)]), 1.65)
		for s: float in [-1.0, 1.0]:
			k.dark.add_prism(PackedVector2Array([Vector2(-3.3, 0.84), Vector2(3.2, 0.84), Vector2(3.3, 1.2), Vector2(-3.55, 1.2)]), 0.015, 0.0, 0.0, 15.0, s * 1.665)
			VehicleKit.headlight(k, Vector3(s * 1.32, 1.5, -3.2), Vector3(0.0, 0.25, -1.0), 0.09)
			k.metal.add_tube(PackedVector3Array([Vector3(s * 1.17, 1.42, -3.3), Vector3(s * 1.18, 1.58, -3.4), Vector3(s * 1.46, 1.58, -3.4), Vector3(s * 1.47, 1.42, -3.3)]), 0.016, 5)
			VehicleKit.box(k.dark, Vector3(s * 0.8, 0.98, -3.76), Vector3(0.13, 0.18, 0.16))
			VehicleKit.cbox(k.body, Vector3(s * 1.4, 1.86, 2.6), Vector3(0.44, 0.2, 1.4), 0.03)
		VehicleKit.hatch(k, Vector3(-0.62, 1.78, -2.05), 0.3)
		for i in 3:
			VehicleKit.periscope(k, Vector3(-0.92 + float(i) * 0.3, 1.78, -2.4), Vector3(0.0, 0.0, -1.0), 0.13)
		VehicleKit.grille(k, Vector3(0.0, 1.78, 2.9), Vector2(2.2, 1.0), 12)
		VehicleKit.cyl(k.cloth, Vector3(-1.4, 1.3, 3.66), Vector3(1.4, 1.3, 3.66), 0.11, 10)
		k.part(VehicleKit.P_ID)
		k.body.add_box(Vector3(0.0, 1.785, -1.5), Vector3(0.9, 0.012, 0.4))
		k.part(VehicleKit.P_HULL)
	)
	var turret := a.node(root, "Turret", Vector3(0.0, 1.78, 0.35))
	a.out["turret"] = turret
	a.mesh(turret, "TurretBody", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.dark.add_lathe(PackedVector2Array([Vector2(-0.06, 1.25), Vector2(0.03, 1.25)]), 28, false, false)
		k.body.add_prism(PackedVector2Array([Vector2(-1.6, 0.0), Vector2(1.6, 0.0), Vector2(1.7, 1.5), Vector2(1.45, 1.8), Vector2(-1.4, 1.8), Vector2(-1.66, 1.5)]), 1.22, 0.05, 0.0)
		# ФАР сопровождения на лобовой части.
		VehicleKit.box(k.body, Vector3(0.0, 0.95, -1.72), Vector3(2.0, 1.55, 0.12))
		VehicleKit.box(k.dark, Vector3(0.0, 0.95, -1.79), Vector3(1.8, 1.35, 0.02))
		for i in 5:
			VehicleKit.box(k.body, Vector3(0.0, 0.4 + float(i) * 0.27, -1.8), Vector3(1.8, 0.015, 0.012))
		VehicleKit.cbox(k.body, Vector3(0.95, 1.9, -1.2), Vector3(0.32, 0.26, 0.45), 0.04)
		k.glass.add_box(Vector3(0.95, 1.9, -1.43), Vector3(0.22, 0.14, 0.01))
		# Ячейки вертикального пуска с крышками.
		for x: float in [-0.75, -0.25, 0.25, 0.75]:
			for z: float in [-0.35, 0.35]:
				VehicleKit.cbox(k.body, Vector3(x, 1.83, z), Vector3(0.42, 0.06, 0.6), 0.02)
				VehicleKit.box(k.dark, Vector3(x, 1.865, z), Vector3(0.36, 0.01, 0.02))
		VehicleKit.cyl(k.body, Vector3(0.0, 1.8, 1.25), Vector3(0.0, 2.05, 1.25), 0.25, 14)
		for s: float in [-1.0, 1.0]:
			VehicleKit.smoke_launchers(k, Vector3(s * 1.15, 1.2, 1.1), Vector3(s * 0.8, 0.0, -1.0), 3, 16.0)
			VehicleKit.whip(k, Vector3(s * 0.9, 1.8, 1.5), 1.8, Vector3(0.0, 0.0, 0.25))
			_side_panel(k, s * 1.18, 0.8, -0.2, 0.9, 1.3, s, 0.05)
		k.part(VehicleKit.P_ID)
		k.body.add_box(Vector3(0.0, 1.805, 0.95), Vector3(0.6, 0.012, 0.3))
	)
	var radar := a.node(turret, "SearchRadar", Vector3(0.0, 2.05, 1.25))
	a.out["radars"] = [{"node": radar, "speed": 2.8}]
	a.mesh(radar, "Antenna", func(k: VehicleKit) -> void:
		VehicleKit.box(k.dark, Vector3(0.0, 0.12, 0.0), Vector3(0.5, 0.24, 0.5))
		k.part(VehicleKit.P_PLAIN)
		k.body.xform = MeshFactory.xf(Vector3(0.0, 0.62, 0.1), Vector3(-15.0, 0.0, 0.0))
		k.body.add_box(Vector3.ZERO, Vector3(2.4, 0.9, 0.16))
		k.body.xform = Transform3D.IDENTITY
		k.dark.xform = MeshFactory.xf(Vector3(0.0, 0.62, 0.01), Vector3(-15.0, 0.0, 0.0))
		k.dark.add_box(Vector3.ZERO, Vector3(2.25, 0.76, 0.02))
		k.dark.xform = Transform3D.IDENTITY
	)
	var points: Array[Node3D] = []
	for x: float in [-0.75, -0.25, 0.25, 0.75]:
		for z: float in [-0.35, 0.35]:
			points.append(a.node(turret, "LaunchPoint", Vector3(x, 1.9, z), Vector3(90.0, 0.0, 0.0)))
	a.out["launch_points"] = points


# --- M1097 Avenger (США) ------------------------------------------------------------------------------------------
## Армейский «Хамви» с турелью Avenger в кузове: кабина оператора между двумя пакетами по четыре ракеты
## FIM-92 «Стингер» и 12,7-мм пулемёт M3P под правым пакетом.
static func _avenger(a: ModelAsm) -> void:
	var root := a.root
	a.mesh(root, "Hull", func(k: VehicleKit) -> void:
		_axles(k, [-1.65, 1.65], 0.91, 0.46, 0.34, 0.5)
		for s: float in [-1.0, 1.0]:
			VehicleKit.box(k.dark, Vector3(s * 0.45, 0.6, 0.0), Vector3(0.16, 0.22, 4.6))
		k.part(VehicleKit.P_HULL)
		# Капот с крыльями (единый откидной), решётка, фары.
		k.body.add_prism(PackedVector2Array([Vector2(-2.47, 0.7), Vector2(-0.9, 0.7), Vector2(-0.9, 1.36), Vector2(-2.3, 1.27), Vector2(-2.47, 1.12)]), 1.08, 0.02)
		for s: float in [-1.0, 1.0]:
			_fender(k.dark, s * 0.91, -1.65, 0.46, 0.5, 0.38, 0.0, 180.0, 0.06)
			_fender(k.dark, s * 0.91, 1.65, 0.46, 0.5, 0.38, 0.0, 180.0, 0.06)
			VehicleKit.headlight(k, Vector3(s * 0.75, 1.08, -2.44), Vector3(0.0, 0.0, -1.0), 0.08)
		VehicleKit.box(k.dark, Vector3(0.0, 1.0, -2.46), Vector3(0.9, 0.34, 0.02))
		for i in 9:
			VehicleKit.box(k.body, Vector3(-0.4 + float(i) * 0.1, 1.0, -2.47), Vector3(0.03, 0.32, 0.02))
		VehicleKit.cbox(k.body, Vector3(0.0, 0.7, -2.52), Vector3(2.0, 0.16, 0.14), 0.02)
		# Кабина: лобовое стекло, двери с окнами, крыша.
		_cab(k, PackedVector2Array([Vector2(-0.95, 0.72), Vector2(0.45, 0.72), Vector2(0.45, 1.85), Vector2(-0.72, 1.86), Vector2(-0.95, 1.36)]), 1.06, 0.06, [-0.95, 1.36, -0.72, 1.86], Rect2(-0.6, 1.35, 0.9, 0.42))
		# Кузов.
		VehicleKit.box(k.body, Vector3(0.0, 0.95, 1.46), Vector3(2.1, 0.12, 2.02))
		for s: float in [-1.0, 1.0]:
			VehicleKit.box(k.body, Vector3(s * 1.03, 1.12, 1.46), Vector3(0.05, 0.4, 2.02))
			k.lamp.add_disc(Vector3(s * 0.85, 1.05, 2.48), Vector3(0.0, 0.0, 1.0), 0.04, 8)
		VehicleKit.box(k.body, Vector3(0.0, 1.12, 2.46), Vector3(2.1, 0.4, 0.05))
		VehicleKit.whip(k, Vector3(-0.95, 1.3, 2.2), 2.0, Vector3(0.0, 0.0, 0.2))
		k.part(VehicleKit.P_ID)
		k.body.add_box(Vector3(0.0, 1.32, -1.6), Vector3(0.8, 0.012, 0.5))
		k.part(VehicleKit.P_HULL)
	)
	var turret := a.node(root, "Turret", Vector3(0.0, 1.05, 1.4))
	a.out["turret"] = turret
	a.mesh(turret, "Turret", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 0.8), Vector2(0.18, 0.78)]), 24, false, true, 40.0)
		# Кабина оператора с остеклением.
		k.body.add_prism(PackedVector2Array([Vector2(-0.5, 0.18), Vector2(0.5, 0.18), Vector2(0.5, 1.25), Vector2(-0.3, 1.25), Vector2(-0.55, 0.9)]), 0.45, 0.04)
		_window(k, [Vector3(-0.36, 0.95, -0.54), Vector3(0.36, 0.95, -0.54), Vector3(0.34, 1.2, -0.33), Vector3(-0.34, 1.2, -0.33)], Vector3(0.0, 0.8, -0.6))
		for s: float in [-1.0, 1.0]:
			_window(k, [Vector3(s * 0.415, 0.7, -0.35), Vector3(s * 0.415, 0.7, 0.2), Vector3(s * 0.405, 1.05, 0.2), Vector3(s * 0.405, 1.05, -0.35)], Vector3(s, 0.04, 0.0))
			VehicleKit.cyl(k.dark, Vector3(s * 0.45, 0.75, 0.0), Vector3(s * 0.58, 0.75, 0.0), 0.12, 10)
	)
	var pivot := a.node(turret, "GunPivot", Vector3(0.0, 0.75, 0.0))
	a.out["gun_pivot"] = pivot
	a.mesh(pivot, "Pods", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		for s: float in [-1.0, 1.0]:
			VehicleKit.cbox(k.body, Vector3(s * 0.8, 0.12, 0.0), Vector3(0.44, 0.52, 1.6), 0.04)
			for dx: float in [-0.1, 0.1]:
				for dy: float in [-0.01, 0.25]:
					k.dark.add_disc(Vector3(s * 0.8 + dx, dy, -0.805), Vector3(0.0, 0.0, -1.0), 0.07, 10)
		VehicleKit.cbox(k.body, Vector3(-0.8, 0.5, -0.2), Vector3(0.26, 0.22, 0.5), 0.03)
		k.glass.add_box(Vector3(-0.8, 0.5, -0.455), Vector3(0.18, 0.12, 0.01))
		# Пулемёт M3P под правым пакетом.
		VehicleKit.cbox(k.body, Vector3(0.8, -0.38, 0.05), Vector3(0.22, 0.2, 0.8), 0.02)
		VehicleKit.barrel(k, Vector3(0.8, -0.38, -0.35), 1.0, 0.04, 0.025, "flash", 8)
	)
	var points: Array[Node3D] = []
	for s: float in [-1.0, 1.0]:
		for dx: float in [-0.1, 0.1]:
			for dy: float in [-0.01, 0.25]:
				points.append(a.node(pivot, "LaunchPoint", Vector3(s * 0.8 + dx, dy, -0.9)))
	a.out["launch_points"] = points
	a.out["muzzles"] = [a.node(pivot, "Muzzle", Vector3(0.8, -0.38, -1.4))]


# --- Открытая многогранная рубка/башня: наружные и внутренние стенки ---------------------------------------
static func _open_tub(k: VehicleKit, sides: int, radius: float, height: float, inset: float, wall: float, phase: float = 0.0) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in sides:
		var ang := float(i) / float(sides) * TAU + phase
		outer.append(Vector2(sin(ang), cos(ang)) * radius)
		inner.append(Vector2(sin(ang), cos(ang)) * (radius - wall))
	k.part(VehicleKit.P_UPPER)
	k.body.add_block(outer, 0.0, height, inset, false, false, 8.0)
	k.part(VehicleKit.P_INTERIOR)
	k.body.add_block(inner, 0.02, height, inset * (radius - wall) / radius, false, false, 8.0, true)
	var floor_pts := PackedVector3Array()
	for p in inner:
		floor_pts.append(Vector3(p.x, 0.03, p.y))
	k.body.add_polygon(floor_pts, Vector3.UP)
	# Верхняя кромка стенок.
	k.part(VehicleKit.P_UPPER)
	var top_scale := (radius - inset) / radius
	for i in sides:
		var a0 := outer[i] * top_scale
		var a1 := outer[(i + 1) % sides] * top_scale
		var b0 := inner[i] * ((radius - wall - inset * (radius - wall) / radius) / (radius - wall))
		var b1 := inner[(i + 1) % sides] * ((radius - wall - inset * (radius - wall) / radius) / (radius - wall))
		k.body.add_polygon(PackedVector3Array([Vector3(a0.x, height, a0.y), Vector3(a1.x, height, a1.y), Vector3(b1.x, height, b1.y), Vector3(b0.x, height, b0.y)]), Vector3.UP)


# --- Flakpanzer IV «Wirbelwind» (Германия) ----------------------------------------------------------------------
## Шасси Pz.Kpfw. IV: восемь сдвоенных катков на четырёх рессорных тележках, ведущее колесо спереди,
## вертикальный лобовой лист рубки с прибором водителя и курсовым пулемётом. Открытая девятигранная
## башня со счетверённой 2-см установкой Flakvierling 38 и расчётом.
static func _wirbelwind(a: ModelAsm) -> void:
	var root := a.root
	a.mesh(root, "Hull", func(k: VehicleKit) -> void:
		var wheels: Array = []
		for bz: float in [-1.65, -0.55, 0.55, 1.65]:
			wheels.append(bz - 0.26)
			wheels.append(bz + 0.26)
		_running_gear(k, {
			"track_x": 1.23, "track_w": 0.4, "wheel_r": 0.235, "track_t": 0.06,
			"wheels": wheels, "dual": true,
			"idler": Vector3(2.55, 0.55, 0.28), "sprocket": Vector3(-2.55, 0.62, 0.33), "teeth": 13,
			"rollers": [-1.8, -0.6, 0.6, 1.8], "roller_y": 0.98, "roller_r": 0.1,
		})
		k.part(VehicleKit.P_HULL)
		for s: float in [-1.0, 1.0]:
			for bz: float in [-1.65, -0.55, 0.55, 1.65]:
				VehicleKit.cbox(k.body, Vector3(s * 0.99, 0.42, bz), Vector3(0.16, 0.3, 0.64), 0.03)
				VehicleKit.box(k.dark, Vector3(s * 1.03, 0.32, bz), Vector3(0.08, 0.07, 0.52))
		k.body.add_prism(PackedVector2Array([Vector2(-2.3, 0.4), Vector2(2.2, 0.4), Vector2(2.6, 0.75), Vector2(2.6, 1.0), Vector2(-2.88, 1.0), Vector2(-2.75, 0.62)]), 0.96)
		k.body.add_prism(PackedVector2Array([Vector2(-2.88, 0.99), Vector2(2.6, 0.99), Vector2(2.62, 1.5), Vector2(2.45, 1.63), Vector2(0.9, 1.63), Vector2(0.86, 1.73), Vector2(-2.3, 1.73), Vector2(-2.35, 1.3)]), 1.04)
		# Надгусеничные полки с крыльями.
		for s: float in [-1.0, 1.0]:
			VehicleKit.box(k.body, Vector3(s * 1.25, 1.0, -0.1), Vector3(0.44, 0.03, 5.5))
			VehicleKit.box(k.body, Vector3(s * 1.25, 0.9, -2.95), Vector3(0.44, 0.03, 0.4), Vector3(-30.0, 0.0, 0.0))
			VehicleKit.box(k.body, Vector3(s * 1.25, 0.92, 2.78), Vector3(0.44, 0.03, 0.4), Vector3(30.0, 0.0, 0.0))
			VehicleKit.cbox(k.body, Vector3(s * 1.25, 1.1, 1.4), Vector3(0.3, 0.18, 0.7), 0.02)
			k.metal.add_tube(PackedVector3Array([Vector3(s * 1.05, 1.5, -1.9), Vector3(s * 1.06, 1.52, 0.4), Vector3(s * 1.05, 1.45, 2.2)]), 0.022, 6)
		# Лобовой лист: прибор наблюдения водителя, шаровая установка пулемёта, запасные траки.
		VehicleKit.cbox(k.body, Vector3(-0.48, 1.52, -2.34), Vector3(0.36, 0.14, 0.08), 0.02)
		k.glass.add_box(Vector3(-0.48, 1.52, -2.385), Vector3(0.22, 0.03, 0.01))
		k.body.xform = Transform3D(Basis(), Vector3(0.52, 1.5, -2.33))
		k.body.add_blob(Vector3.ZERO, Vector3(0.14, 0.14, 0.08), 1, 0.0, 2, Color.WHITE, Color.WHITE)
		k.body.xform = Transform3D.IDENTITY
		VehicleKit.barrel(k, Vector3(0.52, 1.5, -2.38), 0.45, 0.025, 0.014, "", 8)
		for i in 4:
			var t := 0.18 + float(i) * 0.2
			var gp := Vector2(-2.88, 1.0).lerp(Vector2(-2.35, 1.3), t)
			VehicleKit.box(k.dark, Vector3(0.0, gp.y + 0.03, gp.x + 0.015), Vector3(1.4, 0.035, 0.12), Vector3(-29.5, 0.0, 0.0))
		VehicleKit.headlight(k, Vector3(-1.2, 1.12, -2.6), Vector3(0.0, 0.0, -1.0), 0.07)
		VehicleKit.hatch(k, Vector3(-0.5, 1.73, -1.9), 0.26)
		VehicleKit.hatch(k, Vector3(0.5, 1.73, -1.9), 0.26)
		# Моторное отделение: решётки, глушитель, буксирные серьги.
		VehicleKit.grille(k, Vector3(-0.55, 1.635, 1.8), Vector2(0.6, 1.0), 7)
		VehicleKit.grille(k, Vector3(0.55, 1.635, 1.8), Vector2(0.6, 1.0), 7)
		VehicleKit.cyl(k.dark, Vector3(-0.8, 0.82, 2.74), Vector3(0.8, 0.82, 2.74), 0.16, 12)
		for s: float in [-1.0, 1.0]:
			k.dark.add_tube(PackedVector3Array([Vector3(s * 0.5, 0.82, 2.74), Vector3(s * 0.5, 1.2, 2.8), Vector3(s * 0.5, 1.28, 2.95)]), 0.05, 6)
			VehicleKit.box(k.dark, Vector3(s * 0.7, 0.55, -2.78), Vector3(0.1, 0.16, 0.18))
		k.part(VehicleKit.P_ID)
		k.body.add_box(Vector3(0.0, 1.64, 2.35), Vector3(0.9, 0.012, 0.5))
		k.part(VehicleKit.P_HULL)
	)
	for s: float in [-1.0, 1.0]:
		a.decal(root, Insignia.texture("de", "fuselage"), Vector3(s * 1.05, 1.34, 0.7), Vector3(s, 0.0, 0.0), 0.5)
	var turret := a.node(root, "Turret", Vector3(0.0, 1.73, -0.35))
	a.out["turret"] = turret
	a.mesh(turret, "Tub", func(k: VehicleKit) -> void:
		_open_tub(k, 9, 1.02, 0.95, 0.14, 0.03, PI / 9.0)
		k.dark.add_lathe(PackedVector2Array([Vector2(-0.05, 0.98), Vector2(0.02, 0.98)]), 27, false, false)
		VehicleKit.cyl(k.dark, Vector3(0.0, 0.03, 0.0), Vector3(0.0, 0.62, 0.0), 0.14, 10)
		VehicleKit.box(k.dark, Vector3(0.0, 0.42, 0.52), Vector3(0.36, 0.06, 0.32))
		VehicleKit.crew(k, Vector3(0.0, 0.04, 0.62), 0.0, true, "de")
		VehicleKit.crew(k, Vector3(-0.52, 0.03, 0.18), 0.5, false, "de")
		for i in 3:
			VehicleKit.box(k.dark, Vector3(0.62 + float(i) * 0.05, 0.3, 0.1 + float(i) * 0.16), Vector3(0.04, 0.22, 0.13))
	)
	var pivot := a.node(turret, "GunPivot", Vector3(0.0, 1.12, -0.05))
	a.out["gun_pivot"] = pivot
	a.mesh(pivot, "Flakvierling", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		VehicleKit.cbox(k.body, Vector3(0.0, 0.0, 0.1), Vector3(0.22, 0.52, 0.62), 0.03)
		VehicleKit.cyl(k.dark, Vector3(-0.3, 0.0, 0.0), Vector3(0.3, 0.0, 0.0), 0.06, 8)
		for x: float in [-0.17, 0.17]:
			for y: float in [-0.14, 0.16]:
				VehicleKit.box(k.gun, Vector3(x, y, 0.05), Vector3(0.12, 0.15, 0.6))
				VehicleKit.barrel(k, Vector3(x, y, -0.26), 1.42, 0.03, 0.018, "flash", 8)
				VehicleKit.box(k.dark, Vector3(x + signf(x) * 0.1, y + 0.03, -0.02), Vector3(0.05, 0.2, 0.12))
		VehicleKit.cbox(k.body, Vector3(0.0, 0.34, 0.1), Vector3(0.12, 0.14, 0.22), 0.02)
		k.glass.add_box(Vector3(0.0, 0.36, -0.015), Vector3(0.08, 0.08, 0.01))
	)
	var muzzles: Array[Node3D] = []
	for x: float in [-0.17, 0.17]:
		for y: float in [-0.14, 0.16]:
			muzzles.append(a.node(pivot, "Muzzle", Vector3(x, y, -1.72)))
	a.out["muzzles"] = muzzles


# --- M16 MGMC (США) -------------------------------------------------------------------------------------------------
## Полугусеничный M3: передний мост с крыльями, бронированный капот с жалюзи радиатора, бампер с роликом,
## открытая кабина с бронещитком, кормовые гусеницы с тележкой и открытый кузов со счетверённой
## установкой M45 (4× M2 и патронные коробы) и наводчиком.
static func _m16(a: ModelAsm) -> void:
	var root := a.root
	a.mesh(root, "Hull", func(k: VehicleKit) -> void:
		for s: float in [-1.0, 1.0]:
			VehicleKit.wheel(k, Vector3(s * 0.82, 0.42, -2.1), 0.42, 0.26, s, 0.5)
			var x := s * 0.8
			var circles: Array = []
			VehicleKit.sprocket(k, Vector3(x, 0.47, -0.2), 0.3, 0.26, s, 11)
			circles.append(Vector3(-0.2, 0.47, 0.29))
			VehicleKit.road_wheel(k, Vector3(x, 0.45, 2.3), 0.28, 0.24, s)
			circles.append(Vector3(2.3, 0.45, 0.28))
			for z: float in [0.45, 0.85, 1.4, 1.8]:
				VehicleKit.road_wheel(k, Vector3(x, 0.25, z), 0.2, 0.24, s)
				circles.append(Vector3(z, 0.25, 0.2))
			VehicleKit.roller(k, Vector3(x, 0.78, 1.1), 0.08, 0.14, s)
			circles.append(Vector3(1.1, 0.78, 0.08))
			VehicleKit.track_belt(k, x, 0.3, circles, 0.05)
			VehicleKit.cbox(k.body, Vector3(x, 0.4, 1.12), Vector3(0.1, 0.22, 1.2), 0.02)
		VehicleKit.cyl(k.dark, Vector3(-0.7, 0.42, -2.1), Vector3(0.7, 0.42, -2.1), 0.07, 8)
		for s: float in [-1.0, 1.0]:
			VehicleKit.box(k.dark, Vector3(s * 0.42, 0.72, -0.25), Vector3(0.12, 0.18, 5.6))
		k.part(VehicleKit.P_HULL)
		# Бронированный капот и жалюзи радиатора.
		k.body.add_prism(PackedVector2Array([Vector2(-3.0, 0.8), Vector2(-1.3, 0.8), Vector2(-1.3, 1.62), Vector2(-2.8, 1.55), Vector2(-3.0, 1.38)]), 0.52)
		VehicleKit.box(k.dark, Vector3(0.0, 1.1, -3.01), Vector3(0.9, 0.5, 0.02))
		for i in 10:
			VehicleKit.box(k.body, Vector3(-0.41 + float(i) * 0.09, 1.1, -3.02), Vector3(0.03, 0.48, 0.03))
		for s: float in [-1.0, 1.0]:
			_fender(k.body, s * 0.82, -2.1, 0.42, 0.5, 0.38, 5.0, 175.0, 0.035)
			VehicleKit.box(k.body, Vector3(s * 0.85, 0.8, -0.85), Vector3(0.36, 0.03, 1.6))
			VehicleKit.headlight(k, Vector3(s * 0.62, 1.05, -2.62), Vector3(0.0, 0.0, -1.0), 0.09)
			k.metal.add_tube(PackedVector3Array([Vector3(s * 0.5, 0.95, -2.7), Vector3(s * 0.52, 1.18, -2.74), Vector3(s * 0.72, 1.18, -2.74), Vector3(s * 0.74, 0.95, -2.7)]), 0.014, 5)
		# Бампер с роликом.
		VehicleKit.box(k.dark, Vector3(0.0, 0.62, -3.12), Vector3(1.9, 0.14, 0.12))
		VehicleKit.cyl(k.dark, Vector3(-0.78, 0.62, -3.32), Vector3(0.78, 0.62, -3.32), 0.16, 14)
		for s: float in [-1.0, 1.0]:
			VehicleKit.box(k.dark, Vector3(s * 0.85, 0.62, -3.24), Vector3(0.08, 0.1, 0.3))
		# Кабина: пол, борта-двери, поднятый бронещиток с визирными щелями, сиденья, руль.
		VehicleKit.box(k.body, Vector3(0.0, 0.95, -0.85), Vector3(1.95, 0.08, 0.95))
		for s: float in [-1.0, 1.0]:
			k.body.add_prism(PackedVector2Array([Vector2(-1.3, 0.95), Vector2(-0.35, 0.95), Vector2(-0.35, 1.6), Vector2(-1.3, 1.62)]), 0.015, 0.0, 0.0, 15.0, s * 0.97)
			VehicleKit.box(k.dark, Vector3(s * 0.45, 1.2, -0.65), Vector3(0.44, 0.12, 0.4))
		k.body.add_prism(PackedVector2Array([Vector2(-1.33, 1.6), Vector2(-1.27, 1.6), Vector2(-1.27, 2.06), Vector2(-1.33, 2.06)]), 0.97)
		for s: float in [-1.0, 1.0]:
			VehicleKit.box(k.dark, Vector3(s * 0.45, 1.9, -1.34), Vector3(0.36, 0.03, 0.02))
		k.dark.add_tube(PackedVector3Array([Vector3(-0.62, 1.42, -1.05), Vector3(-0.38, 1.42, -1.05)]), 0.02, 4)
		# Кузов: пол, борта, корма, ящики, канистры, фонари.
		VehicleKit.box(k.body, Vector3(0.0, 0.95, 1.12), Vector3(1.95, 0.08, 3.05))
		for s: float in [-1.0, 1.0]:
			k.body.add_prism(PackedVector2Array([Vector2(-0.35, 0.95), Vector2(2.63, 0.95), Vector2(2.63, 1.55), Vector2(-0.35, 1.55)]), 0.015, 0.0, 0.0, 15.0, s * 0.97)
			VehicleKit.box(k.body, Vector3(s * 1.02, 1.45, 1.12), Vector3(0.03, 0.26, 2.9), Vector3(0.0, 0.0, s * 35.0))
			VehicleKit.cbox(k.body, Vector3(s * 0.8, 1.1, 2.3), Vector3(0.24, 0.3, 0.5), 0.02)
			k.lamp.add_disc(Vector3(s * 0.8, 1.2, 2.66), Vector3(0.0, 0.0, 1.0), 0.04, 8)
		k.body.add_prism(PackedVector2Array([Vector2(2.6, 0.9), Vector2(2.66, 0.9), Vector2(2.66, 1.55), Vector2(2.6, 1.55)]), 0.97)
		for i in 3:
			VehicleKit.cbox(k.body, Vector3(-0.4 + float(i) * 0.4, 1.2, 2.78), Vector3(0.16, 0.44, 0.3), 0.02)
		k.part(VehicleKit.P_ID)
		k.body.add_box(Vector3(0.0, 1.625, -2.0), Vector3(0.6, 0.012, 0.6))
		k.part(VehicleKit.P_HULL)
	)
	var star := Insignia.texture("us_star", "fuselage")
	for s: float in [-1.0, 1.0]:
		a.decal(root, star, Vector3(s * 0.985, 1.25, 1.3), Vector3(s, 0.0, 0.0), 0.5)
	var turret := a.node(root, "Turret", Vector3(0.0, 1.0, 1.25))
	a.out["turret"] = turret
	a.mesh(turret, "Mount", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 0.42), Vector2(0.3, 0.36), Vector2(0.34, 0.72), Vector2(0.4, 0.72)]), 20, false, true, 40.0)
		# Бронещитки перед наводчиком и у коробов.
		k.body.add_prism(PackedVector2Array([Vector2(-0.34, 0.45), Vector2(-0.26, 0.45), Vector2(-0.3, 1.2), Vector2(-0.38, 1.2)]), 0.3)
		for s: float in [-1.0, 1.0]:
			k.body.add_prism(PackedVector2Array([Vector2(-0.6, 0.45), Vector2(0.35, 0.45), Vector2(0.3, 1.25), Vector2(-0.55, 1.25)]), 0.012, 0.0, 0.0, 15.0, s * 0.9)
		VehicleKit.box(k.dark, Vector3(0.0, 1.05, -0.37), Vector3(0.24, 0.05, 0.02))
		VehicleKit.box(k.dark, Vector3(0.0, 0.62, 0.3), Vector3(0.36, 0.06, 0.34))
		VehicleKit.crew(k, Vector3(0.0, 0.66, 0.38), 0.0, true, "us")
	)
	var pivot := a.node(turret, "GunPivot", Vector3(0.0, 1.0, -0.05))
	a.out["gun_pivot"] = pivot
	a.mesh(pivot, "M45", func(k: VehicleKit) -> void:
		VehicleKit.cyl(k.dark, Vector3(-0.62, 0.0, 0.0), Vector3(0.62, 0.0, 0.0), 0.05, 8)
		k.part(VehicleKit.P_UPPER)
		for s: float in [-1.0, 1.0]:
			for dy: float in [-0.13, 0.13]:
				VehicleKit.box(k.gun, Vector3(s * 0.45, dy, 0.1), Vector3(0.13, 0.16, 0.55))
				VehicleKit.barrel(k, Vector3(s * 0.45, dy, -0.18), 1.12, 0.026, 0.019, "flash", 8)
				VehicleKit.cbox(k.body, Vector3(s * 0.66, dy, 0.12), Vector3(0.22, 0.24, 0.46), 0.02)
		VehicleKit.cbox(k.body, Vector3(0.0, 0.3, 0.0), Vector3(0.12, 0.16, 0.2), 0.02)
		k.glass.add_box(Vector3(0.0, 0.33, -0.105), Vector3(0.09, 0.09, 0.01))
	)
	var muzzles: Array[Node3D] = []
	for s: float in [-1.0, 1.0]:
		for dy: float in [-0.13, 0.13]:
			muzzles.append(a.node(pivot, "Muzzle", Vector3(s * 0.45, dy, -1.32)))
	a.out["muzzles"] = muzzles


# --- ЗСУ-37 (СССР) ----------------------------------------------------------------------------------------------------
## Шасси СУ-76М: шесть сдвоенных катков, ведущее колесо спереди, длинный наклонный лобовой лист. На корме —
## открытая сверху бронированная рубка; внутри на тумбе вращается 37-мм автомат 61-К с расчётом.
static func _zsu37(a: ModelAsm) -> void:
	var root := a.root
	a.mesh(root, "Hull", func(k: VehicleKit) -> void:
		_running_gear(k, {
			"track_x": 1.15, "track_w": 0.3, "wheel_r": 0.27, "track_t": 0.05,
			"wheels": [-1.75, -1.05, -0.35, 0.35, 1.05, 1.75], "dual": true,
			"idler": Vector3(2.3, 0.5, 0.26), "sprocket": Vector3(-2.3, 0.58, 0.29), "teeth": 12,
			"rollers": [-1.4, 0.0, 1.4], "roller_y": 0.9, "roller_r": 0.075,
		})
		k.part(VehicleKit.P_HULL)
		k.body.add_prism(PackedVector2Array([Vector2(-2.05, 0.38), Vector2(2.1, 0.38), Vector2(2.45, 0.7), Vector2(2.45, 0.95), Vector2(-2.6, 0.95), Vector2(-2.5, 0.6)]), 0.85)
		k.body.add_prism(PackedVector2Array([Vector2(-2.6, 0.93), Vector2(2.45, 0.93), Vector2(2.45, 1.45), Vector2(-1.3, 1.45), Vector2(-2.62, 0.95)]), 1.3)
		# Открытая рубка на корме.
		var plan := VehicleKit.chamfer_rect(2.55, 2.5, 0.25, 1.2)
		k.part(VehicleKit.P_UPPER)
		k.body.add_block(plan, 1.45, 2.35, 0.14, false)
		var inner := VehicleKit.chamfer_rect(2.49, 2.44, 0.24, 1.2)
		k.part(VehicleKit.P_INTERIOR)
		k.body.add_block(inner, 1.46, 2.35, 0.137, false, false, 12.0, true)
		k.part(VehicleKit.P_HULL)
		VehicleKit.hatch(k, Vector3(-0.45, 1.3, -1.72), 0.26)
		for s: float in [-1.0, 1.0]:
			VehicleKit.headlight(k, Vector3(s * 0.95, 1.15, -2.2), Vector3(0.0, 0.3, -1.0), 0.07)
			VehicleKit.cbox(k.body, Vector3(s * 1.18, 1.05, -0.9), Vector3(0.22, 0.2, 0.9), 0.02)
			k.dark.add_tube(PackedVector3Array([Vector3(s * 1.1, 1.05, 0.3), Vector3(s * 1.32, 1.1, 0.35), Vector3(s * 1.32, 1.3, 0.35)]), 0.05, 6)
			VehicleKit.box(k.dark, Vector3(s * 0.7, 0.55, -2.58), Vector3(0.1, 0.14, 0.16))
		VehicleKit.grille(k, Vector3(0.0, 1.455, -0.35), Vector2(1.6, 0.6), 8)
		VehicleKit.cyl(k.cloth, Vector3(-1.2, 1.1, 2.55), Vector3(1.2, 1.1, 2.55), 0.1, 10)
		k.part(VehicleKit.P_ID)
		k.body.add_box(Vector3(0.0, 1.13, -1.85), Vector3(0.7, 0.012, 0.45), )
		k.part(VehicleKit.P_HULL)
	)
	var turret := a.node(root, "Turret", Vector3(0.0, 1.47, 1.25))
	a.out["turret"] = turret
	a.mesh(turret, "Mount", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 0.34), Vector2(0.55, 0.26), Vector2(0.6, 0.4), Vector2(0.66, 0.4)]), 18, false, true, 40.0)
		for s: float in [-1.0, 1.0]:
			k.body.add_prism(PackedVector2Array([Vector2(-0.45, 0.6), Vector2(0.55, 0.6), Vector2(0.35, 1.2), Vector2(-0.3, 1.2)]), 0.04, 0.0, 0.0, 15.0, s * 0.26)
			VehicleKit.box(k.dark, Vector3(s * 0.62, 0.55, 0.3), Vector3(0.3, 0.05, 0.3))
			VehicleKit.crew(k, Vector3(s * 0.62, 0.05, 0.62), 0.0, true, "su")
		VehicleKit.crew(k, Vector3(-0.3, 0.02, 1.0), 0.6, false, "su")
	)
	var pivot := a.node(turret, "GunPivot", Vector3(0.0, 1.08, -0.05))
	a.out["gun_pivot"] = pivot
	a.mesh(pivot, "Gun61K", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		VehicleKit.cbox(k.body, Vector3(0.0, 0.0, 0.2), Vector3(0.3, 0.32, 1.2), 0.04)
		VehicleKit.cyl(k.dark, Vector3(-0.3, 0.0, 0.0), Vector3(0.3, 0.0, 0.0), 0.07, 8)
		VehicleKit.box(k.gun, Vector3(0.0, 0.28, 0.2), Vector3(0.12, 0.24, 0.5))
		VehicleKit.cyl(k.gun, Vector3(0.0, -0.13, 0.4), Vector3(0.0, -0.13, -0.5), 0.05, 8)
		VehicleKit.barrel(k, Vector3(0.0, 0.0, -0.4), 2.62, 0.06, 0.04, "flash", 12)
		for s: float in [-1.0, 1.0]:
			VehicleKit.cbox(k.body, Vector3(s * 0.22, 0.12, -0.1), Vector3(0.1, 0.14, 0.26), 0.02)
			k.glass.add_box(Vector3(s * 0.22, 0.13, -0.235), Vector3(0.07, 0.07, 0.01))
	)
	a.out["muzzles"] = [a.node(pivot, "Muzzle", Vector3(0.0, 0.0, -3.05))]


# --- Зенитные орудия на крестообразном лафете ----------------------------------------------------------------------
## Основание позиции: кольцо мешков с песком, крестообразная платформа с домкратами, тумба, ящики со
## снарядами и заряжающие.
static func _gun_emplacement(k: VehicleKit, helmet: String, wheels: bool) -> void:
	VehicleKit.sandbags(k, Vector3(0.0, 0.0, 0.3), 4.4, 3, Vector3(0.0, 0.0, 1.0), 50.0)
	k.part(VehicleKit.P_HULL)
	VehicleKit.cbox(k.body, Vector3(0.0, 0.22, 0.0), Vector3(0.4, 0.26, 5.6), 0.04, Vector3(0.0, 90.0, 0.0))
	VehicleKit.cbox(k.body, Vector3(0.0, 0.22, 0.0), Vector3(4.4, 0.26, 0.4), 0.04)
	for p: Vector3 in [Vector3(0.0, 0.0, 2.75), Vector3(0.0, 0.0, -2.75), Vector3(2.15, 0.0, 0.0), Vector3(-2.15, 0.0, 0.0)]:
		VehicleKit.cyl(k.dark, p + Vector3(0.0, 0.06, 0.0), p + Vector3(0.0, 0.5, 0.0), 0.06, 8)
		VehicleKit.box(k.dark, p + Vector3(0.0, 0.03, 0.0), Vector3(0.36, 0.06, 0.36))
		var ring := PackedVector3Array()
		for i in 13:
			var ang := float(i) / 12.0 * TAU
			ring.append(p + Vector3(cos(ang) * 0.12, 0.52, sin(ang) * 0.12))
		k.metal.add_tube(ring, 0.012, 4)
	if wheels:
		for zz: float in [-1.7, 1.7]:
			for s: float in [-1.0, 1.0]:
				VehicleKit.wheel(k, Vector3(s * 0.62, 0.52, zz), 0.46, 0.2, s, 0.55)
			VehicleKit.cyl(k.dark, Vector3(-0.55, 0.52, zz), Vector3(0.55, 0.52, zz), 0.06, 8)
	k.body.add_lathe(PackedVector2Array([Vector2(0.3, 0.6), Vector2(0.36, 0.52), Vector2(0.94, 0.44), Vector2(1.0, 0.5)]), 20, false, true, 40.0)
	for i in 3:
		VehicleKit.cbox(k.cloth, Vector3(2.9 + float(i) * 0.08, 0.13, 1.4 + float(i) * 0.48), Vector3(0.5, 0.26, 0.4), 0.02)
	for i in 4:
		var sp := Vector3(-2.8 + float(i % 2) * 0.16, 0.0, 1.8 + float(i / 2) * 0.16)
		k.metal.xform = Transform3D(Basis(), sp)
		k.metal.add_lathe(PackedVector2Array([Vector2(0.0, 0.045), Vector2(0.55, 0.045), Vector2(0.72, 0.03), Vector2(0.82, 0.0)]), 8, true, false, 40.0)
		k.metal.xform = Transform3D.IDENTITY
	VehicleKit.crew(k, Vector3(1.9, 0.0, 1.9), -2.3, false, helmet)
	VehicleKit.crew(k, Vector3(-1.7, 0.0, 2.2), 2.5, false, helmet)


# --- 8,8-cm Flak 37 (Германия) ---------------------------------------------------------------------------------------
## Знаменитая «ахт-ахт»: крестообразный лафет Kreuzlafette с домкратами, тумба, верхний станок со щёками,
## уравновешивающими механизмами и местами наводчиков, ствол L/56 без дульного тормоза, установщик взрывателя.
static func _flak88(a: ModelAsm) -> void:
	var root := a.root
	a.mesh(root, "Base", func(k: VehicleKit) -> void:
		_gun_emplacement(k, "de", false)
	)
	var turret := a.node(root, "Turret", Vector3(0.0, 1.0, 0.0))
	a.out["turret"] = turret
	a.mesh(turret, "Carriage", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 0.72), Vector2(0.12, 0.7)]), 24, false, true, 40.0)
		for s: float in [-1.0, 1.0]:
			k.body.add_prism(PackedVector2Array([Vector2(-0.6, 0.1), Vector2(0.9, 0.1), Vector2(0.7, 1.35), Vector2(0.05, 1.45), Vector2(-0.45, 0.9)]), 0.05, 0.0, 0.0, 15.0, s * 0.42)
			VehicleKit.box(k.dark, Vector3(s * 0.95, 0.58, 0.15), Vector3(0.34, 0.06, 0.3))
			var hw := PackedVector3Array()
			for i in 13:
				var ang := float(i) / 12.0 * TAU
				hw.append(Vector3(s * 0.62, 0.95 + cos(ang) * 0.15, -0.2 + sin(ang) * 0.15))
			k.metal.add_tube(hw, 0.015, 4)
			VehicleKit.cyl(k.dark, Vector3(s * 0.55, 0.2, -0.55), Vector3(s * 0.55, 1.15, -0.45), 0.09, 10)
			VehicleKit.crew(k, Vector3(s * 0.95, 0.12, 0.42), 0.0, true, "de")
		VehicleKit.cbox(k.body, Vector3(0.92, 0.85, -0.7), Vector3(0.3, 0.5, 0.4), 0.03)
	)
	var pivot := a.node(turret, "GunPivot", Vector3(0.0, 1.3, 0.3))
	a.out["gun_pivot"] = pivot
	a.mesh(pivot, "Gun", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		VehicleKit.cbox(k.body, Vector3(0.0, -0.06, 0.05), Vector3(0.34, 0.32, 2.0), 0.04)
		VehicleKit.cyl(k.dark, Vector3(-0.45, 0.0, 0.0), Vector3(0.45, 0.0, 0.0), 0.08, 10)
		VehicleKit.cbox(k.body, Vector3(0.0, 0.0, 0.95), Vector3(0.38, 0.4, 0.4), 0.03)
		VehicleKit.cyl(k.gun, Vector3(0.0, 0.2, 0.8), Vector3(0.0, 0.2, -1.2), 0.07, 10)
		VehicleKit.cyl(k.gun, Vector3(0.0, -0.22, 0.6), Vector3(0.0, -0.22, -0.9), 0.06, 10)
		VehicleKit.barrel(k, Vector3(0.0, 0.0, -0.9), 4.3, 0.12, 0.078, "", 16)
	)
	a.out["muzzles"] = [a.node(pivot, "Muzzle", Vector3(0.0, 0.0, -5.25))]


# --- 85-мм 52-К (СССР) ---------------------------------------------------------------------------------------------------
## Зенитная пушка обр. 1939 г. на четырёхколёсной повозке ЗУ-8 с выносными опорами (колёса приподняты),
## крупный накатник над стволом, пружинные уравновешивающие механизмы, многощелевой дульный тормоз.
static func _k52(a: ModelAsm) -> void:
	var root := a.root
	a.mesh(root, "Base", func(k: VehicleKit) -> void:
		_gun_emplacement(k, "su", true)
	)
	var turret := a.node(root, "Turret", Vector3(0.0, 1.0, 0.0))
	a.out["turret"] = turret
	a.mesh(turret, "Carriage", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 0.7), Vector2(0.14, 0.68)]), 24, false, true, 40.0)
		for s: float in [-1.0, 1.0]:
			k.body.add_prism(PackedVector2Array([Vector2(-0.5, 0.12), Vector2(0.8, 0.12), Vector2(0.55, 1.3), Vector2(-0.05, 1.35), Vector2(-0.4, 0.8)]), 0.05, 0.0, 0.0, 15.0, s * 0.4)
			VehicleKit.cyl(k.body, Vector3(s * 0.62, 0.15, -0.35), Vector3(s * 0.62, 1.1, -0.25), 0.12, 12)
			VehicleKit.box(k.dark, Vector3(s * 0.92, 0.6, 0.2), Vector3(0.32, 0.06, 0.3))
			VehicleKit.crew(k, Vector3(s * 0.92, 0.14, 0.45), 0.0, true, "su")
	)
	var pivot := a.node(turret, "GunPivot", Vector3(0.0, 1.25, 0.2))
	a.out["gun_pivot"] = pivot
	a.mesh(pivot, "Gun", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		VehicleKit.cbox(k.body, Vector3(0.0, -0.05, 0.1), Vector3(0.32, 0.3, 1.9), 0.04)
		VehicleKit.cyl(k.dark, Vector3(-0.43, 0.0, 0.0), Vector3(0.43, 0.0, 0.0), 0.08, 10)
		VehicleKit.cbox(k.body, Vector3(0.0, 0.0, 0.9), Vector3(0.36, 0.38, 0.4), 0.03)
		VehicleKit.cyl(k.body, Vector3(0.0, 0.24, 0.75), Vector3(0.0, 0.24, -1.7), 0.1, 14)
		VehicleKit.barrel(k, Vector3(0.0, 0.0, -0.8), 4.4, 0.11, 0.07, "multi", 16)
	)
	a.out["muzzles"] = [a.node(pivot, "Muzzle", Vector3(0.0, 0.0, -5.28))]
