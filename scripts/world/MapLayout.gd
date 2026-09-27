class_name MapLayout
extends RefCounted
## Раскладка конкретной карты на бой: позиции баз обеих команд (база команды 1 — зеркальная копия
## базы команды 0), нейтральные объекты, острова, границы зоны боя и мира, а также «зоны» рельефа:
##  * flat  — выравнивание площадок (аэродромы, штабы, позиции ПВО, ВМБ, деревни);
##  * water — гарантированная акватория (у причала и в районе патрулирования эсминца).
## Terrain применяет зоны к сетке высот, ИИ и уровень берут отсюда все координаты.

const RUNWAY_LENGTH := 1100.0
const RUNWAY_WIDTH := 50.0
const PIER_LENGTH := 200.0
const PIER_DECK_HEIGHT := 2.4
const NAVAL_BASE_HEIGHT := 3.0
const AIR_SPAWN_ALTITUDE := 480.0
const WARSHIP_PATROL_RADIUS := 260.0

var map_id: String = "coast"
var preset: Dictionary = {}
var shape: String = "coast"
var mirror: String = "x"
var bounds: float = 7000.0
var world: float = 13000.0
var islands: Array[Dictionary] = []
var airfield: Array[Vector2] = []
var runway_dir: Array[Vector2] = []
var airfield_height: Array[float] = [20.0, 20.0]
var hq: Array[Vector2] = []
var radar: Array[Vector2] = []
var ad: Array[Vector2] = []
var pier_root: Array[Vector2] = []
var pier_dir: Array[Vector2] = []
var warship: Array[Vector2] = []
var bunkers: Array = [[], []]
var defense: Array = [[], []]
var villages: Array[Vector2] = []
var towns: Array[Vector2] = []
var lighthouses: Array[Vector2] = []
var oil_rigs: Array[Vector2] = []
var zones: Array[Dictionary] = []


func _init(p_map_id: String = "coast") -> void:
	map_id = p_map_id if MapPresets.MAPS.has(p_map_id) else "coast"
	preset = MapPresets.get_map(map_id)
	shape = str(preset.get("shape", "coast"))
	mirror = str(preset.get("mirror", "x"))
	bounds = float(preset.get("bounds", 7000.0))
	world = float(preset.get("world", 13000.0))
	var base: Dictionary = preset["base"]
	for team in 2:
		airfield.append(mirror_point(base["airfield"], team))
		runway_dir.append(mirror_dir(base["runway"], team).normalized())
		hq.append(mirror_point(base["hq"], team))
		radar.append(mirror_point(base["radar"], team))
		ad.append(mirror_point(base["ad"], team))
		pier_root.append(mirror_point(base["pier"], team))
		pier_dir.append(mirror_dir(base["pier_dir"], team).normalized())
		warship.append(mirror_point(base["warship"], team))
		var bl: Array[Vector2] = []
		for p: Vector2 in base["bunkers"]:
			bl.append(mirror_point(p, team))
		bunkers[team] = bl
		var dl: Array[Vector2] = []
		for p: Vector2 in base["defense"]:
			dl.append(mirror_point(p, team))
		defense[team] = dl
	for isl: Dictionary in preset.get("islands", []):
		islands.append(isl)
		if bool(isl.get("sym", false)):
			var copy := isl.duplicate()
			copy["c"] = mirror_point(isl["c"], 1)
			islands.append(copy)
	var neutral: Dictionary = preset.get("neutral", {})
	villages.assign(neutral.get("villages", []))
	towns.assign(neutral.get("towns", []))
	lighthouses.assign(neutral.get("lighthouses", []))
	oil_rigs.assign(neutral.get("oil_rigs", []))


# --- Симметрия --------------------------------------------------------------------------------------------
func mirror_point(p: Vector2, team: int) -> Vector2:
	if team == 0:
		return p
	match mirror:
		"z":
			return Vector2(p.x, -p.y)
		"point":
			return -p
	return Vector2(-p.x, p.y)


func mirror_dir(d: Vector2, team: int) -> Vector2:
	return mirror_point(d, team)


## Сторона команды по оси X (для ИИ и старых эвристик): -1 — запад, 1 — восток.
func side(team: int) -> float:
	return signf(airfield[team].x) if absf(airfield[team].x) > 1.0 else GameDB.team_side(team)


