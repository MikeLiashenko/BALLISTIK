class_name Vegetation
extends Node3D
## Растительность карты: леса по маске рельефа, одиночные деревья на лугах, пальмы у воды, кусты.
## Расстановка — в фоновых потоках (детерминированный хеш-генератор, чистая математика): для каждого
## чанка сразу собираются буферы MultiMesh. Два уровня детализации переключаются по дальности.

const LOD_RANGES := [[500.0, 1500.0], [800.0, 2600.0], [1200.0, 3800.0], [1700.0, 5200.0]]
const DENSITY := [420.0, 950.0, 1700.0, 2400.0]   ## деревьев на км² при маске леса = 1
const KINDS: Array[String] = ["broadleaf", "pine", "palm", "cypress", "bush"]


## План расстановки (без сцены). Возвращает {"chunks": [{"center", "kinds": {kind: PackedFloat32Array}}]}.
static func plan(terrain: Terrain, quality: int, seed_value: int) -> Dictionary:
	var layout := terrain.layout
	var q := clampi(quality, 0, 3)
	var trees: Dictionary = layout.preset.get("trees", {})
	var kinds: Array = trees.get("kinds", ["broadleaf"])
	var density: float = float(DENSITY[q]) * float(trees.get("density", 1.0))
	var extent := minf(layout.bounds + LOD_RANGES[q][1], terrain.half_size - 200.0)
	var chunk_count: int = [6, 10, 14, 18][q]
	var size := extent * 2.0 / float(chunk_count)
	var jobs: Array = []
	for cz in chunk_count:
		for cx in chunk_count:
			jobs.append(Vector2i(cx, cz))
	var params := {
		"half": terrain.half_size, "cell": terrain.cell, "res": terrain.resolution, "extent": extent, "size": size,
		"density": density, "kinds": kinds, "treeline": float(trees.get("treeline", 450.0)), "seed": seed_value,
		"biome": str(layout.preset.get("biome", "temperate")),
	}
	var n := clampi(OS.get_processor_count() - 1, 1, 8)
	var per := ceili(float(jobs.size()) / float(n))
	var threads: Array[Thread] = []
	var chunks: Array = []
	for t in n:
		var j0 := t * per
		var j1 := mini(jobs.size(), j0 + per)
		if j0 >= j1:
			break
		var th := Thread.new()
		th.start(_plan_range.bind(jobs.slice(j0, j1), params, terrain.heights, terrain.masks))
		threads.append(th)
	for th in threads:
		chunks.append_array(th.wait_to_finish())
	return {"chunks": chunks, "quality": q}


