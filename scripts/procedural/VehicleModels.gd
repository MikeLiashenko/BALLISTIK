class_name VehicleModels
extends RefCounted
## Процедурные модели техники ПВО, кораблей и боеприпасов. Все модели смотрят вдоль -Z (вперёд), +Y — вверх.
## Наземную ПВО строит GroundModels, катера и корабли — NavalModels (детали из VehicleKit, сборка —
## ModelAsm), самолёты — AircraftBuilder. Здесь — единая точка входа build(), материалы окраски техники
## (шейдер «vehicle») и меши боеприпасов.

static var _paint_cache: Dictionary = {}


## Модель наземной или морской техники: {"root": Node3D, ...узлы и маркеры для механики, "aabb"}.
## Для типа без модели — пустой словарь.
static func build(type_id: String, team: int) -> Dictionary:
	if GroundModels.has_model(type_id):
		return GroundModels.build(type_id, team)
	if NavalModels.has_model(type_id):
		return NavalModels.build(type_id, team)
	push_error("Нет модели техники: " + type_id)
	return {}


static func has_model(type_id: String) -> bool:
	return GroundModels.has_model(type_id) or NavalModels.has_model(type_id)


## Материал окраски по описанию paint (цвета камуфляжа, рисунок, износ, режим корабля/машины).
static func paint_material(type_id: String, team: int, paint: Dictionary) -> ShaderMaterial:
	var key := "%s|%d" % [type_id, team]
	if _paint_cache.has(key):
		return _paint_cache[key]
	var m := ShaderLib.material("vehicle")
	m.set_shader_parameter("camo_a", paint.get("a", Color(0.3, 0.34, 0.24)))
	m.set_shader_parameter("camo_b", paint.get("b", Color(0.36, 0.3, 0.2)))
	m.set_shader_parameter("camo_c", paint.get("c", Color(0.0, 0.0, 0.0)))
	m.set_shader_parameter("id_color", GameDB.team_color(team).lerp(Color(0.8, 0.8, 0.8), 0.15))
	m.set_shader_parameter("pattern", int(paint.get("pattern", 1)))
	m.set_shader_parameter("pattern_scale", float(paint.get("scale", 1.0)))
	m.set_shader_parameter("roughness_base", float(paint.get("rough", 0.72)))
	m.set_shader_parameter("metallic_base", float(paint.get("metal", 0.05)))
	m.set_shader_parameter("wear", float(paint.get("wear", 0.5)))
	m.set_shader_parameter("panel_scale", float(paint.get("panel", 1.0)))
	m.set_shader_parameter("panel_strength", float(paint.get("panel_strength", 0.25)))
	m.set_shader_parameter("rivets", float(paint.get("rivets", 0.0)))
	m.set_shader_parameter("mode", 1 if str(paint.get("mode", "ground")) == "naval" else 0)
	m.set_shader_parameter("dust_color", paint.get("dust_color", Color(0.47, 0.42, 0.33)))
	m.set_shader_parameter("dust_height", float(paint.get("dust_height", 1.1)))
	m.set_shader_parameter("dust_amount", float(paint.get("dust", 0.5)))
	m.set_shader_parameter("waterline", float(paint.get("waterline", 0.0)))
	m.set_shader_parameter("antifoul", paint.get("antifoul", Color(0.42, 0.13, 0.1)))
	m.set_shader_parameter("boot_top", paint.get("boot", Color(0.07, 0.07, 0.08)))
	m.set_shader_parameter("deck_color", paint.get("deck", Color(0.3, 0.31, 0.33)))
	m.set_shader_parameter("rust", float(paint.get("rust", 0.25)))
	m.set_shader_parameter("measure_line", float(paint.get("measure", -1000.0)))
	_paint_cache[key] = m
	return m


# --- Ракеты, торпеды и бомбы (общие меши, также используются снарядами в полёте) ----------------------------
## Расстояние от центра меша боеприпаса до сопла (для факела и дымового следа).
static func missile_tail(kind: String) -> float:
	match kind:
		"sam":
			return 2.8
		"sam_big":
			return 3.7
		"cruise":
			return 2.4
	return 1.5


