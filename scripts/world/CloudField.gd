class_name CloudField
extends Node3D
## Кучевые облака: каждое облако — скопление «клубов» (billboard-спрайты MultiMesh) с плоским
## основанием и куполом; шейдер освещает клубы как сферы (светлая верхушка, затенённое основание,
## серебристая кайма против солнца) и растворяет их вблизи камеры — сквозь облако можно пролететь.
## Облака расставляются по полю покрытия (скопления и просветы), а карта теней облаков
## передаётся шейдерам рельефа и воды.

const SHADOW_SIZE := 256

var shadow_texture: Texture2D = null
## (половина мира, высота облаков, 0, сила теней) — для шейдеров рельефа и воды.
var shadow_params: Vector4 = Vector4.ZERO
var material: ShaderMaterial = null


## Данные облаков без сцены (можно вызывать в фоновом потоке): список облаков и карта теней.
static func plan(layout: MapLayout, quality: int, seed_value: int) -> Dictionary:
	var cl: Dictionary = layout.preset.get("clouds", {})
	var coverage := float(cl.get("coverage", 0.5))
	var base := float(cl.get("base", 1400.0))
	var thickness := float(cl.get("thickness", 500.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var field := FastNoiseLite.new()
	field.seed = seed_value + 5
	field.frequency = 0.00016
	field.fractal_octaves = 3
	var count := int(lerpf(14.0, 110.0, coverage) * [0.35, 0.6, 1.0, 1.35][clampi(quality, 0, 3)])
	var extent := layout.world * 0.92
	var clouds: Array = []
	var tries := 0
	while clouds.size() < count and tries < count * 30:
		tries += 1
		var x := rng.randf_range(-extent, extent)
		var z := rng.randf_range(-extent, extent)
		var f := field.get_noise_2d(x, z) * 0.5 + 0.5
		if rng.randf() > smoothstep(0.62 - coverage * 0.45, 0.8 - coverage * 0.3, f):
			continue
		var radius := rng.randf_range(170.0, 420.0) * lerpf(0.8, 1.25, coverage)
		var height := thickness * rng.randf_range(0.45, 1.0) * (radius / 300.0)
		clouds.append({"pos": Vector3(x, base + rng.randf_range(-120.0, 160.0), z), "radius": radius, "height": height})
	var img := Image.create(SHADOW_SIZE, SHADOW_SIZE, false, Image.FORMAT_L8)
	img.fill(Color(0, 0, 0))
	var px_per_m := float(SHADOW_SIZE) / (layout.world * 2.0)
	for c: Dictionary in clouds:
		var pos: Vector3 = c["pos"]
		var r := float(c["radius"]) * 0.85 * px_per_m
		var cx := (pos.x + layout.world) * px_per_m
		var cz := (pos.z + layout.world) * px_per_m
		for py in range(maxi(int(cz - r - 1.0), 0), mini(int(cz + r + 2.0), SHADOW_SIZE)):
			for px in range(maxi(int(cx - r - 1.0), 0), mini(int(cx + r + 2.0), SHADOW_SIZE)):
				var d := Vector2(float(px) - cx, float(py) - cz).length() / maxf(r, 0.5)
				if d < 1.0:
					var v := img.get_pixel(px, py).r + (1.0 - smoothstep(0.35, 1.0, d)) * 0.9
					img.set_pixel(px, py, Color(minf(v, 1.0), 0.0, 0.0))
	return {"clouds": clouds, "shadow": img, "base": base + thickness * 0.3, "coverage": coverage}


func build(plan_data: Dictionary, layout: MapLayout, sun_dir: Vector3, sun_color: Color, quality: int) -> void:
	name = "Clouds"
	var cl: Dictionary = layout.preset.get("clouds", {})
	var sky: Dictionary = layout.preset.get("sky", {})
	var tint: Color = cl.get("tint", Color(1.0, 1.0, 1.0))
	var shadow_img: Image = plan_data["shadow"]
	shadow_texture = ImageTexture.create_from_image(shadow_img)
	shadow_params = Vector4(layout.world, float(plan_data["base"]), 0.0, 0.38 if float(plan_data["coverage"]) > 0.05 else 0.0)
	material = ShaderLib.material("cloud")
	material.set_shader_parameter("puff_noise", ProcTextures.puff_noise())
	material.set_shader_parameter("sun_dir", sun_dir)
	material.set_shader_parameter("sun_color", sun_color)
	var lit := tint * Color(1.02, 1.02, 1.03)
	var horizon: Color = sky.get("horizon", Color(0.6, 0.7, 0.8))
	var top: Color = sky.get("top", Color(0.2, 0.35, 0.6))
	material.set_shader_parameter("lit_color", lit)
	material.set_shader_parameter("shade_color", horizon.lerp(top, 0.35).lerp(Color(0.45, 0.47, 0.52), 0.45) * tint)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(layout.map_id) + 77
	var puff_scale: float = [0.7, 0.85, 1.0, 1.1][clampi(quality, 0, 3)]
	for c: Dictionary in plan_data["clouds"]:
		var radius := float(c["radius"])
		var height := float(c["height"])
		var puffs := clampi(int(radius / 15.0 * puff_scale), 10, 34)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = quad
		mm.instance_count = puffs
		for i in puffs:
			var h := pow(rng.randf(), 1.4)
			var ring := radius * (1.0 - 0.55 * h * h) * sqrt(rng.randf())
			var ang := rng.randf() * TAU
			var off := Vector3(cos(ang) * ring, h * height, sin(ang) * ring * 0.8)
			var size := radius * rng.randf_range(0.55, 0.95) * (1.0 - 0.35 * h)
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(size, size * 0.8, 1.0)), off))
			mm.set_instance_custom_data(i, Color(rng.randf(), clampf(h + 0.15, 0.0, 1.0), rng.randf_range(0.93, 1.04), 0.0))
		var ext := radius * 2.2 + height
		mm.custom_aabb = AABB(Vector3(-ext, -ext * 0.5, -ext), Vector3(ext, ext, ext) * 2.0)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.position = c["pos"]
		add_child(mmi)
