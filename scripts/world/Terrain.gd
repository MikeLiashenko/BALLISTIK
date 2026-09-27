class_name Terrain
extends RefCounted
## Процедурный рельеф арены: суша, береговая линия, морское дно, острова и выровненные площадки баз.
## Высоты считаются один раз в регулярную сетку. Запросы высоты используют ту же треугольную
## интерполяцию, что и визуальный меш, поэтому «физическая» поверхность совпадает с картинкой.

const SEA_FLOOR := -26.0
const NAVIGABLE_DEPTH := -1.2
const LAND_HEIGHT := 0.6

var seed_value: int = 1
var half_size: float = GameDB.TERRAIN_HALF
var resolution: int = 256
var cell: float = 1.0
var heights := PackedFloat32Array()
var flat_zones: Array[Dictionary] = []
var islands: Array[Dictionary] = []

var _hills := FastNoiseLite.new()
var _ridges := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _coast := FastNoiseLite.new()


func _init(p_seed: int = 1, p_resolution: int = 256, p_half_size: float = GameDB.TERRAIN_HALF) -> void:
	seed_value = p_seed
	resolution = maxi(p_resolution, 16)
	half_size = p_half_size
	cell = half_size * 2.0 / float(resolution)
	_setup_noise()
	_define_islands()
	flat_zones = MapLayout.flat_zones(self)
	for zone in flat_zones:
		if float(zone["height"]) < -500.0:
			var c := MapLayout.zone_center(zone)
			zone["height"] = maxf(raw_height(c.x, c.y, false), 2.5)
	_build_grid()


func _setup_noise() -> void:
	_hills.seed = seed_value
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.frequency = 0.0011
	_hills.fractal_type = FastNoiseLite.FRACTAL_FBM
	_hills.fractal_octaves = 4
	_ridges.seed = seed_value + 7
	_ridges.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_ridges.frequency = 0.0021
	_ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridges.fractal_octaves = 3
	_detail.seed = seed_value + 17
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail.frequency = 0.012
	_detail.fractal_octaves = 2
	_coast.seed = seed_value + 101
	_coast.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_coast.frequency = 0.0016
	_coast.fractal_octaves = 3


func _define_islands() -> void:
	islands = [
		{"center": MapLayout.CENTRAL_ISLAND, "radius": 300.0, "height": 34.0},
		{"center": Vector2(-1150.0, 1650.0), "radius": 200.0, "height": 24.0},
		{"center": Vector2(1150.0, 1550.0), "radius": 220.0, "height": 28.0},
		{"center": Vector2(-450.0, 2550.0), "radius": 150.0, "height": 16.0},
		{"center": Vector2(650.0, 2750.0), "radius": 130.0, "height": 14.0},
	]


## Z-координата береговой линии для данного X (суша при z < coast_z).
func coast_z(x: float) -> float:
	return 70.0 * sin(x * 0.0011 + 0.6) + 40.0 * sin(x * 0.0029 + 2.1) + 55.0 * _coast.get_noise_1d(x)


## Аналитическая высота рельефа (до дискретизации в сетку).
func raw_height(x: float, z: float, apply_zones: bool = true) -> float:
	var d := coast_z(x) - z
	var h: float
	if d >= 0.0:
		h = 1.2 + 6.0 * smoothstep(0.0, 160.0, d)
		var hill := _hills.get_noise_2d(x, z) * 0.5 + 0.5
		var ridge := _ridges.get_noise_2d(x, z) * 0.5 + 0.5
		var inland := smoothstep(120.0, 900.0, d)
		h += (pow(hill, 1.7) * 150.0 + ridge * 35.0) * inland
		h += _detail.get_noise_2d(x, z) * 4.0 * smoothstep(40.0, 240.0, d)
		var edge := maxf(absf(x), -z)
		h += smoothstep(3050.0, 3700.0, edge) * 380.0 * (0.7 + 0.3 * hill)
	else:
		var depth := smoothstep(0.0, 420.0, -d)
		h = lerpf(1.2, SEA_FLOOR, depth)
		h += _detail.get_noise_2d(x, z) * 2.5 * depth
	for isl in islands:
		var c: Vector2 = isl["center"]
		var r: float = isl["radius"]
		var dist := Vector2(x, z).distance_to(c)
		if dist < r:
			var k := smoothstep(0.0, 1.0, 1.0 - dist / r)
			var ih := lerpf(SEA_FLOOR, float(isl["height"]), k) + _detail.get_noise_2d(x * 1.7, z * 1.7) * 3.0 * k
			h = maxf(h, ih)
	if apply_zones:
		for zone in flat_zones:
			var radius: float = zone["radius"]
			var falloff: float = zone["falloff"]
			var zd := MapLayout.zone_distance(zone, Vector2(x, z))
			var w := 1.0 - smoothstep(radius, radius + falloff, zd)
			if w > 0.0:
				h = lerpf(h, float(zone["height"]), w)
	return h


