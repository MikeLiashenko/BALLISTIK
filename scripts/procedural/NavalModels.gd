class_name NavalModels
extends RefCounted
## Процедурные модели катеров и кораблей (размеры по реальным образцам, метры; -Z — вперёд, начало координат —
## на ватерлинии под миделем). Корпус строится генератором по обводам (_hull): седловатость палубы, полубак,
## наклонный форштевень со скруглённым подъёмом киля, развал бортов в носу, U-образный мидель, подъём
## днища к транцу; у глиссирующих катеров — скуловой излом и килеватость. Надстройки — блоки с наклонными
## стенками, вооружение — отдельные поворотные узлы. Модель возвращает узлы для механики:
##  * "hull" — узел качки; "main"/"aa"/"mounts" — установки [{"yaw", "pitch", "muzzles", "arc", "rest"}];
##  * "torpedo_mounts" / "torpedo_tubes", "sam_points", "special_points", "wake_points", "radars".

const NAVY_HAZE := Color(0.53, 0.56, 0.59)

const PAINT := {
	"fletcher": {"mode": "naval", "pattern": 5, "a": Color(0.5, 0.53, 0.56), "b": Color(0.2, 0.24, 0.32), "measure": 4.6, "deck": Color(0.22, 0.25, 0.31), "rough": 0.7, "wear": 0.45, "rust": 0.3, "panel_strength": 0.25},
	"burke": {"mode": "naval", "pattern": 0, "a": Color(0.53, 0.56, 0.59), "deck": Color(0.25, 0.26, 0.28), "rough": 0.68, "rust": 0.18, "wear": 0.35, "panel_strength": 0.18},
	"sovremenny": {"mode": "naval", "pattern": 0, "a": Color(0.56, 0.58, 0.59), "deck": Color(0.3, 0.29, 0.28), "rough": 0.7, "rust": 0.35, "wear": 0.45, "panel_strength": 0.22},
	"gnevny": {"mode": "naval", "pattern": 0, "a": Color(0.5, 0.52, 0.53), "deck": Color(0.33, 0.3, 0.27), "rough": 0.72, "rust": 0.4, "wear": 0.5, "panel_strength": 0.25, "rivets": 0.3},
	"molniya": {"mode": "naval", "pattern": 0, "a": Color(0.56, 0.58, 0.6), "deck": Color(0.31, 0.3, 0.29), "rough": 0.7, "rust": 0.3, "wear": 0.45, "panel_strength": 0.2},
	"ticonderoga": {"mode": "naval", "pattern": 0, "a": Color(0.53, 0.56, 0.59), "deck": Color(0.25, 0.26, 0.28), "rough": 0.68, "rust": 0.2, "wear": 0.35, "panel_strength": 0.18},
	"slava": {"mode": "naval", "pattern": 0, "a": Color(0.56, 0.58, 0.59), "deck": Color(0.3, 0.29, 0.28), "rough": 0.7, "rust": 0.35, "wear": 0.45, "panel_strength": 0.22},
	"cleveland": {"mode": "naval", "pattern": 5, "a": Color(0.5, 0.53, 0.56), "b": Color(0.2, 0.24, 0.32), "measure": 6.2, "deck": Color(0.22, 0.25, 0.31), "rough": 0.7, "wear": 0.45, "rust": 0.3, "panel_strength": 0.25},
	"kirov26": {"mode": "naval", "pattern": 0, "a": Color(0.5, 0.52, 0.53), "deck": Color(0.33, 0.3, 0.27), "rough": 0.72, "rust": 0.4, "wear": 0.5, "panel_strength": 0.25, "rivets": 0.3},
	"g5": {"mode": "naval", "pattern": 0, "a": Color(0.5, 0.53, 0.54), "deck": Color(0.42, 0.44, 0.45), "rough": 0.55, "metal": 0.25, "rust": 0.15, "wear": 0.4, "panel_strength": 0.3, "rivets": 0.6, "panel": 0.5},
	"sboot": {"mode": "naval", "pattern": 5, "a": Color(0.62, 0.64, 0.65), "b": Color(0.38, 0.4, 0.42), "measure": 1.1, "deck": Color(0.36, 0.37, 0.38), "rough": 0.65, "rust": 0.3, "wear": 0.45, "panel_strength": 0.2, "panel": 0.5},
	"pt109": {"mode": "naval", "pattern": 0, "a": Color(0.2, 0.25, 0.18), "deck": Color(0.17, 0.2, 0.15), "rough": 0.7, "rust": 0.05, "wear": 0.45, "panel_strength": 0.12, "panel": 0.4},
	"seababy": {"mode": "naval", "pattern": 0, "a": Color(0.2, 0.21, 0.23), "deck": Color(0.14, 0.15, 0.16), "rough": 0.6, "rust": 0.0, "wear": 0.3, "panel_strength": 0.1, "panel": 0.35},
	"markvi": {"mode": "naval", "pattern": 0, "a": Color(0.53, 0.56, 0.59), "deck": Color(0.25, 0.26, 0.28), "rough": 0.62, "rust": 0.1, "wear": 0.3, "panel_strength": 0.15, "panel": 0.45},
	"cb90": {"mode": "naval", "pattern": 2, "a": Color(0.3, 0.35, 0.25), "b": Color(0.16, 0.2, 0.14), "c": Color(0.08, 0.08, 0.08), "scale": 0.9, "deck": Color(0.18, 0.21, 0.16), "rough": 0.68, "rust": 0.05, "wear": 0.35, "panel_strength": 0.12, "panel": 0.4},
}


static func has_model(type_id: String) -> bool:
	return PAINT.has(type_id)


static func build(type_id: String, team: int) -> Dictionary:
	var a := ModelAsm.new(type_id, team, PAINT[type_id])
	match type_id:
		"fletcher":
			_fletcher(a)
		"burke":
			_burke(a)
		"sovremenny":
			_sovremenny(a)
		"gnevny":
			_gnevny(a)
		"molniya":
			_molniya(a)
		"ticonderoga":
			_ticonderoga(a)
		"slava":
			_slava(a)
		"cleveland":
			_cleveland(a)
		"kirov26":
			_kirov26(a)
		"g5":
			_g5(a)
		"sboot":
			_sboot(a)
		"pt109":
			_pt109(a)
		"seababy":
			_seababy(a)
		"markvi":
			_markvi(a)
		"cb90":
			_cb90(a)
	return a.finish()


# === Корпус по обводам ==========================================================================================
## Высота палубы над ватерлинией на относительной длине s (0 — форштевень, 1 — транец).
static func _deck_y(p: Dictionary, s: float) -> float:
	var y := float(p["D"]) + float(p.get("bow_sheer", 1.0)) * pow(1.0 - smoothstep(0.0, 0.45, s), 1.6) + float(p.get("stern_sheer", 0.0)) * smoothstep(0.55, 1.0, s)
	var fc: Array = p.get("fc", [])
	if fc.size() == 2:
		y += float(fc[1]) * (1.0 - smoothstep(float(fc[0]) - 0.004, float(fc[0]) + 0.004, s))
	return y


## Полуширина по палубе.
static func _half_beam(p: Dictionary, s: float) -> float:
	var hb := float(p["B"]) * 0.5
	var entry := float(p.get("entry", 0.35))
	var run := float(p.get("run_beam", 0.72))
	var blunt := float(p.get("bow_blunt", 0.0))
	var f := 1.0
	if s < entry:
		f = blunt + (1.0 - blunt) * pow(sin(PI * 0.5 * s / entry), float(p.get("bow_fine", 1.0)))
	elif s > run:
		f = lerpf(1.0, float(p.get("transom", 0.8)), smoothstep(run, 1.0, s))
	return hb * maxf(f, 0.0)


## Высота киля (отрицательная — под водой): скруглённый подъём к форштевню и подъём днища к транцу.
static func _keel_y(p: Dictionary, s: float) -> float:
	var t_draft := float(p["T"])
	var ff := float(p.get("forefoot", 0.1))
	if s < ff:
		var t := s / ff
		var top := _deck_y(p, 0.0) - 0.25
		return lerpf(top, -t_draft, 1.0 - pow(1.0 - t, float(p.get("stem_curve", 2.2))))
	var run := float(p.get("run", 0.7))
	if s > run:
		return lerpf(-t_draft, -t_draft * float(p.get("stern_rise", 0.3)), smoothstep(run, 1.0, s))
	return -t_draft


## Сечение корпуса на s: полупрофиль от киля вверх по правому борту и по палубе к диаметральной плоскости.
static func _section(p: Dictionary, s: float, s_wl: float) -> PackedVector2Array:
	var nu := 8
	var nt := 6
	var yd := _deck_y(p, s)
	var yk := _keel_y(p, s)
	var bd := _half_beam(p, s)
	var entry := float(p.get("entry", 0.35))
	var e_top := lerpf(float(p.get("bow_flare_exp", 0.8)), float(p.get("mid_flare_exp", 1.6)), smoothstep(0.0, entry, s))
	var flare := float(p.get("flare", 0.18)) * (1.0 - smoothstep(0.0, entry * 1.1, s))
	var bw := bd * (1.0 - flare) * smoothstep(s_wl, s_wl + float(p.get("wl_entry", 0.05)), s)
	var n := lerpf(float(p.get("n_bow", 1.6)), float(p.get("n_mid", 3.2)), smoothstep(0.0, entry * 1.3, s))
	n = lerpf(n, float(p.get("n_stern", 3.6)), smoothstep(float(p.get("run", 0.7)), 1.0, s))
	var pts := PackedVector2Array()
	if yk >= 0.0:
		# Оконечность выше воды: клин от киля до кромки палубы.
		for i in nu:
			pts.append(Vector2(0.0, yk))
		for i in range(1, nt + 1):
			var t := float(i) / float(nt)
			pts.append(Vector2(bd * pow(t, e_top), lerpf(yk, yd, t)))
	elif bool(p.get("chine", false)):
		# Глиссирующий корпус: прямая килеватость до скулы, затем борт.
		var dr := deg_to_rad(lerpf(float(p.get("deadrise_bow", 38.0)), float(p.get("deadrise", 14.0)), smoothstep(0.0, 0.55, s)))
		var bc := bd * float(p.get("chine_in", 0.94))
		var yc := minf(yk + tan(dr) * bc, yd - 0.12)
		for i in nu:
			var t := float(i) / float(nu - 1)
			pts.append(Vector2(bc * t, lerpf(yk, yc, t) - sin(t * PI) * 0.015 * bc))
		for i in range(1, nt + 1):
			var t := float(i) / float(nt)
			pts.append(Vector2(bc + (bd - bc) * pow(t, 0.9), lerpf(yc, yd, t)))
	else:
		for i in nu:
			var th := float(i) / float(nu - 1) * PI * 0.5
			pts.append(Vector2(bw * pow(sin(th), 2.0 / n), yk * pow(cos(th), 2.0 / n)))
		for i in range(1, nt + 1):
			var t := float(i) / float(nt)
			pts.append(Vector2(bw + (bd - bw) * pow(t, e_top), yd * t))
	var camber := float(p.get("camber", 0.25))
	for phi_deg: float in [28.0, 58.0, 90.0]:
		var phi := deg_to_rad(phi_deg)
		pts.append(Vector2(bd * cos(phi), yd + camber * sin(phi)))
	return pts


## Корпус: лофт по сечениям (гладкие обводы, острые кромки палубы и скулы), транец закрыт.
static func _hull(k: VehicleKit, p: Dictionary) -> void:
	var length := float(p["L"])
	var ff := float(p.get("forefoot", 0.1))
	var lo := 0.0
	var hi := ff
	for i in 30:
		var mid := (lo + hi) * 0.5
		if _keel_y(p, mid) > 0.0:
			lo = mid
		else:
			hi = mid
	var s_wl := hi
	var n := int(p.get("stations", maxi(40, int(length / 1.6))))
	var stations: Array = []
	for i in n + 1:
		var s := 0.5 - 0.5 * cos(PI * float(i) / float(n))
		stations.append([-length * 0.5 + s * length, _section(p, s, s_wl)])
	k.part(VehicleKit.P_HULL)
	k.body.add_sections(stations, 38.0, true, true, true)


## Высота палубы в точке (x, z) с учётом погиби.
static func _deck_at(p: Dictionary, z: float, x: float = 0.0) -> float:
	var s := clampf((z + float(p["L"]) * 0.5) / float(p["L"]), 0.0, 1.0)
	var bd := maxf(_half_beam(p, s), 0.01)
	var c := clampf(absf(x) / bd, 0.0, 1.0)
	return _deck_y(p, s) + float(p.get("camber", 0.25)) * sqrt(1.0 - c * c)


## Полуширина палубы в точке z.
static func _beam_at(p: Dictionary, z: float) -> float:
	var s := clampf((z + float(p["L"]) * 0.5) / float(p["L"]), 0.0, 1.0)
	return _half_beam(p, s)


## Леерное ограждение по кромке палубы от z0 до z1 (оба борта).
static func _deck_rails(k: VehicleKit, p: Dictionary, z0: float, z1: float, step: float = 2.0) -> void:
	for side: float in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		var z := z0
		while z <= z1 + 0.01:
			var bd := _beam_at(p, z) - 0.15
			pts.append(Vector3(side * bd, _deck_at(p, z, bd), z))
			z += step
		VehicleKit.railing(k.metal, pts, 1.0, 1.8, 0.02)


## Кнехты, вьюшки и якорные клюзы на баке.
static func _fittings(k: VehicleKit, p: Dictionary, z_anchor: float) -> void:
	var length := float(p["L"])
	for side: float in [-1.0, 1.0]:
		var bd := _beam_at(p, z_anchor)
		var y := _deck_at(p, z_anchor, bd) - 1.2
		k.dark.add_disc(Vector3(side * (bd + 0.02), y, z_anchor), Vector3(side, 0.0, -0.3), 0.45, 12)
		for zz: float in [-length * 0.36, -length * 0.1, length * 0.15, length * 0.38]:
			var bz := _beam_at(p, zz) - 0.6
			var yy := _deck_at(p, zz, bz)
			for dz: float in [-0.3, 0.3]:
				VehicleKit.cyl(k.dark, Vector3(side * bz, yy, zz + dz), Vector3(side * bz, yy + 0.4, zz + dz), 0.14, 8)
	var yc := _deck_at(p, z_anchor + 3.0)
	for side: float in [-1.0, 1.0]:
		VehicleKit.cyl(k.dark, Vector3(side * 1.1, yc, z_anchor + 3.0), Vector3(side * 1.1, yc + 0.5, z_anchor + 3.0), 0.4, 14)
		k.dark.add_tube(PackedVector3Array([Vector3(side * 1.1, yc + 0.1, z_anchor + 3.0), Vector3(side * 1.6, yc + 0.08, z_anchor + 1.2), Vector3(side * (_beam_at(p, z_anchor) - 0.4), yc + 0.05, z_anchor)]), 0.08, 5)


## Иллюминаторы вдоль бортов.
static func _portholes(k: VehicleKit, p: Dictionary, z0: float, z1: float, y_below_deck: float, step: float = 2.4) -> void:
	for side: float in [-1.0, 1.0]:
		var z := z0
		while z <= z1:
			var bd := _beam_at(p, z)
			var y := _deck_at(p, z, bd) - y_below_deck
			if y > 1.0:
				k.dark.add_disc(Vector3(side * (bd + 0.01), y, z), Vector3(side, 0.0, 0.0), 0.2, 8)
			z += step


# === Надстройки и детали ========================================================================================
## Рубка/надстройка: план (x, z) с фасками, от y0 до y1, стенки наклонены внутрь на inset.
static func _house(k: VehicleKit, w: float, d: float, cz: float, y0: float, y1: float, chamfer: float = 0.8, inset: float = 0.15, part: float = VehicleKit.P_UPPER, cx: float = 0.0) -> void:
	k.part(part)
	k.body.add_block(VehicleKit.chamfer_rect(w, d, chamfer, cz, cx), y0, y1, inset, true, false, 10.0)
	k.part(VehicleKit.P_HULL)


## Окна на гранях надстройки, построенной _house с теми же w, d, cz, y0, y1, chamfer, inset: полоса окон
## по высоте от b0 до b1 (м над y0); front/sides/back — число окон на лобовой, каждой боковой и кормовой грани.
static func _house_windows(k: VehicleKit, w: float, d: float, cz: float, y0: float, y1: float, chamfer: float, inset: float, b0: float, b1: float, front: int, sides: int = 0, back: int = 0) -> void:
	var h := maxf(y1 - y0, 0.01)
	var ta := b0 / h
	var tb := b1 / h
	var lean := inset / h
	var mit := 0.41 * inset
	for f: float in [-1.0, 1.0]:
		var count := front if f < 0.0 else back
		if count <= 0:
			continue
		var hw_a := w * 0.5 - chamfer - mit * ta - 0.15
		var hw_b := w * 0.5 - chamfer - mit * tb - 0.15
		var za := cz + f * (d * 0.5 - inset * ta + 0.02)
		var zb := cz + f * (d * 0.5 - inset * tb + 0.02)
		var nrm := Vector3(0.0, lean, f).normalized()
		for i in count:
			var u0 := (float(i) + 0.08) / float(count)
			var u1 := (float(i) + 0.92) / float(count)
			k.glass.add_polygon(PackedVector3Array([
				Vector3(lerpf(-hw_a, hw_a, u0), y0 + b0, za), Vector3(lerpf(-hw_a, hw_a, u1), y0 + b0, za),
				Vector3(lerpf(-hw_b, hw_b, u1), y0 + b1, zb), Vector3(lerpf(-hw_b, hw_b, u0), y0 + b1, zb),
			]), nrm)
	if sides <= 0:
		return
	for s: float in [-1.0, 1.0]:
		var xa := s * (w * 0.5 - inset * ta + 0.02)
		var xb := s * (w * 0.5 - inset * tb + 0.02)
		var z0 := cz - d * 0.5 + chamfer + mit + 0.2
		var z1 := cz + d * 0.5 - chamfer - mit - 0.2
		var nrm := Vector3(s, lean, 0.0).normalized()
		for i in sides:
			var u0 := (float(i) + 0.1) / float(sides)
			var u1 := (float(i) + 0.9) / float(sides)
			k.glass.add_polygon(PackedVector3Array([
				Vector3(xa, y0 + b0, lerpf(z0, z1, u0)), Vector3(xa, y0 + b0, lerpf(z0, z1, u1)),
				Vector3(xb, y0 + b1, lerpf(z0, z1, u1)), Vector3(xb, y0 + b1, lerpf(z0, z1, u0)),
			]), nrm)


## Дымовая труба: план скруглённый прямоугольник w × d, высота h от base, завал назад rake (град), сажа сверху.
static func _funnel(k: VehicleKit, base: Vector3, w: float, d: float, h: float, rake: float = 6.0, cap: bool = true) -> void:
	var old := k.body.xform
	k.body.xform = old * Transform3D(Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(rake)), base)
	var plan := VehicleKit.rounded_rect(w, d, minf(w, d) * 0.45, 3)
	k.part(VehicleKit.P_UPPER)
	k.body.add_block(plan, 0.0, h - 0.8, 0.0, false, false, 30.0)
	k.part(VehicleKit.P_SOOT if cap else VehicleKit.P_UPPER)
	k.body.add_block(plan, h - 0.8, h, -0.05, false, false, 30.0)
	var inner := PackedVector3Array()
	for pnt in VehicleKit.rounded_rect(w * 0.86, d * 0.86, minf(w, d) * 0.4, 3):
		inner.append(Vector3(pnt.x, h - 0.5, pnt.y))
	k.part(VehicleKit.P_SOOT)
	k.body.add_polygon(inner, Vector3.UP)
	k.part(VehicleKit.P_HULL)
	k.body.xform = old


