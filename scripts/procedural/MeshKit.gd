class_name MeshKit
extends RefCounted
## Низкоуровневая сборка мешей: вершины с нормалями, цветами и двумя UV, индексы, трансформация
## добавляемой геометрии. Используется генераторами деревьев, самолётов, корпусов кораблей.

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()
var indices := PackedInt32Array()
var xform := Transform3D.IDENTITY
var color := Color(1.0, 1.0, 1.0, 1.0)
var uv2 := Vector2.ZERO
## Шаг колец лофта по длине (м).
var ring_step: float = 0.22


func vertex_count() -> int:
	return verts.size()


func add_vertex(p: Vector3, n: Vector3, uv: Vector2 = Vector2.ZERO, c: Color = Color(-1.0, 0.0, 0.0, 0.0)) -> int:
	verts.append(xform * p)
	normals.append((xform.basis * n).normalized())
	colors.append(color if c.r < 0.0 else c)
	uvs.append(uv)
	uv2s.append(uv2)
	return verts.size() - 1


func tri(a: int, b: int, c: int) -> void:
	indices.append(a)
	indices.append(b)
	indices.append(c)


## Четырёхугольник a-b-c-d (по часовой стрелке, если смотреть с лицевой стороны).
func quad(a: int, b: int, c: int, d: int) -> void:
	tri(a, b, c)
	tri(a, c, d)


## Сетка вершин rows × cols (row-major); соединяет соседние строки. wrap — замкнуть по столбцам.
func grid(start: int, rows: int, cols: int, wrap: bool, flip: bool = false) -> void:
	var span := cols if wrap else cols - 1
	for r in rows - 1:
		for c in span:
			var c1 := (c + 1) % cols
			var a := start + r * cols + c
			var b := start + r * cols + c1
			var d := start + (r + 1) * cols + c
			var e := start + (r + 1) * cols + c1
			if flip:
				quad(a, d, e, b)
			else:
				quad(a, b, e, d)


func append_kit(other: MeshKit) -> void:
	var base := verts.size()
	for i in other.verts.size():
		verts.append(xform * other.verts[i])
		normals.append((xform.basis * other.normals[i]).normalized())
	colors.append_array(other.colors)
	uvs.append_array(other.uvs)
	uv2s.append_array(other.uv2s)
	for i in other.indices:
		indices.append(base + i)


func is_empty() -> bool:
	return indices.is_empty()


func arrays() -> Array:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_NORMAL] = normals
	a[Mesh.ARRAY_COLOR] = colors
	a[Mesh.ARRAY_TEX_UV] = uvs
	a[Mesh.ARRAY_TEX_UV2] = uv2s
	a[Mesh.ARRAY_INDEX] = indices
	return a


## Добавляет поверхность в mesh (создаёт новый ArrayMesh, если mesh == null).
func commit(mesh: ArrayMesh, material: Material) -> ArrayMesh:
	var m := mesh if mesh != null else ArrayMesh.new()
	if indices.is_empty():
		return m
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays())
	m.surface_set_material(m.get_surface_count() - 1, material)
	return m


# --- Примитивы ------------------------------------------------------------------------------------------
## Усечённый конус вдоль +Y от y0 до y1 (радиусы r0/r1), segments граней, без крышек.
func add_cylinder(center: Vector3, y0: float, y1: float, r0: float, r1: float, segments: int, c0: Color, c1: Color) -> void:
	var start := verts.size()
	var slope := (r0 - r1) / maxf(y1 - y0, 0.001)
	for row in 2:
		var y := y0 if row == 0 else y1
		var r := r0 if row == 0 else r1
		for s in segments:
			var a := float(s) / float(segments) * TAU
			var n := Vector3(cos(a), slope, sin(a)).normalized()
			add_vertex(center + Vector3(cos(a) * r, y, sin(a) * r), n, Vector2.ZERO, c0 if row == 0 else c1)
	grid(start, 2, segments, true, false)


## Сфера-«клуб» (икосаэдр с подразбиением) с неровностями: радиусы по осям, яркость низа/верха.
func add_blob(center: Vector3, radii: Vector3, subdiv: int, jitter: float, seed_value: int, bottom: Color, top: Color) -> void:
	var ico := _icosphere(subdiv)
	var pts: PackedVector3Array = ico["verts"]
	var tris: PackedInt32Array = ico["indices"]
	var start := verts.size()
	for i in pts.size():
		var p := pts[i]
		var h := _hash3(p * 3.7 + Vector3(float(seed_value), float(seed_value) * 0.37, 0.0))
		var r := 1.0 + (h - 0.5) * 2.0 * jitter
		var q := Vector3(p.x * radii.x, p.y * radii.y, p.z * radii.z) * r
		var n := Vector3(p.x / radii.x, p.y / radii.y, p.z / radii.z).normalized()
		var k := clampf(p.y * 0.5 + 0.5, 0.0, 1.0)
		add_vertex(center + q, n, Vector2.ZERO, bottom.lerp(top, k))
	for i in range(0, tris.size(), 3):
		tri(start + tris[i], start + tris[i + 1], start + tris[i + 2])