func _build_grid() -> void:
	var n1 := resolution + 1
	heights.resize(n1 * n1)
	for iz in n1:
		var z := -half_size + float(iz) * cell
		for ix in n1:
			var x := -half_size + float(ix) * cell
			heights[iz * n1 + ix] = raw_height(x, z)


# --- Запросы высоты -------------------------------------------------------------------------------
func get_height(x: float, z: float) -> float:
	var n1 := resolution + 1
	var gx := clampf((x + half_size) / cell, 0.0, float(resolution) - 0.0001)
	var gz := clampf((z + half_size) / cell, 0.0, float(resolution) - 0.0001)
	var ix := int(gx)
	var iz := int(gz)
	var fx := gx - float(ix)
	var fz := gz - float(iz)
	var i00 := iz * n1 + ix
	var h00 := heights[i00]
	var h10 := heights[i00 + 1]
	var h01 := heights[i00 + n1]
	var h11 := heights[i00 + n1 + 1]
	if fx >= fz:
		return h00 + (h10 - h00) * fx + (h11 - h10) * fz
	return h00 + (h11 - h01) * fx + (h01 - h00) * fz


## Высота поверхности: рельеф или уровень моря (вода — 0).
func get_surface_height(x: float, z: float) -> float:
	return maxf(get_height(x, z), 0.0)