## Мачта-шест с конусностью и реями.
static func _pole(k: VehicleKit, base: Vector3, h: float, r: float, yards: Array = []) -> void:
	k.metal.add_tube(PackedVector3Array([base, base + Vector3.UP * h]), r, 8, true, r * 0.4)
	for yd: Vector2 in yards:
		k.metal.add_tube(PackedVector3Array([base + Vector3(-yd.y * 0.5, yd.x, 0.0), base + Vector3(yd.y * 0.5, yd.x, 0.0)]), r * 0.35, 5)


## Треногая мачта: основная стойка и две подкосные ноги назад-в-стороны.
static func _tripod(k: VehicleKit, base: Vector3, h: float, spread: float, r: float, rake: float = 4.0) -> Vector3:
	var top := base + Vector3(0.0, h, deg_to_rad(rake) * h)
	k.metal.add_tube(PackedVector3Array([base, top]), r, 8, false, r * 0.7)
	for side: float in [-1.0, 1.0]:
		k.metal.add_tube(PackedVector3Array([base + Vector3(side * spread, 0.0, spread * 0.8), top - Vector3(0.0, h * 0.25, 0.0)]), r * 0.7, 6)
	return top


## Шлюпка на шлюпбалках (борт side): корпус-лофт, тент, балки.
static func _boat_davit(k: VehicleKit, pos: Vector3, side: float, length: float = 7.5) -> void:
	var st: Array = []
	var hw := length * 0.14
	for i in 7:
		var t := float(i) / 6.0
		var w := hw * sin(PI * clampf(t * 1.05 + 0.02, 0.0, 1.0))
		st.append([pos.z - length * 0.5 + length * t, PackedVector2Array([Vector2(0.0, -0.55), Vector2(w * 0.7, -0.45), Vector2(w, -0.1), Vector2(w, 0.2), Vector2(w * 0.5, 0.26), Vector2(0.0, 0.28)])])
	var old := k.body.xform
	k.body.xform = old * Transform3D(Basis(), Vector3(pos.x, pos.y, 0.0))
	k.part(VehicleKit.P_WHITE)
	k.body.add_sections(st, 40.0, true, true, true)
	k.part(VehicleKit.P_HULL)
	k.body.xform = old
	for dz: float in [-length * 0.35, length * 0.35]:
		k.metal.add_tube(PackedVector3Array([Vector3(pos.x - side * 1.2, pos.y - 1.6, pos.z + dz), Vector3(pos.x - side * 0.9, pos.y + 1.2, pos.z + dz), Vector3(pos.x + side * 0.1, pos.y + 1.3, pos.z + dz)]), 0.07, 6)


## Спасательные плоты в контейнерах (белые цилиндры) на стеллаже.
static func _liferafts(k: VehicleKit, pos: Vector3, count: int, side: float) -> void:
	k.part(VehicleKit.P_WHITE)
	for i in count:
		var p := pos + Vector3(0.0, 0.0, float(i) * 0.75)
		VehicleKit.cyl(k.body, p + Vector3(-0.35, 0.0, 0.0), p + Vector3(0.35, 0.0, 0.0), 0.3, 10)
	k.part(VehicleKit.P_HULL)
	VehicleKit.box(k.dark, pos + Vector3(side * 0.1, -0.32, float(count - 1) * 0.375), Vector3(0.8, 0.06, float(count) * 0.75))


## Центры крышек ячеек вертикального пуска: сетка cols × rows вокруг center (на палубе).
static func _vls_cells(center: Vector3, cols: int, rows: int, cell: float = 0.63) -> Array[Vector3]:
	var cells: Array[Vector3] = []
	for c in cols:
		for r in rows:
			cells.append(center + Vector3((float(c) - float(cols - 1) * 0.5) * cell, 0.09, (float(r) - float(rows - 1) * 0.5) * cell))
	return cells


## Установка вертикального пуска: рама и крышки ячеек.
static func _vls(k: VehicleKit, center: Vector3, cols: int, rows: int, cell: float = 0.63) -> void:
	VehicleKit.box(k.dark, center + Vector3(0.0, 0.03, 0.0), Vector3(float(cols) * cell + 0.3, 0.06, float(rows) * cell + 0.3))
	for p in _vls_cells(center, cols, rows, cell):
		VehicleKit.cbox(k.body, p, Vector3(cell * 0.86, 0.05, cell * 0.86), 0.02)


## Плоская восьмиугольная ФАР (SPY-1) по нормали normal: панель чуть темнее надстройки и тёмная окантовка.
static func _phased_panel(k: VehicleKit, center: Vector3, normal: Vector3, radius: float) -> void:
	var n := normal.normalized()
	var old := k.body.xform
	k.body.xform = old * Transform3D(VehicleKit.basis_y(n), center)
	k.part(VehicleKit.P_INTERIOR)
	k.body.add_lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, radius), Vector2(0.07, radius * 1.02), Vector2(0.09, 0.0)]), 8, false, false, 20.0, PI / 8.0)
	k.part(VehicleKit.P_HULL)
	k.body.xform = old
	var od := k.dark.xform
	k.dark.xform = od * Transform3D(VehicleKit.basis_y(n), center + n * 0.095)
	k.dark.add_lathe(PackedVector2Array([Vector2(0.0, radius * 1.02), Vector2(0.0, radius * 0.94)]), 8, false, false, 20.0, PI / 8.0)
	k.dark.xform = od


## Белый палубный круг вертолётной площадки и осевая линия.
static func _helipad(k: VehicleKit, center: Vector3, radius: float, length: float) -> void:
	k.part(VehicleKit.P_WHITE)
	var old := k.body.xform
	k.body.xform = old * Transform3D(Basis(), center + Vector3.UP * 0.03)
	k.body.add_lathe(PackedVector2Array([Vector2(0.0, radius + 0.25), Vector2(0.0, radius)]), 40, false, false, 10.0)
	k.body.xform = old
	k.body.add_box(center + Vector3(0.0, 0.03, 0.0), Vector3(0.3, 0.01, length))
	k.part(VehicleKit.P_HULL)


# === Корабельное вооружение (поворотные узлы) ====================================================================
## Установка: узел азимута на pos (rest — исходный разворот), корпус установки, узел угла места, стволы.
static func _mount(a: ModelAsm, parent: Node3D, part: String, pos: Vector3, house: Callable, gun: Callable, pivot: Vector3, muzzles: Array, arc: Vector2 = Vector2(-180.0, 180.0), rest: float = 0.0) -> Dictionary:
	var yaw := a.node(parent, part, pos)
	yaw.rotation.y = rest
	a.mesh(yaw, part + "House", house)
	var pitch := a.node(yaw, part + "Pivot", pivot)
	a.mesh(pitch, part + "Gun", gun)
	var mz: Array[Node3D] = []
	for m: Vector3 in muzzles:
		mz.append(a.node(pitch, "Muzzle", m))
	return {"yaw": yaw, "pitch": pitch, "muzzles": mz, "arc": arc, "rest": rest}


## 127-мм 5"/38 Mk 30: закрытая одноорудийная установка эсминцев US Navy.
static func _gun_5in38(a: ModelAsm, parent: Node3D, pos: Vector3, arc: Vector2, rest: float) -> Dictionary:
	return _mount(a, parent, "Mk30", pos, func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 1.55), Vector2(0.32, 1.5)]), 28, false, true, 40.0)
		k.body.add_prism(PackedVector2Array([Vector2(-1.9, 0.3), Vector2(2.3, 0.3), Vector2(2.3, 2.3), Vector2(-0.7, 2.45), Vector2(-1.95, 1.75)]), 1.5, 0.07, 0.3)
		for s: float in [-1.0, 1.0]:
			VehicleKit.cbox(k.body, Vector3(s * 0.8, 2.55, -0.3), Vector3(0.45, 0.28, 0.8), 0.06)
			k.glass.add_box(Vector3(s * 0.8, 2.57, -0.71), Vector3(0.3, 0.12, 0.01))
			k.metal.add_tube(PackedVector3Array([Vector3(s * 1.45, 1.0, 1.2), Vector3(s * 1.45, 1.9, 1.2)]), 0.03, 4)
		VehicleKit.box(k.dark, Vector3(0.0, 1.3, 2.31), Vector3(0.9, 1.6, 0.03))
		VehicleKit.box(k.dark, Vector3(0.0, 1.25, -1.93), Vector3(0.5, 0.9, 0.05))
	, func(k: VehicleKit) -> void:
		k.dark.xform = VehicleKit.forward_xform(Vector3(0.0, 0.0, -0.5))
		k.dark.add_lathe(PackedVector2Array([Vector2(0.0, 0.34), Vector2(0.35, 0.2)]), 12, true, false, 40.0)
		k.dark.xform = Transform3D.IDENTITY
		VehicleKit.barrel(k, Vector3(0.0, 0.0, -0.6), 4.8, 0.16, 0.085, "", 14)
	, Vector3(0.0, 1.25, -1.3), [Vector3(0.0, 0.0, -5.5)], arc, rest)


## 127-мм Mk 45 Mod 4: гранёный малозаметный щит, длинный ствол 62 калибра.
static func _gun_mk45(a: ModelAsm, parent: Node3D, pos: Vector3, arc: Vector2, rest: float) -> Dictionary:
	return _mount(a, parent, "Mk45", pos, func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 1.9), Vector2(0.3, 1.85)]), 28, false, true, 40.0)
		k.body.add_prism(PackedVector2Array([Vector2(-2.3, 0.3), Vector2(2.1, 0.3), Vector2(2.2, 1.3), Vector2(1.2, 2.35), Vector2(-1.1, 2.35), Vector2(-2.35, 1.0)]), 1.7, 0.26, 0.3)
		VehicleKit.box(k.dark, Vector3(0.0, 1.05, -2.1), Vector3(0.55, 0.9, 0.2), Vector3(-30.0, 0.0, 0.0))
	, func(k: VehicleKit) -> void:
		VehicleKit.barrel(k, Vector3(0.0, 0.0, -0.4), 7.9, 0.15, 0.09, "", 14)
	, Vector3(0.0, 1.3, -1.7), [Vector3(0.0, 0.0, -8.4)], arc, rest)


## Спаренная 130-мм АК-130: крупная башня с двумя стволами.
static func _gun_ak130(a: ModelAsm, parent: Node3D, pos: Vector3, arc: Vector2, rest: float) -> Dictionary:
	return _mount(a, parent, "AK130", pos, func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 2.6), Vector2(0.35, 2.55)]), 32, false, true, 40.0)
		k.body.add_prism(PackedVector2Array([Vector2(-2.9, 0.35), Vector2(3.0, 0.35), Vector2(3.1, 2.4), Vector2(2.4, 2.8), Vector2(-1.3, 2.9), Vector2(-3.0, 1.55)]), 2.3, 0.12, 0.35)
		VehicleKit.box(k.dark, Vector3(0.0, 1.4, -2.92), Vector3(2.2, 1.0, 0.1), Vector3(-38.0, 0.0, 0.0))
		for s: float in [-1.0, 1.0]:
			VehicleKit.cbox(k.body, Vector3(s * 1.5, 3.0, 0.2), Vector3(0.6, 0.3, 1.2), 0.08)
		k.metal.add_tube(PackedVector3Array([Vector3(-1.8, 2.95, 2.4), Vector3(1.8, 2.95, 2.4)]), 0.03, 4)
	, func(k: VehicleKit) -> void:
		for s: float in [-1.0, 1.0]:
			VehicleKit.barrel(k, Vector3(s * 0.62, 0.0, -0.3), 7.0, 0.2, 0.1, "", 14)
			VehicleKit.cyl(k.gun, Vector3(s * 0.62, 0.0, -2.2), Vector3(s * 0.62, 0.0, -2.9), 0.19, 14)
	, Vector3(0.0, 1.55, -2.2), [Vector3(-0.62, 0.0, -7.4), Vector3(0.62, 0.0, -7.4)], arc, rest)


## ЗАК Phalanx CIWS: белый обтекатель РЛС над шестиствольной 20-мм пушкой.
static func _phalanx(a: ModelAsm, parent: Node3D, pos: Vector3, arc: Vector2 = Vector2(-180.0, 180.0), rest: float = 0.0) -> Dictionary:
	return _mount(a, parent, "Phalanx", pos, func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_WHITE)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 0.75), Vector2(0.55, 0.7), Vector2(0.62, 0.45), Vector2(0.75, 0.42)]), 20, false, true, 40.0)
		VehicleKit.cbox(k.body, Vector3(0.0, 0.95, 0.35), Vector3(0.9, 0.55, 0.9), 0.08)
	, func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_WHITE)
		k.body.add_lathe(PackedVector2Array([Vector2(0.05, 0.62), Vector2(0.5, 0.64), Vector2(0.95, 0.52), Vector2(1.25, 0.3), Vector2(1.38, 0.0)]), 20, true, false, 40.0)
		VehicleKit.cbox(k.body, Vector3(0.0, -0.05, 0.5), Vector3(0.7, 0.6, 1.0), 0.1)
		VehicleKit.cyl(k.gun, Vector3(0.0, -0.3, 0.0), Vector3(0.0, -0.3, -1.9), 0.13, 12)
		VehicleKit.cyl(k.dark, Vector3(0.0, -0.3, -1.6), Vector3(0.0, -0.3, -2.05), 0.16, 12)
	, Vector3(0.0, 0.85, 0.0), [Vector3(0.0, -0.3, -2.1)], arc, rest)


## ЗАК АК-630: компактная башня с шестиствольным 30-мм автоматом в кожухе.
static func _ak630(a: ModelAsm, parent: Node3D, pos: Vector3, arc: Vector2 = Vector2(-180.0, 180.0), rest: float = 0.0) -> Dictionary:
	return _mount(a, parent, "AK630", pos, func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 0.95), Vector2(0.25, 0.9)]), 20, false, true, 40.0)
		k.body.add_prism(PackedVector2Array([Vector2(-0.95, 0.2), Vector2(0.95, 0.2), Vector2(0.95, 1.1), Vector2(-0.5, 1.25), Vector2(-0.95, 0.85)]), 0.8, 0.12, 0.2)
	, func(k: VehicleKit) -> void:
		VehicleKit.cyl(k.gun, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.7), 0.15, 12)
		VehicleKit.cyl(k.dark, Vector3(0.0, 0.0, -1.45), Vector3(0.0, 0.0, -1.85), 0.18, 12)
	, Vector3(0.0, 0.7, -0.55), [Vector3(0.0, 0.0, -1.9)], arc, rest)


## Спаренный 40-мм «Бофорс» Mk 1 с полукруглым щитом и расчётом.
static func _bofors_twin(a: ModelAsm, parent: Node3D, pos: Vector3, arc: Vector2 = Vector2(-180.0, 180.0), rest: float = 0.0) -> Dictionary:
	return _mount(a, parent, "Bofors2", pos, func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 1.2), Vector2(0.4, 1.15)]), 20, false, true, 40.0)
		for i in 4:
			var ang := deg_to_rad(-60.0 + float(i) * 30.0)
			var ang2 := deg_to_rad(-60.0 + float(i + 1) * 30.0)
			var p0 := Vector3(sin(ang) * 1.25, 0.4, -cos(ang) * 1.25)
			var p1 := Vector3(sin(ang2) * 1.25, 0.4, -cos(ang2) * 1.25)
			k.body.add_polygon(PackedVector3Array([p0, p1, p1 + Vector3.UP * 0.9, p0 + Vector3.UP * 0.9]), (p0 + p1).normalized())
			k.body.add_polygon(PackedVector3Array([p1, p0, p0 + Vector3.UP * 0.9, p1 + Vector3.UP * 0.9]), -(p0 + p1).normalized())
		VehicleKit.crew(k, Vector3(-0.8, 0.4, 0.5), 0.0, true, "us")
		VehicleKit.crew(k, Vector3(0.8, 0.4, 0.5), 0.0, true, "us")
	, func(k: VehicleKit) -> void:
		VehicleKit.cbox(k.gun, Vector3(0.0, 0.0, 0.25), Vector3(0.8, 0.45, 1.1), 0.05)
		for s: float in [-1.0, 1.0]:
			VehicleKit.barrel(k, Vector3(s * 0.28, 0.0, -0.3), 2.4, 0.07, 0.045, "flash", 10)
			VehicleKit.cyl(k.gun, Vector3(s * 0.28, 0.0, -0.3), Vector3(s * 0.28, 0.0, -0.9), 0.1, 10)
			VehicleKit.box(k.dark, Vector3(s * 0.28, 0.35, 0.3), Vector3(0.14, 0.3, 0.22))
	, Vector3(0.0, 0.95, 0.0), [Vector3(-0.28, 0.0, -2.75), Vector3(0.28, 0.0, -2.75)], arc, rest)


## 130-мм Б-13: одноорудийная палубная установка с открытым сзади щитом.
static func _gun_b13(a: ModelAsm, parent: Node3D, pos: Vector3, arc: Vector2, rest: float) -> Dictionary:
	return _mount(a, parent, "B13", pos, func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 1.4), Vector2(0.3, 1.3)]), 24, false, true, 40.0)
		# Щит: наклонный лоб и борта, корма открыта.
		k.body.add_prism(PackedVector2Array([Vector2(-1.7, 0.3), Vector2(-1.55, 0.3), Vector2(-0.95, 2.35), Vector2(-1.1, 2.35)]), 1.35, 0.05, 0.3)
		for s: float in [-1.0, 1.0]:
			k.body.add_prism(PackedVector2Array([Vector2(-1.6, 0.3), Vector2(1.3, 0.3), Vector2(1.1, 2.1), Vector2(-1.0, 2.35)]), 0.03, 0.0, 0.0, 15.0, s * 1.33)
		k.body.add_prism(PackedVector2Array([Vector2(-1.1, 2.3), Vector2(0.6, 2.1), Vector2(0.6, 2.16), Vector2(-1.1, 2.36)]), 1.35)
		VehicleKit.box(k.dark, Vector3(0.0, 1.35, -1.34), Vector3(0.5, 0.9, 0.12), Vector3(-17.0, 0.0, 0.0))
		VehicleKit.crew(k, Vector3(-0.8, 0.3, 0.4), 0.0, false, "su")
		VehicleKit.crew(k, Vector3(0.7, 0.3, 0.8), 0.4, false, "su")
	, func(k: VehicleKit) -> void:
		VehicleKit.cbox(k.gun, Vector3(0.0, 0.0, 0.5), Vector3(0.5, 0.55, 1.5), 0.05)
		VehicleKit.barrel(k, Vector3(0.0, 0.0, -0.25), 6.3, 0.18, 0.1, "", 14)
	, Vector3(0.0, 1.2, -0.35), [Vector3(0.0, 0.0, -6.6)], arc, rest)


## 76-мм АК-176: компактная обтекаемая башня.
static func _gun_ak176(a: ModelAsm, parent: Node3D, pos: Vector3, arc: Vector2, rest: float) -> Dictionary:
	return _mount(a, parent, "AK176", pos, func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 1.45), Vector2(0.25, 1.4)]), 24, false, true, 40.0)
		k.body.add_prism(PackedVector2Array([Vector2(-1.45, 0.25), Vector2(1.5, 0.25), Vector2(1.5, 1.35), Vector2(0.9, 1.65), Vector2(-0.7, 1.65), Vector2(-1.45, 0.95)]), 1.2, 0.18, 0.25)
		VehicleKit.box(k.dark, Vector3(0.0, 0.85, -1.4), Vector3(0.36, 0.55, 0.12), Vector3(-40.0, 0.0, 0.0))
	, func(k: VehicleKit) -> void:
		VehicleKit.barrel(k, Vector3(0.0, 0.0, -0.3), 4.2, 0.11, 0.065, "", 12)
	, Vector3(0.0, 0.85, -0.9), [Vector3(0.0, 0.0, -4.55)], arc, rest)


