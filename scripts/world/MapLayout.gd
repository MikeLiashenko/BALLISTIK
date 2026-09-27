class_name MapLayout
extends RefCounted
## Раскладка арены. Суша — на севере (-Z), море — на юге (+Z), береговая линия идёт вдоль оси X.
## Команда 0 (СИНИЕ) базируется на западе (-X), команда 1 (КРАСНЫЕ) — на востоке (+X).
## У каждой команды: аэродром, штаб, РЛС, береговые позиции ПВО, военно-морская база с причалом и эсминец.

const AIRFIELD_X := 2250.0
const AIRFIELD_Z := -1500.0
const AIRFIELD_HEIGHT := 22.0
const RUNWAY_LENGTH := 900.0
const RUNWAY_WIDTH := 50.0
const AIR_SPAWN_ALTITUDE := 400.0
const HQ_X := 2650.0
const HQ_Z := -700.0
const HQ_HEIGHT := 16.0
const RADAR_X := 2150.0
const RADAR_Z := -520.0
const SHORE_AD_X := 1750.0
const SHORE_AD_INLAND := 150.0
const SHORE_AD_HEIGHT := 6.0
const PIER_X := 2300.0
const PIER_LENGTH := 200.0
const PIER_DECK_HEIGHT := 2.4
const NAVAL_BASE_HEIGHT := 3.0
const WARSHIP_X := 1700.0
const WARSHIP_OFFSHORE := 700.0
const VILLAGE := Vector2(0.0, -1100.0)
const OIL_RIG := Vector2(0.0, 2150.0)
const CENTRAL_ISLAND := Vector2(0.0, 900.0)


static func side(team: int) -> float:
	return GameDB.team_side(team)


static func airfield_center(team: int) -> Vector3:
	return Vector3(side(team) * AIRFIELD_X, AIRFIELD_HEIGHT, AIRFIELD_Z)


static func hq_center(team: int) -> Vector2:
	return Vector2(side(team) * HQ_X, HQ_Z)


static func radar_center(team: int) -> Vector2:
	return Vector2(side(team) * RADAR_X, RADAR_Z)


static func shore_ad_center(terrain: Terrain, team: int) -> Vector2:
	var x := side(team) * SHORE_AD_X
	return Vector2(x, terrain.coast_z(x) - SHORE_AD_INLAND)


static func pier_root(terrain: Terrain, team: int) -> Vector2:
	var x := side(team) * PIER_X
	return Vector2(x, terrain.coast_z(x) - 30.0)


static func pier_tip(terrain: Terrain, team: int) -> Vector2:
	return pier_root(terrain, team) + Vector2(0.0, PIER_LENGTH)


static func warship_anchor(terrain: Terrain, team: int) -> Vector3:
	var x := side(team) * WARSHIP_X
	return Vector3(x, 0.0, terrain.coast_z(x) + WARSHIP_OFFSHORE)


## Точки спавна по категориям: авиация — над аэродромом, ПВО — береговые позиции, флот — у причала.
static func spawn_transforms(terrain: Terrain, team: int, category: int) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	var s := side(team)
	match category:
		GameDB.Category.AIR:
			var forward := Vector3(-s, 0.0, 0.0)
			var yaw := GameDB.yaw_of(forward)
			for i in 3:
				var lateral := (float(i) - 1.0) * 90.0
				var along := float(i) * 60.0
				var pos := Vector3(s * (AIRFIELD_X + 200.0 - along), AIR_SPAWN_ALTITUDE + float(i) * 30.0, AIRFIELD_Z + lateral)
				result.append(Transform3D(Basis(Vector3.UP, yaw), pos))
		GameDB.Category.GROUND:
			var c := shore_ad_center(terrain, team)
			var look_at := Vector3(0.0, 0.0, c.y + 250.0)
			var offsets: Array[Vector2] = [Vector2(-45.0, -30.0), Vector2(45.0, -30.0), Vector2(-45.0, 35.0), Vector2(45.0, 35.0)]
			for o in offsets:
				var p2 := c + o
				var pos := Vector3(p2.x, terrain.get_height(p2.x, p2.y), p2.y)
				var yaw := GameDB.yaw_of(GameDB.flat(look_at - pos))
				result.append(Transform3D(Basis(Vector3.UP, yaw), pos))
		GameDB.Category.NAVAL:
			var root := pier_root(terrain, team)
			var look := Vector3(s * 900.0, 0.0, root.y + 1100.0)
			var offsets: Array[Vector2] = [Vector2(-34.0, 150.0), Vector2(34.0, 150.0), Vector2(-34.0, 215.0), Vector2(34.0, 215.0), Vector2(0.0, 270.0)]
			for o in offsets:
				var pos := Vector3(root.x + o.x, 0.0, root.y + o.y)
				var yaw := GameDB.yaw_of(GameDB.flat(look - pos))
				result.append(Transform3D(Basis(Vector3.UP, yaw), pos))
	return result


## Выровненные площадки рельефа (аэродромы, базы, деревня). height < -500 — «по месту».
static func flat_zones(terrain: Terrain) -> Array[Dictionary]:
	var zones: Array[Dictionary] = []
	for team in 2:
		var s := side(team)
		zones.append({
			"type": "capsule",
			"a": Vector2(s * (AIRFIELD_X - RUNWAY_LENGTH * 0.5 - 90.0), AIRFIELD_Z),
			"b": Vector2(s * (AIRFIELD_X + RUNWAY_LENGTH * 0.5 + 90.0), AIRFIELD_Z),
			"radius": 190.0, "falloff": 240.0, "height": AIRFIELD_HEIGHT,
		})
		zones.append({"type": "circle", "center": hq_center(team), "radius": 150.0, "falloff": 190.0, "height": HQ_HEIGHT})
		zones.append({"type": "circle", "center": radar_center(team), "radius": 75.0, "falloff": 140.0, "height": HQ_HEIGHT})
		zones.append({"type": "circle", "center": shore_ad_center(terrain, team), "radius": 115.0, "falloff": 120.0, "height": SHORE_AD_HEIGHT})
		var root := pier_root(terrain, team)
		zones.append({"type": "circle", "center": root + Vector2(0.0, -60.0), "radius": 95.0, "falloff": 80.0, "height": NAVAL_BASE_HEIGHT})
		for bx: float in [1500.0, 2050.0]:
			var x := s * bx
			zones.append({"type": "circle", "center": Vector2(x, terrain.coast_z(x) - 60.0), "radius": 26.0, "falloff": 40.0, "height": -1000.0})
	zones.append({"type": "circle", "center": VILLAGE, "radius": 170.0, "falloff": 220.0, "height": -1000.0})
	zones.append({"type": "circle", "center": CENTRAL_ISLAND, "radius": 55.0, "falloff": 80.0, "height": -1000.0})
	return zones


static func zone_distance(zone: Dictionary, p: Vector2) -> float:
	if str(zone["type"]) == "capsule":
		var a: Vector2 = zone["a"]
		var b: Vector2 = zone["b"]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		return p.distance_to(a + ab * t)
	var c: Vector2 = zone["center"]
	return p.distance_to(c)


static func zone_center(zone: Dictionary) -> Vector2:
	if str(zone["type"]) == "capsule":
		var a: Vector2 = zone["a"]
		var b: Vector2 = zone["b"]
		return (a + b) * 0.5
	var c: Vector2 = zone["center"]
	return c


static func near_any_zone(zones: Array[Dictionary], p: Vector2, margin: float) -> bool:
	for zone in zones:
		var r: float = zone["radius"]
		if zone_distance(zone, p) < r + margin:
			return true
	return false
