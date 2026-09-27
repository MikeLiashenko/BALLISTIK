class_name TerrainSampler
extends RefCounted
## Аналитическая функция высоты рельефа карты. У каждого потока генерации — свой экземпляр
## (собственные объекты шума, параметры — примитивы): вызовы методов общих объектов из нескольких
## потоков упираются в глобальную блокировку движка, а чистая математика GDScript масштабируется.
## Симметрия карты: для зеркала по X координата «складывается» гладко (sqrt(x² + ε²)) — один вызов
## шума вместо двух и без излома на осевой линии; для центральной симметрии шум усредняется.

enum Shape { COAST, ISLANDS, GULF, FJORDS, STRAIT }
enum Mirror { X, Z, POINT }

const FOLD2 := 260.0 * 260.0

var shape: int = Shape.COAST
var mirror: int = Mirror.X
var hills_amp := 150.0
var mount_amp := 500.0
var mount_thr := 0.5
var mount_start := 1500.0
var sea_floor := -45.0
var shelf := 800.0
var coast_amp := 140.0
var cliff := 0.0
var terrace := 0.0
var edge := 11000.0
var warp_amp := 500.0
var islands := PackedFloat32Array()
var p := PackedFloat32Array()   ## Параметры формы суши (зависят от shape)
## Гарантии баз: круги суши [x, z, r], круги воды [x, z, r], береговые линии у причалов [x, z, dx, dz].
var land_points := PackedFloat32Array()
var water_points := PackedFloat32Array()
var shore_points := PackedFloat32Array()
var fields_max_h := 220.0

var forest_amount := 0.5
var treeline := 450.0
var near_water := false
var fields := 0.5

var _hills := FastNoiseLite.new()
var _ridges := FastNoiseLite.new()
var _mask := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _coast := FastNoiseLite.new()
var _coast_fine := FastNoiseLite.new()
var _forest := FastNoiseLite.new()
var _moist := FastNoiseLite.new()
var _farm := FastNoiseLite.new()
var _warp_a := FastNoiseLite.new()
var _warp_b := FastNoiseLite.new()
var _edge_n := FastNoiseLite.new()