## Направление «на противника» от базы команды (горизонтальное, единичное).
func enemy_dir(team: int) -> Vector3:
	var d := airfield[GameDB.enemy_team(team)] - airfield[team]
	return Vector3(d.x, 0.0, d.y).normalized()


func airfield_center(team: int) -> Vector3:
	var a := airfield[team]
	return Vector3(a.x, airfield_height[team], a.y)


func pier_tip(team: int) -> Vector2:
	return pier_root[team] + pier_dir[team] * PIER_LENGTH


func warship_anchor(team: int) -> Vector3:
	var w := warship[team]
	return Vector3(w.x, 0.0, w.y)


func in_bounds(x: float, z: float, margin: float = 0.0) -> bool:
	return absf(x) <= bounds + margin and absf(z) <= bounds + margin


# --- Зоны рельефа ------------------------------------------------------------------------------------------
## Строит зоны. height_at(x, z) — «естественная» высота рельефа (для зон с автоматической высотой).
func build_zones(height_at: Callable) -> void:
	zones.clear()
	for v in villages:
		_flat_circle(v, 190.0, 230.0, _auto(height_at, v, 4.0, 90.0))
	for team in 2:
		for b: Vector2 in bunkers[team]:
			_flat_circle(b, 28.0, 45.0, _auto(height_at, b, 2.6, 40.0))
		_flat_circle(ad[team], 135.0, 140.0, _auto(height_at, ad[team], 4.0, 45.0))
		_flat_circle(radar[team], 80.0, 150.0, _auto(height_at, radar[team], 6.0, 120.0))
		_flat_circle(hq[team], 160.0, 200.0, _auto(height_at, hq[team], 6.0, 90.0))
		var af := airfield[team]
		var dir := runway_dir[team]
		var af_h := _auto(height_at, af, 6.0, 70.0)
		airfield_height[team] = af_h
		var half := RUNWAY_LENGTH * 0.5 + 110.0
		zones.append(_capsule("flat", af - dir * half, af + dir * half, 210.0, 280.0, {"height": af_h}))
		var root := pier_root[team]
		var pd := pier_dir[team]
		_flat_circle(root - pd * 95.0, 85.0, 70.0, NAVAL_BASE_HEIGHT)
	for l in lighthouses:
		zones.append(_circle("flat", l, 50.0, 70.0, {"height": _auto(height_at, l, 3.0, 40.0)}))
	for team in 2:
		var root := pier_root[team]
		var pd := pier_dir[team]
		zones.append(_capsule("water", root + pd * 210.0, root + pd * 560.0, 125.0, 700.0, {"depth": -16.0, "slope": 0.2}))
		zones.append(_circle("water", warship[team], WARSHIP_PATROL_RADIUS + 190.0, 900.0, {"depth": -28.0, "slope": 0.12}))


func _auto(height_at: Callable, p: Vector2, min_h: float, max_h: float) -> float:
	var h := 0.0
	for o: Vector2 in [Vector2.ZERO, Vector2(60.0, 0.0), Vector2(-60.0, 0.0), Vector2(0.0, 60.0), Vector2(0.0, -60.0)]:
		h += float(height_at.call(p.x + o.x, p.y + o.y))
	return clampf(h / 5.0, min_h, max_h)


func _flat_circle(c: Vector2, radius: float, falloff: float, height: float) -> void:
	zones.append(_circle("flat", c, radius, falloff, {"height": height}))


func _circle(kind: String, c: Vector2, radius: float, reach: float, extra: Dictionary) -> Dictionary:
	var z := {"kind": kind, "type": "circle", "center": c, "radius": radius, "falloff": reach}
	z.merge(extra)
	var r := radius + reach
	z["rect"] = Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
	return z


func _capsule(kind: String, a: Vector2, b: Vector2, radius: float, reach: float, extra: Dictionary) -> Dictionary:
	var z := {"kind": kind, "type": "capsule", "a": a, "b": b, "radius": radius, "falloff": reach}
	z.merge(extra)
	var r := radius + reach
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(r, r)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(r, r)
	z["rect"] = Rect2(lo, hi - lo)
	return z