## Одноорудийная зенитная установка со щитком (34-К, 21-К, B-34, Oerlikon): калибр задаёт размеры.
static func _aa_single(a: ModelAsm, parent: Node3D, pos: Vector3, part: String, scale: float, helmet: String, arc: Vector2 = Vector2(-180.0, 180.0), rest: float = 0.0) -> Dictionary:
	return _mount(a, parent, part, pos, func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 0.55 * scale), Vector2(0.7 * scale, 0.35 * scale), Vector2(0.75 * scale, 0.45 * scale)]), 16, false, true, 40.0)
		k.body.add_prism(PackedVector2Array([Vector2(-0.75, 0.6), Vector2(-0.68, 0.6), Vector2(-0.5, 1.5), Vector2(-0.57, 1.5)]), 0.75 * scale)
		VehicleKit.crew(k, Vector3(-0.55 * scale, 0.0, 0.35), 0.2, false, helmet)
	, func(k: VehicleKit) -> void:
		VehicleKit.cbox(k.gun, Vector3(0.0, 0.0, 0.25 * scale), Vector3(0.26 * scale, 0.3 * scale, 0.9 * scale), 0.03)
		VehicleKit.barrel(k, Vector3(0.0, 0.0, -0.2 * scale), 2.6 * scale, 0.07 * scale, 0.045 * scale, "flash", 10)
	, Vector3(0.0, 0.95 * scale, 0.0), [Vector3(0.0, 0.0, -2.9 * scale)], arc, rest)


## Трёхорудийная башня главного калибра крейсера: барбет, бронированная башня с дальномером, три ствола.
static func _turret_triple(a: ModelAsm, parent: Node3D, pos: Vector3, part: String, barrel_len: float, r0: float, r1: float, width: float, arc: Vector2, rest: float, barbette: float = 0.0) -> Dictionary:
	var hw := width * 0.5
	return _mount(a, parent, part, pos, func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		if barbette > 0.0:
			VehicleKit.cyl(k.body, Vector3(0.0, -barbette, 0.0), Vector3(0.0, 0.35, 0.0), hw * 0.95, 28)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, hw * 0.98), Vector2(0.35, hw * 0.95)]), 28, false, true, 40.0)
		k.body.add_prism(PackedVector2Array([Vector2(-hw * 1.05, 0.35), Vector2(hw * 1.3, 0.35), Vector2(hw * 1.3, hw * 0.78), Vector2(-hw * 0.5, hw * 0.82), Vector2(-hw * 1.1, hw * 0.55)]), hw, 0.08, 0.35)
		# Дальномер поперёк задней части башни.
		k.metal.add_tube(PackedVector3Array([Vector3(-hw * 1.18, hw * 0.72, hw * 0.55), Vector3(hw * 1.18, hw * 0.72, hw * 0.55)]), 0.22, 10)
		for s: float in [-1.0, 1.0]:
			VehicleKit.cyl(k.dark, Vector3(s * hw * 1.18, hw * 0.72, hw * 0.55), Vector3(s * hw * 1.24, hw * 0.72, hw * 0.55), 0.3, 10)
			VehicleKit.cbox(k.body, Vector3(s * hw * 0.5, hw * 0.86, -hw * 0.1), Vector3(0.5, 0.3, 0.9), 0.06)
		VehicleKit.box(k.dark, Vector3(0.0, hw * 0.45, -hw * 1.06), Vector3(width * 0.78, hw * 0.35, 0.1), Vector3(-25.0, 0.0, 0.0))
	, func(k: VehicleKit) -> void:
		for i in 3:
			var x := (float(i) - 1.0) * hw * 0.55
			VehicleKit.barrel(k, Vector3(x, 0.0, -0.2), barrel_len, r0, r1, "", 14)
			k.dark.xform = VehicleKit.forward_xform(Vector3(x, 0.0, -0.25))
			k.dark.add_lathe(PackedVector2Array([Vector2(0.0, r0 * 2.0), Vector2(0.4, r0 * 1.2)]), 12, true, false, 40.0)
			k.dark.xform = Transform3D.IDENTITY
	, Vector3(0.0, hw * 0.45, -hw * 0.95), [Vector3(-hw * 0.55, 0.0, -barrel_len - 0.4), Vector3(0.0, 0.0, -barrel_len - 0.4), Vector3(hw * 0.55, 0.0, -barrel_len - 0.4)], arc, rest)


## Спаренная универсальная 127-мм установка 5"/38 Mk 38 (крейсера US Navy).
static func _gun_5in38_twin(a: ModelAsm, parent: Node3D, pos: Vector3, arc: Vector2 = Vector2(-180.0, 180.0), rest: float = 0.0) -> Dictionary:
	return _mount(a, parent, "Mk38", pos, func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 2.1), Vector2(0.3, 2.0)]), 28, false, true, 40.0)
		k.body.add_prism(PackedVector2Array([Vector2(-2.1, 0.3), Vector2(2.6, 0.3), Vector2(2.6, 2.4), Vector2(-0.8, 2.5), Vector2(-2.15, 1.8)]), 2.0, 0.07, 0.3)
		for s: float in [-1.0, 1.0]:
			VehicleKit.cbox(k.body, Vector3(s * 1.2, 2.6, -0.4), Vector3(0.45, 0.28, 0.8), 0.06)
	, func(k: VehicleKit) -> void:
		for s: float in [-1.0, 1.0]:
			VehicleKit.barrel(k, Vector3(s * 0.7, 0.0, -0.4), 4.8, 0.15, 0.085, "", 12)
	, Vector3(0.0, 1.25, -1.5), [Vector3(-0.7, 0.0, -5.3), Vector3(0.7, 0.0, -5.3)], arc, rest)


## Счетверённый 40-мм «Бофорс» Mk 2 с щитом и расчётом.
static func _bofors_quad(a: ModelAsm, parent: Node3D, pos: Vector3, arc: Vector2 = Vector2(-180.0, 180.0), rest: float = 0.0) -> Dictionary:
	return _mount(a, parent, "Bofors4", pos, func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 1.6), Vector2(0.4, 1.55)]), 20, false, true, 40.0)
		k.body.add_prism(PackedVector2Array([Vector2(-1.75, 0.4), Vector2(-1.65, 0.4), Vector2(-1.5, 1.3), Vector2(-1.6, 1.3)]), 1.6)
		VehicleKit.crew(k, Vector3(-1.0, 0.4, 0.7), 0.0, true, "us")
		VehicleKit.crew(k, Vector3(1.0, 0.4, 0.7), 0.0, true, "us")
	, func(k: VehicleKit) -> void:
		VehicleKit.cbox(k.gun, Vector3(0.0, 0.0, 0.25), Vector3(1.6, 0.45, 1.1), 0.05)
		for x: float in [-0.66, -0.22, 0.22, 0.66]:
			VehicleKit.barrel(k, Vector3(x, 0.0, -0.3), 2.4, 0.07, 0.045, "flash", 10)
			VehicleKit.box(k.dark, Vector3(x, 0.35, 0.3), Vector3(0.14, 0.3, 0.22))
	, Vector3(0.0, 1.0, 0.0), [Vector3(-0.66, 0.0, -2.75), Vector3(-0.22, 0.0, -2.75), Vector3(0.22, 0.0, -2.75), Vector3(0.66, 0.0, -2.75)], arc, rest)


## Пятитрубный торпедный аппарат Mk 15 на поворотной платформе.
static func _torpedo_mount(a: ModelAsm, parent: Node3D, part: String, pos: Vector3, tubes: int, length: float, radius: float, rest: float = 0.0) -> Dictionary:
	var yaw := a.node(parent, part, pos)
	yaw.rotation.y = rest
	a.mesh(yaw, part + "Body", func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 1.4), Vector2(0.3, 1.35)]), 24, false, true, 40.0)
		var span := float(tubes - 1) * radius * 2.15
		VehicleKit.box(k.body, Vector3(0.0, 0.4, 0.0), Vector3(span + radius * 2.6, 0.2, length * 0.5))
		for i in tubes:
			var x := -span * 0.5 + float(i) * radius * 2.15
			VehicleKit.cyl(k.body, Vector3(x, 0.4 + radius + 0.1, length * 0.42), Vector3(x, 0.4 + radius + 0.1, -length * 0.58), radius, 12)
			k.dark.add_disc(Vector3(x, 0.4 + radius + 0.1, -length * 0.58 - 0.005), Vector3(0.0, 0.0, -1.0), radius * 0.8, 12)
			for zz: float in [-length * 0.3, length * 0.2]:
				VehicleKit.cyl(k.dark, Vector3(x, 0.5 + radius, zz + 0.06), Vector3(x, 0.5 + radius, zz - 0.06), radius * 1.08, 12)
		VehicleKit.cbox(k.body, Vector3(0.0, 0.4 + radius * 2.4 + 0.3, length * 0.25), Vector3(1.0, 0.7, 1.0), 0.08)
	)
	var pts: Array[Node3D] = []
	var span2 := float(tubes - 1) * radius * 2.15
	for i in tubes:
		pts.append(a.node(yaw, "Tube", Vector3(-span2 * 0.5 + float(i) * radius * 2.15, 0.5 + radius, -length * 0.6)))
	return {"yaw": yaw, "tubes": pts, "rest": rest}


# === Эсминец типа Fletcher (США, 1942) ============================================================================
## Гладкопалубный корпус 114,8 × 12 м, пять 127-мм установок Mk 30 (51–52 в носу, 53–55 в корме), мостик с
## директором Mk 37, треногая фок-мачта с РЛС SC, две дымовые трубы, два пятитрубных торпедных аппарата,
## спаренные «Бофорсы», шлюпка, глубинные бомбы. Окраска — «Мера 22» (тёмно-синий борт, серый верх).
static func _fletcher(a: ModelAsm) -> void:
	var p := {"L": 114.8, "B": 12.0, "T": 4.2, "D": 5.0, "bow_sheer": 2.2, "stern_sheer": -0.4, "entry": 0.36, "run": 0.72, "run_beam": 0.74, "transom": 0.7, "stern_rise": 0.22, "flare": 0.2, "camber": 0.25, "forefoot": 0.09, "stem_curve": 2.0, "n_mid": 3.4}
	var root := a.root
	var hull := a.node(root, "Hull")
	a.out["hull"] = hull
	var d := func(z: float) -> float: return _deck_at(p, z)
	a.mesh(hull, "HullBody", func(k: VehicleKit) -> void:
		_hull(k, p)
		_fittings(k, p, -52.0)
		_deck_rails(k, p, -54.0, 55.0)
		_portholes(k, p, -48.0, -20.0, 1.6, 2.2)
		# Носовая надстройка: подбашенная рубка установки 52, мостик, пост Mk 37.
		var y52: float = d.call(-34.5)
		var yb: float = d.call(-24.0)
		_house(k, 5.2, 6.0, -34.5, y52 - 0.3, y52 + 2.2, 0.8, 0.1)
		_house(k, 8.0, 14.5, -24.0, yb - 0.3, yb + 2.5, 1.2, 0.1)
		_house(k, 7.0, 9.5, -25.5, yb + 2.5, yb + 5.0, 1.4, 0.2)
		_house_windows(k, 7.0, 9.5, -25.5, yb + 2.5, yb + 5.0, 1.4, 0.2, 1.0, 1.8, 6, 5)
		_house(k, 6.0, 4.5, -27.8, yb + 5.0, yb + 7.3, 1.3, 0.2)
		_house_windows(k, 6.0, 4.5, -27.8, yb + 5.0, yb + 7.3, 1.3, 0.2, 0.6, 1.6, 5, 1)
		VehicleKit.cbox(k.body, Vector3(0.0, yb + 8.3, -26.6), Vector3(3.2, 2.0, 3.4), 0.3)
		k.metal.add_tube(PackedVector3Array([Vector3(-2.4, yb + 8.6, -26.2), Vector3(2.4, yb + 8.6, -26.2)]), 0.14, 8)
		VehicleKit.box(k.dark, Vector3(0.0, yb + 9.7, -26.6), Vector3(2.4, 0.8, 0.3))
		# Треногая фок-мачта с реями.
		var top: Vector3 = _tripod(k, Vector3(0.0, yb + 5.0, -20.5), 17.0, 1.4, 0.3, 3.0)
		k.metal.add_tube(PackedVector3Array([top + Vector3(-3.2, -3.0, 0.0), top + Vector3(3.2, -3.0, 0.0)]), 0.1, 5)
		k.metal.add_tube(PackedVector3Array([top, top + Vector3(0.0, 5.0, 0.4)]), 0.1, 6, false, 0.04)
		# Трубы на рубках, между ними — площадки «Бофорсов», торпедные аппараты, кормовая рубка.
		var ym: float = d.call(-4.5)
		_house(k, 5.5, 13.0, -4.5, ym - 0.3, ym + 2.3, 0.9, 0.1)
		_funnel(k, Vector3(0.0, ym + 2.2, -8.5), 3.2, 4.4, 6.8, 6.0)
		_funnel(k, Vector3(0.0, ym + 2.2, 1.5), 3.0, 4.2, 6.2, 6.0)
		for zt: float in [9.0, 17.5]:
			var yt: float = d.call(zt)
			VehicleKit.cyl(k.body, Vector3(0.0, yt - 0.2, zt), Vector3(0.0, yt + 0.9, zt), 1.5, 20)
		var ya: float = d.call(28.5)
		_house(k, 6.0, 12.0, 28.5, ya - 0.3, ya + 2.3, 1.0, 0.1)
		_pole(k, Vector3(0.0, ya + 2.3, 24.0), 7.5, 0.18, [Vector2(5.0, 3.0)])
		# Стеллажи глубинных бомб на корме, шлюпки, плоты.
		for s: float in [-1.0, 1.0]:
			for i in 5:
				var zc := 50.0 + float(i) * 1.1
				var yc: float = d.call(zc)
				VehicleKit.cyl(k.dark, Vector3(s * 2.4 - 0.3, yc + 0.35, zc), Vector3(s * 2.4 + 0.3, yc + 0.35, zc), 0.32, 10)
			_boat_davit(k, Vector3(s * 3.8, yb + 2.4, -14.0), s, 7.5)
			_liferafts(k, Vector3(s * 2.6, ya + 2.6, 23.5), 4, s)
	)
	var main: Array = []
	main.append(_gun_5in38(a, hull, Vector3(0.0, d.call(-41.0), -41.0), Vector2(-150.0, 150.0), 0.0))
	main.append(_gun_5in38(a, hull, Vector3(0.0, d.call(-34.5) + 2.2, -34.5), Vector2(-150.0, 150.0), 0.0))
	main.append(_gun_5in38(a, hull, Vector3(0.0, d.call(31.5) + 2.3, 31.5), Vector2(30.0, -30.0), PI))
	main.append(_gun_5in38(a, hull, Vector3(0.0, d.call(38.5), 38.5), Vector2(30.0, -30.0), PI))
	main.append(_gun_5in38(a, hull, Vector3(0.0, d.call(45.5), 45.5), Vector2(30.0, -30.0), PI))
	a.out["main"] = main
	var aa: Array = []
	for s: float in [-1.0, 1.0]:
		aa.append(_bofors_twin(a, hull, Vector3(s * 3.9, d.call(-3.5), -3.5), Vector2(-180.0, 180.0), 0.0))
	aa.append(_bofors_twin(a, hull, Vector3(0.0, d.call(25.0) + 2.3, 25.0), Vector2(-180.0, 180.0), PI))
	a.out["aa"] = aa
	var tm: Array = []
	for zt: float in [9.0, 17.5]:
		tm.append(_torpedo_mount(a, hull, "Mk15", Vector3(0.0, d.call(zt) + 0.9, zt), 5, 7.2, 0.3, 0.0))
	a.out["torpedo_mounts"] = tm
	var radar := a.node(hull, "RadarSC", Vector3(0.0, d.call(-24.0) + 22.2, -19.7))
	a.mesh(radar, "SC", func(k: VehicleKit) -> void:
		k.metal.add_tube(PackedVector3Array([Vector3(0.0, -0.3, 0.0), Vector3(0.0, 0.3, 0.0)]), 0.1, 6)
		k.dark.xform = MeshFactory.xf(Vector3(0.0, 0.9, 0.0), Vector3(-8.0, 0.0, 0.0))
		k.dark.add_box(Vector3.ZERO, Vector3(4.6, 1.6, 0.12))
		k.dark.xform = Transform3D.IDENTITY
	)
	a.out["radars"] = [{"node": radar, "speed": 1.1}]
	a.out["wake_points"] = [a.node(root, "Wake", Vector3(0.0, 0.2, 56.0))]
	a.out["body_aabb"] = AABB(Vector3(-6.0, -4.2, -57.4), Vector3(12.0, 14.0, 114.8))
	for s: float in [-1.0, 1.0]:
		a.decal(hull, Insignia.hull_number("557", true), Vector3(s * 5.2, 5.2, -47.0), Vector3(s, 0.0, 0.0), 3.4, 1.6)