func _init(layout: MapLayout, seed_value: int) -> void:
	var preset := layout.preset
	shape = {"coast": Shape.COAST, "islands": Shape.ISLANDS, "gulf": Shape.GULF, "fjords": Shape.FJORDS, "strait": Shape.STRAIT}.get(layout.shape, Shape.COAST)
	mirror = {"x": Mirror.X, "z": Mirror.Z, "point": Mirror.POINT}.get(layout.mirror, Mirror.X)
	var tp: Dictionary = preset.get("terrain", {})
	hills_amp = float(tp.get("hills", 150.0))
	mount_amp = float(tp.get("mountains", 500.0))
	mount_thr = float(tp.get("mountain_mask", 0.5))
	mount_start = float(tp.get("mountain_start", 1500.0))
	sea_floor = float(tp.get("sea_floor", -45.0))
	shelf = float(tp.get("shelf", 800.0))
	coast_amp = float(tp.get("coast_noise", 140.0))
	cliff = float(tp.get("cliff", 0.0))
	terrace = float(tp.get("terrace", 0.0))
	edge = layout.world - 1900.0
	warp_amp = float(tp.get("warp", 500.0))
	fields_max_h = float(preset.get("fields_max_h", 220.0))
	for isl in layout.islands:
		var c: Vector2 = isl["c"]
		islands.append_array(PackedFloat32Array([c.x, c.y, float(isl["r"])]))
	for team in 2:
		var af := layout.airfield[team]
		var rw := layout.runway_dir[team] * (MapLayout.RUNWAY_LENGTH * 0.5)
		for q: Vector2 in [af - rw, af, af + rw]:
			land_points.append_array(PackedFloat32Array([q.x, q.y, 560.0]))
		for q: Vector2 in [layout.hq[team], layout.radar[team]]:
			land_points.append_array(PackedFloat32Array([q.x, q.y, 420.0]))
		land_points.append_array(PackedFloat32Array([layout.ad[team].x, layout.ad[team].y, 330.0]))
		for q: Vector2 in layout.bunkers[team]:
			land_points.append_array(PackedFloat32Array([q.x, q.y, 110.0]))
		var root := layout.pier_root[team]
		var pd := layout.pier_dir[team]
		land_points.append_array(PackedFloat32Array([root.x - pd.x * 260.0, root.y - pd.y * 260.0, 230.0]))
		shore_points.append_array(PackedFloat32Array([root.x, root.y, pd.x, pd.y]))
		var wp := root + pd * 420.0
		water_points.append_array(PackedFloat32Array([wp.x, wp.y, 250.0]))
		water_points.append_array(PackedFloat32Array([layout.warship[team].x, layout.warship[team].y, 620.0]))
	for q: Vector2 in layout.villages:
		land_points.append_array(PackedFloat32Array([q.x, q.y, 320.0]))
	match shape:
		Shape.COAST:
			var c: Dictionary = preset["coast"]
			p = PackedFloat32Array([c["z0"], c["a1"], c["f1"], c["a2"], c["f2"], c["noise"]])
		Shape.GULF:
			var g: Dictionary = preset["gulf"]
			p = PackedFloat32Array([g["top"], g["w0"], g["k"]])
		Shape.FJORDS:
			var f: Dictionary = preset["fjord"]
			p = PackedFloat32Array([f["z0"], f["a"], f["f"], f["hw"], f["hw_a"], f["south_w"], f["sea_z"], f["branch_x"]])
		Shape.STRAIT:
			var s: Dictionary = preset["strait"]
			p = PackedFloat32Array([s["a"], s["f"], s["w"], s["w_a"], s["w_f"]])
	var trees: Dictionary = preset.get("trees", {})
	forest_amount = float(trees.get("forest", 0.5))
	treeline = float(trees.get("treeline", 450.0))
	near_water = bool(trees.get("near_water", false))
	fields = float(preset.get("fields", 0.5))
	_configure(_hills, seed_value, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.00075, FastNoiseLite.FRACTAL_FBM, 4)
	_configure(_ridges, seed_value + 7, FastNoiseLite.TYPE_SIMPLEX, 0.00085, FastNoiseLite.FRACTAL_RIDGED, 3)
	_configure(_mask, seed_value + 13, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.00022, FastNoiseLite.FRACTAL_FBM, 2)
	_configure(_detail, seed_value + 17, FastNoiseLite.TYPE_SIMPLEX, 0.006, FastNoiseLite.FRACTAL_FBM, 3)
	_configure(_coast, seed_value + 101, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.0009, FastNoiseLite.FRACTAL_FBM, 3)
	_configure(_coast_fine, seed_value + 131, FastNoiseLite.TYPE_SIMPLEX, 0.004, FastNoiseLite.FRACTAL_FBM, 2)
	_configure(_forest, seed_value + 211, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.0016, FastNoiseLite.FRACTAL_FBM, 3)
	_configure(_moist, seed_value + 223, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.00045, FastNoiseLite.FRACTAL_FBM, 2)
	_configure(_farm, seed_value + 239, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.0007, FastNoiseLite.FRACTAL_FBM, 2)
	_configure(_warp_a, seed_value + 307, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.00042, FastNoiseLite.FRACTAL_FBM, 2)
	_configure(_warp_b, seed_value + 311, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.00042, FastNoiseLite.FRACTAL_FBM, 2)
	_configure(_edge_n, seed_value + 331, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.00035, FastNoiseLite.FRACTAL_FBM, 3)


func _configure(n: FastNoiseLite, s: int, type: int, freq: float, fractal: int, octaves: int) -> void:
	n.seed = s
	n.noise_type = type
	n.frequency = freq
	n.fractal_type = fractal
	n.fractal_octaves = octaves


## Симметричный шум относительно зеркала карты.
func sym(n: FastNoiseLite, x: float, z: float) -> float:
	match mirror:
		Mirror.X:
			return n.get_noise_2d(sqrt(x * x + FOLD2), z)
		Mirror.Z:
			return n.get_noise_2d(x, sqrt(z * z + FOLD2))
	return (n.get_noise_2d(x, z) + n.get_noise_2d(-x, -z)) * 0.62


## Искажение координат (domain warp) с сохранением симметрии карты: берега и фьорды становятся извилистыми.
func _warp(x: float, z: float) -> Vector2:
	if warp_amp <= 0.0:
		return Vector2(x, z)
	match mirror:
		Mirror.X:
			var fx := sqrt(x * x + FOLD2)
			return Vector2(x + _warp_a.get_noise_2d(fx, z) * warp_amp * x / fx, z + _warp_b.get_noise_2d(fx, z) * warp_amp)
		Mirror.Z:
			var fz := sqrt(z * z + FOLD2)
			return Vector2(x + _warp_a.get_noise_2d(x, fz) * warp_amp, z + _warp_b.get_noise_2d(x, fz) * warp_amp * z / fz)
	var wx := (_warp_a.get_noise_2d(x, z) - _warp_a.get_noise_2d(-x, -z)) * 0.62
	var wz := (_warp_b.get_noise_2d(x, z) - _warp_b.get_noise_2d(-x, -z)) * 0.62
	return Vector2(x + wx * warp_amp, z + wz * warp_amp)


