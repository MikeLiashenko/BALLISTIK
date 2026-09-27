class_name MapPreview
extends RefCounted
## Растровая миникарта (вид сверху): вода по глубине, суша по климату, леса и поля из масок рельефа,
## отмывка рельефа по освещению и значки баз. Используется для превью карт в лобби и в тестах.

static var _cache: Dictionary = {}


const THUMB_SEED := 20260927


## Превью карты для интерфейса (кэшируется): рельеф низкого разрешения, генерируется за доли секунды.
static func thumbnail(map_id: String, size: int = 256) -> Texture2D:
	var key := "%s|%d" % [map_id, size]
	if _cache.has(key):
		return _cache[key]
	var tex := ImageTexture.create_from_image(thumbnail_image(map_id, size))
	_cache[key] = tex
	return tex


static func has_thumbnail(map_id: String, size: int) -> bool:
	return _cache.has("%s|%d" % [map_id, size])


static func store_thumbnail(map_id: String, size: int, tex: Texture2D) -> void:
	_cache["%s|%d" % [map_id, size]] = tex


## Растр превью без сцены и кэша (можно вызывать в фоновом потоке).
static func thumbnail_image(map_id: String, size: int) -> Image:
	var layout := MapLayout.new(map_id)
	var terrain := Terrain.new(layout, THUMB_SEED, 160)
	terrain.generate()
	return render(terrain, size, true)


static func render(terrain: Terrain, size: int, markers: bool = true, view_half: float = -1.0) -> Image:
	var layout := terrain.layout
	var biome := MapPresets.biome(layout.map_id)
	var water: Dictionary = layout.preset.get("water", {})
	var deep: Color = water.get("deep", Color(0.03, 0.1, 0.16))
	var shallow: Color = water.get("shallow", Color(0.08, 0.3, 0.32))
	var snow_line := float(layout.preset.get("snow_line", 800.0))
	var half := layout.bounds * 1.12 if view_half <= 0.0 else view_half
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var light := Vector3(-0.55, 0.75, -0.4).normalized()
	var fields: Array = biome["fields"]
	for py in size:
		var z := -half + (float(py) + 0.5) / float(size) * half * 2.0
		for px in size:
			var x := -half + (float(px) + 0.5) / float(size) * half * 2.0
			var h := terrain.get_height(x, z)
			var col: Color
			if h < 0.0:
				var k := clampf(-h / 30.0, 0.0, 1.0)
				col = shallow.lerp(deep, k) * 1.6
				if h > -1.6:
					col = col.lerp(Color(0.85, 0.9, 0.9), 0.35)
			else:
				var m := terrain.get_mask(x, z)
				var n := terrain.get_normal(x, z)
				var grass: Color = (biome["grass"] as Color).lerp(biome["grass2"], m.b)
				grass = grass.lerp(biome["dry"], m.b * 0.5)
				col = grass.lerp(biome["forest"], m.r * 0.9)
				if m.g > 0.5:
					var cell := Vector2i(floori((x * 0.93 + z * 0.37) / 190.0), floori((z * 0.93 - x * 0.37) / 140.0))
					var hsh := absi(cell.x * 73856093 ^ cell.y * 19349663) % 97
					if hsh > 20:
						col = fields[hsh % fields.size()]
				if h < 3.0:
					col = col.lerp(biome["sand"], 1.0 - smoothstep(1.5, 3.0, h))
				var rock := clampf((0.8 - n.y) * 5.0, 0.0, 1.0)
				col = col.lerp(biome["rock"], rock)
				col = col.lerp(biome["snow"], smoothstep(snow_line, snow_line + 80.0, h) * (1.0 - rock * 0.6))
				if m.a > 0.5:
					col = col.lerp(Color(0.5, 0.5, 0.48), 0.35)
				var shade := clampf(n.dot(light) * 1.1, 0.35, 1.2)
				col = col * (0.55 + 0.6 * shade)
			img.set_pixel(px, py, Color(clampf(col.r, 0.0, 1.0), clampf(col.g, 0.0, 1.0), clampf(col.b, 0.0, 1.0)))
	if markers:
		_draw_markers(img, layout, half)
	return img


static func _to_px(p: Vector2, half: float, size: int) -> Vector2i:
	return Vector2i(int((p.x + half) / (half * 2.0) * size), int((p.y + half) / (half * 2.0) * size))


static func _dot(img: Image, p: Vector2i, r: int, col: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				var q := p + Vector2i(dx, dy)
				if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
					img.set_pixelv(q, col)


static func _line(img: Image, a: Vector2i, b: Vector2i, col: Color, r: int = 1) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in steps + 1:
		var t := float(i) / float(maxi(steps, 1))
		_dot(img, Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t))), r, col)


static func _draw_markers(img: Image, layout: MapLayout, half: float) -> void:
	var size := img.get_width()
	var r := maxi(size / 160, 1)
	var bound_a := _to_px(Vector2(-layout.bounds, -layout.bounds), half, size)
	var bound_b := _to_px(Vector2(layout.bounds, layout.bounds), half, size)
	var edge := Color(0.1, 0.9, 1.0)
	_line(img, bound_a, Vector2i(bound_b.x, bound_a.y), edge, 0)
	_line(img, Vector2i(bound_b.x, bound_a.y), bound_b, edge, 0)
	_line(img, bound_b, Vector2i(bound_a.x, bound_b.y), edge, 0)
	_line(img, Vector2i(bound_a.x, bound_b.y), bound_a, edge, 0)
	for team in 2:
		var col := GameDB.team_color(team)
		var af := layout.airfield[team]
		var half_rw := layout.runway_dir[team] * MapLayout.RUNWAY_LENGTH * 0.5
		_line(img, _to_px(af - half_rw, half, size), _to_px(af + half_rw, half, size), Color(0.12, 0.12, 0.13), r + 1)
		_line(img, _to_px(af - half_rw, half, size), _to_px(af + half_rw, half, size), col, maxi(r - 1, 0))
		_dot(img, _to_px(layout.hq[team], half, size), r * 3, col)
		_dot(img, _to_px(layout.radar[team], half, size), r * 2, col.lightened(0.3))
		_dot(img, _to_px(layout.ad[team], half, size), r * 2, col.darkened(0.2))
		_line(img, _to_px(layout.pier_root[team], half, size), _to_px(layout.pier_tip(team), half, size), Color(0.9, 0.9, 0.85), r)
		_dot(img, _to_px(layout.warship[team], half, size), r * 2, Color(0.95, 0.95, 1.0))
		for b: Vector2 in layout.bunkers[team]:
			_dot(img, _to_px(b, half, size), r, col)
	for v in layout.villages:
		_dot(img, _to_px(v, half, size), r * 2, Color(0.95, 0.8, 0.55))
	for l in layout.lighthouses:
		_dot(img, _to_px(l, half, size), r + 1, Color(1.0, 1.0, 0.6))
	for o in layout.oil_rigs:
		_dot(img, _to_px(o, half, size), r + 1, Color(0.9, 0.5, 0.2))