# === Эсминец УРО типа Arleigh Burke (США, Flight IIA) ==============================================================
## Корпус 155 × 20 м с сильным развалом бортов в носу; 127-мм Mk 45 Mod 4, УВП Mk 41 в носу (32 ячейки)
## и корме (64), надстройка с наклонными стенками и четырьмя ФАР SPY-1D, наклонная мачта, две трубы
## с газоотводами, ангары вертолётов и площадка, «Фаланксы», контейнеры «Гарпунов», катера в нишах.
static func _burke(a: ModelAsm) -> void:
	var p := {"L": 155.3, "B": 20.0, "T": 6.3, "D": 6.8, "bow_sheer": 2.8, "stern_sheer": -1.6, "entry": 0.4, "run": 0.7, "run_beam": 0.7, "transom": 0.86, "stern_rise": 0.18, "flare": 0.3, "camber": 0.3, "forefoot": 0.12, "stem_curve": 1.8, "n_mid": 3.0, "bow_flare_exp": 0.7}
	var root := a.root
	var hull := a.node(root, "Hull")
	a.out["hull"] = hull
	var d := func(z: float) -> float: return _deck_at(p, z)
	var vls_fwd := Vector3(0.0, _deck_at(p, -45.5), -45.5)
	var vls_aft := Vector3(0.0, _deck_at(p, 32.5), 32.5)
	a.mesh(hull, "HullBody", func(k: VehicleKit) -> void:
		_hull(k, p)
		_fittings(k, p, -70.0)
		_deck_rails(k, p, -74.0, 76.0)
		_vls(k, vls_fwd, 8, 4)
		# Носовая надстройка с наклонными стенками, гранями ФАР и мостиком.
		var y0: float = d.call(-28.0)
		_house(k, 15.0, 25.0, -27.0, y0 - 0.3, y0 + 6.5, 4.5, 0.9)
		_house(k, 12.0, 15.0, -30.0, y0 + 6.5, y0 + 10.0, 2.4, 0.6)
		_house_windows(k, 12.0, 15.0, -30.0, y0 + 6.5, y0 + 10.0, 2.4, 0.6, 1.3, 2.6, 8, 4)
		_house(k, 7.0, 7.0, -26.0, y0 + 10.0, y0 + 12.5, 1.6, 0.4)
		for s: float in [-1.0, 1.0]:
			_phased_panel(k, Vector3(s * 4.85, y0 + 4.6, -36.85), Vector3(s * 0.66, 0.35, -0.66), 1.85)
		# Мачта: наклонная ферма-пирамида с площадками и антеннами.
		var mb := Vector3(0.0, y0 + 12.5, -26.0)
		k.part(VehicleKit.P_UPPER)
		k.body.xform = Transform3D(Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(8.0)), mb)
		k.body.add_block(VehicleKit.chamfer_rect(3.2, 3.2, 0.5), 0.0, 9.0, 1.1, true, false, 10.0)
		k.body.add_block(VehicleKit.chamfer_rect(4.8, 1.6, 0.3), 5.0, 5.3, 0.0, true, true, 10.0)
		k.body.add_block(VehicleKit.chamfer_rect(3.4, 1.4, 0.3), 8.2, 8.5, 0.0, true, true, 10.0)
		k.body.xform = Transform3D.IDENTITY
		k.part(VehicleKit.P_HULL)
		k.metal.add_tube(PackedVector3Array([mb + Vector3(0.0, 9.0, 1.3), mb + Vector3(0.0, 17.0, 2.3)]), 0.1, 6, false, 0.04)
		for s: float in [-1.0, 1.0]:
			k.part(VehicleKit.P_WHITE)
			VehicleKit.cyl(k.body, mb + Vector3(s * 1.9, 5.3, 0.7), mb + Vector3(s * 1.9, 6.3, 0.7), 0.35, 12)
			k.part(VehicleKit.P_HULL)
		# Трубы с тремя газоотводами, средняя надстройка, катера в нишах.
		for zf: float in [-9.0, 11.0]:
			var yf: float = d.call(zf)
			_house(k, 6.8, 7.5, zf, yf - 0.3, yf + 7.0, 1.2, 0.8)
			for i in 3:
				var ex := (float(i) - 1.0) * 1.3
				VehicleKit.cyl(k.body, Vector3(ex, yf + 6.9, zf + 0.6), Vector3(ex, yf + 9.2, zf + 0.9), 0.5, 12)
				k.part(VehicleKit.P_SOOT)
				VehicleKit.cyl(k.body, Vector3(ex, yf + 9.2, zf + 0.9), Vector3(ex, yf + 9.8, zf + 1.0), 0.52, 12)
				k.part(VehicleKit.P_HULL)
		var ymid: float = d.call(1.0)
		_house(k, 13.0, 13.0, 1.0, ymid - 0.3, ymid + 5.0, 1.8, 0.7)
		for s: float in [-1.0, 1.0]:
			k.part(VehicleKit.P_INTERIOR)
			VehicleKit.box(k.body, Vector3(s * 6.33, ymid + 2.4, 1.0), Vector3(0.1, 2.6, 7.5))
			k.part(VehicleKit.P_HULL)
			_boat_davit(k, Vector3(s * 5.6, ymid + 1.9, 1.0), s, 7.0)
		# Кормовая надстройка с ФАР, УВП и ангары.
		var ya: float = d.call(22.0)
		_house(k, 14.0, 13.0, 21.5, ya - 0.3, ya + 7.5, 4.5, 0.8)
		for s: float in [-1.0, 1.0]:
			_phased_panel(k, Vector3(s * 4.45, ya + 4.2, 25.45), Vector3(s * 0.66, 0.35, 0.66), 1.85)
		_vls(k, vls_aft, 8, 8)
		var yh: float = d.call(42.5)
		_house(k, 16.5, 11.5, 42.5, yh - 0.3, yh + 6.5, 1.5, 0.3)
		for s: float in [-1.0, 1.0]:
			VehicleKit.box(k.dark, Vector3(s * 3.9, yh + 2.8, 48.26), Vector3(6.0, 5.0, 0.05))
			_liferafts(k, Vector3(s * 6.2, ya + 7.7, 16.8), 5, s)
		_helipad(k, Vector3(0.0, d.call(60.0), 60.0), 5.5, 22.0)
		# Контейнеры «Гарпунов» (ПКР) поперёк палубы за кормовой надстройкой.
		var yhp: float = d.call(29.0)
		for s: float in [-1.0, 1.0]:
			for i in 4:
				var hp := Vector3(s * 2.6, yhp + 0.9 + float(i % 2) * 0.72, 28.2 + float(i / 2) * 0.75)
				k.body.xform = Transform3D(Basis(Vector3(0.0, 0.0, 1.0), s * deg_to_rad(35.0)), hp)
				k.body.add_prism(VehicleKit.rounded_rect(0.7, 0.7, 0.08, 1), 2.2, 0.0, 0.0, 30.0, 0.0)
				k.body.xform = Transform3D.IDENTITY
	)
	var main: Array = [_gun_mk45(a, hull, Vector3(0.0, d.call(-55.0), -55.0), Vector2(-150.0, 150.0), 0.0)]
	a.out["main"] = main
	var aa: Array = []
	aa.append(_phalanx(a, hull, Vector3(0.0, d.call(-28.0) + 10.0, -37.0), Vector2(-150.0, 150.0), 0.0))
	aa.append(_phalanx(a, hull, Vector3(0.0, d.call(42.5) + 6.5, 45.0), Vector2(30.0, -30.0), PI))
	a.out["aa"] = aa
	var sams: Array[Node3D] = []
	var cells := _vls_cells(vls_fwd, 8, 4) + _vls_cells(vls_aft, 8, 8)
	for i in range(0, cells.size(), 7):
		sams.append(a.node(hull, "VLSCell", cells[i] + Vector3.UP * 0.1, Vector3(90.0, 0.0, 0.0)))
	a.out["sam_points"] = sams
	var ssm: Array[Node3D] = []
	for s: float in [-1.0, 1.0]:
		var n := a.node(hull, "Harpoon", Vector3(s * 4.2, d.call(29.0) + 2.0, 28.6))
		n.basis = Basis(Vector3(0.0, 1.0, 0.0), -s * PI * 0.5) * Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(35.0))
		ssm.append(n)
	a.out["special_points"] = ssm
	var radar := a.node(hull, "NavRadar", Vector3(0.0, d.call(-28.0) + 21.4, -24.8))
	a.mesh(radar, "Bar", func(k: VehicleKit) -> void:
		VehicleKit.box(k.dark, Vector3(0.0, 0.2, 0.0), Vector3(3.0, 0.3, 0.35))
		VehicleKit.cyl(k.dark, Vector3(0.0, -0.3, 0.0), Vector3(0.0, 0.1, 0.0), 0.12, 8)
	)
	a.out["radars"] = [{"node": radar, "speed": 2.5}]
	a.out["wake_points"] = [a.node(root, "Wake", Vector3(0.0, 0.2, 76.0))]
	a.out["body_aabb"] = AABB(Vector3(-10.0, -6.3, -77.6), Vector3(20.0, 20.0, 155.3))
	for s: float in [-1.0, 1.0]:
		a.decal(hull, Insignia.hull_number("51", true), Vector3(s * 7.2, 6.8, -63.0), Vector3(s, 0.0, -0.25), 4.2, 2.5)


# === Эсминец проекта 956 «Современный» (СССР) ======================================================================
## Корпус 156,5 × 17,2 м с высоким полубаком; две спаренные 130-мм АК-130, однобалочные пусковые ЗРК
## «Ураган», две счетверённые пусковые ПКР «Москит» у мостика, пирамидальная мачта с РЛС «Фрегат» (Top Plate),
## широкая дымовая труба, четыре АК-630, вертолётная площадка с телескопическим ангаром.
static func _sovremenny(a: ModelAsm) -> void:
	var p := {"L": 156.5, "B": 17.2, "T": 6.0, "D": 6.4, "bow_sheer": 3.2, "stern_sheer": -0.6, "entry": 0.4, "run": 0.72, "run_beam": 0.72, "transom": 0.8, "stern_rise": 0.2, "flare": 0.26, "camber": 0.3, "forefoot": 0.11, "stem_curve": 1.9, "n_mid": 3.0}
	var root := a.root
	var hull := a.node(root, "Hull")
	a.out["hull"] = hull
	var d := func(z: float) -> float: return _deck_at(p, z)
	a.mesh(hull, "HullBody", func(k: VehicleKit) -> void:
		_hull(k, p)
		_fittings(k, p, -71.0)
		_deck_rails(k, p, -75.0, 77.0)
		_portholes(k, p, -60.0, 50.0, 1.4, 3.0)
		# Барбет пусковой «Ураган» на баке.
		var yu: float = d.call(-44.0)
		VehicleKit.cyl(k.body, Vector3(0.0, yu - 0.3, -44.0), Vector3(0.0, yu + 1.3, -44.0), 2.2, 20)
		# Носовая надстройка и мостик.
		var yb: float = d.call(-28.0)
		_house(k, 12.5, 22.0, -27.0, yb - 0.3, yb + 5.2, 1.6, 0.4)
		_house(k, 10.5, 13.0, -30.0, yb + 5.2, yb + 8.4, 1.8, 0.4)
		_house_windows(k, 10.5, 13.0, -30.0, yb + 5.2, yb + 8.4, 1.8, 0.4, 1.2, 2.6, 9, 4)
		_house(k, 8.0, 5.0, -33.2, yb + 8.4, yb + 10.4, 1.4, 0.3)
		k.part(VehicleKit.P_WHITE)
		k.body.xform = Transform3D(Basis(), Vector3(0.0, yb + 10.4, -33.4))
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 1.6), Vector2(0.9, 1.5), Vector2(1.7, 1.0), Vector2(2.1, 0.0)]), 20, true, false, 45.0)
		k.body.xform = Transform3D.IDENTITY
		k.part(VehicleKit.P_HULL)
		# Пирамидальная мачта (решётчатая ферма).
		VehicleKit.lattice(k.metal, Vector3(0.0, yb + 8.4, -24.0), Vector3(0.0, yb + 24.0, -23.2), 4.5, 1.3, 4, 6, 0.12)
		k.metal.add_tube(PackedVector3Array([Vector3(-3.5, yb + 17.0, -23.6), Vector3(3.5, yb + 17.0, -23.6)]), 0.09, 5)
		# Пусковые ПКР «Москит»: по четыре трубы по бортам мостика.
		var ym: float = d.call(-30.0)
		for s: float in [-1.0, 1.0]:
			var lp := Vector3(s * 5.6, ym + 1.4, -30.5)
			k.body.xform = Transform3D(Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(12.0)), lp)
			for tx: float in [-0.62, 0.62]:
				for ty: float in [-0.62, 0.62]:
					VehicleKit.cyl(k.body, Vector3(tx, ty, 5.0), Vector3(tx, ty, -5.0), 0.58, 14)
					k.dark.xform = k.body.xform
					k.dark.add_disc(Vector3(tx, ty, -5.01), Vector3(0.0, 0.0, -1.0), 0.5, 12)
					k.dark.xform = Transform3D.IDENTITY
			k.body.add_box(Vector3(0.0, -1.3, 0.0), Vector3(2.7, 0.3, 8.0))
			k.body.xform = Transform3D.IDENTITY
		# Широкая дымовая труба с наклонным срезом.
		var yf: float = d.call(-7.0)
		k.part(VehicleKit.P_UPPER)
		k.body.add_prism(PackedVector2Array([Vector2(-12.0, yf - 0.3), Vector2(-2.0, yf - 0.3), Vector2(-2.5, yf + 7.8), Vector2(-9.5, yf + 7.0), Vector2(-12.0, yf + 4.5)]), 3.8, 0.12, yf)
		k.part(VehicleKit.P_SOOT)
		k.body.add_box(Vector3(0.0, yf + 7.45, -6.0), Vector3(5.0, 0.2, 6.2))
		k.part(VehicleKit.P_HULL)
		# Вертолётная площадка с телескопическим ангаром, кормовая надстройка.
		var yh: float = d.call(3.5)
		_house(k, 11.0, 5.5, 3.5, yh - 0.3, yh + 4.5, 1.2, 0.2)
		_helipad(k, Vector3(0.0, d.call(12.5), 12.5), 5.0, 12.0)
		var ya: float = d.call(24.0)
		_house(k, 11.0, 12.0, 24.5, ya - 0.3, ya + 5.5, 1.4, 0.3)
		VehicleKit.cyl(k.body, Vector3(0.0, ya + 5.5, 27.0), Vector3(0.0, ya + 6.6, 27.0), 2.0, 20)
		var ybt: float = d.call(-2.0)
		for s: float in [-1.0, 1.0]:
			_boat_davit(k, Vector3(s * 7.2, ybt + 2.0, -2.0), s, 7.5)
			_liferafts(k, Vector3(s * 5.9, ya + 5.8, 19.5), 4, s)
	)
	var main: Array = []
	main.append(_gun_ak130(a, hull, Vector3(0.0, d.call(-56.0), -56.0), Vector2(-150.0, 150.0), 0.0))
	main.append(_gun_ak130(a, hull, Vector3(0.0, d.call(41.0), 41.0), Vector2(30.0, -30.0), PI))
	a.out["main"] = main
	var aa: Array = []
	for s: float in [-1.0, 1.0]:
		aa.append(_ak630(a, hull, Vector3(s * 5.4, d.call(-15.0) + 3.0, -15.0), Vector2(-180.0, 180.0), 0.0))
		aa.append(_ak630(a, hull, Vector3(s * 4.6, d.call(24.0) + 5.5, 21.0), Vector2(-180.0, 180.0), PI))
	a.out["aa"] = aa
	# Однобалочные пусковые «Ураган» (с ракетой на направляющей).
	var sams: Array[Node3D] = []
	for cfg: Array in [[Vector3(0.0, d.call(-44.0) + 1.3, -44.0), 0.0], [Vector3(0.0, d.call(24.0) + 6.6, 27.0), PI]]:
		var lau := a.node(hull, "Uragan", cfg[0])
		lau.rotation.y = float(cfg[1])
		a.mesh(lau, "UraganArm", func(k: VehicleKit) -> void:
			k.part(VehicleKit.P_UPPER)
			k.body.add_lathe(PackedVector2Array([Vector2(0.0, 1.0), Vector2(1.2, 0.8), Vector2(1.6, 0.4), Vector2(1.7, 0.0)]), 16, true, false, 40.0)
			VehicleKit.cbox(k.body, Vector3(0.0, 1.8, 0.4), Vector3(0.7, 0.4, 3.5), 0.06, Vector3(-18.0, 0.0, 0.0))
			k.part(VehicleKit.P_WHITE)
			VehicleKit.missile(k.body, k.dark, Vector3(0.0, 2.4, 2.4), 5.5, 0.2, 4, 0.95, 0.16)
		)
		sams.append(a.node(lau, "Rail", Vector3(0.0, 2.9, -3.0), Vector3(18.0, 0.0, 0.0)))
	a.out["sam_points"] = sams
	var ssm: Array[Node3D] = []
	for s: float in [-1.0, 1.0]:
		ssm.append(a.node(hull, "Moskit", Vector3(s * 5.6, d.call(-30.0) + 2.5, -36.0), Vector3(12.0, 0.0, 0.0)))
	a.out["special_points"] = ssm
	var radar := a.node(hull, "TopPlate", Vector3(0.0, d.call(-28.0) + 24.2, -23.2))
	a.mesh(radar, "Fregat", func(k: VehicleKit) -> void:
		VehicleKit.cyl(k.dark, Vector3(0.0, -0.4, 0.0), Vector3(0.0, 0.5, 0.0), 0.4, 10)
		for s: float in [-1.0, 1.0]:
			k.dark.xform = MeshFactory.xf(Vector3(0.0, 1.3, s * 0.35), Vector3(s * 10.0, 0.0, 0.0))
			k.dark.add_box(Vector3.ZERO, Vector3(5.6, 1.8, 0.22))
			k.dark.xform = Transform3D.IDENTITY
	)
	a.out["radars"] = [{"node": radar, "speed": 1.2}]
	a.out["wake_points"] = [a.node(root, "Wake", Vector3(0.0, 0.2, 77.0))]
	a.out["body_aabb"] = AABB(Vector3(-8.6, -6.0, -78.2), Vector3(17.2, 19.0, 156.5))
	for s: float in [-1.0, 1.0]:
		a.decal(hull, Insignia.hull_number("620", false), Vector3(s * 6.3, 6.8, -60.0), Vector3(s, 0.0, -0.2), 4.4, 2.4)


# === Эсминец проекта 7 «Гневный» (СССР, 1938) ======================================================================
## Корпус 112,8 × 10,2 м с полубаком; четыре 130-мм Б-13 (две в носу, две в корме, по одной — на возвышенных
## площадках), мостик с командно-дальномерным постом, треногая фок-мачта, две трубы (носовая шире), два
## трёхтрубных торпедных аппарата, 76-мм 34-К и 45-мм 21-К, грот-мачта, шлюпки.
static func _gnevny(a: ModelAsm) -> void:
	var p := {"L": 112.8, "B": 10.2, "T": 4.0, "D": 4.1, "bow_sheer": 1.3, "fc": [0.285, 1.7], "stern_sheer": -0.3, "entry": 0.36, "run": 0.72, "run_beam": 0.74, "transom": 0.7, "stern_rise": 0.25, "flare": 0.2, "camber": 0.2, "forefoot": 0.09, "stem_curve": 2.0, "n_mid": 3.3}
	var root := a.root
	var hull := a.node(root, "Hull")
	a.out["hull"] = hull
	var d := func(z: float) -> float: return _deck_at(p, z)
	a.mesh(hull, "HullBody", func(k: VehicleKit) -> void:
		_hull(k, p)
		_fittings(k, p, -51.0)
		_deck_rails(k, p, -53.0, 55.0)
		_portholes(k, p, -48.0, -28.0, 1.5, 2.2)
		var y2: float = d.call(-37.0)
		_house(k, 4.6, 5.0, -37.0, y2 - 0.3, y2 + 2.0, 0.7, 0.1)
		# Мостик и командно-дальномерный пост.
		var yb: float = d.call(-29.0)
		_house(k, 7.4, 8.5, -29.0, yb - 0.3, yb + 2.4, 1.0, 0.1)
		_house(k, 6.0, 5.0, -30.2, yb + 2.4, yb + 4.7, 1.2, 0.2)
		_house_windows(k, 6.0, 5.0, -30.2, yb + 2.4, yb + 4.7, 1.2, 0.2, 0.9, 1.7, 5, 2)
		VehicleKit.cyl(k.body, Vector3(0.0, yb + 4.7, -30.0), Vector3(0.0, yb + 6.4, -30.0), 1.1, 16)
		k.metal.add_tube(PackedVector3Array([Vector3(-2.1, yb + 6.0, -30.0), Vector3(2.1, yb + 6.0, -30.0)]), 0.13, 8)
		var top: Vector3 = _tripod(k, Vector3(0.0, yb + 2.4, -24.6), 16.0, 1.2, 0.26, 3.0)
		k.metal.add_tube(PackedVector3Array([top + Vector3(-2.8, -2.5, 0.0), top + Vector3(2.8, -2.5, 0.0)]), 0.09, 5)
		# Трубы на рубке, торпедные аппараты, кормовая надстройка с 76-мм.
		var ym: float = d.call(-9.0)
		_house(k, 4.8, 17.0, -9.5, ym - 0.3, ym + 1.8, 0.8, 0.1)
		_funnel(k, Vector3(0.0, ym + 1.7, -15.0), 3.6, 5.4, 6.6, 5.0)
		_funnel(k, Vector3(0.0, ym + 1.7, -4.5), 3.0, 4.4, 6.0, 5.0)
		var ya: float = d.call(26.0)
		_house(k, 5.2, 12.0, 26.0, ya - 0.3, ya + 2.2, 0.9, 0.1)
		_pole(k, Vector3(0.0, ya + 2.2, 21.0), 10.0, 0.2, [Vector2(7.0, 3.5)])
		for s: float in [-1.0, 1.0]:
			_boat_davit(k, Vector3(s * 3.4, ym + 2.0, 0.0), s, 6.5)
			for i in 4:
				var zc := 47.0 + float(i) * 1.2
				var yc: float = d.call(zc)
				VehicleKit.cyl(k.dark, Vector3(s * 2.1 - 0.28, yc + 0.32, zc), Vector3(s * 2.1 + 0.28, yc + 0.32, zc), 0.3, 10)
		# Прожекторные площадки.
		for s: float in [-1.0, 1.0]:
			VehicleKit.cyl(k.dark, Vector3(s * 1.2, yb + 4.9, -27.8), Vector3(s * 1.2, yb + 5.5, -27.8), 0.35, 10)
	)
	var main: Array = []
	main.append(_gun_b13(a, hull, Vector3(0.0, d.call(-44.5), -44.5), Vector2(-150.0, 150.0), 0.0))
	main.append(_gun_b13(a, hull, Vector3(0.0, d.call(-37.0) + 2.0, -37.0), Vector2(-150.0, 150.0), 0.0))
	main.append(_gun_b13(a, hull, Vector3(0.0, d.call(32.5) + 2.2, 32.5), Vector2(30.0, -30.0), PI))
	main.append(_gun_b13(a, hull, Vector3(0.0, d.call(40.5), 40.5), Vector2(30.0, -30.0), PI))
	a.out["main"] = main
	var aa: Array = []
	for s: float in [-1.0, 1.0]:
		aa.append(_aa_single(a, hull, Vector3(s * 1.6, d.call(24.0) + 2.2, 24.0), "K34", 1.2, "su"))
		aa.append(_aa_single(a, hull, Vector3(s * 3.3, d.call(-22.0), -22.0), "K21", 0.85, "su"))
	a.out["aa"] = aa
	var tm: Array = []
	for zt: float in [5.0, 14.0]:
		tm.append(_torpedo_mount(a, hull, "TA39", Vector3(0.0, d.call(zt), zt), 3, 7.0, 0.3, 0.0))
	a.out["torpedo_mounts"] = tm
	a.out["wake_points"] = [a.node(root, "Wake", Vector3(0.0, 0.2, 55.0))]
	a.out["body_aabb"] = AABB(Vector3(-5.1, -4.0, -56.4), Vector3(10.2, 13.0, 112.8))