## Знаковое расстояние до береговой линии (м): > 0 — суша, < 0 — море.
func land_signal(x0: float, z0: float) -> float:
	var wp := _warp(x0, z0)
	var x := wp.x
	var z := wp.y
	var d := -1.0e9
	match shape:
		Shape.COAST:
			var cz := p[0] + p[1] * cos(x * p[2]) + p[3] * cos(x * p[4])
			cz += _coast.get_noise_1d(sqrt(x * x + FOLD2)) * p[5]
			d = cz - z
		Shape.GULF:
			if z >= p[0]:
				d = absf(x) - (p[1] + (z - p[0]) * p[2])
			else:
				d = sqrt(x * x + (z - p[0]) * (z - p[0])) - p[1]
		Shape.FJORDS:
			var zc := p[0] + p[1] * cos(x * p[2])
			var hw := p[3] + p[4] * cos(x * p[2] * 1.9)
			d = absf(z - zc) - hw
			var zc0 := p[0] + p[1]
			if z > zc0 - p[3]:
				var sw := p[5] * (1.0 + 0.55 * _warp_b.get_noise_1d(z * 1.7)) + (z - zc0) * 0.05
				d = minf(d, absf(x) - sw)
			d = minf(d, p[6] + 260.0 * cos(x * 0.0009) - z)
			var zb := p[0] + p[1] * cos(p[7] * p[2])
			d = minf(d, maxf(maxf(absf(absf(x) - p[7]) - 340.0, (zb - 2500.0) - z), z - zb))
		Shape.STRAIT:
			var zs := p[0] * sin(x * p[1])
			d = absf(z - zs) - (p[2] + p[3] * cos(x * p[4]))
	var cn := sym(_coast, x0, z0)
	var n_isl := islands.size()
	var i := 0
	while i < n_isl:
		var dx := x - islands[i]
		var dz := z - islands[i + 1]
		var r := islands[i + 2]
		d = maxf(d, r * (1.0 + 0.3 * cn) - sqrt(dx * dx + dz * dz))
		i += 3
	d += cn * coast_amp + sym(_coast_fine, x0, z0) * coast_amp * 0.25
	# Гарантии баз: суша под аэродромами и штабами, вода у причалов и эсминцев, берег у причала.
	var n := land_points.size()
	i = 0
	while i < n:
		var dx := x0 - land_points[i]
		var dz := z0 - land_points[i + 1]
		d = maxf(d, land_points[i + 2] * (1.0 + 0.25 * cn) - sqrt(dx * dx + dz * dz))
		i += 3
	n = water_points.size()
	i = 0
	while i < n:
		var dx := x0 - water_points[i]
		var dz := z0 - water_points[i + 1]
		d = minf(d, sqrt(dx * dx + dz * dz) - water_points[i + 2] * (1.0 + 0.2 * cn))
		i += 3
	n = shore_points.size()
	i = 0
	while i < n:
		var dx := x0 - shore_points[i]
		var dz := z0 - shore_points[i + 1]
		var dist := sqrt(dx * dx + dz * dz)
		if dist < 900.0:
			var designed := -(dx * shore_points[i + 2] + dz * shore_points[i + 3])
			d = lerpf(d, designed, 1.0 - smoothstep(380.0, 900.0, dist))
		i += 4
	# Край мира: скруглённый «остров» с неровным берегом далеко за пределами зоны боя.
	var ax := absf(x0) / edge
	var az := absf(z0) / edge
	var norm := pow(pow(ax, 6.0) + pow(az, 6.0), 1.0 / 6.0)
	var edge_d := (1.0 - norm) * edge + sym(_edge_n, x0, z0) * 900.0 - 400.0
	return minf(d, edge_d)


