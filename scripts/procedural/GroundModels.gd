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
				VehicleKit.box(k.dark, Vector3(s * 1.335, 0.33, -0.55 + float(i) * 0.95), Vector3(0.02, 0.36, 0.62))
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