# === Ракетный катер проекта 12411 «Молния» (СССР) ==================================================================
## Корпус 56 × 10,2 м; 76-мм АК-176 на баке, надстройка с большим радиопрозрачным обтекателем РЛС «Минерал»,
## решётчатая мачта, четыре пусковые трубы ПКР П-270 «Москит» по бортам (попарно, под углом вверх),
## два шестиствольных АК-630 и РЛС управления огнём на корме.
static func _molniya(a: ModelAsm) -> void:
	var p := {"L": 56.1, "B": 10.4, "T": 2.5, "D": 3.2, "bow_sheer": 1.3, "stern_sheer": -0.4, "entry": 0.4, "run": 0.68, "run_beam": 0.7, "transom": 0.84, "stern_rise": 0.4, "flare": 0.24, "camber": 0.18, "forefoot": 0.12, "stem_curve": 1.8, "n_mid": 2.4, "n_stern": 3.0, "stations": 44}
	var root := a.root
	var hull := a.node(root, "Hull")
	a.out["hull"] = hull
	var d := func(z: float) -> float: return _deck_at(p, z)
	a.mesh(hull, "HullBody", func(k: VehicleKit) -> void:
		_hull(k, p)
		_fittings(k, p, -24.5)
		_deck_rails(k, p, -26.0, 27.0, 1.6)
		var yb: float = d.call(-6.0)
		_house(k, 7.2, 16.0, -5.0, yb - 0.3, yb + 2.3, 1.2, 0.2)
		_house(k, 6.0, 6.5, -9.0, yb + 2.3, yb + 4.4, 1.3, 0.3)
		_house_windows(k, 6.0, 6.5, -9.0, yb + 2.3, yb + 4.4, 1.3, 0.3, 0.9, 1.7, 6, 3)
		k.part(VehicleKit.P_WHITE)
		k.body.xform = Transform3D(Basis(), Vector3(0.0, yb + 4.4, -9.4))
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 1.5), Vector2(0.9, 1.45), Vector2(1.7, 1.05), Vector2(2.15, 0.45), Vector2(2.25, 0.0)]), 20, true, false, 45.0)
		k.body.xform = Transform3D.IDENTITY
		k.part(VehicleKit.P_HULL)
		VehicleKit.lattice(k.metal, Vector3(0.0, yb + 4.4, -5.2), Vector3(0.0, yb + 11.0, -5.0), 1.6, 0.5, 3, 4, 0.07)
		k.metal.add_tube(PackedVector3Array([Vector3(-1.8, yb + 9.0, -5.1), Vector3(1.8, yb + 9.0, -5.1)]), 0.05, 4)
		# Пусковые трубы «Москит»: по две с каждого борта, под углом 12° вверх.
		var yl: float = d.call(7.0)
		for s: float in [-1.0, 1.0]:
			k.body.xform = Transform3D(Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(12.0)), Vector3(s * 3.4, yl + 1.3, 7.5))
			for ty: float in [0.0, 1.25]:
				VehicleKit.cyl(k.body, Vector3(0.0, ty, 4.8), Vector3(0.0, ty, -4.8), 0.6, 16)
				k.dark.xform = k.body.xform
				k.dark.add_disc(Vector3(0.0, ty, -4.81), Vector3(0.0, 0.0, -1.0), 0.52, 14)
				k.dark.xform = Transform3D.IDENTITY
			k.body.add_box(Vector3(0.0, -0.8, 0.0), Vector3(1.3, 0.3, 7.5))
			k.body.xform = Transform3D.IDENTITY
			VehicleKit.cyl(k.dark, Vector3(s * 3.4, yl, 10.5), Vector3(s * 3.4, yl + 0.5, 10.5), 0.25, 8)
		# Кормовая рубка: АК-630 и РЛС управления огнём МР-123.
		var ys: float = d.call(18.0)
		_house(k, 6.5, 7.0, 16.5, ys - 0.3, ys + 1.6, 1.0, 0.1)
		VehicleKit.cyl(k.body, Vector3(0.0, ys + 1.6, 14.2), Vector3(0.0, ys + 3.4, 14.2), 0.3, 10)
		VehicleKit.dish(k.body, Vector3(0.0, ys + 3.8, 14.0), Vector3(0.0, 0.1, -1.0), 0.8, 0.25, 0.04, 20)
		for s: float in [-1.0, 1.0]:
			_liferafts(k, Vector3(s * 3.0, yb + 2.6, -1.0), 3, s)
			k.part(VehicleKit.P_SOOT)
			VehicleKit.box(k.body, Vector3(s * 2.2, 1.2, 28.02), Vector3(1.2, 0.8, 0.05))
			k.part(VehicleKit.P_HULL)
	)
	a.out["main"] = [_gun_ak176(a, hull, Vector3(0.0, d.call(-18.5), -18.5), Vector2(-160.0, 160.0), 0.0)]
	var aa: Array = []
	for s: float in [-1.0, 1.0]:
		aa.append(_ak630(a, hull, Vector3(s * 1.9, d.call(18.0) + 1.6, 18.5), Vector2(-180.0, 180.0), PI))
	a.out["aa"] = aa
	var ssm: Array[Node3D] = []
	for s: float in [-1.0, 1.0]:
		for ty: float in [0.0, 1.25]:
			var base: float = d.call(7.0) + 1.3
			var local := Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(12.0)) * Vector3(0.0, ty, -5.2)
			ssm.append(a.node(hull, "Moskit", Vector3(s * 3.4, base, 7.5) + local, Vector3(12.0, 0.0, 0.0)))
	a.out["special_points"] = ssm
	a.out["wake_points"] = [a.node(root, "Wake", Vector3(0.0, 0.2, 28.5))]
	a.out["body_aabb"] = AABB(Vector3(-5.2, -2.5, -28.0), Vector3(10.4, 9.0, 56.1))
	for s: float in [-1.0, 1.0]:
		a.decal(hull, Insignia.hull_number("954", false), Vector3(s * 4.6, 3.3, -19.0), Vector3(s, 0.0, -0.15), 2.8, 1.8)


## Большая вращающаяся антенна-сетка (SPS-49, SK): отражатель w × h с каркасом на поворотной опоре.
static func _big_radar(a: ModelAsm, parent: Node3D, part: String, pos: Vector3, w: float, h: float, depth: float, speed: float, twin: bool = false) -> Dictionary:
	var node := a.node(parent, part, pos)
	a.mesh(node, part + "Array", func(k: VehicleKit) -> void:
		VehicleKit.cyl(k.dark, Vector3(0.0, -0.5, 0.0), Vector3(0.0, 0.4, 0.0), 0.35, 10)
		for side: float in ([-1.0, 1.0] if twin else [1.0]):
			var grid: Array = []
			for r in 4:
				var row := PackedVector3Array()
				var y := 0.5 + float(r) / 3.0 * h
				for c in 11:
					var t := float(c) / 10.0 * 2.0 - 1.0
					row.append(Vector3(t * w * 0.5, y, side * (0.25 + depth * (1.0 - t * t))))
				grid.append(row)
			k.dark.add_patch(grid, side > 0.0, true)
			k.metal.add_tube(PackedVector3Array([Vector3(-w * 0.5, 0.5, side * 0.25), Vector3(w * 0.5, 0.5, side * 0.25)]), 0.07, 5)
			k.metal.add_tube(PackedVector3Array([Vector3(-w * 0.5, 0.5 + h, side * 0.25), Vector3(w * 0.5, 0.5 + h, side * 0.25)]), 0.07, 5)
			k.metal.add_tube(PackedVector3Array([Vector3(0.0, 0.4, 0.0), Vector3(0.0, 0.5 + h * 0.5, side * (0.25 + depth))]), 0.06, 5)
	)
	return {"node": node, "speed": speed}


# === Крейсер УРО «Тикондерога» (CG-47, США) — флагман реактивной эпохи ===========================================
## Корпус 172,8 × 16,8 м; две 127-мм Mk 45, две УВП Mk 41 по 61 ячейке, носовая и кормовая надстройки с
## ФАР SPY-1A, высокие трубы, РЛС SPS-49 на фок-мачте, «Фаланксы», вертолётная площадка, «Гарпуны».
static func _ticonderoga(a: ModelAsm) -> void:
	var p := {"L": 172.8, "B": 16.8, "T": 6.5, "D": 7.2, "bow_sheer": 2.6, "stern_sheer": -1.9, "entry": 0.42, "run": 0.7, "run_beam": 0.7, "transom": 0.84, "stern_rise": 0.2, "flare": 0.24, "camber": 0.3, "forefoot": 0.12, "stem_curve": 1.8, "n_mid": 3.0}
	var root := a.root
	var hull := a.node(root, "Hull")
	a.out["hull"] = hull
	var d := func(z: float) -> float: return _deck_at(p, z)
	var vls_f := Vector3(0.0, _deck_at(p, -56.0), -56.0)
	var vls_a := Vector3(0.0, _deck_at(p, 40.0), 40.0)
	var yf: float = _deck_at(p, -30.0)
	var ya: float = _deck_at(p, 16.0)
	a.mesh(hull, "HullBody", func(k: VehicleKit) -> void:
		_hull(k, p)
		_fittings(k, p, -78.0)
		_deck_rails(k, p, -83.0, 85.0)
		_portholes(k, p, -70.0, -48.0, 1.6, 3.0)
		_vls(k, vls_f, 8, 8)
		_vls(k, vls_a, 8, 8)
		# Носовая надстройка, мостик, ФАР, дымовая труба и фок-мачта.
		_house(k, 13.5, 33.0, -29.0, yf - 0.3, yf + 6.0, 3.8, 0.5)
		for s: float in [-1.0, 1.0]:
			_phased_panel(k, Vector3(s * 4.65, yf + 3.4, -43.4), Vector3(s * 0.66, 0.3, -0.66), 1.7)
		_house(k, 11.0, 14.0, -36.0, yf + 6.0, yf + 9.2, 2.0, 0.4)
		_house_windows(k, 11.0, 14.0, -36.0, yf + 6.0, yf + 9.2, 2.0, 0.4, 1.2, 2.4, 8, 4)
		_house(k, 7.0, 8.0, -33.0, yf + 9.2, yf + 11.5, 1.5, 0.3)
		_house(k, 5.0, 6.5, -18.0, yf + 6.0, yf + 14.0, 1.0, 0.3)
		k.part(VehicleKit.P_SOOT)
		k.body.add_block(VehicleKit.chamfer_rect(4.5, 6.0, 0.9, -18.0), yf + 14.0, yf + 14.8, 0.0, true, false, 10.0)
		k.part(VehicleKit.P_HULL)
		_tripod(k, Vector3(0.0, yf + 11.5, -26.0), 11.0, 1.1, 0.25, 0.0)
		# Средняя надстройка с катерами, кормовая надстройка с ФАР и трубой, ангар.
		var ym: float = d.call(-3.5)
		_house(k, 12.0, 14.0, -3.5, ym - 0.3, ym + 5.0, 1.8, 0.5)
		for s: float in [-1.0, 1.0]:
			_boat_davit(k, Vector3(s * 5.4, ym + 2.2, -3.5), s, 7.0)
		_house(k, 13.0, 26.0, 17.0, ya - 0.3, ya + 6.5, 3.8, 0.5)
		for s: float in [-1.0, 1.0]:
			_phased_panel(k, Vector3(s * 4.4, ya + 3.3, 28.1), Vector3(s * 0.66, 0.3, 0.66), 1.7)
			_liferafts(k, Vector3(s * 5.4, ya + 6.8, 8.0), 5, s)
		_house(k, 5.0, 6.5, 10.0, ya + 6.5, ya + 13.0, 1.0, 0.3)
		k.part(VehicleKit.P_SOOT)
		k.body.add_block(VehicleKit.chamfer_rect(4.5, 6.0, 0.9, 10.0), ya + 13.0, ya + 13.8, 0.0, true, false, 10.0)
		k.part(VehicleKit.P_HULL)
		_pole(k, Vector3(0.0, ya + 6.5, 20.5), 13.0, 0.25, [Vector2(8.0, 5.0)])
		VehicleKit.box(k.dark, Vector3(0.0, ya + 2.8, 30.04), Vector3(6.0, 5.0, 0.05))
		_helipad(k, Vector3(0.0, d.call(54.0), 54.0), 5.5, 18.0)
		# Контейнеры «Гарпунов» на юте.
		var yh: float = d.call(67.0)
		for s: float in [-1.0, 1.0]:
			for i in 4:
				var hp := Vector3(s * 2.6, yh + 0.9 + float(i % 2) * 0.72, 66.4 + float(i / 2) * 0.75)
				k.body.xform = Transform3D(Basis(Vector3(0.0, 0.0, 1.0), s * deg_to_rad(35.0)), hp)
				k.body.add_prism(VehicleKit.rounded_rect(0.7, 0.7, 0.08, 1), 2.2, 0.0, 0.0, 30.0, 0.0)
				k.body.xform = Transform3D.IDENTITY
	)
	a.out["main"] = [
		_gun_mk45(a, hull, Vector3(0.0, d.call(-66.0), -66.0), Vector2(-150.0, 150.0), 0.0),
		_gun_mk45(a, hull, Vector3(0.0, d.call(75.0), 75.0), Vector2(30.0, -30.0), PI),
	]
	var aa: Array = []
	for s: float in [-1.0, 1.0]:
		aa.append(_phalanx(a, hull, Vector3(s * 4.6, ya + 6.5, 26.5), Vector2(-180.0, 180.0), PI))
	a.out["aa"] = aa
	var sams: Array[Node3D] = []
	var cells := _vls_cells(vls_f, 8, 8) + _vls_cells(vls_a, 8, 8)
	for i in range(0, cells.size(), 9):
		sams.append(a.node(hull, "VLSCell", cells[i] + Vector3.UP * 0.1, Vector3(90.0, 0.0, 0.0)))
	a.out["sam_points"] = sams
	a.out["radars"] = [_big_radar(a, hull, "SPS49", Vector3(0.0, yf + 22.8, -26.0), 7.3, 3.2, 0.5, 0.9)]
	a.out["wake_points"] = [a.node(root, "Wake", Vector3(0.0, 0.2, 86.0))]
	a.out["body_aabb"] = AABB(Vector3(-8.4, -6.5, -86.4), Vector3(16.8, 22.0, 172.8))
	for s: float in [-1.0, 1.0]:
		a.decal(hull, Insignia.hull_number("47", true), Vector3(s * 6.3, 7.4, -70.0), Vector3(s, 0.0, -0.2), 4.4, 2.5)


