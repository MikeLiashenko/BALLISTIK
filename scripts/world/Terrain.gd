class_name Terrain
extends RefCounted
## Процедурный рельеф карты: форма суши (побережье, архипелаг, залив, фьорды, пролив), холмы и хребты,
## морское дно, выровненные площадки баз. Высоты считаются один раз в регулярную сетку
## (TerrainSampler, несколько потоков); запросы высоты используют ту же треугольную интерполяцию,
## что и меш LOD0, — «физическая» поверхность совпадает с картинкой. Дополнительно строятся маски
## (леса, поля, вариации климата) для отрисовки и расстановки растительности.

const NAVIGABLE_DEPTH := -1.2
const LAND_HEIGHT := 0.6
## Больше 4 потоков не даёт выигрыша: вызовы методов объектов движка из потоков сериализуются.
const MAX_THREADS := 4

var layout: MapLayout = null
var preset: Dictionary = {}
var seed_value: int = 1
var half_size: float = 13000.0
var resolution: int = 512
var cell: float = 1.0
var heights := PackedFloat32Array()
## Маски на узлах сетки (RGBA8): r — лес, g — пригодность под поля, b — сухость/вариация, a — площадка базы.
var masks := PackedByteArray()

var _sampler: TerrainSampler = null


func _init(p_layout: MapLayout, p_seed: int = 1, p_resolution: int = 512) -> void:
	layout = p_layout
	preset = layout.preset
	seed_value = p_seed
	resolution = maxi(p_resolution, 32)
	half_size = layout.world
	cell = half_size * 2.0 / float(resolution)
	_sampler = TerrainSampler.new(layout, seed_value)
	layout.build_zones(func(x: float, z: float) -> float: return _sampler.base_height(x, z))


## «Естественная» высота рельефа (аналитически, без сетки и площадок).
func base_height(x: float, z: float) -> float:
	return _sampler.base_height(x, z)


func land_signal(x: float, z: float) -> float:
	return _sampler.land_signal(x, z)


# --- Генерация сетки -------------------------------------------------------------------------------------
## Строит сетку высот и масок. Вызывается один раз (можно из фонового потока).
func generate() -> void:
	var n1 := resolution + 1
	heights = PackedFloat32Array()
	for part: PackedFloat32Array in _parallel(func(s: TerrainSampler, r0: int, r1: int) -> Variant:
		return s.height_rows(r0, r1, n1, half_size, cell)
	):
		heights.append_array(part)
	_apply_zones()
	var zone_mask := _rasterize_zones()
	var h := heights
	masks = PackedByteArray()
	for part: PackedByteArray in _parallel(func(s: TerrainSampler, r0: int, r1: int) -> Variant:
		return s.mask_rows(r0, r1, n1, half_size, cell, h, zone_mask)
	):
		masks.append_array(part)


## job(sampler, r0, r1) по диапазонам строк; у каждого потока — свой семплер. Результаты по порядку.
func _parallel(job: Callable) -> Array:
	var total := resolution + 1
	var n := clampi(OS.get_processor_count() - 1, 1, MAX_THREADS)
	if total < 128:
		n = 1
	var per := ceili(float(total) / float(n))
	var results: Array = []
	if n == 1:
		results.append(job.call(_sampler, 0, total))
		return results
	var threads: Array[Thread] = []
	for t in n:
		var r0 := t * per
		var r1 := mini(total, r0 + per)
		if r0 >= r1:
			break
		var s := _sampler if t == 0 else TerrainSampler.new(layout, seed_value)
		var th := Thread.new()
		th.start(job.bind(s, r0, r1))
		threads.append(th)
	for th in threads:
		results.append(th.wait_to_finish())
	return results


func _apply_zones() -> void:
	var n1 := resolution + 1
	for zone in layout.zones:
		var rect: Rect2 = zone["rect"]
		var ix0 := clampi(int(floor((rect.position.x + half_size) / cell)), 0, resolution)
		var ix1 := clampi(int(ceil((rect.end.x + half_size) / cell)), 0, resolution)
		var iz0 := clampi(int(floor((rect.position.y + half_size) / cell)), 0, resolution)
		var iz1 := clampi(int(ceil((rect.end.y + half_size) / cell)), 0, resolution)
		for iz in range(iz0, iz1 + 1):
			var z := -half_size + float(iz) * cell
			for ix in range(ix0, ix1 + 1):
				var i := iz * n1 + ix
				heights[i] = MapLayout.apply_zone(zone, Vector2(-half_size + float(ix) * cell, z), heights[i])