## «Естественная» высота рельефа (без выровненных площадок).
func base_height(x: float, z: float) -> float:
	var d := land_signal(x, z)
	var detail := sym(_detail, x, z)
	if d < 0.0:
		var k := smoothstep(0.0, shelf, -d)
		return lerpf(0.8, sea_floor, k) + detail * 2.5 * k
	var hills_n := sym(_hills, x, z) * 0.5 + 0.5
	var hills := pow(hills_n, 1.4) * hills_amp
	var ridge := clampf(sym(_ridges, x, z) * 0.5 + 0.5, 0.0, 1.0)
	var mmask_n := sym(_mask, x, z) * 0.5 + 0.5
	var mmask := smoothstep(mount_thr - 0.16, mount_thr + 0.2, mmask_n)
	mmask = maxf(mmask * smoothstep(mount_start, mount_start + 1800.0, d), smoothstep(mount_start + 2600.0, mount_start + 5200.0, d) * 0.6)
	# Массив: плавное поднятие (маска и холмы) + хребты, врезанные в его верхнюю часть.
	var massif := mmask * (0.55 + 0.45 * smoothstep(0.2, 0.9, hills_n))
	var mountains := mount_amp * massif * (0.42 + 0.58 * pow(ridge, 1.15) * smoothstep(0.1, 0.7, massif))
	var coastal := 1.2 + 5.0 * smoothstep(0.0, 170.0, d) + cliff * smoothstep(10.0, 140.0, d)
	var inland := smoothstep(60.0, 900.0, d)
	var h := coastal + (hills + mountains) * inland + detail * 4.0 * smoothstep(30.0, 250.0, d)
	if terrace > 0.0 and h > 12.0:
		var k2 := h / terrace
		var fl := floorf(k2)
		var terraced := (fl + smoothstep(0.3, 0.7, k2 - fl)) * terrace
		h = lerpf(h, terraced, 0.72 * smoothstep(12.0, 40.0, h))
	return h


## Строки сетки высот [r0, r1).
func height_rows(r0: int, r1: int, n1: int, half: float, cell: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize((r1 - r0) * n1)
	var i := 0
	for iz in range(r0, r1):
		var z := -half + float(iz) * cell
		for ix in n1:
			out[i] = base_height(-half + float(ix) * cell, z)
			i += 1
	return out


## Строки масок (RGBA8): r — лес, g — поля, b — сухость, a — площадка базы.
func mask_rows(r0: int, r1: int, n1: int, half: float, cell: float, heights: PackedFloat32Array, zone_mask: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize((r1 - r0) * n1 * 4)
	var res := n1 - 1
	var i := 0
	for iz in range(r0, r1):
		var z := -half + float(iz) * cell
		for ix in n1:
			var x := -half + float(ix) * cell
			var h := heights[iz * n1 + ix]
			var hl := heights[iz * n1 + maxi(ix - 1, 0)]
			var hr := heights[iz * n1 + mini(ix + 1, res)]
			var hd := heights[maxi(iz - 1, 0) * n1 + ix]
			var hu := heights[mini(iz + 1, res) * n1 + ix]
			var ny := 2.0 * cell / sqrt((hl - hr) * (hl - hr) + 4.0 * cell * cell + (hd - hu) * (hd - hu))
			var zoned := zone_mask[iz * n1 + ix] > 0
			var forest := 0.0
			var farm := 0.0
			var moist := _moist.get_noise_2d(x, z) * 0.5 + 0.5
			if h > 2.5 and not zoned:
				forest = smoothstep(1.0 - forest_amount - 0.08, 1.0 - forest_amount + 0.1, _forest.get_noise_2d(x, z) * 0.5 + 0.5)
				forest *= smoothstep(0.78, 0.86, ny) * (1.0 - smoothstep(treeline - 60.0, treeline + 40.0, h))
				if near_water:
					forest *= 1.0 - smoothstep(12.0, 60.0, h)
				farm = smoothstep(1.0 - fields - 0.05, 1.0 - fields + 0.2, _farm.get_noise_2d(x, z) * 0.5 + 0.5) * smoothstep(0.955, 0.985, ny)
				farm *= (1.0 - smoothstep(fields_max_h * 0.75, fields_max_h, h)) * smoothstep(3.0, 7.0, h)
				if farm > 0.4:
					forest *= 0.15
			out[i] = int(clampf(forest, 0.0, 1.0) * 255.0)
			out[i + 1] = int(clampf(farm, 0.0, 1.0) * 255.0)
			out[i + 2] = int(clampf(1.0 - moist, 0.0, 1.0) * 255.0)
			out[i + 3] = 255 if zoned else 0
			i += 4
	return out