# === Ракетный крейсер проекта 1164 «Слава» (СССР) — флагман реактивной эпохи ====================================
## Корпус 186,4 × 20,8 м; шестнадцать пусковых ПКР «Вулкан» попарно вдоль носовой надстройки, спаренная
## 130-мм АК-130, мостик с башней и РЛС «Фрегат» (Top Pair), две трубы бок о бок, кормовая надстройка
## с обтекателем РЛС «Top Dome», восемь люков ЗРК С-300Ф, шесть АК-630, вертолётная площадка.
static func _slava(a: ModelAsm) -> void:
	var p := {"L": 186.4, "B": 20.8, "T": 7.6, "D": 7.2, "bow_sheer": 3.2, "stern_sheer": -0.8, "entry": 0.4, "run": 0.72, "run_beam": 0.72, "transom": 0.82, "stern_rise": 0.22, "flare": 0.26, "camber": 0.32, "forefoot": 0.11, "stem_curve": 1.9, "n_mid": 3.0}
	var root := a.root
	var hull := a.node(root, "Hull")
	a.out["hull"] = hull
	var d := func(z: float) -> float: return _deck_at(p, z)
	var yb: float = _deck_at(p, -15.0)
	var ya: float = _deck_at(p, 22.0)
	var hatches: Array[Vector3] = []
	for i in 4:
		for s: float in [-1.0, 1.0]:
			var zh := 41.0 + float(i) * 3.3
			hatches.append(Vector3(s * 2.7, _deck_at(p, zh, 2.7), zh))
	a.mesh(hull, "HullBody", func(k: VehicleKit) -> void:
		_hull(k, p)
		_fittings(k, p, -86.0)
		_deck_rails(k, p, -90.0, 92.0)
		_portholes(k, p, -80.0, 60.0, 1.6, 3.2)
		# Носовая рубка и пусковые «Вулкан» (по четыре пары с каждого борта, ступенями).
		var yh: float = d.call(-45.0)
		_house(k, 7.0, 40.0, -45.0, yh - 0.3, yh + 3.0, 1.5, 0.2)
		for s: float in [-1.0, 1.0]:
			for kp in 4:
				var zc := -58.0 + float(kp) * 9.0
				var yc: float = d.call(zc)
				var base := Vector3(0.0, yc + 1.7 + float(kp) * 0.45, zc)
				k.body.xform = Transform3D(Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(8.0)), base)
				for tx: float in [4.8, 6.8]:
					VehicleKit.cyl(k.body, Vector3(s * tx, 0.0, 5.3), Vector3(s * tx, 0.0, -5.3), 0.95, 18)
					k.dark.xform = k.body.xform
					k.dark.add_disc(Vector3(s * tx, 0.0, -5.31), Vector3(0.0, 0.0, -1.0), 0.85, 16)
					k.dark.xform = Transform3D.IDENTITY
				k.body.xform = Transform3D.IDENTITY
				VehicleKit.box(k.dark, Vector3(s * 5.8, yc + 0.7 + float(kp) * 0.2, zc + 3.0), Vector3(3.8, 1.2 + float(kp) * 0.4, 0.4))
				VehicleKit.box(k.dark, Vector3(s * 5.8, yc + 0.7 + float(kp) * 0.2, zc - 2.5), Vector3(3.8, 1.0 + float(kp) * 0.4, 0.4))
		# Надстройка, мостик, башня с РЛС.
		_house(k, 15.0, 20.0, -14.0, yb - 0.3, yb + 6.5, 2.5, 0.5)
		_house(k, 12.0, 11.0, -18.0, yb + 6.5, yb + 10.0, 2.2, 0.4)
		_house_windows(k, 12.0, 11.0, -18.0, yb + 6.5, yb + 10.0, 2.2, 0.4, 1.3, 2.5, 8, 3)
		_house(k, 6.0, 6.0, -13.0, yb + 10.0, yb + 16.0, 1.2, 0.8)
		# Две трубы бок о бок.
		for s: float in [-1.0, 1.0]:
			_funnel(k, Vector3(s * 3.1, d.call(3.0) - 0.3, 3.0), 3.8, 7.5, 9.0, 0.0)
		# Кормовая надстройка с обтекателем РЛС и мачтой.
		_house(k, 15.0, 26.0, 23.0, ya - 0.3, ya + 6.8, 2.5, 0.5)
		k.part(VehicleKit.P_WHITE)
		k.body.xform = Transform3D(Basis(), Vector3(0.0, ya + 6.8, 30.0))
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 2.3), Vector2(1.2, 2.25), Vector2(2.4, 1.6), Vector2(3.0, 0.7), Vector2(3.15, 0.0)]), 22, true, false, 45.0)
		k.body.xform = Transform3D.IDENTITY
		k.part(VehicleKit.P_HULL)
		VehicleKit.lattice(k.metal, Vector3(0.0, ya + 6.8, 16.0), Vector3(0.0, ya + 18.0, 16.5), 3.6, 1.0, 4, 5, 0.1)
		# Люки пусковых С-300Ф.
		for h: Vector3 in hatches:
			VehicleKit.cyl(k.dark, h + Vector3(0.0, -0.05, 0.0), h + Vector3(0.0, 0.06, 0.0), 1.25, 20)
			VehicleKit.cyl(k.body, h + Vector3(0.0, 0.06, 0.0), h + Vector3(0.0, 0.14, 0.0), 1.1, 20)
		_helipad(k, Vector3(0.0, d.call(72.0), 72.0), 5.5, 16.0)
		var ym: float = d.call(-2.0)
		for s: float in [-1.0, 1.0]:
			_boat_davit(k, Vector3(s * 8.4, ym + 2.3, -2.0), s, 8.0)
			_liferafts(k, Vector3(s * 6.8, ya + 7.0, 14.0), 5, s)
	)
	a.out["main"] = [_gun_ak130(a, hull, Vector3(0.0, d.call(-75.0), -75.0), Vector2(-150.0, 150.0), 0.0)]
	var aa: Array = []
	for s: float in [-1.0, 1.0]:
		aa.append(_ak630(a, hull, Vector3(s * 5.8, yb + 6.5, -8.5), Vector2(-180.0, 180.0), 0.0))
		aa.append(_ak630(a, hull, Vector3(s * 6.2, ya + 6.8, 14.0), Vector2(-180.0, 180.0), 0.0))
		aa.append(_ak630(a, hull, Vector3(s * 5.8, ya + 6.8, 33.5), Vector2(-180.0, 180.0), PI))
	a.out["aa"] = aa
	var sams: Array[Node3D] = []
	for h: Vector3 in hatches:
		sams.append(a.node(hull, "Revolver", h + Vector3.UP * 0.3, Vector3(90.0, 0.0, 0.0)))
	a.out["sam_points"] = sams
	a.out["radars"] = [_big_radar(a, hull, "TopPair", Vector3(0.0, yb + 16.6, -13.0), 7.0, 2.6, 0.25, 1.0, true)]
	a.out["wake_points"] = [a.node(root, "Wake", Vector3(0.0, 0.2, 93.0))]
	a.out["body_aabb"] = AABB(Vector3(-10.4, -7.6, -93.2), Vector3(20.8, 24.0, 186.4))
	for s: float in [-1.0, 1.0]:
		a.decal(hull, Insignia.hull_number("121", false), Vector3(s * 7.4, 7.8, -76.0), Vector3(s, 0.0, -0.2), 5.0, 2.8)


# === Лёгкий крейсер типа «Кливленд» (США, 1942) — флагман эпохи 1940-х ==========================================
## Корпус 186 × 20,2 м; четыре трёхорудийные 152-мм башни (по две в носу и в корме, с возвышением), шесть
## спаренных 5"/38 (две по оси, четыре бортовые), счетверённые «Бофорсы», мостик с боевой рубкой и директорами
## Mk 37, треногие мачты, две дымовые трубы, катапульты на юте. Окраска «Мера 22».
static func _cleveland(a: ModelAsm) -> void:
	var p := {"L": 186.0, "B": 20.2, "T": 7.5, "D": 7.0, "bow_sheer": 2.4, "stern_sheer": -1.2, "entry": 0.4, "run": 0.7, "run_beam": 0.72, "transom": 0.7, "stern_rise": 0.2, "flare": 0.14, "camber": 0.3, "forefoot": 0.1, "stem_curve": 2.0, "n_mid": 3.3}
	var root := a.root
	var hull := a.node(root, "Hull")
	a.out["hull"] = hull
	var d := func(z: float) -> float: return _deck_at(p, z)
	var yb: float = _deck_at(p, -30.0)
	var ya: float = _deck_at(p, 26.0)
	a.mesh(hull, "HullBody", func(k: VehicleKit) -> void:
		_hull(k, p)
		_fittings(k, p, -86.0)
		_deck_rails(k, p, -90.0, 91.0)
		_portholes(k, p, -80.0, 70.0, 1.6, 2.6)
		# Носовая надстройка, боевая рубка, мостик, директоры Mk 37, фок-мачта.
		_house(k, 13.0, 22.0, -30.0, yb - 0.3, yb + 3.0, 1.8, 0.1)
		_house(k, 11.0, 16.0, -31.0, yb + 3.0, yb + 6.0, 1.8, 0.2)
		_house(k, 9.0, 8.0, -33.5, yb + 6.0, yb + 8.5, 1.6, 0.2)
		_house_windows(k, 9.0, 8.0, -33.5, yb + 6.0, yb + 8.5, 1.6, 0.2, 0.9, 1.8, 7, 3)
		VehicleKit.cyl(k.body, Vector3(0.0, yb + 3.0, -38.4), Vector3(0.0, yb + 5.6, -38.4), 1.9, 20)
		for zd: float in [-32.0]:
			VehicleKit.cbox(k.body, Vector3(0.0, yb + 9.6, zd), Vector3(3.4, 2.0, 3.6), 0.3)
			k.metal.add_tube(PackedVector3Array([Vector3(-2.5, yb + 9.9, zd + 0.4), Vector3(2.5, yb + 9.9, zd + 0.4)]), 0.14, 8)
		var fore: Vector3 = _tripod(k, Vector3(0.0, yb + 6.0, -26.0), 20.0, 1.6, 0.3, 2.0)
		k.metal.add_tube(PackedVector3Array([fore + Vector3(-3.6, -4.0, 0.0), fore + Vector3(3.6, -4.0, 0.0)]), 0.1, 5)
		# Трубы на рубке, бортовые площадки 5-дюймовок.
		var ym: float = d.call(0.0)
		_house(k, 9.0, 26.0, 0.0, ym - 0.3, ym + 2.6, 1.4, 0.1)
		_funnel(k, Vector3(0.0, ym + 2.5, -8.0), 4.2, 6.2, 9.5, 8.0)
		_funnel(k, Vector3(0.0, ym + 2.5, 7.0), 4.0, 6.0, 9.0, 8.0)
		for s: float in [-1.0, 1.0]:
			for zw: float in [-16.0, 16.0]:
				var yw: float = d.call(zw)
				_house(k, 4.5, 5.0, zw, yw - 0.3, yw + 2.2, 0.6, 0.05, VehicleKit.P_UPPER, s * 6.9)
		# Кормовая надстройка с директором и грот-мачтой.
		_house(k, 12.0, 18.0, 26.0, ya - 0.3, ya + 3.0, 1.8, 0.1)
		_house(k, 9.0, 10.0, 25.0, ya + 3.0, ya + 5.5, 1.6, 0.2)
		VehicleKit.cbox(k.body, Vector3(0.0, ya + 6.6, 26.0), Vector3(3.4, 2.0, 3.6), 0.3)
		k.metal.add_tube(PackedVector3Array([Vector3(-2.5, ya + 6.9, 26.4), Vector3(2.5, ya + 6.9, 26.4)]), 0.14, 8)
		_tripod(k, Vector3(0.0, ya + 5.5, 21.0), 13.0, 1.3, 0.26, 2.0)
		# Катапульты и кран на юте.
		var yc: float = d.call(80.0)
		for s: float in [-1.0, 1.0]:
			VehicleKit.cyl(k.dark, Vector3(s * 4.5, yc, 80.0), Vector3(s * 4.5, yc + 0.9, 80.0), 0.6, 12)
			k.dark.xform = Transform3D(Basis(Vector3.UP, s * deg_to_rad(35.0)), Vector3(s * 4.5, yc + 1.1, 80.0))
			k.dark.add_box(Vector3(0.0, 0.0, 0.0), Vector3(0.8, 0.4, 13.0))
			k.dark.xform = Transform3D.IDENTITY
		k.metal.add_tube(PackedVector3Array([Vector3(0.0, yc, 88.0), Vector3(0.0, yc + 7.0, 87.0), Vector3(0.0, yc + 8.0, 80.0)]), 0.2, 6)
		for s: float in [-1.0, 1.0]:
			_boat_davit(k, Vector3(s * 5.6, ym + 2.6, 12.0), s, 8.0)
	)
	a.out["main"] = [
		_turret_triple(a, hull, Vector3(0.0, d.call(-60.0), -60.0), "T152", 7.2, 0.26, 0.12, 8.2, Vector2(-150.0, 150.0), 0.0),
		_turret_triple(a, hull, Vector3(0.0, d.call(-49.0) + 2.6, -49.0), "T152", 7.2, 0.26, 0.12, 8.2, Vector2(-150.0, 150.0), 0.0, 2.6),
		_turret_triple(a, hull, Vector3(0.0, d.call(47.0) + 2.6, 47.0), "T152", 7.2, 0.26, 0.12, 8.2, Vector2(30.0, -30.0), PI, 2.6),
		_turret_triple(a, hull, Vector3(0.0, d.call(58.0), 58.0), "T152", 7.2, 0.26, 0.12, 8.2, Vector2(30.0, -30.0), PI),
	]
	var aa: Array = []
	aa.append(_gun_5in38_twin(a, hull, Vector3(0.0, yb + 3.0, -40.5), Vector2(-150.0, 150.0), 0.0))
	aa.append(_gun_5in38_twin(a, hull, Vector3(0.0, ya + 3.0, 36.0), Vector2(30.0, -30.0), PI))
	for s: float in [-1.0, 1.0]:
		for zw: float in [-16.0, 16.0]:
			aa.append(_gun_5in38_twin(a, hull, Vector3(s * 6.9, _deck_at(p, zw) + 2.2, zw), Vector2(-180.0, 180.0), 0.0))
		aa.append(_bofors_quad(a, hull, Vector3(s * 6.0, _deck_at(p, -2.0) + 2.6, -2.0), Vector2(-180.0, 180.0), 0.0))
		aa.append(_bofors_quad(a, hull, Vector3(s * 5.0, ya + 3.0, 31.0), Vector2(-180.0, 180.0), PI))
	a.out["aa"] = aa
	a.out["radars"] = [_big_radar(a, hull, "SK", Vector3(0.0, yb + 26.4, -25.3), 4.6, 3.6, 0.1, 0.8)]
	a.out["wake_points"] = [a.node(root, "Wake", Vector3(0.0, 0.2, 93.0))]
	a.out["body_aabb"] = AABB(Vector3(-10.1, -7.5, -93.0), Vector3(20.2, 22.0, 186.0))


# === Крейсер проекта 26 «Киров» (СССР, 1938) — флагман эпохи 1940-х ==============================================
## Корпус 191,3 × 17,7 м с длинным полубаком; три трёхорудийные 180-мм башни (две в носу, одна в корме),
## высокая командная башня с КДП, треногие мачты, две трубы, катапульта с краном, шесть 100-мм Б-34 и 45-мм 21-К.
static func _kirov26(a: ModelAsm) -> void:
	var p := {"L": 191.3, "B": 17.7, "T": 6.3, "D": 6.0, "bow_sheer": 2.6, "fc": [0.6, 1.4], "stern_sheer": -0.5, "entry": 0.42, "run": 0.72, "run_beam": 0.74, "transom": 0.7, "stern_rise": 0.22, "flare": 0.15, "camber": 0.28, "forefoot": 0.1, "stem_curve": 2.0, "n_mid": 3.2}
	var root := a.root
	var hull := a.node(root, "Hull")
	a.out["hull"] = hull
	var d := func(z: float) -> float: return _deck_at(p, z)
	var yb: float = _deck_at(p, -40.0)
	var ya: float = _deck_at(p, 26.0)
	a.mesh(hull, "HullBody", func(k: VehicleKit) -> void:
		_hull(k, p)
		_fittings(k, p, -88.0)
		_deck_rails(k, p, -92.0, 94.0)
		_portholes(k, p, -82.0, 20.0, 1.6, 2.6)
		# Носовая надстройка, мостик и высокая командная башня с КДП, фок-мачта.
		_house(k, 11.0, 18.0, -39.0, yb - 0.3, yb + 3.0, 1.6, 0.1)
		_house(k, 9.0, 12.0, -40.0, yb + 3.0, yb + 6.0, 1.6, 0.2)
		_house(k, 8.0, 6.0, -42.5, yb + 6.0, yb + 8.5, 1.4, 0.2)
		_house_windows(k, 8.0, 6.0, -42.5, yb + 6.0, yb + 8.5, 1.4, 0.2, 0.9, 1.8, 6, 2)
		VehicleKit.cyl(k.body, Vector3(0.0, yb + 8.5, -40.0), Vector3(0.0, yb + 14.0, -40.0), 2.0, 20)
		VehicleKit.cbox(k.body, Vector3(0.0, yb + 15.0, -40.0), Vector3(3.6, 2.0, 3.6), 0.3)
		k.metal.add_tube(PackedVector3Array([Vector3(-3.0, yb + 15.3, -39.6), Vector3(3.0, yb + 15.3, -39.6)]), 0.16, 8)
		var fore: Vector3 = _tripod(k, Vector3(0.0, yb + 6.0, -33.0), 20.0, 1.6, 0.3, 2.0)
		k.metal.add_tube(PackedVector3Array([fore + Vector3(-3.4, -4.0, 0.0), fore + Vector3(3.4, -4.0, 0.0)]), 0.1, 5)
		# Трубы, катапульта с краном.
		var ym: float = d.call(-11.0)
		_house(k, 8.0, 28.0, -11.0, ym - 0.3, ym + 2.2, 1.2, 0.1)
		_funnel(k, Vector3(0.0, ym + 2.1, -20.0), 4.6, 7.0, 9.0, 5.0)
		_funnel(k, Vector3(0.0, ym + 2.1, -2.0), 4.2, 6.2, 8.4, 5.0)
		VehicleKit.cyl(k.dark, Vector3(0.0, ym + 2.2, -11.0), Vector3(0.0, ym + 3.2, -11.0), 0.8, 12)
		k.dark.xform = Transform3D(Basis(Vector3.UP, deg_to_rad(25.0)), Vector3(0.0, ym + 3.4, -11.0))
		k.dark.add_box(Vector3.ZERO, Vector3(0.9, 0.5, 15.0))
		k.dark.xform = Transform3D.IDENTITY
		k.metal.add_tube(PackedVector3Array([Vector3(4.2, ym + 2.2, -11.0), Vector3(4.2, ym + 10.0, -11.5), Vector3(0.5, ym + 11.0, -12.0)]), 0.18, 6)
		# Грот-мачта, кормовая надстройка с дальномером.
		_tripod(k, Vector3(0.0, d.call(14.0), 14.0), 16.0, 1.4, 0.26, 2.0)
		_house(k, 9.0, 14.0, 26.0, ya - 0.3, ya + 3.0, 1.4, 0.1)
		VehicleKit.cbox(k.body, Vector3(0.0, ya + 4.1, 25.0), Vector3(3.0, 1.8, 3.0), 0.3)
		k.metal.add_tube(PackedVector3Array([Vector3(-2.4, ya + 4.4, 25.3), Vector3(2.4, ya + 4.4, 25.3)]), 0.13, 8)
		for s: float in [-1.0, 1.0]:
			_boat_davit(k, Vector3(s * 5.4, ym + 2.4, 6.0), s, 8.0)
	)
	a.out["main"] = [
		_turret_triple(a, hull, Vector3(0.0, d.call(-66.0), -66.0), "T180", 10.3, 0.3, 0.14, 8.0, Vector2(-150.0, 150.0), 0.0),
		_turret_triple(a, hull, Vector3(0.0, d.call(-55.0) + 2.4, -55.0), "T180", 10.3, 0.3, 0.14, 8.0, Vector2(-150.0, 150.0), 0.0, 2.4),
		_turret_triple(a, hull, Vector3(0.0, d.call(47.0) + 1.0, 47.0), "T180", 10.3, 0.3, 0.14, 8.0, Vector2(30.0, -30.0), PI, 1.0),
	]
	var aa: Array = []
	for s: float in [-1.0, 1.0]:
		for zz: float in [-26.0, 4.0, 12.0]:
			aa.append(_aa_single(a, hull, Vector3(s * 6.6, d.call(zz), zz), "B34", 1.45, "su"))
		aa.append(_aa_single(a, hull, Vector3(s * 3.2, ya + 3.0, 30.0), "K21", 0.85, "su", Vector2(-180.0, 180.0), PI))
		aa.append(_aa_single(a, hull, Vector3(s * 3.6, yb + 3.0, -45.0), "K21", 0.85, "su"))
	a.out["aa"] = aa
	a.out["wake_points"] = [a.node(root, "Wake", Vector3(0.0, 0.2, 95.0))]
	a.out["body_aabb"] = AABB(Vector3(-8.85, -6.3, -95.7), Vector3(17.7, 23.0, 191.3))


# === Детали катеров ==================================================================================================
## Высота палубы у борта (без погиби) на продольной координате z.
static func _deck_edge(p: Dictionary, z: float) -> float:
	return _deck_y(p, clampf((z + float(p["L"]) * 0.5) / float(p["L"]), 0.0, 1.0))


