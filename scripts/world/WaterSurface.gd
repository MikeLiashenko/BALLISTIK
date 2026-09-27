class_name WaterSurface
extends MeshInstance3D
## Морская поверхность до горизонта: волны из нескольких слоёв карт нормалей, цвет по глубине
## (карта высот рельефа — бирюзовые отмели и глубокая синь), прибой и пена у берега, барашки,
## отражение неба и солнечная дорожка (PBR), тени облаков.


func setup(terrain: Terrain, cloud_shadow: Texture2D, cloud_params: Vector4, sun_dir: Vector3) -> void:
	name = "Water"
	var layout := terrain.layout
	var water: Dictionary = layout.preset.get("water", {})
	var plane := PlaneMesh.new()
	plane.size = Vector2(layout.world * 14.0, layout.world * 14.0)
	var mat := ShaderLib.material("water")
	mat.set_shader_parameter("height_map", ImageTexture.create_from_image(terrain.height_image()))
	mat.set_shader_parameter("world_half", terrain.half_size)
	mat.set_shader_parameter("wave_normal", ProcTextures.wave_normal())
	mat.set_shader_parameter("foam_noise", ProcTextures.foam_noise())
	mat.set_shader_parameter("cloud_shadow", cloud_shadow)
	mat.set_shader_parameter("cloud_params", cloud_params)
	mat.set_shader_parameter("sun_dir", sun_dir)
	mat.set_shader_parameter("deep_color", water.get("deep", Color(0.02, 0.1, 0.16)))
	mat.set_shader_parameter("shallow_color", water.get("shallow", Color(0.07, 0.3, 0.3)))
	mat.set_shader_parameter("wave_strength", float(water.get("waves", 1.0)))
	plane.material = mat
	mesh = plane
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
