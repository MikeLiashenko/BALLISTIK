class_name TreeMeshes
extends RefCounted
## Процедурные деревья двух уровней детализации: лиственное (кроны из «клубов»), ель (ярусы
## со звёздчатым краем), пальма (изогнутый ствол, перистые листья), кипарис, куст. Цвета — в вершинах
## (затенение низа кроны), альфа вершины — гибкость для колыхания ветром в шейдере листвы.

const KIND_SCALE := {"broadleaf": 1.0, "pine": 1.05, "palm": 1.0, "cypress": 1.0, "bush": 1.0}

static var _cache: Dictionary = {}
static var _material: ShaderMaterial = null


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderLib.material("foliage")
	return _material


static func get_mesh(kind: String, lod: int, biome: Dictionary) -> ArrayMesh:
	var trees: Dictionary = biome.get("trees", {})
	var leaf: Color = trees.get(kind, Color(0.2, 0.3, 0.12))
	var trunk: Color = biome.get("trunk", Color(0.3, 0.23, 0.17))
	var key := "%s|%d|%s|%s" % [kind, lod, leaf.to_html(), trunk.to_html()]
	if _cache.has(key):
		return _cache[key]
	var k := MeshKit.new()
	match kind:
		"pine":
			_pine(k, lod, leaf, trunk)
		"palm":
			_palm(k, lod, leaf, trunk)
		"cypress":
			_cypress(k, lod, leaf, trunk)
		"bush":
			_bush(k, lod, leaf)
		_:
			_broadleaf(k, lod, leaf, trunk)
	var mesh := k.commit(null, material())
	_cache[key] = mesh
	return mesh