## Приподнятый полубак, повторяющий седловатость и обводы палубы: от z0 до z1, высота h над кромкой палубы,
## стенки отступают от борта на inset, торцы закрыты.
static func _raised_deck(k: VehicleKit, p: Dictionary, z0: float, z1: float, h: float, inset: float) -> void:
	var st: Array = []
	for i in 13:
		var z := lerpf(z0, z1, float(i) / 12.0)
		var w := maxf(_beam_at(p, z) - inset, 0.1)
		var y := _deck_edge(p, z)
		st.append([z, PackedVector2Array([Vector2(0.0, y - 0.4), Vector2(w, y - 0.4), Vector2(w, y + h - 0.05), Vector2(w - 0.06, y + h), Vector2(w * 0.5, y + h + 0.05), Vector2(0.0, y + h + 0.07)])])
	k.part(VehicleKit.P_UPPER)
	k.body.add_sections(st, 30.0, true, true, true)
	k.part(VehicleKit.P_HULL)


## Белый полусферический обтекатель антенны радиусом r с основанием в pos.
static func _dome(k: VehicleKit, pos: Vector3, r: float) -> void:
	var prof := PackedVector2Array()
	for i in 7:
		var t := float(i) / 6.0 * PI * 0.5
		prof.append(Vector2(sin(t) * r, cos(t) * r))
	var old := k.body.xform
	k.body.xform = old * Transform3D(Basis(), pos)
	k.part(VehicleKit.P_WHITE)
	k.body.add_lathe(prof, 16, false, false, 60.0)
	k.part(VehicleKit.P_HULL)
	k.body.xform = old


## Образующая сферы радиуса r для add_lathe (от нижнего полюса к верхнему).
static func _sphere_profile(r: float, n: int = 8) -> PackedVector2Array:
	var prof := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n) * PI
		prof.append(Vector2(-cos(t) * r, sin(t) * r))
	return prof


## Торпеда (тело вращения) от хвоста tail вперёд по -Z: длина length, радиус r, крестовина стабилизаторов.
static func _torpedo_body(k: VehicleKit, tail: Vector3, length: float, r: float) -> void:
	k.metal.xform = VehicleKit.forward_xform(tail)
	k.metal.add_lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, r * 0.35), Vector2(r * 1.1, r * 0.85), Vector2(r * 2.2, r), Vector2(length - r * 1.6, r), Vector2(length - r * 0.6, r * 0.6), Vector2(length, 0.0)]), 12)
	k.metal.xform = Transform3D.IDENTITY
	VehicleKit.box(k.dark, tail + Vector3(0.0, 0.0, -0.12), Vector3(r * 2.1, 0.025, 0.16))
	VehicleKit.box(k.dark, tail + Vector3(0.0, 0.0, -0.12), Vector3(0.025, r * 2.1, 0.16))


# === Вооружение катеров ==============================================================================================
## Пулемётная установка с расчётом: на турели в кольце по пояс (tub) или на тумбе; одиночный ДШК с дульным
## тормозом или спаренный M2 с патронными коробами по бокам.
static func _mg_ring(a: ModelAsm, parent: Node3D, pos: Vector3, part: String, twin: bool, helmet: String, arc: Vector2 = Vector2(-180.0, 180.0), rest: float = 0.0, tub: bool = true) -> Dictionary:
	var muzzle := "brake" if part.begins_with("DShK") else "flash"
	var xs: Array = [-0.13, 0.13] if twin else [0.0]
	var mz: Array = []
	for x: float in xs:
		mz.append(Vector3(x, 0.0, -1.3))
	return _mount(a, parent, part, pos, func(k: VehicleKit) -> void:
		if tub:
			k.part(VehicleKit.P_UPPER)
			k.body.add_lathe(PackedVector2Array([Vector2(-0.3, 0.64), Vector2(0.72, 0.64), Vector2(0.78, 0.6)]), 18, false, false, 30.0)
			k.body.add_lathe(PackedVector2Array([Vector2(0.78, 0.6), Vector2(0.76, 0.57), Vector2(0.0, 0.57)]), 18, false, false, 30.0)
			k.part(VehicleKit.P_HULL)
		else:
			VehicleKit.cyl(k.dark, Vector3(0.0, -0.2, -0.35), Vector3(0.0, 0.95, -0.35), 0.06, 8)
			VehicleKit.cyl(k.dark, Vector3(0.0, -0.2, -0.35), Vector3(0.0, 0.05, -0.35), 0.16, 10)
		VehicleKit.crew(k, Vector3(0.0, 0.0, 0.5), 0.0, false, helmet)
	, func(k: VehicleKit) -> void:
		for x: float in xs:
			VehicleKit.box(k.gun, Vector3(x, 0.0, 0.1), Vector3(0.12, 0.15, 0.55))
			VehicleKit.barrel(k, Vector3(x, 0.0, -0.18), 1.1, 0.026, 0.02, muzzle, 8)
			VehicleKit.box(k.dark, Vector3(x + (0.16 if x >= 0.0 else -0.16), -0.05, 0.12), Vector3(0.12, 0.16, 0.3))
		VehicleKit.box(k.gun, Vector3(0.0, -0.1, 0.05), Vector3(0.4 if twin else 0.16, 0.06, 0.12))
		for s: float in [-1.0, 1.0]:
			k.metal.add_tube(PackedVector3Array([Vector3(s * 0.12, -0.02, 0.35), Vector3(s * 0.16, -0.05, 0.6)]), 0.018, 4)
	, Vector3(0.0, 1.05, -0.35), mz, arc, rest)


## Дистанционно управляемый модуль на тумбе масштаба size: 1 — 12,7-мм пулемёт или 40-мм гранатомёт,
## 1,6 — 25-мм Mk 38 Mod 2 (оптико-электронный блок слева, патронный короб справа).
static func _rws(a: ModelAsm, parent: Node3D, pos: Vector3, part: String, size: float, arc: Vector2 = Vector2(-180.0, 180.0), rest: float = 0.0) -> Dictionary:
	var sc := size
	return _mount(a, parent, part, pos, func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 0.38 * sc), Vector2(0.14 * sc, 0.34 * sc)]), 16, false, true, 40.0)
		k.body.add_prism(PackedVector2Array([Vector2(-0.3 * sc, 0.12 * sc), Vector2(0.35 * sc, 0.12 * sc), Vector2(0.35 * sc, 0.42 * sc), Vector2(-0.2 * sc, 0.44 * sc)]), 0.26 * sc)
		k.part(VehicleKit.P_HULL)
	, func(k: VehicleKit) -> void:
		k.part(VehicleKit.P_UPPER)
		VehicleKit.cbox(k.body, Vector3(0.0, 0.0, 0.05 * sc), Vector3(0.3 * sc, 0.26 * sc, 0.7 * sc), 0.03)
		VehicleKit.cbox(k.body, Vector3(-0.26 * sc, 0.06 * sc, -0.05 * sc), Vector3(0.16 * sc, 0.2 * sc, 0.26 * sc), 0.02)
		VehicleKit.cbox(k.body, Vector3(0.25 * sc, -0.02 * sc, 0.12 * sc), Vector3(0.14 * sc, 0.24 * sc, 0.4 * sc), 0.02)
		k.part(VehicleKit.P_HULL)
		k.glass.add_box(Vector3(-0.26 * sc, 0.06 * sc, -0.185 * sc), Vector3(0.1 * sc, 0.1 * sc, 0.01))
		VehicleKit.barrel(k, Vector3(0.0, 0.0, -0.3 * sc), 1.2 * sc, 0.03 * sc, 0.022 * sc, "brake" if sc > 1.3 else "flash", 8)
	, Vector3(0.0, 0.62 * sc, 0.0), [Vector3(0.0, 0.0, -1.55 * sc)], arc, rest)


# === Торпедный катер Г-5 (СССР) ======================================================================================
## Дюралевый реданный глиссер конструкции Туполева 19 × 3,4 м с округлой «черепашьей» палубой: рубка с
## иллюминаторами и ветровым стеклом, спаренные ДШК на турели, две 533-мм торпеды в кормовых жёлобах
## (сбрасывались хвостом вперёд), рама реактивных снарядов М-8.
static func _g5(a: ModelAsm) -> void:
	var p := {"L": 19.1, "B": 3.4, "T": 0.75, "D": 0.85, "bow_sheer": 0.35, "stern_sheer": 0.0, "entry": 0.42, "run": 0.62, "run_beam": 0.8, "transom": 0.92, "stern_rise": 0.95, "flare": 0.0, "camber": 0.75, "forefoot": 0.18, "stem_curve": 1.5, "chine": true, "deadrise": 14.0, "deadrise_bow": 34.0, "chine_in": 0.96, "stations": 36}
	var root := a.root
	var hull := a.node(root, "Hull")
	a.out["hull"] = hull
	var yc := _deck_at(p, -1.6)
	var rails := Transform3D(Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(20.0)), Vector3(0.0, _deck_at(p, 2.4) + 0.35, 2.4))
	a.mesh(hull, "HullBody", func(k: VehicleKit) -> void:
		_hull(k, p)
		# Рубка с иллюминаторами, ветровое стекло, флагшток.
		k.part(VehicleKit.P_UPPER)
		k.body.add_block(VehicleKit.rounded_rect(1.3, 1.9, 0.5, 3, 0.0, -1.6), yc - 0.35, yc + 0.5, 0.12, true, false, 30.0)
		k.part(VehicleKit.P_HULL)
		k.glass.xform = MeshFactory.xf(Vector3(0.0, yc + 0.66, -2.36), Vector3(35.0, 0.0, 0.0))
		k.glass.add_box(Vector3.ZERO, Vector3(0.95, 0.34, 0.02))
		k.glass.xform = Transform3D.IDENTITY
		for s: float in [-1.0, 1.0]:
			for dz: float in [-0.35, 0.35]:
				k.dark.add_disc(Vector3(s * 0.585, yc + 0.18, -1.6 + dz), Vector3(s, 0.15, 0.0), 0.08, 8)
		_pole(k, Vector3(0.0, yc + 0.5, -0.9), 1.8, 0.035)
		# Торпеды в кормовых жёлобах.
		for s: float in [-1.0, 1.0]:
			var yt := _deck_at(p, 6.0, 0.85)
			_torpedo_body(k, Vector3(s * 0.85, yt + 0.14, 9.3), 6.0, 0.27)
			for dx: float in [-0.3, 0.3]:
				VehicleKit.box(k.dark, Vector3(s * 0.85 + dx, yt + 0.02, 6.3), Vector3(0.05, 0.12, 6.0))
		# Рама реактивных снарядов М-8 (восемь направляющих) на стойках.
		k.dark.xform = rails
		for i in 4:
			for row in 2:
				k.dark.add_box(Vector3(-0.45 + float(i) * 0.3, float(row) * 0.2, 0.0), Vector3(0.06, 0.05, 1.6))
		for zz: float in [-0.5, 0.5]:
			k.dark.add_box(Vector3(0.0, -0.1, zz), Vector3(1.2, 0.08, 0.1))
		k.dark.xform = Transform3D.IDENTITY
		for s: float in [-1.0, 1.0]:
			var front: Vector3 = rails * Vector3(s * 0.55, -0.1, -0.5)
			var back: Vector3 = rails * Vector3(s * 0.55, -0.1, 0.5)
			VehicleKit.cyl(k.dark, Vector3(front.x, front.y - 0.6, front.z), front, 0.035, 6)
			VehicleKit.cyl(k.dark, Vector3(back.x, back.y - 0.3, back.z), back, 0.035, 6)
	)
	a.out["mounts"] = [_mg_ring(a, hull, Vector3(0.0, _deck_at(p, 0.4), 0.4), "DShK2", true, "su")]
	var tubes: Array[Node3D] = []
	for s: float in [-1.0, 1.0]:
		tubes.append(a.node(hull, "TorpedoTube", Vector3(s * 0.95, 0.3, -3.0)))
	a.out["torpedo_tubes"] = tubes
	var sp: Array[Node3D] = []
	for row in 2:
		for i in 4:
			sp.append(a.node(hull, "Rocket", rails * Vector3(-0.45 + float(i) * 0.3, float(row) * 0.2 + 0.05, -0.85), Vector3(20.0, 0.0, 0.0)))
	a.out["special_points"] = sp
	a.out["wake_points"] = [a.node(root, "Wake", Vector3(0.0, 0.15, 9.8))]
	a.out["body_aabb"] = AABB(Vector3(-1.7, -0.75, -9.55), Vector3(3.4, 3.1, 19.1))


# === «Шнельбот» S-100 (Германия) =====================================================================================
## Мореходный торпедный катер 32,8 × 5,1 м с округлыми обводами: приподнятый полубак над торпедными
## аппаратами (срезы труб в лобовой стенке), бронированная рубка-«калотта», 2-см автоматы на баке и в
## середине, 3,7-см на корме, запасные торпеды у бортов, выхлопы в транце.
static func _sboot(a: ModelAsm) -> void:
	var p := {"L": 32.8, "B": 5.1, "T": 1.7, "D": 1.9, "bow_sheer": 1.1, "stern_sheer": -0.2, "entry": 0.36, "run": 0.7, "run_beam": 0.72, "transom": 0.72, "stern_rise": 0.45, "flare": 0.22, "camber": 0.16, "forefoot": 0.12, "stem_curve": 1.8, "n_mid": 2.6, "stations": 44}
	var root := a.root
	var hull := a.node(root, "Hull")
	a.out["hull"] = hull
	var z_fc := -12.4
	var fc_h := 0.85
	var y_mouth := _deck_edge(p, z_fc) + 0.5
	var y_bridge := _deck_edge(p, -3.6) + fc_h + 0.07
	a.mesh(hull, "HullBody", func(k: VehicleKit) -> void:
		_hull(k, p)
		_deck_rails(k, p, -1.0, 15.6, 1.4)
		# Полубак над торпедными аппаратами, срезы труб в лобовой стенке.
		_raised_deck(k, p, z_fc, -1.3, fc_h, 0.1)
		for s: float in [-1.0, 1.0]:
			k.dark.add_disc(Vector3(s * 0.62, y_mouth, z_fc - 0.012), Vector3(0.0, 0.0, -1.0), 0.28, 16)
			k.metal.xform = VehicleKit.forward_xform(Vector3(s * 0.62, y_mouth, z_fc + 0.02))
			k.metal.add_lathe(PackedVector2Array([Vector2(0.0, 0.34), Vector2(0.07, 0.34), Vector2(0.07, 0.28)]), 16, false, false, 30.0)
			k.metal.xform = Transform3D.IDENTITY
		# Бронированная рубка-«калотта» со смотровыми щелями и мачта.
		k.part(VehicleKit.P_UPPER)
		k.body.xform = Transform3D(Basis(), Vector3(0.0, y_bridge - 0.1, -3.6))
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 1.45), Vector2(0.55, 1.42), Vector2(0.95, 1.2), Vector2(1.2, 0.8), Vector2(1.32, 0.35), Vector2(1.35, 0.0)]), 24, false, false, 45.0)
		k.body.xform = Transform3D.IDENTITY
		k.part(VehicleKit.P_HULL)
		k.dark.xform = Transform3D(Basis(), Vector3(0.0, y_bridge - 0.1, -3.6))
		k.dark.add_lathe(PackedVector2Array([Vector2(0.72, 1.36), Vector2(0.8, 1.3)]), 24, false, false, 30.0)
		k.dark.xform = Transform3D.IDENTITY
		_pole(k, Vector3(0.0, _deck_edge(p, -1.8) + fc_h, -1.8), 4.5, 0.07, [Vector2(3.2, 1.8)])
		# Машинный люк, запасные торпеды у бортов, выхлопы, спасательные плоты.
		var ym := _deck_at(p, 6.5)
		_house(k, 1.6, 5.0, 6.5, ym - 0.25, ym + 0.45, 0.4, 0.08)
		for s: float in [-1.0, 1.0]:
			var yt := _deck_at(p, 4.5, 1.55)
			_torpedo_body(k, Vector3(s * 1.55, yt + 0.3, 8.2), 7.0, 0.27)
			for zc: float in [2.5, 6.5]:
				VehicleKit.box(k.dark, Vector3(s * 1.55, yt + 0.06, zc), Vector3(0.5, 0.12, 0.15))
			VehicleKit.cyl(k.dark, Vector3(s * 1.2, 0.9, 15.9), Vector3(s * 1.2, 0.9, 16.55), 0.26, 10)
		_liferafts(k, Vector3(1.3, _deck_at(p, 13.4, 1.3) + 0.32, 13.0), 2, 1.0)
	)
	a.out["mounts"] = [
		_aa_single(a, hull, Vector3(0.0, _deck_edge(p, -9.0) + fc_h + 0.07, -9.0), "C30", 0.85, "de", Vector2(-160.0, 160.0), 0.0),
		_aa_single(a, hull, Vector3(0.0, _deck_at(p, 2.0), 2.0), "Flak38", 0.9, "de"),
		_aa_single(a, hull, Vector3(0.0, _deck_at(p, 11.5), 11.5), "Flak37", 1.1, "de", Vector2(25.0, -25.0), PI),
	]
	var tubes: Array[Node3D] = []
	for s: float in [-1.0, 1.0]:
		tubes.append(a.node(hull, "TorpedoTube", Vector3(s * 0.62, 0.4, z_fc - 0.3)))
	a.out["torpedo_tubes"] = tubes
	a.out["wake_points"] = [a.node(root, "Wake", Vector3(0.0, 0.15, 16.6))]
	a.out["body_aabb"] = AABB(Vector3(-2.55, -1.7, -16.4), Vector3(5.1, 5.9, 32.8))