## Конус «ёлочного яруса» с зубчатым краем (звёздчатое сечение).
func add_spiky_cone(center: Vector3, y0: float, height: float, radius: float, segments: int, bottom: Color, top: Color) -> void:
	var apex := add_vertex(center + Vector3(0.0, y0 + height, 0.0), Vector3.UP, Vector2.ZERO, top)
	var ring_start := verts.size()
	for s in segments:
		var a := float(s) / float(segments) * TAU
		var r := radius * (1.0 if s % 2 == 0 else 0.68)
		var droop := -height * 0.08 if s % 2 == 0 else 0.0
		var n := Vector3(cos(a), 0.55, sin(a)).normalized()
		add_vertex(center + Vector3(cos(a) * r, y0 + droop, sin(a) * r), n, Vector2.ZERO, bottom)
	var under := add_vertex(center + Vector3(0.0, y0 + height * 0.12, 0.0), Vector3.DOWN, Vector2.ZERO, bottom.darkened(0.3))
	for s in segments:
		var a := ring_start + s
		var b := ring_start + (s + 1) % segments
		tri(apex, a, b)
		tri(under, b, a)


# --- Лофт и параллелепипеды ----------------------------------------------------------------------------
static func interp_station(st: Array, i: int, t: float) -> PackedFloat32Array:
	var p0: Array = st[maxi(i - 1, 0)]
	var p1: Array = st[i]
	var p2: Array = st[i + 1]
	var p3: Array = st[mini(i + 2, st.size() - 1)]
	var out := PackedFloat32Array()
	var t2 := t * t
	var t3 := t2 * t
	for j in p1.size():
		var a := float(p0[j])
		var b := float(p1[j])
		var c := float(p2[j])
		var d := float(p3[j])
		if j == 0:
			out.append(lerpf(b, c, t))
		else:
			out.append(0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t2 + (-a + 3.0 * b - 3.0 * c + d) * t3))
	return out


## Лофт по сечениям: stations — [s, половина ширины, верх, низ, центр по высоте]. Сечение симметрично
## по X, поэтому парные тела (мотогондолы, баки) строятся простым смещением offset.
func add_loft(stations: Array, n: float, segs: int, cg: float, part: float, offset: Vector3, cap_front: bool, cap_back: bool) -> void:
	var rings: Array[PackedFloat32Array] = []
	for i in stations.size() - 1:
		var a: Array = stations[i]
		var b: Array = stations[i + 1]
		var steps := maxi(2, ceili((float(b[0]) - float(a[0])) / ring_step))
		for k in steps:
			rings.append(interp_station(stations, i, float(k) / float(steps)))
	var last: Array = stations[stations.size() - 1]
	var last_p := PackedFloat32Array()
	for v in last:
		last_p.append(float(v))
	rings.append(last_p)
	var nr := rings.size()
	var cols := segs + 1
	var pts := PackedVector3Array()
	pts.resize(nr * cols)
	var e := 2.0 / maxf(n, 0.5)
	for r in nr:
		var st := rings[r]
		var w := maxf(st[1], 0.004)
		var ht := maxf(st[2], 0.004)
		var hb := maxf(st[3], 0.004)
		var yc := st[4]
		for c in cols:
			var th := -PI + TAU * float(c % segs) / float(segs)
			var sn := sin(th)
			var cs := cos(th)
			var px := w * signf(sn) * pow(absf(sn), e)
			var py := yc + (ht if cs >= 0.0 else hb) * signf(cs) * pow(absf(cs), e)
			pts[r * cols + c] = Vector3(px, py, st[0] - cg) + Vector3(offset.x, offset.y, 0.0)
	var nrm := PackedVector3Array()
	nrm.resize(nr * cols)
	for r in nr:
		var center := Vector3(offset.x, rings[r][4] + offset.y, rings[r][0] - cg)
		for c in cols:
			var cp := (c - 1 + segs) % segs
			var cn := (c + 1) % segs
			var t_th := pts[r * cols + cn] - pts[r * cols + cp]
			var t_s := pts[mini(r + 1, nr - 1) * cols + c] - pts[maxi(r - 1, 0) * cols + c]
			var nv := t_s.cross(t_th)
			var radial := pts[r * cols + c] - center
			if nv.length_squared() < 1e-10:
				nv = radial if radial.length_squared() > 1e-8 else Vector3(0.0, 0.0, -1.0 if r == 0 else 1.0)
			if nv.dot(radial) < 0.0:
				nv = -nv
			nrm[r * cols + c] = nv.normalized()
	var base := vertex_count()
	uv2 = Vector2(0.0, part)
	for r in nr:
		var arc := PackedFloat32Array()
		arc.resize(cols)
		arc[0] = 0.0
		for c in range(1, cols):
			arc[c] = arc[c - 1] + pts[r * cols + c].distance_to(pts[r * cols + c - 1])
		var top := arc[segs / 2]
		for c in cols:
			add_vertex(pts[r * cols + c], nrm[r * cols + c], Vector2(rings[r][0], arc[c] - top))
	for r in nr - 1:
		for c in segs:
			var a := base + r * cols + c
			var b := a + 1
			var d := a + cols
			var f := d + 1
			quad(a, b, f, d)
	if cap_back:
		_cap(pts, (nr - 1) * cols, segs, true)
	if cap_front:
		_cap(pts, 0, segs, false)