func get_normal(x: float, z: float) -> Vector3:
	var e := cell * 0.5
	var hl := get_height(x - e, z)
	var hr := get_height(x + e, z)
	var hd := get_height(x, z - e)
	var hu := get_height(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()


func is_land(x: float, z: float) -> bool:
	return get_height(x, z) > LAND_HEIGHT


func is_water(x: float, z: float) -> bool:
	return get_height(x, z) < 0.0


func is_navigable(x: float, z: float, margin: float = 0.0) -> bool:
	if absf(x) > GameDB.MAP_HALF + 150.0 or absf(z) > GameDB.MAP_HALF + 150.0:
		return false
	if get_height(x, z) > NAVIGABLE_DEPTH:
		return false
	if margin > 0.0:
		for offset: Vector2 in [Vector2(margin, 0.0), Vector2(-margin, 0.0), Vector2(0.0, margin), Vector2(0.0, -margin)]:
			if get_height(x + offset.x, z + offset.y) > NAVIGABLE_DEPTH + 0.4:
				return false
	return true


## Пересечение луча с поверхностью (рельеф и, по желанию, вода). Шаговый марш + бисекция.
func raycast(origin: Vector3, direction: Vector3, max_distance: float, include_water: bool = true) -> Dictionary:
	var d := direction.normalized()
	var t := 0.0
	var step := 6.0
	while t < max_distance:
		var next_t := minf(t + step, max_distance)
		var p := origin + d * next_t
		var ground := get_surface_height(p.x, p.z) if include_water else get_height(p.x, p.z)
		if p.y <= ground:
			var lo := t
			var hi := next_t
			for i in 10:
				var mid := (lo + hi) * 0.5
				var q := origin + d * mid
				var g := get_surface_height(q.x, q.z) if include_water else get_height(q.x, q.z)
				if q.y <= g:
					hi = mid
				else:
					lo = mid
			return {"hit": true, "position": origin + d * hi, "distance": hi}
		t = next_t
		step = clampf(t * 0.015, 6.0, 30.0)
	return {"hit": false, "position": origin + d * max_distance, "distance": max_distance}


## Прямая видимость между точками (рельеф заслоняет, вода — нет).
func line_of_sight(a: Vector3, b: Vector3, clearance: float = 1.5) -> bool:
	var dist := a.distance_to(b)
	var steps := clampi(int(dist / 50.0), 2, 90)
	for i in range(1, steps):
		var p := a.lerp(b, float(i) / float(steps))
		if p.y < get_height(p.x, p.z) + clearance:
			return false
	return true


# --- Визуальный меш -------------------------------------------------------------------------------
func build_mesh(material: Material) -> ArrayMesh:
	var n1 := resolution + 1
	var count := n1 * n1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(count)
	normals.resize(count)
	colors.resize(count)
	for iz in n1:
		for ix in n1:
			var i := iz * n1 + ix
			var x := -half_size + float(ix) * cell
			var z := -half_size + float(iz) * cell
			var h := heights[i]
			verts[i] = Vector3(x, h, z)
			var hl := heights[iz * n1 + maxi(ix - 1, 0)]
			var hr := heights[iz * n1 + mini(ix + 1, resolution)]
			var hd := heights[maxi(iz - 1, 0) * n1 + ix]
			var hu := heights[mini(iz + 1, resolution) * n1 + ix]
			var n := Vector3(hl - hr, 2.0 * cell, hd - hu).normalized()
			normals[i] = n
			colors[i] = _color_for(x, z, h, n.y)
	var indices := PackedInt32Array()
	indices.resize(resolution * resolution * 6)
	var k := 0
	for iz in resolution:
		for ix in resolution:
			var i00 := iz * n1 + ix
			var i10 := i00 + 1
			var i01 := i00 + n1
			var i11 := i01 + 1
			indices[k] = i00
			indices[k + 1] = i10
			indices[k + 2] = i11
			indices[k + 3] = i00
			indices[k + 4] = i11
			indices[k + 5] = i01
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


func _color_for(x: float, z: float, h: float, ny: float) -> Color:
	var v := _detail.get_noise_2d(x * 0.35, z * 0.35) * 0.5 + 0.5
	if h < -3.0:
		return Color(0.16, 0.2, 0.2).lerp(Color(0.25, 0.27, 0.23), v)
	if h < 3.2:
		return Color(0.55, 0.51, 0.39).lerp(Color(0.63, 0.59, 0.46), v)
	var c := Color(0.14, 0.22, 0.11).lerp(Color(0.23, 0.3, 0.15), v)
	var rock := clampf((0.86 - ny) * 5.0, 0.0, 1.0)
	rock = maxf(rock, smoothstep(140.0, 190.0, h))
	c = c.lerp(Color(0.33, 0.32, 0.3), rock)
	return c.lerp(Color(0.86, 0.88, 0.92), smoothstep(230.0, 300.0, h))


# --- Случайные точки для ИИ и декораций ------------------------------------------------------------
func random_land_point(rng: RandomNumberGenerator, min_h: float, max_h: float, bounds: float = GameDB.MAP_HALF, max_tries: int = 40) -> Vector3:
	for i in max_tries:
		var x := rng.randf_range(-bounds, bounds)
		var z := rng.randf_range(-bounds, bounds)
		var h := get_height(x, z)
		if h >= min_h and h <= max_h:
			return Vector3(x, h, z)
	return Vector3(0.0, get_height(0.0, -1000.0), -1000.0)


func random_sea_point(rng: RandomNumberGenerator, x_min: float, x_max: float, z_min: float, z_max: float, max_tries: int = 40) -> Vector3:
	for i in max_tries:
		var x := rng.randf_range(x_min, x_max)
		var z := rng.randf_range(z_min, z_max)
		if is_navigable(x, z, 60.0):
			return Vector3(x, 0.0, z)
	return Vector3(0.0, 0.0, 1800.0)