static func _flex(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


static func _broadleaf(k: MeshKit, lod: int, leaf: Color, trunk: Color) -> void:
	k.add_cylinder(Vector3.ZERO, -0.4, 4.4, 0.34, 0.2, 6 if lod == 0 else 4, _flex(trunk * 0.8, 0.05), _flex(trunk, 0.2))
	var dark := _flex(leaf * 0.5, 1.0)
	var light := _flex(leaf * 1.18, 1.0)
	if lod == 0:
		var blobs := [
			[Vector3(0.0, 7.3, 0.0), Vector3(3.3, 2.8, 3.2)],
			[Vector3(1.6, 6.1, 0.8), Vector3(2.4, 2.0, 2.3)],
			[Vector3(-1.5, 6.4, -0.9), Vector3(2.5, 2.1, 2.2)],
			[Vector3(0.3, 9.1, -0.4), Vector3(2.3, 1.9, 2.2)],
			[Vector3(-0.6, 5.7, 1.6), Vector3(2.0, 1.7, 1.9)],
		]
		for i in blobs.size():
			var b: Array = blobs[i]
			k.add_blob(b[0], b[1], 1, 0.16, i * 7 + 3, dark, light)
	else:
		k.add_blob(Vector3(0.0, 7.2, 0.0), Vector3(3.8, 3.4, 3.6), 0, 0.1, 5, dark, light)


static func _pine(k: MeshKit, lod: int, leaf: Color, trunk: Color) -> void:
	k.add_cylinder(Vector3.ZERO, -0.4, 14.5, 0.3, 0.06, 6 if lod == 0 else 4, _flex(trunk * 0.75, 0.05), _flex(trunk, 0.4))
	var dark := _flex(leaf * 0.55, 1.0)
	var light := _flex(leaf * 1.2, 1.0)
	if lod == 0:
		var tiers := [[2.2, 4.4, 3.3], [4.8, 3.9, 2.85], [7.1, 3.5, 2.4], [9.2, 3.1, 1.95], [11.1, 2.7, 1.45], [12.8, 2.9, 0.95]]
		for t: Array in tiers:
			k.add_spiky_cone(Vector3.ZERO, t[0], t[1], t[2], 12, dark, light)
	else:
		k.add_spiky_cone(Vector3.ZERO, 2.2, 7.5, 3.2, 6, dark, light)
		k.add_spiky_cone(Vector3.ZERO, 7.6, 7.0, 2.0, 6, dark, light)


static func _cypress(k: MeshKit, lod: int, leaf: Color, trunk: Color) -> void:
	k.add_cylinder(Vector3.ZERO, -0.3, 1.8, 0.22, 0.16, 5 if lod == 0 else 4, _flex(trunk, 0.05), _flex(trunk, 0.1))
	k.add_blob(Vector3(0.0, 6.4, 0.0), Vector3(1.35, 5.6, 1.35), 1 if lod == 0 else 0, 0.13, 11, _flex(leaf * 0.55, 0.8), _flex(leaf * 1.15, 1.0))


static func _bush(k: MeshKit, lod: int, leaf: Color) -> void:
	var dark := _flex(leaf * 0.55, 0.5)
	var light := _flex(leaf * 1.15, 0.7)
	if lod == 0:
		k.add_blob(Vector3(0.0, 0.8, 0.0), Vector3(1.4, 1.0, 1.3), 1, 0.18, 1, dark, light)
		k.add_blob(Vector3(0.9, 0.6, 0.4), Vector3(1.0, 0.8, 1.0), 1, 0.18, 2, dark, light)
		k.add_blob(Vector3(-0.8, 0.55, -0.3), Vector3(0.9, 0.7, 0.9), 1, 0.18, 3, dark, light)
	else:
		k.add_blob(Vector3(0.0, 0.8, 0.0), Vector3(1.8, 1.1, 1.6), 0, 0.1, 1, dark, light)


static func _palm(k: MeshKit, lod: int, leaf: Color, trunk: Color) -> void:
	var rings := 8 if lod == 0 else 4
	var sides := 6 if lod == 0 else 4
	var height := 11.0
	var bend := 1.6
	var start := k.vertex_count()
	for r in rings + 1:
		var t := float(r) / float(rings)
		var y := t * height - 0.3
		var cx := bend * t * t
		var rad := lerpf(0.26, 0.16, t)
		var band := 0.85 + 0.2 * float(r % 2)
		for s in sides:
			var a := float(s) / float(sides) * TAU
			var n := Vector3(cos(a), 0.0, sin(a))
			k.add_vertex(Vector3(cx + cos(a) * rad, y, sin(a) * rad), n, Vector2.ZERO, _flex(trunk * band, 0.08 + 0.3 * t))
	k.grid(start, rings + 1, sides, true, false)
	var crown := Vector3(bend, height - 0.3, 0.0)
	var fronds := 9 if lod == 0 else 5
	var segs := 7 if lod == 0 else 3
	for f in fronds:
		var ang := float(f) / float(fronds) * TAU + 0.3 * sin(float(f) * 2.3)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var length := 5.2 + 0.8 * sin(float(f) * 1.7)
		var tilt := 0.55 + 0.25 * cos(float(f) * 3.1)
		var col_base := _flex(leaf * 0.8, 1.0)
		var col_tip := _flex(leaf.lerp(Color(0.62, 0.6, 0.28), 0.35), 1.0)
		var prev: Array[int] = []
		for s in segs + 1:
			var t := float(s) / float(segs)
			var p := crown + dir * length * t + Vector3.UP * (tilt * length * t - 0.9 * length * t * t)
			var w := 1.05 * pow(sin(PI * clampf(t * 0.95 + 0.05, 0.0, 1.0)), 0.8)
			var c := col_base.lerp(col_tip, t)
			var up := Vector3.UP
			var mid := k.add_vertex(p, up, Vector2.ZERO, c)
			var left := k.add_vertex(p + side * w - Vector3.UP * w * 0.3, (up + side * 0.3).normalized(), Vector2.ZERO, c * 0.92)
			var right := k.add_vertex(p - side * w - Vector3.UP * w * 0.3, (up - side * 0.3).normalized(), Vector2.ZERO, c * 0.92)
			if not prev.is_empty():
				k.quad(prev[0], mid, left, prev[1])
				k.quad(prev[0], prev[2], right, mid)
			prev = [mid, left, right]
