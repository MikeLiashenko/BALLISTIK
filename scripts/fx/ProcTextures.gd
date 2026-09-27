class_name ProcTextures
extends RefCounted
## Процедурные текстуры (генерируются в коде и кэшируются): бесшовные шумы для рельефа и облаков,
## карты нормалей волн и неровностей, мягкие спрайты частиц, «клубящийся» дым.

static var _cache: Dictionary = {}


static func noise(key: String, size: int, freq: float, octaves: int, seed_value: int, type: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH, fractal: int = FastNoiseLite.FRACTAL_FBM) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var img := _noise_image(size, freq, octaves, seed_value, type, fractal)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func normal_map(key: String, size: int, freq: float, octaves: int, seed_value: int, strength: float, type: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH, fractal: int = FastNoiseLite.FRACTAL_FBM) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var img := _noise_image(size, freq, octaves, seed_value, type, fractal)
	img.convert(Image.FORMAT_RGBA8)
	img.bump_map_to_normal_map(strength)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _noise_image(size: int, freq: float, octaves: int, seed_value: int, type: int, fractal: int) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = type
	n.frequency = freq
	n.fractal_type = fractal
	n.fractal_octaves = octaves
	var img := n.get_seamless_image(size, size, false, false, 0.1, true)
	if img.get_format() != Image.FORMAT_L8:
		img.convert(Image.FORMAT_L8)
	return img


# --- Наборы текстур окружения ---------------------------------------------------------------------------
static func terrain_macro() -> Texture2D:
	return noise("terrain_macro", 512, 0.006, 5, 11)


static func terrain_detail() -> Texture2D:
	return noise("terrain_detail", 512, 0.018, 4, 23, FastNoiseLite.TYPE_SIMPLEX)


static func terrain_normal() -> Texture2D:
	return normal_map("terrain_normal", 512, 0.02, 5, 37, 9.0, FastNoiseLite.TYPE_SIMPLEX)


static func wave_normal() -> Texture2D:
	return normal_map("wave_normal", 512, 0.012, 4, 51, 5.0, FastNoiseLite.TYPE_SIMPLEX)


static func foam_noise() -> Texture2D:
	return noise("foam_noise", 256, 0.03, 4, 67, FastNoiseLite.TYPE_CELLULAR, FastNoiseLite.FRACTAL_FBM)


static func cloud_noise() -> Texture2D:
	return noise("cloud_noise", 256, 0.012, 5, 79)


static func puff_noise() -> Texture2D:
	return noise("puff_noise", 256, 0.018, 5, 83)


## Мягкий круглый спрайт для частиц (радиальный градиент).
static func soft_disc() -> Texture2D:
	if _cache.has("soft_disc"):
		return _cache["soft_disc"]
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	g.add_point(0.45, Color(1.0, 1.0, 1.0, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	_cache["soft_disc"] = t
	return t


## Выжженная воронка для декали: тёмное пятно с рваным краем и сажевыми лучами.
static func scorch() -> Texture2D:
	if _cache.has("scorch"):
		return _cache["scorch"]
	var size := 128
	var n := FastNoiseLite.new()
	n.seed = 131
	n.frequency = 0.06
	n.fractal_octaves = 4
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := (float(x) + 0.5) / float(size) * 2.0 - 1.0
			var v := (float(y) + 0.5) / float(size) * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			var ang := atan2(v, u)
			var nv := n.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var rays := 0.5 + 0.5 * sin(ang * 9.0 + nv * 4.0)
			var a := clampf(1.0 - smoothstep(0.35 + rays * 0.25, 0.95, r + (nv - 0.5) * 0.35), 0.0, 1.0)
			var c := 0.04 + 0.08 * nv
			img.set_pixel(x, y, Color(c, c * 0.92, c * 0.85, a * 0.9))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache["scorch"] = tex
	return tex


## «Клубящийся» спрайт дыма/огня: круг, изрезанный шумом (альфа), с мягким краем.
static func smoke_puff() -> Texture2D:
	if _cache.has("smoke_puff"):
		return _cache["smoke_puff"]
	var size := 128
	var n := FastNoiseLite.new()
	n.seed = 97
	n.frequency = 0.045
	n.fractal_octaves = 4
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := (float(x) + 0.5) / float(size) * 2.0 - 1.0
			var v := (float(y) + 0.5) / float(size) * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			var nv := n.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var a := clampf(1.0 - smoothstep(0.35, 1.0, r + (nv - 0.5) * 0.7), 0.0, 1.0)
			var shade := clampf(0.72 + 0.4 * nv - v * 0.12, 0.0, 1.0)
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache["smoke_puff"] = tex
	return tex