## Крышка торца лофта (веер). Кольцо обходится снизу через левый борт вверх — для кормовой крышки
## такой обход идёт по часовой стрелке (лицевая сторона в Godot), для носовой — обратный порядок.
func _cap(pts: PackedVector3Array, ring_start: int, segs: int, back: bool) -> void:
	var center := Vector3.ZERO
	for c in segs:
		center += pts[ring_start + c]
	center /= float(segs)
	var nv := Vector3(0.0, 0.0, 1.0 if back else -1.0)
	var ci := add_vertex(center, nv)
	var ring := PackedInt32Array()
	for c in segs:
		ring.append(add_vertex(pts[ring_start + c], nv))
	for c in segs:
		var a := ring[c]
		var b := ring[(c + 1) % segs]
		if back:
			tri(ci, a, b)
		else:
			tri(ci, b, a)


## Параллелепипед с плоскими гранями.
func add_box(center: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]
	for f: Array in faces:
		var nv: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c := center + nv * h
		var hu := u * absf(u.dot(h))
		var hv := v * absf(v.dot(h))
		var a := add_vertex(c - hu - hv, nv)
		var b := add_vertex(c + hu - hv, nv)
		var d := add_vertex(c + hu + hv, nv)
		var e := add_vertex(c - hu + hv, nv)
		quad(a, e, d, b)


static var _ico_cache: Dictionary = {}


static func _icosphere(subdiv: int) -> Dictionary:
	if _ico_cache.has(subdiv):
		return _ico_cache[subdiv]
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	for i in v.size():
		v[i] = v[i].normalized()
	var f: Array[Vector3i] = [
		Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10), Vector3i(0, 10, 11),
		Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6), Vector3i(7, 1, 8),
		Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9),
		Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7), Vector3i(9, 8, 1),
	]
	for s in subdiv:
		var mids: Dictionary = {}
		var nf: Array[Vector3i] = []
		for face in f:
			var a := _mid(v, mids, face.x, face.y)
			var b := _mid(v, mids, face.y, face.z)
			var c := _mid(v, mids, face.z, face.x)
			nf.append(Vector3i(face.x, a, c))
			nf.append(Vector3i(face.y, b, a))
			nf.append(Vector3i(face.z, c, b))
			nf.append(Vector3i(a, b, c))
		f = nf
	var pv := PackedVector3Array(v)
	var idx := PackedInt32Array()
	for face in f:
		# Порядок обхода для лицевой стороны снаружи (соглашение Godot — по часовой стрелке).
		idx.append(face.x)
		idx.append(face.z)
		idx.append(face.y)
	var result := {"verts": pv, "indices": idx}
	_ico_cache[subdiv] = result
	return result


static func _mid(v: Array[Vector3], mids: Dictionary, a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if mids.has(key):
		return mids[key]
	v.append(((v[a] + v[b]) * 0.5).normalized())
	mids[key] = v.size() - 1
	return v.size() - 1


static func _hash3(p: Vector3) -> float:
	var h := sin(p.dot(Vector3(12.9898, 78.233, 37.719))) * 43758.5453
	return h - floorf(h)
