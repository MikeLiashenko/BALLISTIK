class_name TerrainRenderer
extends Node3D
## Отрисовка рельефа: чанки с уровнями детализации (переключение по дальности — visibility range)
## и материал-сплаттинг (трава, луга, поля, лес, песок, скалы, снег, тени облаков).

## Границы переключения LOD в размерах чанка.
const LOD_SWITCH := [2.3, 4.8, 9.5, 18.0]

var material: ShaderMaterial = null


func setup_material(layout: MapLayout, cloud_shadow: Texture2D, cloud_params: Vector4, sun_dir: Vector3, quality: int) -> void:
	var biome := MapPresets.biome(layout.map_id)
	material = ShaderLib.material("terrain")
	material.set_shader_parameter("noise_macro", ProcTextures.terrain_macro())
	material.set_shader_parameter("noise_detail", ProcTextures.terrain_detail())
	material.set_shader_parameter("normal_detail", ProcTextures.terrain_normal())
	material.set_shader_parameter("cloud_shadow", cloud_shadow)
	material.set_shader_parameter("cloud_params", cloud_params)
	material.set_shader_parameter("sun_dir", sun_dir)
	for key: String in ["grass", "grass2", "dry", "forest", "dirt", "rock", "rock2", "sand", "snow"]:
		material.set_shader_parameter("c_" + key, _lin(biome[key]))
	var fields := PackedVector3Array()
	var src: Array = biome["fields"]
	for i in 5:
		fields.append(_lin(src[i % src.size()]))
	material.set_shader_parameter("c_fields", fields)
	material.set_shader_parameter("snow_line", float(layout.preset.get("snow_line", 800.0)))
	material.set_shader_parameter("field_angle", float(layout.preset.get("field_angle", 0.3)))
	material.set_shader_parameter("detail_fade", [1400.0, 2200.0, 2800.0, 3400.0][clampi(quality, 0, 3)])


static func _lin(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)


## Создаёт узлы чанков из данных TerrainMeshBuilder (вызывать в основном потоке).
func commit(builder: TerrainMeshBuilder, results: Array, shadow_lods: int) -> void:
	var size := builder.chunk_size()
	for r: Dictionary in results:
		var lod: int = r["lod"]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = r["verts"]
		arrays[Mesh.ARRAY_NORMAL] = r["normals"]
		arrays[Mesh.ARRAY_COLOR] = r["colors"]
		arrays[Mesh.ARRAY_INDEX] = builder.lod_indices[lod]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, material)
		var mi := MeshInstance3D.new()
		mi.name = "Chunk_%d_%d_L%d" % [int(r["cx"]), int(r["cz"]), lod]
		mi.mesh = mesh
		mi.position = r["center"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod < shadow_lods else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if builder.lods > 1:
			mi.visibility_range_begin = 0.0 if lod == 0 else LOD_SWITCH[lod - 1] * size
			mi.visibility_range_end = 0.0 if lod == builder.lods - 1 else LOD_SWITCH[lod] * size
		add_child(mi)
