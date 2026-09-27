class_name Atmosphere
extends RefCounted
## Небо, солнце и окружение карты: аналитическое небо (градиент рассеяния, ореол солнца, перистые
## облака на куполе), направленный свет с каскадными тенями, воздушная перспектива (туман по
## дальности с окраской под небо), тонмаппинг AgX, свечение, SSAO/SSR по качеству графики.


## Направление НА солнце по высоте и азимуту (азимут 0° — север (-Z), 90° — восток (+X)).
static func sun_direction(sky: Dictionary) -> Vector3:
	var elev := deg_to_rad(float(sky.get("sun_elevation", 30.0)))
	var az := deg_to_rad(float(sky.get("sun_azimuth", 135.0)))
	return Vector3(sin(az) * cos(elev), sin(elev), -cos(az) * cos(elev)).normalized()


static func sky_material(preset: Dictionary) -> ShaderMaterial:
	var sky: Dictionary = preset.get("sky", {})
	var clouds: Dictionary = preset.get("clouds", {})
	var mat := ShaderLib.material("sky")
	mat.set_shader_parameter("top_color", sky.get("top", Color(0.15, 0.33, 0.66)))
	mat.set_shader_parameter("horizon_color", sky.get("horizon", Color(0.63, 0.74, 0.87)))
	mat.set_shader_parameter("ground_color", sky.get("ground", Color(0.35, 0.4, 0.44)))
	mat.set_shader_parameter("sun_color", sky.get("sun_color", Color(1.0, 0.92, 0.82)))
	mat.set_shader_parameter("cloud_tex", ProcTextures.cloud_noise())
	mat.set_shader_parameter("cloud_amount", float(clouds.get("high", 0.4)))
	mat.set_shader_parameter("cloud_tint", clouds.get("tint", Color(1.0, 1.0, 1.0)))
	return mat


## Создаёт WorldEnvironment и солнце в parent. Возвращает {"env", "sun", "sun_dir", "sun_color"}.
static func create(parent: Node, preset: Dictionary, quality: int) -> Dictionary:
	var sky: Dictionary = preset.get("sky", {})
	var sun_dir := sun_direction(sky)
	var sky_res := Sky.new()
	sky_res.sky_material = sky_material(preset)
	sky_res.process_mode = Sky.PROCESS_MODE_QUALITY if quality >= 2 else Sky.PROCESS_MODE_INCREMENTAL
	sky_res.radiance_size = Sky.RADIANCE_SIZE_256 if quality >= 1 else Sky.RADIANCE_SIZE_128
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky_res
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = float(sky.get("ambient", 1.0))
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = float(sky.get("exposure", 1.0)) * 1.08
	env.glow_enabled = quality >= 1
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = sky.get("fog", Color(0.66, 0.74, 0.84))
	env.fog_light_energy = 1.0
	env.fog_density = float(sky.get("fog_density", 0.0001))
	env.fog_sun_scatter = 0.28
	env.fog_aerial_perspective = 0.62
	env.fog_sky_affect = 0.12
	env.ssao_enabled = quality >= 2
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.6
	env.ssr_enabled = quality >= 3
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.basis = GameDB.basis_from_forward(-sun_dir)
	var sun_color: Color = sky.get("sun_color", Color(1.0, 0.92, 0.82))
	sun.light_color = sun_color
	sun.light_energy = float(sky.get("sun_energy", 1.3))
	sun.light_angular_distance = 0.6
	sun.shadow_enabled = quality >= 1
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if quality >= 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = [300.0, 900.0, 1600.0, 2600.0][clampi(quality, 0, 3)]
	sun.directional_shadow_blend_splits = quality >= 2
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.18
	sun.directional_shadow_split_3 = 0.45
	sun.shadow_blur = 1.2
	sun.shadow_normal_bias = 1.4
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	parent.add_child(sun)
	return {"env": env, "world_env": we, "sun": sun, "sun_dir": sun_dir, "sun_color": sun_color}