static func missile_mesh(kind: String) -> Mesh:
	var key := "munition2_" + kind
	var cached := MeshFactory.cached_mesh(key)
	if cached != null:
		return cached
	var k := VehicleKit.new()
	var body_color := Color(0.84, 0.85, 0.82)
	match kind:
		"aam":
			VehicleKit.missile(k.body, k.dark, Vector3(0.0, 0.0, 1.45), 2.9, 0.085, 4, 0.36, 0.12, true)
		"sam":
			VehicleKit.missile(k.body, k.dark, Vector3(0.0, 0.0, 2.75), 5.5, 0.2, 4, 0.95, 0.16)
		"sam_small":
			body_color = Color(0.32, 0.36, 0.27)
			VehicleKit.missile(k.body, k.dark, Vector3(0.0, 0.0, 1.45), 2.9, 0.1, 4, 0.42, 0.14, true)
		"sam_big":
			VehicleKit.missile(k.body, k.dark, Vector3(0.0, 0.0, 3.6), 7.2, 0.26, 4, 1.1, 0.15)
		"cruise":
			VehicleKit.missile(k.body, k.dark, Vector3(0.0, 0.0, 2.3), 4.6, 0.21, 4, 0.55, 0.12)
			k.body.add_prism(PackedVector2Array([Vector2(0.45, -0.018), Vector2(-0.25, -0.018), Vector2(-0.18, 0.018), Vector2(0.42, 0.018)]), 1.05)
		"torpedo":
			body_color = Color(0.24, 0.26, 0.27)
			k.body.xform = VehicleKit.forward_xform(Vector3(0.0, 0.0, 2.75))
			k.body.add_lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, 0.08), Vector2(0.3, 0.2), Vector2(0.65, 0.27), Vector2(5.0, 0.27), Vector2(5.28, 0.22), Vector2(5.44, 0.12), Vector2(5.5, 0.0)]), 16)
			k.body.xform = Transform3D.IDENTITY
			for i in 4:
				var a := float(i) * PI * 0.5
				VehicleKit.box(k.dark, Vector3(cos(a) * 0.2, sin(a) * 0.2, 2.55), Vector3(0.02 + absf(cos(a)) * 0.3, 0.02 + absf(sin(a)) * 0.3, 0.3))
			VehicleKit.cyl(k.dark, Vector3(0.0, 0.0, 2.72), Vector3(0.0, 0.0, 2.84), 0.16, 8)
		"ballistic":
			body_color = Color(0.88, 0.88, 0.86)
			VehicleKit.missile(k.body, k.dark, Vector3(0.0, 0.0, 3.2), 6.4, 0.42, 4, 1.4, 0.26)
			VehicleKit.cyl(k.dark, Vector3(0.0, 0.0, -0.7), Vector3(0.0, 0.0, -1.2), 0.43, 16)
		"rocket":
			body_color = Color(0.5, 0.52, 0.48)
			VehicleKit.missile(k.body, k.dark, Vector3(0.0, 0.0, 0.8), 1.6, 0.065, 4, 0.22, 0.14)
		"bomb":
			body_color = Color(0.3, 0.33, 0.26)
			k.body.xform = VehicleKit.forward_xform(Vector3(0.0, 0.0, 1.25))
			k.body.add_lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, 0.1), Vector2(0.55, 0.27), Vector2(1.45, 0.27), Vector2(2.05, 0.19), Vector2(2.35, 0.06), Vector2(2.4, 0.0)]), 16)
			k.body.xform = Transform3D.IDENTITY
			for i in 4:
				var a := float(i) * PI * 0.5 + PI * 0.25
				VehicleKit.box(k.dark, Vector3(cos(a) * 0.2, sin(a) * 0.2, 1.1), Vector3(0.02 + absf(cos(a)) * 0.22, 0.02 + absf(sin(a)) * 0.22, 0.42))
		"shell":
			body_color = Color(0.22, 0.22, 0.2)
			k.body.xform = VehicleKit.forward_xform(Vector3(0.0, 0.0, 0.55))
			k.body.add_lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, 0.14), Vector2(0.7, 0.16), Vector2(0.95, 0.1), Vector2(1.15, 0.0)]), 12)
			k.body.xform = Transform3D.IDENTITY
	var mesh := k.commit(MeshFactory.mat(body_color, 0.45, 0.25))
	MeshFactory.store_mesh(key, mesh)
	return mesh