static func _plan_range(jobs: Array, params: Dictionary, h: PackedFloat32Array, m: PackedByteArray) -> Array:
	var out: Array = []
	var half: float = params["half"]
	var cell: float = params["cell"]
	var res: int = params["res"]
	var extent: float = params["extent"]
	var size: float = params["size"]
	var density: float = params["density"]
	var kinds: Array = params["kinds"]
	var treeline: float = params["treeline"]
	var biome: String = params["biome"]
	var n1 := res + 1
	for job: Vector2i in jobs:
		var x0 := -extent + float(job.x) * size
		var z0 := -extent + float(job.y) * size
		var center := Vector3(x0 + size * 0.5, 0.0, z0 + size * 0.5)
		var state := int(params["seed"]) * 7919 + job.x * 104729 + job.y * 1299709 + 17
		var attempts := int(size * size / 1.0e6 * density * 1.1)
		var entries := PackedFloat32Array()
		for a in attempts:
			state = _next(state)
			var x := x0 + _unit(state) * size
			state = _next(state)
			var z := z0 + _unit(state) * size
			var gx := clampf((x + half) / cell, 0.0, float(res) - 0.001)
			var gz := clampf((z + half) / cell, 0.0, float(res) - 0.001)
			var ix := int(gx)
			var iz := int(gz)
			var fx := gx - float(ix)
			var fz := gz - float(iz)
			var i00 := iz * n1 + ix
			var h00 := h[i00]
			var h10 := h[i00 + 1]
			var h01 := h[i00 + n1]
			var h11 := h[i00 + n1 + 1]
			var y := h00 + (h10 - h00) * fx + (h11 - h10) * fz if fx >= fz else h00 + (h11 - h01) * fx + (h01 - h00) * fz
			if y < 3.0 or y > treeline + 40.0:
				continue
			var ny := 2.0 * cell / sqrt((h00 - h10) * (h00 - h10) * 4.0 + 4.0 * cell * cell + (h00 - h01) * (h00 - h01) * 4.0)
			if ny < 0.8:
				continue
			var mi := i00 * 4
			var forest := float(m[mi]) / 255.0
			if m[mi + 3] > 60 or m[mi + 1] > 110:
				continue
			state = _next(state)
			if _unit(state) > clampf(forest * 1.1 + 0.02, 0.0, 1.0):
				continue
			state = _next(state)
			var r := _unit(state)
			var kind := _pick_kind(biome, kinds, y, forest, r)
			state = _next(state)
			var s := lerpf(0.85, 1.55, _unit(state)) * float(TreeMeshes.KIND_SCALE.get(kind, 1.0))
			var sy := s * lerpf(0.88, 1.18, r)
			state = _next(state)
			var rot := _unit(state) * TAU
			state = _next(state)
			var tint := 0.86 + 0.28 * _unit(state)
			var cs := cos(rot) * s
			var sn := sin(rot) * s
			entries.append_array(PackedFloat32Array([float(KINDS.find(kind)), cs, 0.0, sn, x - center.x, 0.0, sy, 0.0, y - 0.25, -sn, 0.0, cs, z - center.z, tint * lerpf(0.94, 1.06, r), tint, tint * lerpf(1.04, 0.92, r), 1.0]))
		if entries.is_empty():
			continue
		# Раскладка по видам (локальные массивы — дописываются на месте, без копирования).
		var bufs: Dictionary = {}
		for k in KINDS.size():
			var buf := PackedFloat32Array()
			var e := 0
			while e < entries.size():
				if int(entries[e]) == k:
					buf.append_array(entries.slice(e + 1, e + 17))
				e += 17
			if not buf.is_empty():
				bufs[KINDS[k]] = buf
		out.append({"center": center, "kinds": bufs})
	return out


static func _pick_kind(biome: String, kinds: Array, y: float, forest: float, r: float) -> String:
	match biome:
		"temperate":
			if forest < 0.45 and r < 0.18:
				return "bush"
			return "pine" if y > 240.0 + r * 140.0 or r < 0.22 else "broadleaf"
		"tropical":
			if y < 45.0 or r < 0.45:
				return "palm"
			return "broadleaf" if r < 0.85 else "bush"
		"desert":
			return "palm" if y < 26.0 and r < 0.6 else "bush"
		"arctic":
			return "bush" if y > 300.0 and r < 0.3 else "pine"
		"mediterranean":
			if r < 0.2:
				return "bush"
			return "cypress" if r < 0.55 else "broadleaf"
	return str(kinds[int(r * kinds.size()) % kinds.size()])


static func _next(s: int) -> int:
	return (s * 6364136223846793005 + 1442695040888963407) & 0x7FFFFFFFFFFFFFFF


static func _unit(s: int) -> float:
	return float((s >> 31) & 0xFFFFFF) / 16777216.0


## Создаёт MultiMesh-узлы по плану (основной поток).
func build(plan_data: Dictionary, layout: MapLayout) -> void:
	name = "Vegetation"
	var biome := MapPresets.biome(layout.map_id)
	var ranges: Array = LOD_RANGES[int(plan_data["quality"])]
	for chunk: Dictionary in plan_data["chunks"]:
		var center: Vector3 = chunk["center"]
		var kinds: Dictionary = chunk["kinds"]
		for kind: String in kinds.keys():
			var buf: PackedFloat32Array = kinds[kind]
			var count := buf.size() / 16
			if count <= 0:
				continue
			for lod in 2:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.use_custom_data = true
				mm.mesh = TreeMeshes.get_mesh(kind, lod, biome)
				mm.instance_count = count
				mm.buffer = buf
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.position = center
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.visibility_range_begin = 0.0 if lod == 0 else float(ranges[0])
				mmi.visibility_range_end = float(ranges[0]) if lod == 0 else float(ranges[1])
				mmi.visibility_range_begin_margin = 0.0 if lod == 0 else 60.0
				mmi.visibility_range_end_margin = 60.0
				add_child(mmi)