# === Торпедный катер PT-109 (Elco 80', США) =========================================================================
## Фанерный глиссер 24,4 × 6,3 м с острой скулой: штурманская рубка с кокпитом и мачтой РЛС, две турели со
## спаренными 12,7-мм M2 (в шахматном порядке), четыре торпедных аппарата Mk 18 у бортов, 37-мм на баке,
## 20-мм «Эрликон» и дымовой генератор на корме, пусковые Mk 50 для реактивных снарядов, номер на скуле.
static func _pt109(a: ModelAsm) -> void:
	var p := {"L": 24.4, "B": 6.3, "T": 1.1, "D": 1.6, "bow_sheer": 0.7, "stern_sheer": -0.1, "entry": 0.4, "run": 0.6, "run_beam": 0.75, "transom": 0.9, "stern_rise": 0.85, "flare": 0.1, "camber": 0.22, "forefoot": 0.16, "stem_curve": 1.6, "chine": true, "deadrise": 12.0, "deadrise_bow": 38.0, "chine_in": 0.95, "stations": 40}
	var root := a.root
	var hull := a.node(root, "Hull")
	a.out["hull"] = hull
	var yc := _deck_at(p, -3.2)
	var racks: Array[Transform3D] = []
	for s: float in [-1.0, 1.0]:
		racks.append(Transform3D(Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(15.0)), Vector3(s * 1.45, _deck_at(p, -8.0) + 0.4, -8.0)))
	var tubes_fwd: Array = []
	var tubes_aft: Array = []
	for s: float in [-1.0, 1.0]:
		var yf := _deck_at(p, -3.4, 2.5) + 0.42
		var ya := _deck_at(p, 5.4, 2.6) + 0.42
		tubes_fwd.append([Vector3(s * 2.79, yf, 0.05), Vector3(s * 2.31, yf, -6.85)])
		tubes_aft.append([Vector3(s * 2.7, ya, 8.85), Vector3(s * 2.7, ya, 1.95)])
	a.mesh(hull, "HullBody", func(k: VehicleKit) -> void:
		_hull(k, p)
		# Рубка с иллюминаторами, ветровое стекло кокпита, мачта РЛС с обтекателем.
		_house(k, 3.0, 5.5, -3.2, yc - 0.3, yc + 0.95, 0.6, 0.15)
		_house_windows(k, 3.0, 5.5, -3.2, yc - 0.3, yc + 0.95, 0.6, 0.15, 0.55, 0.95, 3, 3)
		k.glass.xform = MeshFactory.xf(Vector3(0.0, yc + 1.12, -1.75), Vector3(30.0, 0.0, 0.0))
		k.glass.add_box(Vector3.ZERO, Vector3(2.2, 0.36, 0.02))
		k.glass.xform = Transform3D.IDENTITY
		k.metal.add_tube(PackedVector3Array([Vector3(0.0, yc + 0.95, -3.6), Vector3(0.0, yc + 3.3, -3.7)]), 0.06, 6)
		k.part(VehicleKit.P_UPPER)
		k.body.xform = Transform3D(Basis(), Vector3(0.0, yc + 3.3, -3.7))
		k.body.add_lathe(PackedVector2Array([Vector2(0.0, 0.34), Vector2(0.3, 0.32), Vector2(0.5, 0.16), Vector2(0.55, 0.0)]), 14, true, false, 45.0)
		k.body.xform = Transform3D.IDENTITY
		k.part(VehicleKit.P_HULL)
		# Торпедные аппараты Mk 18: передняя пара со схождением к носу, задняя — вдоль борта.
		for tube: Array in tubes_fwd + tubes_aft:
			var t0: Vector3 = tube[0]
			var t1: Vector3 = tube[1]
			k.part(VehicleKit.P_UPPER)
			VehicleKit.cyl(k.body, t0, t1, 0.3, 14)
			k.part(VehicleKit.P_HULL)
			k.dark.add_disc(t1 + (t1 - t0).normalized() * 0.005, t1 - t0, 0.25, 12)
			for f: float in [0.1, 0.9]:
				VehicleKit.cyl(k.metal, t0.lerp(t1, f - 0.01), t0.lerp(t1, f + 0.01), 0.33, 14)
			for f: float in [0.25, 0.75]:
				var c := t0.lerp(t1, f)
				VehicleKit.box(k.metal, Vector3(c.x, c.y - 0.3, c.z), Vector3(0.35, 0.3, 0.25))
		# Пусковые НУРС Mk 50 на баке.
		for rk: Transform3D in racks:
			k.dark.xform = rk
			for i in 4:
				for row in 2:
					k.dark.add_box(Vector3(float(i) * 0.16 - 0.24, float(row) * 0.18, 0.0), Vector3(0.05, 0.05, 1.8))
			for zz: float in [-0.6, 0.6]:
				k.dark.add_box(Vector3(0.0, -0.12, zz), Vector3(0.7, 0.08, 0.1))
			k.dark.xform = Transform3D.IDENTITY
			var front: Vector3 = rk * Vector3(0.0, -0.12, -0.6)
			var back: Vector3 = rk * Vector3(0.0, -0.12, 0.6)
			VehicleKit.cyl(k.dark, Vector3(front.x, front.y - 0.6, front.z), front, 0.04, 6)
			VehicleKit.cyl(k.dark, Vector3(back.x, back.y - 0.3, back.z), back, 0.04, 6)
		# Машинный люк и дымовой генератор на транце.
		var ym := _deck_at(p, 3.4)
		_house(k, 1.8, 3.2, 3.4, ym - 0.2, ym + 0.35, 0.3, 0.08)
		var ys := _deck_at(p, 11.6) + 0.33
		VehicleKit.cyl(k.metal, Vector3(0.0, ys, 11.2), Vector3(0.0, ys, 12.1), 0.3, 12)
	)
	var mounts: Array = []
	mounts.append(_mg_ring(a, hull, Vector3(-1.75, _deck_at(p, -0.6, 1.75), -0.6), "M2Twin", true, "us"))
	mounts.append(_mg_ring(a, hull, Vector3(1.75, _deck_at(p, 0.9, 1.75), 0.9), "M2Twin", true, "us"))
	mounts.append(_aa_single(a, hull, Vector3(0.0, _deck_at(p, -9.3), -9.3), "M4_37", 0.95, "us", Vector2(-150.0, 150.0), 0.0))
	mounts.append(_aa_single(a, hull, Vector3(0.0, _deck_at(p, 10.0), 10.0), "Oerlikon", 0.8, "us", Vector2(25.0, -25.0), PI))
	a.out["mounts"] = mounts
	var tubes: Array[Node3D] = []
	for tube: Array in tubes_fwd + tubes_aft:
		var t0: Vector3 = tube[0]
		var t1: Vector3 = tube[1]
		tubes.append(a.node(hull, "TorpedoTube", t1 + (t1 - t0).normalized() * 0.4))
	a.out["torpedo_tubes"] = tubes
	var sp: Array[Node3D] = []
	for rk: Transform3D in racks:
		for i in 4:
			sp.append(a.node(hull, "Rocket", rk * Vector3(float(i) * 0.16 - 0.24, 0.09, -0.95), Vector3(15.0, 0.0, 0.0)))
	a.out["special_points"] = sp
	a.out["wake_points"] = [a.node(root, "Wake", Vector3(0.0, 0.15, 12.4))]
	a.out["body_aabb"] = AABB(Vector3(-3.15, -1.1, -12.2), Vector3(6.3, 4.4, 24.4))
	for s: float in [-1.0, 1.0]:
		a.decal(hull, Insignia.hull_number("109", false), Vector3(s * 1.75, 1.55, -8.5), Vector3(s, 0.0, 0.0), 1.5, 0.9)


# === Безэкипажный катер Sea Baby (Украина) ===========================================================================
## Низкий глиссирующий корпус 6,2 × 2,2 м, гранёная надстройка с аппаратурой, мачта с оптико-электронным
## шаром, антенны и купол спутниковой связи, пулемётный модуль, пеналы торпед по бортам и наклонный
## контейнер баллистической ракеты на корме, водомёты в транце.
static func _seababy(a: ModelAsm) -> void:
	var p := {"L": 6.2, "B": 2.2, "T": 0.35, "D": 0.5, "bow_sheer": 0.15, "entry": 0.45, "run": 0.6, "run_beam": 0.85, "transom": 0.95, "stern_rise": 0.9, "flare": 0.0, "camber": 0.08, "forefoot": 0.2, "stem_curve": 1.4, "chine": true, "deadrise": 16.0, "deadrise_bow": 32.0, "chine_in": 0.97, "stations": 28}
	var root := a.root
	var hull := a.node(root, "Hull")
	a.out["hull"] = hull
	var y0 := _deck_at(p, -0.2)
	var yl := _deck_at(p, 2.2)
	var launcher := Transform3D(Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(25.0)), Vector3(0.0, yl + 0.45, 2.2))
	a.mesh(hull, "HullBody", func(k: VehicleKit) -> void:
		_hull(k, p)
		# Гранёная надстройка с аппаратурой.
		k.part(VehicleKit.P_UPPER)
		k.body.add_prism(PackedVector2Array([Vector2(-1.7, y0 - 0.05), Vector2(0.9, y0 - 0.05), Vector2(0.9, y0 + 0.3), Vector2(-0.6, y0 + 0.38), Vector2(-1.7, y0 + 0.12)]), 0.74, 0.4, y0)
		k.part(VehicleKit.P_HULL)
		# Мачта с оптико-электронным шаром, штыревые антенны, купол спутниковой связи.
		k.metal.add_tube(PackedVector3Array([Vector3(0.5, y0 + 0.33, -1.1), Vector3(0.5, y0 + 1.2, -1.1)]), 0.035, 6)
		k.dark.xform = Transform3D(Basis(), Vector3(0.5, y0 + 1.33, -1.1))
		k.dark.add_lathe(_sphere_profile(0.13), 12, false, false, 60.0)
		k.dark.xform = Transform3D.IDENTITY
		k.glass.add_disc(Vector3(0.5, y0 + 1.33, -1.235), Vector3(0.0, 0.0, -1.0), 0.07, 10)
		VehicleKit.whip(k, Vector3(-0.45, y0 + 0.33, -0.3), 1.3, Vector3(0.0, 0.0, 0.15))
		VehicleKit.whip(k, Vector3(0.45, y0 + 0.3, 0.6), 1.0, Vector3(0.0, 0.0, 0.2))
		_dome(k, Vector3(-0.35, y0 + 0.3, 0.6), 0.15)
		# Пеналы торпед по бортам, водомёты в транце.
		for s: float in [-1.0, 1.0]:
			VehicleKit.cyl(k.dark, Vector3(s * 0.95, y0 + 0.02, 1.7), Vector3(s * 0.95, y0 + 0.02, -0.7), 0.17, 12)
			k.metal.add_disc(Vector3(s * 0.95, y0 + 0.02, -0.705), Vector3(0.0, 0.0, -1.0), 0.13, 12)
			VehicleKit.box(k.dark, Vector3(s * 0.45, 0.1, 3.12), Vector3(0.35, 0.25, 0.05))
		# Пусковой контейнер баллистической ракеты на стойках.
		k.body.xform = launcher
		k.part(VehicleKit.P_UPPER)
		k.body.add_box(Vector3.ZERO, Vector3(0.45, 0.45, 1.1))
		k.part(VehicleKit.P_HULL)
		k.body.xform = Transform3D.IDENTITY
		k.dark.xform = launcher
		k.dark.add_disc(Vector3(0.0, 0.0, -0.555), Vector3(0.0, 0.0, -1.0), 0.18, 14)
		k.dark.xform = Transform3D.IDENTITY
		for s: float in [-1.0, 1.0]:
			var leg: Vector3 = launcher * Vector3(s * 0.18, -0.225, -0.45)
			VehicleKit.cyl(k.dark, Vector3(leg.x, yl - 0.05, leg.z), leg, 0.03, 6)
	)
	a.out["mounts"] = [_rws(a, hull, Vector3(0.0, y0 + 0.32, 0.45), "RWS12", 0.8)]
	var tubes: Array[Node3D] = []
	for s: float in [-1.0, 1.0]:
		tubes.append(a.node(hull, "TorpedoTube", Vector3(s * 0.95, 0.3, -0.9)))
	a.out["torpedo_tubes"] = tubes
	a.out["special_points"] = [a.node(hull, "Launcher", launcher * Vector3(0.0, 0.0, -0.6), Vector3(25.0, 0.0, 0.0))]
	a.out["wake_points"] = [a.node(root, "Wake", Vector3(0.0, 0.1, 3.3))]
	a.out["body_aabb"] = AABB(Vector3(-1.1, -0.35, -3.1), Vector3(2.2, 1.8, 6.2))


# === Патрульный катер Mark VI (США) ==================================================================================
## Алюминиевый катер 25,6 × 6,2 м: рубка с панорамным остеклением, мачта с вращающейся РЛС, купола
## спутниковой связи, две дистанционные 25-мм установки Mk 38 Mod 2 (бак и корма) и 12,7-мм пулемёты
## на тумбах по бортам за рубкой.
static func _markvi(a: ModelAsm) -> void:
	var p := {"L": 25.6, "B": 6.2, "T": 1.2, "D": 2.0, "bow_sheer": 1.0, "stern_sheer": -0.2, "entry": 0.42, "run": 0.62, "run_beam": 0.75, "transom": 0.9, "stern_rise": 0.8, "flare": 0.18, "camber": 0.15, "forefoot": 0.15, "stem_curve": 1.6, "chine": true, "deadrise": 16.0, "deadrise_bow": 36.0, "chine_in": 0.93, "stations": 40}
	var root := a.root
	var hull := a.node(root, "Hull")
	a.out["hull"] = hull
	var yh := _deck_at(p, -0.5)
	a.mesh(hull, "HullBody", func(k: VehicleKit) -> void:
		_hull(k, p)
		_deck_rails(k, p, -11.0, 12.6, 1.4)
		# Рубка, крыша-мостик, мачта, купола, антенны, спасательные плоты.
		_house(k, 4.8, 7.5, -0.5, yh - 0.3, yh + 2.3, 1.2, 0.35)
		_house_windows(k, 4.8, 7.5, -0.5, yh - 0.3, yh + 2.3, 1.2, 0.35, 1.2, 2.1, 5, 4)
		_house(k, 3.8, 5.2, -0.1, yh + 2.3, yh + 2.55, 0.8, 0.05)
		k.metal.add_tube(PackedVector3Array([Vector3(0.0, yh + 2.55, 0.8), Vector3(0.0, yh + 5.4, 1.1)]), 0.09, 6, false, 0.06)
		k.metal.add_tube(PackedVector3Array([Vector3(-1.1, yh + 4.4, 0.95), Vector3(1.1, yh + 4.4, 0.95)]), 0.04, 4)
		for s: float in [-1.0, 1.0]:
			_dome(k, Vector3(s * 1.2, yh + 2.55, 1.5), 0.36)
			VehicleKit.whip(k, Vector3(s * 1.55, yh + 2.55, 2.1), 2.4, Vector3(s * 0.1, 0.0, 0.15))
			_liferafts(k, Vector3(s * 1.4, yh + 2.9, -2.2), 2, s)
	)
	var mounts: Array = []
	mounts.append(_rws(a, hull, Vector3(0.0, _deck_at(p, -8.3), -8.3), "Mk38", 1.6, Vector2(-160.0, 160.0), 0.0))
	mounts.append(_rws(a, hull, Vector3(0.0, _deck_at(p, 9.0), 9.0), "Mk38", 1.6, Vector2(25.0, -25.0), PI))
	for s: float in [-1.0, 1.0]:
		var m := _mg_ring(a, hull, Vector3(s * 2.25, _deck_at(p, 4.6, 2.25), 4.6), "M2", false, "us", Vector2(-175.0, -5.0) if s > 0.0 else Vector2(5.0, 175.0), -s * PI * 0.5, false)
		m["weapon"] = "guns2"
		mounts.append(m)
	a.out["mounts"] = mounts
	var radar := a.node(hull, "NavRadar", Vector3(0.0, yh + 5.4, 1.1))
	a.mesh(radar, "Bar", func(k: VehicleKit) -> void:
		VehicleKit.cyl(k.dark, Vector3(0.0, -0.05, 0.0), Vector3(0.0, 0.1, 0.0), 0.14, 10)
		VehicleKit.box(k.dark, Vector3(0.0, 0.16, 0.0), Vector3(1.8, 0.16, 0.2))
	)
	a.out["radars"] = [{"node": radar, "speed": 2.6}]
	a.out["wake_points"] = [a.node(root, "Wake", Vector3(0.0, 0.15, 12.9))]
	a.out["body_aabb"] = AABB(Vector3(-3.1, -1.2, -12.8), Vector3(6.2, 6.0, 25.6))


# === Штурмовой катер CB 90 (Швеция) ===================================================================================
## Водомётный катер 15,9 × 3,8 м: тупой нос с аппарелью, десантное отделение с дверью на бак и спаренной
## 12,7-мм турелью на крыше, рубка с круговым остеклением и 40-мм гранатомётом Mk 19, пусковые RBS 17 на
## корме, две водомётные насадки в транце. Шведский «осколочный» камуфляж.
static func _cb90(a: ModelAsm) -> void:
	var p := {"L": 15.9, "B": 3.8, "T": 0.8, "D": 1.3, "bow_sheer": 0.35, "stern_sheer": 0.0, "entry": 0.28, "run": 0.62, "run_beam": 0.8, "transom": 0.95, "stern_rise": 0.85, "flare": 0.05, "camber": 0.1, "forefoot": 0.14, "stem_curve": 1.3, "chine": true, "deadrise": 20.0, "deadrise_bow": 30.0, "chine_in": 0.95, "bow_blunt": 0.55, "stations": 32}
	var root := a.root
	var hull := a.node(root, "Hull")
	a.out["hull"] = hull
	var yt := _deck_at(p, -2.6)
	var yw := _deck_at(p, 1.2)
	var rbs: Array[Transform3D] = []
	for s: float in [-1.0, 1.0]:
		rbs.append(Transform3D(Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(20.0)), Vector3(s * 1.3, _deck_at(p, 6.3, 1.3) + 0.45, 6.3)))
	a.mesh(hull, "HullBody", func(k: VehicleKit) -> void:
		_hull(k, p)
		# Носовая аппарель с петлями.
		var yr := _deck_at(p, -7.3)
		k.part(VehicleKit.P_UPPER)
		k.body.add_box(Vector3(0.0, yr + 0.05, -7.3), Vector3(1.7, 0.08, 1.1))
		k.part(VehicleKit.P_HULL)
		VehicleKit.box(k.dark, Vector3(0.0, yr + 0.03, -6.72), Vector3(1.75, 0.06, 0.06))
		for s: float in [-1.0, 1.0]:
			VehicleKit.cyl(k.dark, Vector3(s * 0.85, yr + 0.09, -6.72), Vector3(s * 0.65, yr + 0.09, -6.72), 0.07, 8)
		# Десантное отделение с дверью на бак, рубка с круговым остеклением, машинный люк.
		_house(k, 3.2, 4.0, -2.6, yt - 0.3, yt + 1.1, 0.5, 0.0)
		_house_windows(k, 3.2, 4.0, -2.6, yt - 0.3, yt + 1.1, 0.5, 0.0, 0.85, 1.15, 0, 3)
		VehicleKit.box(k.dark, Vector3(0.0, yt + 0.45, -4.61), Vector3(0.9, 0.95, 0.03))
		_house(k, 3.0, 3.6, 1.2, yw - 0.3, yw + 1.9, 0.6, 0.3)
		_house_windows(k, 3.0, 3.6, 1.2, yw - 0.3, yw + 1.9, 0.6, 0.3, 1.2, 1.8, 4, 3, 2)
		var ye := _deck_at(p, 5.4)
		_house(k, 1.6, 2.4, 5.4, ye - 0.2, ye + 0.3, 0.3, 0.06)
		for s: float in [-1.0, 1.0]:
			VehicleKit.box(k.dark, Vector3(s * 0.55, 0.12, 7.96), Vector3(0.55, 0.42, 0.06))
			VehicleKit.whip(k, Vector3(s * 1.1, yw + 1.9, 2.4), 2.4, Vector3(0.0, 0.0, 0.25))
		# Пусковые RBS 17 на корме.
		for rt: Transform3D in rbs:
			k.dark.xform = rt
			k.dark.add_box(Vector3.ZERO, Vector3(0.28, 0.28, 1.5))
			k.dark.xform = Transform3D.IDENTITY
			var leg: Vector3 = rt * Vector3(0.0, -0.14, -0.5)
			VehicleKit.cyl(k.dark, Vector3(leg.x, leg.y - 0.5, leg.z), leg, 0.035, 6)
	)
	var mounts: Array = [_mg_ring(a, hull, Vector3(0.0, yt + 1.1, -2.9), "M2Twin", true, "us")]
	var m19 := _rws(a, hull, Vector3(0.0, yw + 1.9, 1.3), "Mk19", 1.0, Vector2(-180.0, 180.0), PI)
	m19["weapon"] = "guns2"
	mounts.append(m19)
	a.out["mounts"] = mounts
	var sp: Array[Node3D] = []
	for rt: Transform3D in rbs:
		sp.append(a.node(hull, "RBS17", rt * Vector3(0.0, 0.0, -0.8), Vector3(20.0, 0.0, 0.0)))
	a.out["special_points"] = sp
	a.out["wake_points"] = [a.node(root, "Wake", Vector3(0.0, 0.1, 8.1))]
	a.out["body_aabb"] = AABB(Vector3(-1.9, -0.8, -7.95), Vector3(3.8, 4.3, 15.9))