static func zone_distance(zone: Dictionary, p: Vector2) -> float:
	if str(zone["type"]) == "capsule":
		var a: Vector2 = zone["a"]
		var b: Vector2 = zone["b"]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		return p.distance_to(a + ab * t)
	var c: Vector2 = zone["center"]
	return p.distance_to(c)


## Применение зоны к высоте h в точке p.
static func apply_zone(zone: Dictionary, p: Vector2, h: float) -> float:
	var d := zone_distance(zone, p)
	var radius: float = zone["radius"]
	var falloff: float = zone["falloff"]
	if str(zone["kind"]) == "water":
		# Дно поднимается от края акватории с заданным уклоном; к границе зоны влияние плавно исчезает.
		var limit := float(zone["depth"]) + maxf(d - radius, 0.0) * float(zone["slope"])
		var fade := smoothstep(radius + falloff * 0.55, radius + falloff, d)
		return lerpf(minf(h, limit), h, fade)
	var w := 1.0 - smoothstep(radius, radius + falloff, d)
	if w <= 0.0:
		return h
	return lerpf(h, float(zone["height"]), w)


## Точка в пределах выровненной площадки (для запрета деревьев и домов).
func near_flat_zone(p: Vector2, margin: float) -> bool:
	for zone in zones:
		if str(zone["kind"]) != "flat":
			continue
		var rect: Rect2 = zone["rect"]
		if not rect.grow(margin).has_point(p):
			continue
		if zone_distance(zone, p) < float(zone["radius"]) + margin:
			return true
	return false


# --- Точки появления ----------------------------------------------------------------------------------------
## Авиация — воздушный старт над аэродромом курсом на противника; ПВО — позиции у берега; флот — у причала.
func spawn_transforms(terrain: Terrain, team: int, category: int) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	match category:
		GameDB.Category.AIR:
			var fwd := enemy_dir(team)
			var right := fwd.cross(Vector3.UP).normalized()
			var yaw := GameDB.yaw_of(fwd)
			var center := airfield_center(team)
			for i in 4:
				var lateral := (float(i % 2) * 2.0 - 1.0) * (70.0 + float(i / 2) * 90.0)
				var pos := center - fwd * (120.0 + float(i) * 70.0) + right * lateral
				pos.y = maxf(center.y, terrain.get_surface_height(pos.x, pos.z)) + AIR_SPAWN_ALTITUDE + float(i) * 35.0
				result.append(Transform3D(Basis(Vector3.UP, yaw), pos))
		GameDB.Category.GROUND:
			var c := ad[team]
			var look := Vector3(pier_tip(team).x, 0.0, pier_tip(team).y) + enemy_dir(team) * 900.0
			var offsets: Array[Vector2] = [Vector2(-45.0, -30.0), Vector2(45.0, -30.0), Vector2(-45.0, 35.0), Vector2(45.0, 35.0), Vector2(0.0, 70.0)]
			for o in offsets:
				var p2 := c + o
				var pos := Vector3(p2.x, terrain.get_height(p2.x, p2.y), p2.y)
				var yaw := GameDB.yaw_of(GameDB.flat(look - pos))
				result.append(Transform3D(Basis(Vector3.UP, yaw), pos))
		GameDB.Category.NAVAL:
			var root := pier_root[team]
			var pd := pier_dir[team]
			var lat := Vector2(-pd.y, pd.x)
			var yaw := GameDB.yaw_of(Vector3(pd.x, 0.0, pd.y))
			for o: Vector2 in [Vector2(-34.0, 160.0), Vector2(34.0, 160.0), Vector2(-40.0, 230.0), Vector2(40.0, 230.0), Vector2(0.0, 290.0)]:
				var p2 := root + lat * o.x + pd * o.y
				result.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(p2.x, 0.0, p2.y)))
	return result


## Точки обороны для наземной ПВО ботов.
func defense_points(team: int) -> Array[Vector2]:
	var list: Array[Vector2] = [ad[team], hq[team] + (ad[team] - hq[team]).normalized() * 180.0, radar[team]]
	var af := airfield[team]
	var lat := Vector2(-runway_dir[team].y, runway_dir[team].x)
	list.append(af + lat * 160.0)
	list.append(pier_root[team] - pier_dir[team] * 150.0 + lat * 120.0)
	for p: Vector2 in defense[team]:
		list.append(p)
	return list
