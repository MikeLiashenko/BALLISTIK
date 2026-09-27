class_name MeshFactory
extends RefCounted
## Фабрика процедурных примитивов Godot (BoxMesh, CylinderMesh, SphereMesh, PrismMesh, TorusMesh)
## и материалов. Одинаковые ресурсы кэшируются и переиспользуются всеми моделями.

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}


# --- Материалы ------------------------------------------------------------------------------------
static func mat(color: Color, roughness: float = 0.7, metallic: float = 0.0, emission_energy: float = 0.0) -> StandardMaterial3D:
	var key := "std|%s|%.2f|%.2f|%.2f" % [color.to_html(), roughness, metallic, emission_energy]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission_energy
	_materials[key] = m
	return m


## Неоновый светящийся материал (не зависит от освещения, «цепляет» glow).
static func glow(color: Color, energy: float = 3.0) -> StandardMaterial3D:
	var key := "glow|%s|%.2f" % [color.to_html(), energy]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.disable_receive_shadows = true
	_materials[key] = m
	return m


## Полупрозрачный материал (новый экземпляр — для анимации прозрачности эффектов).
static func fade_material(color: Color, additive: bool = false, unshaded: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	return m


static func shared_fade_material(key: String, color: Color, additive: bool = false) -> StandardMaterial3D:
	var k := "fade|%s" % key
	if _materials.has(k):
		return _materials[k]
	var m := fade_material(color, additive)
	_materials[k] = m
	return m


# --- Примитивы (кэш) ---------------------------------------------------------------------------------
static func box(size: Vector3) -> BoxMesh:
	var key := "box|%.3f|%.3f|%.3f" % [size.x, size.y, size.z]
	if _meshes.has(key):
		return _meshes[key]
	var m := BoxMesh.new()
	m.size = size
	_meshes[key] = m
	return m


static func cylinder(top_radius: float, bottom_radius: float, height: float, segments: int = 14) -> CylinderMesh:
	var key := "cyl|%.3f|%.3f|%.3f|%d" % [top_radius, bottom_radius, height, segments]
	if _meshes.has(key):
		return _meshes[key]
	var m := CylinderMesh.new()
	m.top_radius = top_radius
	m.bottom_radius = bottom_radius
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	_meshes[key] = m
	return m


static func sphere(radius: float, height: float = -1.0, segments: int = 16, rings: int = 8) -> SphereMesh:
	var h := radius * 2.0 if height <= 0.0 else height
	var key := "sph|%.3f|%.3f|%d|%d" % [radius, h, segments, rings]
	if _meshes.has(key):
		return _meshes[key]
	var m := SphereMesh.new()
	m.radius = radius
	m.height = h
	m.radial_segments = segments
	m.rings = rings
	_meshes[key] = m
	return m


static func prism(size: Vector3, left_to_right: float = 0.5) -> PrismMesh:
	var key := "prism|%.3f|%.3f|%.3f|%.3f" % [size.x, size.y, size.z, left_to_right]
	if _meshes.has(key):
		return _meshes[key]
	var m := PrismMesh.new()
	m.size = size
	m.left_to_right = left_to_right
	_meshes[key] = m
	return m


static func torus(inner_radius: float, outer_radius: float, rings: int = 32, ring_segments: int = 8) -> TorusMesh:
	var key := "torus|%.3f|%.3f|%d|%d" % [inner_radius, outer_radius, rings, ring_segments]
	if _meshes.has(key):
		return _meshes[key]
	var m := TorusMesh.new()
	m.inner_radius = inner_radius
	m.outer_radius = outer_radius
	m.rings = rings
	m.ring_segments = ring_segments
	_meshes[key] = m
	return m


static func quad(size: Vector2) -> QuadMesh:
	var key := "quad|%.3f|%.3f" % [size.x, size.y]
	if _meshes.has(key):
		return _meshes[key]
	var m := QuadMesh.new()
	m.size = size
	_meshes[key] = m
	return m


static func cached_mesh(key: String) -> Mesh:
	return _meshes.get(key)


static func store_mesh(key: String, mesh: Mesh) -> void:
	_meshes[key] = mesh


# --- Трансформации ------------------------------------------------------------------------------------
## Трансформация по позиции и углам Эйлера в градусах (порядок YXZ, как в редакторе Godot).
static func xf(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> Transform3D:
	var b := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
	return Transform3D(b, pos)


## Цилиндр вдоль оси Z (вершина цилиндра смотрит назад, +Z).
static func along_z(pos: Vector3) -> Transform3D:
	return xf(pos, Vector3(90.0, 0.0, 0.0))


## Конус/цилиндр вдоль оси -Z (вершина смотрит вперёд).
static func along_forward(pos: Vector3) -> Transform3D:
	return xf(pos, Vector3(-90.0, 0.0, 0.0))


## Цилиндр вдоль оси X (колёса, оси).
static func along_x(pos: Vector3) -> Transform3D:
	return xf(pos, Vector3(0.0, 0.0, 90.0))


## Плоская треугольная призма в горизонтальной плоскости (крылья): вершина — вперёд (-Z).
static func flat_wing(pos: Vector3, yaw_deg: float = 0.0) -> Transform3D:
	return xf(pos, Vector3(-90.0, yaw_deg, 0.0))


static func mesh_instance(mesh: Mesh, material: Material = null, name: String = "Mesh") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	if material != null:
		mi.material_override = material
	return mi