## Растровая маска выровненных площадок (запрет деревьев и полей рядом с базами).
func _rasterize_zones() -> PackedByteArray:
	var n1 := resolution + 1
	var out := PackedByteArray()
	out.resize(n1 * n1)
	out.fill(0)
	for zone in layout.zones:
		if str(zone["kind"]) != "flat":
			continue
		var reach := float(zone["radius"]) + 60.0
		var rect: Rect2 = zone["rect"]
		var ix0 := clampi(int(floor((rect.position.x + half_size) / cell)), 0, resolution)
		var ix1 := clampi(int(ceil((rect.end.x + half_size) / cell)), 0, resolution)
		var iz0 := clampi(int(floor((rect.position.y + half_size) / cell)), 0, resolution)
		var iz1 := clampi(int(ceil((rect.end.y + half_size) / cell)), 0, resolution)
		for iz in range(iz0, iz1 + 1):
			var z := -half_size + float(iz) * cell
			for ix in range(ix0, ix1 + 1):
				if MapLayout.zone_distance(zone, Vector2(-half_size + float(ix) * cell, z)) < reach:
					out[iz * n1 + ix] = 255
	return out


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


## Маска в точке (билинейно): r — лес, g — поля, b — сухость, a — площадка базы (0..1).
func get_mask(x: float, z: float) -> Color:
	var n1 := resolution + 1
	var gx := clampf((x + half_size) / cell, 0.0, float(resolution) - 0.0001)
	var gz := clampf((z + half_size) / cell, 0.0, float(resolution) - 0.0001)
	var ix := int(gx)
	var iz := int(gz)
	var fx := gx - float(ix)
	var fz := gz - float(iz)
	var c00 := _mask_color((iz * n1 + ix) * 4)
	var c10 := _mask_color((iz * n1 + ix + 1) * 4)
	var c01 := _mask_color(((iz + 1) * n1 + ix) * 4)
	var c11 := _mask_color(((iz + 1) * n1 + ix + 1) * 4)
	return c00.lerp(c10, fx).lerp(c01.lerp(c11, fx), fz)


func _mask_color(i: int) -> Color:
	return Color(masks[i] / 255.0, masks[i + 1] / 255.0, masks[i + 2] / 255.0, masks[i + 3] / 255.0)


func is_land(x: float, z: float) -> bool:
	return get_height(x, z) > LAND_HEIGHT


func is_water(x: float, z: float) -> bool:
	return get_height(x, z) < 0.0


func is_navigable(x: float, z: float, margin: float = 0.0) -> bool:
	if not layout.in_bounds(x, z, 150.0):
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
		step = clampf(t * 0.015, 6.0, 40.0)
	return {"hit": false, "position": origin + d * max_distance, "distance": max_distance}


## Прямая видимость между точками (рельеф заслоняет, вода — нет).
func line_of_sight(a: Vector3, b: Vector3, clearance: float = 1.5) -> bool:
	var dist := a.distance_to(b)
	var steps := clampi(int(dist / 60.0), 2, 120)
	for i in range(1, steps):
		var q := a.lerp(b, float(i) / float(steps))
		if q.y < get_height(q.x, q.z) + clearance:
			return false
	return true


## Карта высот для шейдеров (R16F, (resolution+1)²): глубина у берега, пена, отмели.
func height_image() -> Image:
	var img := Image.create_from_data(resolution + 1, resolution + 1, false, Image.FORMAT_RF, heights.to_byte_array())
	img.convert(Image.FORMAT_RH)
	return img


# --- Случайные точки для ИИ и декораций ------------------------------------------------------------
func random_land_point(rng: RandomNumberGenerator, min_h: float, max_h: float, bounds: float = -1.0, max_tries: int = 60) -> Vector3:
	var b := layout.bounds if bounds <= 0.0 else bounds
	for i in max_tries:
		var x := rng.randf_range(-b, b)
		var z := rng.randf_range(-b, b)
		var h := get_height(x, z)
		if h >= min_h and h <= max_h:
			return Vector3(x, h, z)
	var hq := layout.hq[0]
	return Vector3(hq.x, get_height(hq.x, hq.y), hq.y)


func random_sea_point(rng: RandomNumberGenerator, x_min: float, x_max: float, z_min: float, z_max: float, max_tries: int = 60) -> Vector3:
	for i in max_tries:
		var x := rng.randf_range(x_min, x_max)
		var z := rng.randf_range(z_min, z_max)
		if is_navigable(x, z, 60.0):
			return Vector3(x, 0.0, z)
	var w := layout.warship[0]
	return Vector3(w.x, 0.0, w.y)
