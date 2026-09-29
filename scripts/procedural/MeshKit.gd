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


# --- Треугольники с автоматическим порядком обхода --------------------------------------------------
## Треугольник, лицевая сторона которого смотрит в сторону outward (в локальных координатах xform).
func tri_out(a: int, b: int, c: int, outward: Vector3) -> void:
	var n := (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if n.dot(xform.basis * outward) > 0.0:
		tri(a, c, b)
	else:
		tri(a, b, c)


## Плоский многоугольник (выпуклый или нет) с нормалью normal: точки в 3D, лежащие в одной плоскости.
func add_polygon(points: PackedVector3Array, normal: Vector3, uv_scale: float = 1.0) -> void:
	if points.size() < 3:
		return
	var n := normal.normalized()
	var u_axis := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var v_axis := n.cross(u_axis)
	var flat := PackedVector2Array()
	for p in points:
		flat.append(Vector2(p.dot(u_axis), p.dot(v_axis)))
	var tris := Geometry2D.triangulate_polygon(flat)
	if tris.is_empty():
		return
	var start := verts.size()
	for i in points.size():
		add_vertex(points[i], n, flat[i] * uv_scale)
	for i in range(0, tris.size(), 3):
		tri_out(start + tris[i], start + tris[i + 1], start + tris[i + 2], n)


## Диск (круг) с нормалью normal.
func add_disc(center: Vector3, normal: Vector3, radius: float, segs: int = 16) -> void:
	var n := normal.normalized()
	var u_axis := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var v_axis := n.cross(u_axis)
	var ci := add_vertex(center, n)
	var ring := PackedInt32Array()
	for i in segs:
		var a := float(i) / float(segs) * TAU
		ring.append(add_vertex(center + (u_axis * cos(a) + v_axis * sin(a)) * radius, n))
	for i in segs:
		tri_out(ci, ring[i], ring[(i + 1) % segs], n)


# --- Тела вращения ---------------------------------------------------------------------------------------
## Тело вращения вокруг локальной оси +Y: profile — точки (y, r). Нормали по наклону образующей;
## изломы круче smooth_deg остаются острыми (дульные тормоза, фланцы). Развёртка UV — в метрах.
func add_lathe(profile: PackedVector2Array, segs: int = 16, cap_start: bool = false, cap_end: bool = false, smooth_deg: float = 50.0, phase: float = 0.0) -> void:
	var n := profile.size()
	if n < 2:
		return
	# Нормали сегментов образующей в плоскости (r, y).
	var seg_n: Array[Vector2] = []
	for i in n - 1:
		var d := profile[i + 1] - profile[i]
		var sn := Vector2(d.x, -d.y)  # (dy, -dr) → нормаль (r-составляющая, y-составляющая)
		if sn.length_squared() < 1e-12:
			sn = Vector2(1.0, 0.0)
		seg_n.append(sn.normalized())
	var cos_lim := cos(deg_to_rad(smooth_deg))
	var arc := 0.0
	for i in n - 1:
		var p0 := profile[i]
		var p1 := profile[i + 1]
		var sn: Vector2 = seg_n[i]
		var n0 := sn
		var n1 := sn
		if i > 0 and seg_n[i - 1].dot(sn) > cos_lim:
			n0 = (seg_n[i - 1] + sn).normalized()
		if i < n - 2 and seg_n[i + 1].dot(sn) > cos_lim:
			n1 = (seg_n[i + 1] + sn).normalized()
		var seg_len := p0.distance_to(p1)
		var start := verts.size()
		for s in segs + 1:
			var a := phase + float(s) / float(segs) * TAU
			var ca := cos(a)
			var sa := sin(a)
			add_vertex(Vector3(ca * p0.y, p0.x, sa * p0.y), Vector3(ca * n0.x, n0.y, sa * n0.x), Vector2(a * maxf(p0.y, 0.01), arc))
			add_vertex(Vector3(ca * p1.y, p1.x, sa * p1.y), Vector3(ca * n1.x, n1.y, sa * n1.x), Vector2(a * maxf(p1.y, 0.01), arc + seg_len))
		arc += seg_len
		for s in segs:
			var a0 := start + s * 2
			var a1 := a0 + 1
			var b0 := a0 + 2
			var b1 := a0 + 3
			var am := phase + (float(s) + 0.5) / float(segs) * TAU
			var outward := Vector3(cos(am) * sn.x, sn.y, sin(am) * sn.x)
			if (profile[i + 1].y < 1e-5 and profile[i].y < 1e-5):
				continue
			tri_out(a0, a1, b1, outward)
			tri_out(a0, b1, b0, outward)
	if cap_start and profile[0].y > 1e-4:
		_lathe_cap(profile[0], segs, phase, -1.0 if profile[1].x > profile[0].x else 1.0)
	if cap_end and profile[n - 1].y > 1e-4:
		_lathe_cap(profile[n - 1], segs, phase, 1.0 if profile[n - 1].x > profile[n - 2].x else -1.0)


func _lathe_cap(p: Vector2, segs: int, phase: float, dir: float) -> void:
	var nv := Vector3(0.0, dir, 0.0)
	var ci := add_vertex(Vector3(0.0, p.x, 0.0), nv)
	var ring := PackedInt32Array()
	for s in segs:
		var a := phase + float(s) / float(segs) * TAU
		ring.append(add_vertex(Vector3(cos(a) * p.y, p.x, sin(a) * p.y), nv))
	for s in segs:
		tri_out(ci, ring[s], ring[(s + 1) % segs], nv)


# --- Лофт по сечениям произвольной формы ------------------------------------------------------------------
## stations — массив [z, PackedVector2Array]: полупрофили сечений (x ≥ 0) от нижней точки на оси
## симметрии вверх по правому борту до верхней точки на оси (mirror = true — левый борт зеркально);
## при mirror = false — замкнутый контур целиком (против часовой стрелки, если смотреть с +Z).
## Число точек во всех сечениях одинаковое. Нормали сглаживаются между гранями, угол между которыми
## меньше smooth_deg, иначе ребро остаётся острым (броня, надстройки). Крышки торцов — триангуляцией.
func add_sections(stations: Array, smooth_deg: float = 30.0, cap_front: bool = true, cap_back: bool = true, mirror: bool = true) -> void:
	var nst := stations.size()
	if nst < 2:
		return
	var rings: Array[PackedVector3Array] = []
	for st: Array in stations:
		var z := float(st[0])
		var pts: PackedVector2Array = st[1]
		var ring := PackedVector3Array()
		for p in pts:
			ring.append(Vector3(p.x, p.y, z))
		if mirror:
			for i in range(pts.size() - 2, 0, -1):
				ring.append(Vector3(-pts[i].x, pts[i].y, z))
		rings.append(ring)
	var cols := rings[0].size()
	for r in rings:
		if r.size() != cols:
			push_error("MeshKit.add_sections: разное число точек в сечениях")
			return
	# Ориентация: контур против часовой стрелки (вид с +Z) и рост z вдоль станций.
	var area := 0.0
	for i in nst:
		var a := _ring_area(rings[i])
		if absf(a) > absf(area):
			area = a
	var sign_k := 1.0 if area >= 0.0 else -1.0
	if float(stations[nst - 1][0]) < float(stations[0][0]):
		sign_k = -sign_k
	# Нормали граней.
	var fn: Array[Vector3] = []
	fn.resize((nst - 1) * cols)
	for r in nst - 1:
		for c in cols:
			var c1 := (c + 1) % cols
			var a := rings[r][c]
			var b := rings[r][c1]
			var d := rings[r + 1][c]
			var e := rings[r + 1][c1]
			var nv := ((b - a) + (e - d)).cross((d - a) + (e - b)) * sign_k
			fn[r * cols + c] = nv.normalized() if nv.length_squared() > 1e-14 else Vector3.ZERO
	var cos_lim := cos(deg_to_rad(smooth_deg))
	var arc_cache: Array[PackedFloat32Array] = []
	for r in nst:
		var arc := PackedFloat32Array()
		arc.resize(cols + 1)
		for c in range(1, cols + 1):
			arc[c] = arc[c - 1] + rings[r][c % cols].distance_to(rings[r][c - 1])
		arc_cache.append(arc)
	for r in nst - 1:
		for c in cols:
			var f := fn[r * cols + c]
			if f == Vector3.ZERO:
				continue
			var c1 := (c + 1) % cols
			var corners := [[r, c], [r, c1], [r + 1, c1], [r + 1, c]]
			var ids := PackedInt32Array()
			for k in 4:
				var rr: int = corners[k][0]
				var cc: int = corners[k][1]
				var nsum := Vector3.ZERO
				# Грани, примыкающие к вершине (rr, cc): (rr-1|rr) × (cc-1|cc).
				for dr: int in [rr - 1, rr]:
					if dr < 0 or dr >= nst - 1:
						continue
					for dc: int in [(cc - 1 + cols) % cols, cc]:
						var g := fn[dr * cols + dc]
						if g != Vector3.ZERO and g.dot(f) >= cos_lim:
							nsum += g
				var nn := nsum.normalized() if nsum.length_squared() > 1e-12 else f
				var arc_i := cols if (k == 1 or k == 2) and c1 == 0 else cc
				ids.append(add_vertex(rings[rr][cc], nn, Vector2(rings[rr][cc].z, arc_cache[rr][arc_i])))
			tri_out(ids[0], ids[3], ids[2], f)
			tri_out(ids[0], ids[2], ids[1], f)
	if cap_front:
		_ring_cap(rings[0], Vector3(0.0, 0.0, -1.0 if float(stations[0][0]) <= float(stations[nst - 1][0]) else 1.0))
	if cap_back:
		_ring_cap(rings[nst - 1], Vector3(0.0, 0.0, 1.0 if float(stations[nst - 1][0]) >= float(stations[0][0]) else -1.0))


static func _ring_area(ring: PackedVector3Array) -> float:
	var a := 0.0
	for i in ring.size():
		var p := ring[i]
		var q := ring[(i + 1) % ring.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


func _ring_cap(ring: PackedVector3Array, normal: Vector3) -> void:
	var flat := PackedVector2Array()
	for p in ring:
		flat.append(Vector2(p.x, p.y))
	if absf(_ring_area(ring)) < 1e-6:
		return
	var tris := Geometry2D.triangulate_polygon(flat)
	if tris.is_empty():
		return
	var start := verts.size()
	for p in ring:
		add_vertex(p, normal, Vector2(p.x, p.y))
	for i in range(0, tris.size(), 3):
		tri_out(start + tris[i], start + tris[i + 1], start + tris[i + 2], normal)


# --- Призмы и блоки ---------------------------------------------------------------------------------------
## Призма, выдавленная поперёк (вдоль X) из бокового профиля profile — замкнутый контур в плоскости
## (z, y). Полуширина зависит от высоты: hw(y) = half_width - taper·(y - y_ref) — наклонные борта
## (броня, башни, кабины). Боковины плоские; грани по контуру — с резкими рёбрами (smooth_deg).
func add_prism(profile: PackedVector2Array, half_width: float, taper: float = 0.0, y_ref: float = 0.0, smooth_deg: float = 15.0, x_offset: float = 0.0) -> void:
	var n := profile.size()
	if n < 3:
		return
	var area := 0.0
	for i in n:
		var p := profile[i]
		var q := profile[(i + 1) % n]
		area += p.x * q.y - q.x * p.y
	var orient := 1.0 if area > 0.0 else -1.0
	var hw := PackedFloat32Array()
	for p in profile:
		hw.append(maxf(half_width - taper * (p.y - y_ref), 0.002))
	# Боковины.
	for side: float in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		for i in n:
			pts.append(Vector3(x_offset + side * hw[i], profile[i].y, profile[i].x))
		var nrm := Vector3(side, taper, 0.0).normalized()
		var flat := PackedVector2Array()
		for p in profile:
			flat.append(p)
		var tris := Geometry2D.triangulate_polygon(flat)
		var start := verts.size()
		for i in n:
			add_vertex(pts[i], nrm, Vector2(profile[i].x, profile[i].y))
		for i in range(0, tris.size(), 3):
			tri_out(start + tris[i], start + tris[i + 1], start + tris[i + 2], nrm)
	# Грани по контуру.
	var en: Array[Vector3] = []
	for i in n:
		var a := profile[i]
		var b := profile[(i + 1) % n]
		var d := b - a
		# Внешняя нормаль в плоскости (z, y): для контура против часовой стрелки (z вправо, y вверх) — справа от ребра.
		var out2 := Vector2(d.y, -d.x) * orient
		en.append(Vector3(0.0, out2.y, out2.x).normalized() if out2.length_squared() > 1e-12 else Vector3.ZERO)
	var cos_lim := cos(deg_to_rad(smooth_deg))
	var arc := 0.0
	for i in n:
		var j := (i + 1) % n
		var f := en[i]
		if f == Vector3.ZERO:
			continue
		var ni := f
		var nj := f
		var prev := en[(i - 1 + n) % n]
		var next := en[j]
		if prev.dot(f) > cos_lim:
			ni = (prev + f).normalized()
		if next.dot(f) > cos_lim:
			nj = (next + f).normalized()
		var len_e := profile[i].distance_to(profile[j])
		var a0 := add_vertex(Vector3(x_offset - hw[i], profile[i].y, profile[i].x), ni, Vector2(-hw[i], arc))
		var a1 := add_vertex(Vector3(x_offset + hw[i], profile[i].y, profile[i].x), ni, Vector2(hw[i], arc))
		var b0 := add_vertex(Vector3(x_offset - hw[j], profile[j].y, profile[j].x), nj, Vector2(-hw[j], arc + len_e))
		var b1 := add_vertex(Vector3(x_offset + hw[j], profile[j].y, profile[j].x), nj, Vector2(hw[j], arc + len_e))
		arc += len_e
		tri_out(a0, a1, b1, f)
		tri_out(a0, b1, b0, f)


## Блок по плану: многоугольник plan (x, z) выдавлен вверх от y0 до y1, стены наклонены внутрь на inset
## (верхний контур сжат). Надстройки кораблей, рубки, кабины. top/bottom — закрывать ли торцы.
func add_block(plan: PackedVector2Array, y0: float, y1: float, inset: float = 0.0, top: bool = true, bottom: bool = false, smooth_deg: float = 12.0, inside: bool = false) -> void:
	var n := plan.size()
	if n < 3:
		return
	var upper := _inset_polygon(plan, inset)
	var area := 0.0
	for i in n:
		var p := plan[i]
		var q := plan[(i + 1) % n]
		area += p.x * q.y - q.x * p.y
	var orient := 1.0 if area > 0.0 else -1.0
	var en: Array[Vector3] = []
	for i in n:
		var j := (i + 1) % n
		var a := Vector3(plan[i].x, y0, plan[i].y)
		var b := Vector3(plan[j].x, y0, plan[j].y)
		var c := Vector3(upper[i].x, y1, upper[i].y)
		var e := b - a
		var up := c - a
		var nv := e.cross(up)
		# Внешняя нормаль: для обхода против часовой (x вправо, z вниз на плане) — знак по ориентации;
		# inside — стенки смотрят внутрь (открытые рубки, внутренние поверхности башен).
		nv = nv * -orient * (-1.0 if inside else 1.0)
		en.append(nv.normalized() if nv.length_squared() > 1e-12 else Vector3.ZERO)
	var cos_lim := cos(deg_to_rad(smooth_deg))
	for i in n:
		var j := (i + 1) % n
		var f := en[i]
		if f == Vector3.ZERO:
			continue
		var ni := f
		var nj := f
		var prev := en[(i - 1 + n) % n]
		if prev.dot(f) > cos_lim:
			ni = (prev + f).normalized()
		if en[j].dot(f) > cos_lim:
			nj = (en[j] + f).normalized()
		var a0 := add_vertex(Vector3(plan[i].x, y0, plan[i].y), ni)
		var b0 := add_vertex(Vector3(plan[j].x, y0, plan[j].y), nj)
		var a1 := add_vertex(Vector3(upper[i].x, y1, upper[i].y), ni)
		var b1 := add_vertex(Vector3(upper[j].x, y1, upper[j].y), nj)
		tri_out(a0, b0, b1, f)
		tri_out(a0, b1, a1, f)
	if top:
		var pts := PackedVector3Array()
		for p in upper:
			pts.append(Vector3(p.x, y1, p.y))
		add_polygon(pts, Vector3.UP)
	if bottom:
		var pts := PackedVector3Array()
		for p in plan:
			pts.append(Vector3(p.x, y0, p.y))
		add_polygon(pts, Vector3.DOWN)


static func _inset_polygon(plan: PackedVector2Array, inset: float) -> PackedVector2Array:
	if absf(inset) < 1e-5:
		return plan
	var res := Geometry2D.offset_polygon(plan, -inset, Geometry2D.JOIN_MITER)
	if res.size() == 1 and (res[0] as PackedVector2Array).size() == plan.size():
		var poly: PackedVector2Array = res[0]
		# Сопоставление вершин: offset_polygon может начинать контур с другой вершины.
		var best := 0
		var best_d := INF
		for k in poly.size():
			var d := poly[k].distance_squared_to(plan[0])
			if d < best_d:
				best_d = d
				best = k
		var out := PackedVector2Array()
		var same_dir := (poly[(best + 1) % poly.size()] - plan[1]).length() < (poly[(best - 1 + poly.size()) % poly.size()] - plan[1]).length()
		for k in poly.size():
			out.append(poly[(best + k) % poly.size()] if same_dir else poly[(best - k + poly.size()) % poly.size()])
		return out
	# Запасной вариант — масштабирование к центру.
	var c := Vector2.ZERO
	for p in plan:
		c += p
	c /= float(plan.size())
	var out2 := PackedVector2Array()
	for p in plan:
		var d := p - c
		out2.append(c + d * maxf(1.0 - inset / maxf(d.length(), 0.01), 0.05))
	return out2


# --- Трубы, тросы, лееры ----------------------------------------------------------------------------------
## Труба по ломаной: кольца ориентированы по касательной (параллельный перенос).
func add_tube(points: PackedVector3Array, radius: float, segs: int = 6, cap: bool = false, radius_end: float = -1.0) -> void:
	var n := points.size()
	if n < 2:
		return
	var r_end := radius if radius_end < 0.0 else radius_end
	var t0 := (points[1] - points[0]).normalized()
	var ref := Vector3.UP if absf(t0.y) < 0.9 else Vector3.RIGHT
	var u := t0.cross(ref).normalized()
	var total := 0.0
	for i in n - 1:
		total += points[i].distance_to(points[i + 1])
	var acc := 0.0
	var prev_ring := PackedInt32Array()
	var prev_t := t0
	for i in n:
		var t: Vector3
		if i == 0:
			t = t0
		elif i == n - 1:
			t = (points[i] - points[i - 1]).normalized()
		else:
			t = ((points[i] - points[i - 1]).normalized() + (points[i + 1] - points[i]).normalized()).normalized()
		if i > 0:
			acc += points[i].distance_to(points[i - 1])
			# Параллельный перенос опорного вектора.
			var axis := prev_t.cross(t)
			if axis.length_squared() > 1e-10:
				u = u.rotated(axis.normalized(), prev_t.angle_to(t))
			u = (u - t * u.dot(t)).normalized()
		prev_t = t
		var v := t.cross(u)
		var r := lerpf(radius, r_end, acc / maxf(total, 0.0001))
		var ring := PackedInt32Array()
		for s in segs:
			var a := float(s) / float(segs) * TAU
			var dir := u * cos(a) + v * sin(a)
			ring.append(add_vertex(points[i] + dir * r, dir, Vector2(a * r, acc)))
		if not prev_ring.is_empty():
			for s in segs:
				var s1 := (s + 1) % segs
				var am := (float(s) + 0.5) / float(segs) * TAU
				var outward := u * cos(am) + v * sin(am)
				tri_out(prev_ring[s], ring[s], ring[s1], outward)
				tri_out(prev_ring[s], ring[s1], prev_ring[s1], outward)
		prev_ring = ring
	if cap:
		add_disc(points[0], -t0, radius, segs)
		add_disc(points[n - 1], (points[n - 1] - points[n - 2]).normalized(), r_end, segs)


## Поверхность-сетка: grid — массив строк PackedVector3Array одинаковой длины. Лицевая сторона смотрит
## по (P[r][c+1] - P[r][c]) × (P[r+1][c] - P[r][c]) (или обратно при flip); double — с изнанкой.
func add_patch(grid: Array, flip: bool = false, double: bool = false) -> void:
	var rows := grid.size()
	if rows < 2:
		return
	var cols := (grid[0] as PackedVector3Array).size()
	var nrm: Array[PackedVector3Array] = []
	for r in rows:
		var row := PackedVector3Array()
		var pr: PackedVector3Array = grid[r]
		var pu: PackedVector3Array = grid[mini(r + 1, rows - 1)]
		var pd: PackedVector3Array = grid[maxi(r - 1, 0)]
		for c in cols:
			var du := pr[mini(c + 1, cols - 1)] - pr[maxi(c - 1, 0)]
			var dv := pu[c] - pd[c]
			var nv := du.cross(dv)
			if flip:
				nv = -nv
			row.append(nv.normalized() if nv.length_squared() > 1e-14 else Vector3.UP)
		nrm.append(row)
	for pass_i in (2 if double else 1):
		var s := 1.0 if pass_i == 0 else -1.0
		var start := verts.size()
		for r in rows:
			var pr: PackedVector3Array = grid[r]
			for c in cols:
				add_vertex(pr[c], nrm[r][c] * s, Vector2(float(c), float(r)))
		for r in rows - 1:
			for c in cols - 1:
				var a := start + r * cols + c
				var b := a + 1
				var d := a + cols
				var e := d + 1
				var f := (nrm[r][c] + nrm[r + 1][c + 1] + nrm[r][c + 1] + nrm[r + 1][c]) * s
				tri_out(a, b, e, f)
				tri_out(a, e, d, f)


## Лента гусеницы: path — замкнутый контур (z, y) внутренней поверхности (обход против часовой
## стрелки, z вправо), от x0 до x1 по ширине, толщина thickness. UV.x — длина по ленте (для траков).
func add_belt(path: PackedVector2Array, x0: float, x1: float, thickness: float) -> void:
	var n := path.size()
	if n < 3:
		return
	var area := 0.0
	for i in n:
		var p := path[i]
		var q := path[(i + 1) % n]
		area += p.x * q.y - q.x * p.y
	var orient := 1.0 if area > 0.0 else -1.0
	var outer := PackedVector2Array()
	var nrm2 := PackedVector2Array()
	for i in n:
		var a := path[(i - 1 + n) % n]
		var b := path[(i + 1) % n]
		var d := (b - a).normalized()
		var out2 := Vector2(d.y, -d.x) * orient
		nrm2.append(out2)
		outer.append(path[i] + out2 * thickness)
	var lens := PackedFloat32Array()
	lens.resize(n + 1)
	for i in range(1, n + 1):
		lens[i] = lens[i - 1] + path[i % n].distance_to(path[i - 1])
	var w := x1 - x0
	var part_uv2 := uv2
	for i in n:
		var j := (i + 1) % n
		var u0 := lens[i]
		var u1 := lens[i + 1]
		var no_i := Vector3(0.0, nrm2[i].y, nrm2[i].x)
		var no_j := Vector3(0.0, nrm2[j].y, nrm2[j].x)
		uv2 = Vector2(1.0, uv2.y)
		# Внешняя поверхность (грунтозацепы).
		var a0 := add_vertex(Vector3(x0, outer[i].y, outer[i].x), no_i, Vector2(u0, 0.0))
		var a1 := add_vertex(Vector3(x1, outer[i].y, outer[i].x), no_i, Vector2(u0, w))
		var b0 := add_vertex(Vector3(x0, outer[j].y, outer[j].x), no_j, Vector2(u1, 0.0))
		var b1 := add_vertex(Vector3(x1, outer[j].y, outer[j].x), no_j, Vector2(u1, w))
		var fo := (no_i + no_j).normalized()
		tri_out(a0, a1, b1, fo)
		tri_out(a0, b1, b0, fo)
		# Внутренняя поверхность (гребни).
		uv2 = Vector2(0.0, uv2.y)
		var c0 := add_vertex(Vector3(x0, path[i].y, path[i].x), -no_i, Vector2(u0, 0.0))
		var c1 := add_vertex(Vector3(x1, path[i].y, path[i].x), -no_i, Vector2(u0, w))
		var d0 := add_vertex(Vector3(x0, path[j].y, path[j].x), -no_j, Vector2(u1, 0.0))
		var d1 := add_vertex(Vector3(x1, path[j].y, path[j].x), -no_j, Vector2(u1, w))
		tri_out(c0, c1, d1, -fo)
		tri_out(c0, d1, d0, -fo)
		# Боковины.
		for side: float in [-1.0, 1.0]:
			var x := x0 if side < 0.0 else x1
			var sn := Vector3(side, 0.0, 0.0)
			var e0 := add_vertex(Vector3(x, path[i].y, path[i].x), sn, Vector2(u0, 0.0))
			var e1 := add_vertex(Vector3(x, outer[i].y, outer[i].x), sn, Vector2(u0, thickness))
			var e2 := add_vertex(Vector3(x, path[j].y, path[j].x), sn, Vector2(u1, 0.0))
			var e3 := add_vertex(Vector3(x, outer[j].y, outer[j].x), sn, Vector2(u1, thickness))
			tri_out(e0, e1, e3, sn)
			tri_out(e0, e3, e2, sn)
	uv2 = part_uv2


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
