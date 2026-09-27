class_name TerrainMeshBuilder
extends RefCounted
## Подготовка данных мешей рельефа (без обращения к сцене — можно в фоновых потоках).
## Рельеф режется на квадратные чанки; для каждого строится до 4 уровней детализации (LOD):
## LOD0 — полная сетка высот (совпадает с физикой), каждый следующий — вдвое реже. Щели между
## соседними чанками разного LOD скрываются «юбками» — вертикальными полосами вниз по краю.
## Сборка — чистая математика GDScript (упакованные массивы), поэтому хорошо масштабируется по потокам.

const SKIRT_DEPTH := 45.0

var resolution: int = 512
var half: float = 13000.0
var cell: float = 50.0
var chunks: int = 8
var cells_per_chunk: int = 64
var lods: int = 4
var heights := PackedFloat32Array()
var masks := PackedByteArray()
## Индексы треугольников для каждого LOD (одинаковы для всех чанков).
var lod_indices: Array[PackedInt32Array] = []


func _init(terrain: Terrain, p_chunks: int, p_lods: int) -> void:
	resolution = terrain.resolution
	half = terrain.half_size
	cell = terrain.cell
	chunks = p_chunks
	cells_per_chunk = resolution / chunks
	lods = clampi(p_lods, 1, 5)
	while lods > 1 and (cells_per_chunk >> (lods - 1)) < 4:
		lods -= 1
	heights = terrain.heights
	masks = terrain.masks
	for lod in lods:
		lod_indices.append(_build_indices(cells_per_chunk >> lod))


func chunk_size() -> float:
	return cell * float(cells_per_chunk)


func chunk_center(cx: int, cz: int) -> Vector3:
	var s := chunk_size()
	return Vector3(-half + (float(cx) + 0.5) * s, 0.0, -half + (float(cz) + 0.5) * s)


## Все чанки всех LOD. Возвращает массив словарей {cx, cz, lod, center, verts, normals, colors}.
func build_all(max_threads: int = 8) -> Array:
	var jobs: Array[Vector3i] = []
	for cz in chunks:
		for cx in chunks:
			for lod in lods:
				jobs.append(Vector3i(cx, cz, lod))
	var n := clampi(OS.get_processor_count() - 1, 1, max_threads)
	var per := ceili(float(jobs.size()) / float(n))
	var threads: Array[Thread] = []
	var results: Array = []
	for t in n:
		var j0 := t * per
		var j1 := mini(jobs.size(), j0 + per)
		if j0 >= j1:
			break
		var th := Thread.new()
		th.start(_build_range.bind(jobs.slice(j0, j1), heights, masks))
		threads.append(th)
	for th in threads:
		results.append_array(th.wait_to_finish())
	return results


func _build_range(jobs: Array, h: PackedFloat32Array, m: PackedByteArray) -> Array:
	var out: Array = []
	for job: Vector3i in jobs:
		out.append(build_chunk(job.x, job.y, job.z, h, m))
	return out


func build_chunk(cx: int, cz: int, lod: int, h: PackedFloat32Array, m: PackedByteArray) -> Dictionary:
	var step := 1 << lod
	var seg := cells_per_chunk >> lod
	var side := seg + 1
	var n1 := resolution + 1
	var ix0 := cx * cells_per_chunk
	var iz0 := cz * cells_per_chunk
	var center := chunk_center(cx, cz)
	var count := side * side + side * 4
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(count)
	normals.resize(count)
	colors.resize(count)
	var k := 0
	var inv := 1.0 / 255.0
	for j in side:
		var iz := iz0 + j * step
		var izm := maxi(iz - step, 0)
		var izp := mini(iz + step, resolution)
		for i in side:
			var ix := ix0 + i * step
			var gi := iz * n1 + ix
			verts[k] = Vector3(-half + float(ix) * cell - center.x, h[gi], -half + float(iz) * cell - center.z)
			var hl := h[iz * n1 + maxi(ix - step, 0)]
			var hr := h[iz * n1 + mini(ix + step, resolution)]
			var hd := h[izm * n1 + ix]
			var hu := h[izp * n1 + ix]
			normals[k] = Vector3(hl - hr, 2.0 * cell * float(step), hd - hu).normalized()
			var mi := gi * 4
			colors[k] = Color(m[mi] * inv, m[mi + 1] * inv, m[mi + 2] * inv, m[mi + 3] * inv)
			k += 1
	# Юбки: копии краевых вершин, опущенные вниз (порядок: верх, низ, лево, право).
	var edges: Array[PackedInt32Array] = _edge_lists(side)
	for e in edges:
		for src in e:
			verts[k] = verts[src] - Vector3(0.0, SKIRT_DEPTH, 0.0)
			normals[k] = normals[src]
			colors[k] = colors[src]
			k += 1
	return {"cx": cx, "cz": cz, "lod": lod, "center": center, "verts": verts, "normals": normals, "colors": colors}


func _edge_lists(side: int) -> Array[PackedInt32Array]:
	var top := PackedInt32Array()
	var bottom := PackedInt32Array()
	var left := PackedInt32Array()
	var right := PackedInt32Array()
	for i in side:
		top.append(i)
		bottom.append((side - 1) * side + i)
		left.append(i * side)
		right.append(i * side + side - 1)
	return [top, bottom, left, right]


func _build_indices(seg: int) -> PackedInt32Array:
	var side := seg + 1
	var idx := PackedInt32Array()
	idx.resize(seg * seg * 6 + 4 * seg * 12)
	var k := 0
	for j in seg:
		for i in seg:
			var i00 := j * side + i
			var i10 := i00 + 1
			var i01 := i00 + side
			var i11 := i01 + 1
			idx[k] = i00
			idx[k + 1] = i10
			idx[k + 2] = i11
			idx[k + 3] = i00
			idx[k + 4] = i11
			idx[k + 5] = i01
			k += 6
	var base := side * side
	var edges := _edge_lists(side)
	for e in edges.size():
		var list: PackedInt32Array = edges[e]
		var s0 := base + e * side
		for i in seg:
			var a := list[i]
			var b := list[i + 1]
			var sa := s0 + i
			var sb := s0 + i + 1
			# Двусторонняя полоса: видна с обеих сторон независимо от ориентации края.
			for tri: PackedInt32Array in [PackedInt32Array([a, b, sb]), PackedInt32Array([a, sb, sa]), PackedInt32Array([a, sb, b]), PackedInt32Array([a, sa, sb])]:
				idx[k] = tri[0]
				idx[k + 1] = tri[1]
				idx[k + 2] = tri[2]
				k += 3
	return idx
