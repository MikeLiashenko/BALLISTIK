class_name ModelBuilder
extends RefCounted
## Сборщик модели: объединяет множество примитивов в один ArrayMesh (одна поверхность на материал).
## Меньше узлов и draw calls — важно для Android.

var _tools: Dictionary = {}
var _order: Array[Material] = []


func add(mesh: Mesh, transform: Transform3D, material: Material) -> ModelBuilder:
	var st: SurfaceTool = _tools.get(material)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[material] = st
		_order.append(material)
	st.append_from(mesh, 0, transform)
	return self


func is_empty() -> bool:
	return _order.is_empty()


func build() -> ArrayMesh:
	var am := ArrayMesh.new()
	for m in _order:
		var st: SurfaceTool = _tools[m]
		st.commit(am)
		am.surface_set_material(am.get_surface_count() - 1, m)
	return am


func build_instance(node_name: String = "Model") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = build()
	return mi
