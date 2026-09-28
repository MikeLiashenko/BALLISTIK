class_name VehicleKit
extends RefCounted
## Меш одной детали техники, разложенный по материалам (комплекты MeshKit), и библиотека типовых
## узлов для процедурных моделей ПВО и кораблей: опорные катки, ведущие колёса и ленивцы, гусеничные
## ленты (по выпуклой оболочке катков), колёса с шинами, стволы с дульными тормозами, параболические
## антенны, решётчатые мачты, леера, ракеты, люки, фары, фигуры расчёта.
## Ось X — вправо, Y — вверх, -Z — вперёд; размеры в метрах.

## Части окраски корпуса (UV2.y в шейдере «vehicle»).
const P_HULL := 0.0
const P_UPPER := 1.0
const P_DECK := 2.0
const P_PLAIN := 3.0
const P_INTERIOR := 4.0
const P_ID := 5.0
const P_SOOT := 6.0
const P_WHITE := 7.0

var body := MeshKit.new()    ## Окрашенные поверхности (камуфляж)
var dark := MeshKit.new()    ## Резина, уплотнения, решётки, тёмный металл
var metal := MeshKit.new()   ## Светлый металл без краски
var gun := MeshKit.new()     ## Воронёная сталь стволов
var glass := MeshKit.new()   ## Стёкла, оптика
var tire := MeshKit.new()    ## Шины (протектор)
var track := MeshKit.new()   ## Гусеничные ленты (траки)
var lamp := MeshKit.new()    ## Фары и огни
var cloth := MeshKit.new()   ## Брезент, мешки с песком, обмундирование

static var _mats: Dictionary = {}


func all() -> Array[MeshKit]:
	return [body, dark, metal, gun, glass, tire, track, lamp, cloth]


func set_xform(t: Transform3D) -> void:
	for k in all():
		k.xform = t


func reset_xform() -> void:
	set_xform(Transform3D.IDENTITY)


## Часть окраски для последующей геометрии комплекта body.
func part(p: float) -> void:
	body.uv2 = Vector2(0.0, p)


func is_empty() -> bool:
	for k in all():
		if not k.is_empty():
			return false
	return true


## Собирает ArrayMesh: поверхность на каждый непустой комплект. Индекс поверхности корпуса — в мета
## «body_surface» (для подмены материала окраски другой команды).
func commit(body_mat: Material) -> ArrayMesh:
	var am := ArrayMesh.new()
	var mats: Array[Material] = [body_mat, dark_mat(), metal_mat(), gun_mat(), glass_mat(), tire_mat(), track_mat(), lamp_mat(), cloth_mat()]
	var kits := all()
	for i in kits.size():
		if kits[i].is_empty():
			continue
		kits[i].commit(am, mats[i])
		if i == 0:
			am.set_meta("body_surface", am.get_surface_count() - 1)
	return am


# --- Материалы -----------------------------------------------------------------------------------------
static func dark_mat() -> Material:
	return MeshFactory.mat(Color(0.075, 0.078, 0.08), 0.62, 0.3)


static func metal_mat() -> Material:
	return MeshFactory.mat(Color(0.42, 0.41, 0.39), 0.4, 0.8)


static func gun_mat() -> Material:
	return MeshFactory.mat(Color(0.13, 0.135, 0.14), 0.36, 0.75)


static func cloth_mat() -> Material:
	return MeshFactory.mat(Color(0.44, 0.41, 0.31), 0.96, 0.0)


static func lamp_mat() -> Material:
	return MeshFactory.mat(Color(0.92, 0.9, 0.82), 0.08, 0.2, 0.35)


static func glass_mat() -> Material:
	if _mats.has("glass"):
		return _mats["glass"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.06, 0.09, 0.11)
	m.roughness = 0.05
	m.metallic = 0.6
	m.metallic_specular = 0.9
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.7
	_mats["glass"] = m
	return m


static func tire_mat() -> Material:
	if _mats.has("tire"):
		return _mats["tire"]
	var m := ShaderLib.material("rubber")
	m.set_shader_parameter("kind", 1)
	m.set_shader_parameter("pitch", 0.2)
	m.set_shader_parameter("width", 0.62)
	m.set_shader_parameter("dust", 0.35)
	_mats["tire"] = m
	return m


static func track_mat() -> Material:
	if _mats.has("track"):
		return _mats["track"]
	var m := ShaderLib.material("rubber")
	m.set_shader_parameter("kind", 0)
	m.set_shader_parameter("pitch", 0.16)
	m.set_shader_parameter("width", 0.5)
	m.set_shader_parameter("dust", 0.4)
	_mats["track"] = m
	return m


# --- Преобразования ------------------------------------------------------------------------------------------
## Базис, у которого ось Y направлена вдоль dir (для тел вращения по произвольной оси).
static func basis_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y)
	return Basis(x, y, z)


## Ось вращения колеса вдоль X, внешняя сторона — side (+1 справа, -1 слева).
static func wheel_xform(center: Vector3, side: float) -> Transform3D:
	return Transform3D(Basis(Vector3(0.0, 0.0, 1.0), -PI * 0.5 * signf(side if side != 0.0 else 1.0)), center)


## Ось тела вращения вдоль -Z (стволы, ракеты) от точки start.
static func forward_xform(start: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3(1.0, 0.0, 0.0), -PI * 0.5), start)


# --- Простые формы -------------------------------------------------------------------------------------------
static func box(kit: MeshKit, center: Vector3, size: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var old := kit.xform
	kit.xform = old * MeshFactory.xf(center, rot_deg)
	kit.add_box(Vector3.ZERO, size)
	kit.xform = old


## Цилиндр между точками a и b (с торцами).
static func cyl(kit: MeshKit, a: Vector3, b: Vector3, r: float, segs: int = 12, caps: bool = true, r_b: float = -1.0) -> void:
	var d := b - a
	var L := d.length()
	if L < 1e-5:
		return
	var old := kit.xform
	kit.xform = old * Transform3D(basis_y(d), a)
	kit.add_lathe(PackedVector2Array([Vector2(0.0, r), Vector2(L, r if r_b < 0.0 else r_b)]), segs, caps, caps, 40.0)
	kit.xform = old


## Брусок со скошенными продольными рёбрами (вдоль X): center, size, chamfer — размер фаски.
static func cbox(kit: MeshKit, center: Vector3, size: Vector3, chamfer: float, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var hz := size.z * 0.5
	var hy := size.y * 0.5
	var c := minf(chamfer, minf(hz, hy) * 0.95)
	var prof := PackedVector2Array([
		Vector2(-hz + c, -hy), Vector2(hz - c, -hy), Vector2(hz, -hy + c), Vector2(hz, hy - c),
		Vector2(hz - c, hy), Vector2(-hz + c, hy), Vector2(-hz, hy - c), Vector2(-hz, -hy + c),
	])
	var old := kit.xform
	kit.xform = old * MeshFactory.xf(center, rot_deg)
	kit.add_prism(prof, size.x * 0.5)
	kit.xform = old


## Скруглённый профиль-прямоугольник для add_prism/add_block: w×h, радиус скругления r.
static func rounded_rect(w: float, h: float, r: float, steps: int = 3, cx: float = 0.0, cy: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var hw := w * 0.5
	var hh := h * 0.5
	var rr := minf(r, minf(hw, hh))
	var corners := [Vector2(hw - rr, -hh + rr), Vector2(hw - rr, hh - rr), Vector2(-hw + rr, hh - rr), Vector2(-hw + rr, -hh + rr)]
	var start_angles := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for i in 4:
		var cc: Vector2 = corners[i]
		for s in steps + 1:
			var a: float = float(start_angles[i]) + float(s) / float(steps) * PI * 0.5
			pts.append(Vector2(cx, cy) + cc + Vector2(cos(a), sin(a)) * rr)
	return pts


## Многоугольник-план с фасками на углах (надстройки): прямоугольник w×d, фаски c (x — ширина, y — длина).
static func chamfer_rect(w: float, d: float, c: float, cz: float = 0.0, cx: float = 0.0) -> PackedVector2Array:
	var hw := w * 0.5
	var hd := d * 0.5
	var k := minf(c, minf(hw, hd) * 0.9)
	return PackedVector2Array([
		Vector2(cx - hw + k, cz - hd), Vector2(cx + hw - k, cz - hd), Vector2(cx + hw, cz - hd + k), Vector2(cx + hw, cz + hd - k),
		Vector2(cx + hw - k, cz + hd), Vector2(cx - hw + k, cz + hd), Vector2(cx - hw, cz + hd - k), Vector2(cx - hw, cz - hd + k),
	])


# --- Ходовая часть -------------------------------------------------------------------------------------------
## Опорный каток: окрашенный диск со ступицей и резиновым бандажом. side — внешняя сторона (±1).
static func road_wheel(k: VehicleKit, c: Vector3, r: float, w: float, side: float, spokes: int = 0) -> void:
	var hw := w * 0.5
	var xf := wheel_xform(c, side)
	var od := k.dark.xform
	k.dark.xform = od * xf
	k.dark.add_lathe(PackedVector2Array([Vector2(-hw, r * 0.82), Vector2(-hw, r * 0.96), Vector2(-hw * 0.88, r), Vector2(hw * 0.88, r), Vector2(hw, r * 0.96), Vector2(hw, r * 0.82)]), 22, false, false, 40.0)
	k.dark.xform = od
	var ob := k.body.xform
	k.body.xform = ob * xf
	var old_part := k.body.uv2
	k.body.uv2 = Vector2(0.0, P_PLAIN)
	k.body.add_lathe(PackedVector2Array([
		Vector2(-hw * 0.7, 0.0), Vector2(-hw * 0.7, r * 0.3), Vector2(-hw * 0.84, r * 0.83), Vector2(hw * 0.84, r * 0.83),
		Vector2(hw * 0.62, r * 0.62), Vector2(hw * 0.5, r * 0.36), Vector2(hw * 0.95, r * 0.24), Vector2(hw * 0.95, 0.0),
	]), 20, false, false, 30.0)
	k.body.uv2 = old_part
	k.body.xform = ob
	# Болты ступицы и отверстия облегчения.
	for i in 6:
		var a := float(i) / 6.0 * TAU
		var p := c + Vector3(side * hw * 0.98, cos(a) * r * 0.16, sin(a) * r * 0.16)
		box(k.metal, p, Vector3(0.03, r * 0.05, r * 0.05))
	if spokes > 0:
		for i in spokes:
			var a := (float(i) + 0.5) / float(spokes) * TAU
			var p := c + Vector3(side * hw * 0.58, cos(a) * r * 0.5, sin(a) * r * 0.5)
			k.dark.add_disc(p, Vector3(side, 0.0, 0.0), r * 0.1, 8)


## Ведущее колесо (звёздочка): диск со ступицей и два венца зубьев.
static func sprocket(k: VehicleKit, c: Vector3, r: float, w: float, side: float, teeth: int = 13) -> void:
	var hw := w * 0.5
	var xf := wheel_xform(c, side)
	var ob := k.body.xform
	k.body.xform = ob * xf
	var old_part := k.body.uv2
	k.body.uv2 = Vector2(0.0, P_PLAIN)
	k.body.add_lathe(PackedVector2Array([
		Vector2(-hw * 0.8, 0.0), Vector2(-hw * 0.8, r * 0.4), Vector2(-hw * 0.5, r * 0.82), Vector2(hw * 0.5, r * 0.82),
		Vector2(hw * 0.7, r * 0.45), Vector2(hw * 1.05, r * 0.3), Vector2(hw * 1.05, 0.0),
	]), 20, false, false, 30.0)
	k.body.uv2 = old_part
	k.body.xform = ob
	for ring: float in [-0.32, 0.32]:
		for i in teeth:
			var a := float(i) / float(teeth) * TAU
			var p := c + Vector3(side * hw * ring, cos(a) * r * 0.9, sin(a) * r * 0.9)
			var old := k.metal.xform
			k.metal.xform = old * Transform3D(Basis(Vector3(1.0, 0.0, 0.0), -a), p)
			k.metal.add_box(Vector3.ZERO, Vector3(hw * 0.5, r * 0.22, r * 0.2))
			k.metal.xform = old
	for i in 6:
		var a := float(i) / 6.0 * TAU
		box(k.metal, c + Vector3(side * hw * 1.07, cos(a) * r * 0.2, sin(a) * r * 0.2), Vector3(0.03, r * 0.06, r * 0.06))


## Поддерживающий каток / небольшой ролик.
static func roller(k: VehicleKit, c: Vector3, r: float, w: float, side: float) -> void:
	var hw := w * 0.5
	var od := k.dark.xform
	k.dark.xform = od * wheel_xform(c, side)
	k.dark.add_lathe(PackedVector2Array([Vector2(-hw, 0.0), Vector2(-hw, r * 0.9), Vector2(-hw * 0.8, r), Vector2(hw * 0.8, r), Vector2(hw, r * 0.9), Vector2(hw, r * 0.3), Vector2(hw * 1.3, r * 0.25), Vector2(hw * 1.3, 0.0)]), 14, false, false, 40.0)
	k.dark.xform = od


## Гусеничная лента вокруг колёс: circles — массив Vector3(z, y, r) (ведущее, ленивец, катки, ролики).
## Лента проходит по выпуклой оболочке окружностей; траки рисует шейдер.
static func track_belt(k: VehicleKit, x_center: float, width: float, circles: Array, thickness: float = 0.07) -> void:
	var pts := PackedVector2Array()
	for c: Vector3 in circles:
		var n := 28 if c.z > 0.3 else 18
		for i in n:
			var a := float(i) / float(n) * TAU
			pts.append(Vector2(c.x + cos(a) * c.z, c.y + sin(a) * c.z))
	var hull := Geometry2D.convex_hull(pts)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.remove_at(hull.size() - 1)
	# Длинные прямые участки дробятся, чтобы тень и освещение ложились ровно.
	var dense := PackedVector2Array()
	for i in hull.size():
		var a := hull[i]
		var b := hull[(i + 1) % hull.size()]
		dense.append(a)
		var steps := int(a.distance_to(b) / 0.6)
		for s in range(1, steps):
			dense.append(a.lerp(b, float(s) / float(steps)))
	k.track.add_belt(dense, x_center - width * 0.5, x_center + width * 0.5, thickness)


## Колесо машины: шина с протектором и диск со ступицей. side — внешняя сторона (±1).
static func wheel(k: VehicleKit, c: Vector3, r: float, w: float, side: float, rim_k: float = 0.58, hub_boss: bool = true) -> void:
	var hw := w * 0.5
	var rim_r := r * rim_k
	var xf := wheel_xform(c, side)
	var ot := k.tire.xform
	k.tire.xform = ot * xf
	var first := k.tire.vertex_count()
	k.tire.add_lathe(PackedVector2Array([
		Vector2(-hw * 0.84, rim_r), Vector2(-hw * 0.98, lerpf(rim_r, r, 0.4)), Vector2(-hw, lerpf(rim_r, r, 0.78)),
		Vector2(-hw * 0.9, r * 0.985), Vector2(-hw * 0.72, r), Vector2(hw * 0.72, r), Vector2(hw * 0.9, r * 0.985),
		Vector2(hw, lerpf(rim_r, r, 0.78)), Vector2(hw * 0.98, lerpf(rim_r, r, 0.4)), Vector2(hw * 0.84, rim_r),
	]), 26, false, false, 38.0)
	k.tire.xform = ot
	# Поперечная координата протектора нормируется на ширину материала шин.
	var span := 0.0
	for i in range(first, k.tire.vertex_count()):
		span = maxf(span, k.tire.uvs[i].y)
	for i in range(first, k.tire.vertex_count()):
		k.tire.uvs[i].y = k.tire.uvs[i].y / maxf(span, 0.01) * 0.62
	var ob := k.body.xform
	k.body.xform = ob * xf
	var old_part := k.body.uv2
	k.body.uv2 = Vector2(0.0, P_PLAIN)
	var prof := PackedVector2Array([
		Vector2(-hw * 0.7, 0.0), Vector2(-hw * 0.7, rim_r * 0.5), Vector2(-hw * 0.84, rim_r * 1.01), Vector2(hw * 0.84, rim_r * 1.01),
		Vector2(hw * 0.62, rim_r * 0.92), Vector2(hw * 0.45, rim_r * 0.55),
	])
	if hub_boss:
		prof.append(Vector2(hw * 0.7, rim_r * 0.38))
		prof.append(Vector2(hw * 0.95, rim_r * 0.26))
		prof.append(Vector2(hw * 0.95, 0.0))
	else:
		prof.append(Vector2(hw * 0.45, 0.0))
	k.body.add_lathe(prof, 20, false, false, 30.0)
	k.body.uv2 = old_part
	k.body.xform = ob
	for i in 8:
		var a := float(i) / 8.0 * TAU
		box(k.metal, c + Vector3(side * hw * 0.5, cos(a) * rim_r * 0.46, sin(a) * rim_r * 0.46), Vector3(0.05, r * 0.045, r * 0.045))


# --- Вооружение ------------------------------------------------------------------------------------------
## Профиль ствола (расстояние от казны, радиус): длина, радиусы у казны и у дула, тип дульного
## устройства: "" — нет, "brake" — двухкамерный тормоз, "flash" — конический пламегаситель,
## "multi" — многощелевой тормоз, "jacket" — ствол в перфорированном кожухе.
static func barrel_profile(length: float, r0: float, r1: float, muzzle: String = "") -> PackedVector2Array:
	var p := PackedVector2Array()
	p.append(Vector2(0.0, 0.0))
	p.append(Vector2(0.0, r0 * 1.25))
	p.append(Vector2(length * 0.1, r0 * 1.25))
	p.append(Vector2(length * 0.11, r0))
	var tip := length
	match muzzle:
		"brake":
			var bl := r1 * 5.0
			p.append(Vector2(tip - bl - 0.02, r1))
			p.append(Vector2(tip - bl, r1 * 1.75))
			p.append(Vector2(tip - bl * 0.55, r1 * 1.75))
			p.append(Vector2(tip - bl * 0.5, r1 * 1.35))
			p.append(Vector2(tip - bl * 0.45, r1 * 1.75))
			p.append(Vector2(tip, r1 * 1.75))
		"flash":
			var fl := r1 * 5.5
			p.append(Vector2(tip - fl, r1))
			p.append(Vector2(tip, r1 * 1.9))
		"multi":
			var ml := r1 * 7.0
			p.append(Vector2(tip - ml - 0.02, r1))
			p.append(Vector2(tip - ml, r1 * 1.6))
			for i in 4:
				var z0 := tip - ml + ml * float(i) / 4.0
				p.append(Vector2(z0 + ml * 0.14, r1 * 1.6))
				p.append(Vector2(z0 + ml * 0.16, r1 * 1.3))
				p.append(Vector2(z0 + ml * 0.23, r1 * 1.3))
				p.append(Vector2(z0 + ml * 0.25, r1 * 1.6))
			p.append(Vector2(tip, r1 * 1.6))
		"jacket":
			p.append(Vector2(length * 0.14, r1 * 2.2))
			p.append(Vector2(tip * 0.82, r1 * 2.2))
			p.append(Vector2(tip * 0.83, r1))
			p.append(Vector2(tip - r1 * 2.0, r1))
			p.append(Vector2(tip - r1 * 1.6, r1 * 1.5))
			p.append(Vector2(tip, r1 * 1.5))
		_:
			p.append(Vector2(tip - r1 * 1.5, r1))
			p.append(Vector2(tip - r1 * 1.2, r1 * 1.18))
			p.append(Vector2(tip, r1 * 1.18))
	return p


## Ствол вдоль -Z от точки start (в комплекте gun) с тёмным каналом ствола на срезе.
static func barrel(k: VehicleKit, start: Vector3, length: float, r0: float, r1: float, muzzle: String = "", segs: int = 12) -> void:
	var prof := barrel_profile(length, r0, r1, muzzle)
	var og := k.gun.xform
	k.gun.xform = og * forward_xform(start)
	k.gun.add_lathe(prof, segs, false, false, 35.0)
	k.gun.xform = og
	var bore_r := prof[prof.size() - 1].y * 0.55
	k.dark.add_disc(start + Vector3(0.0, 0.0, -length - 0.004), Vector3(0.0, 0.0, -1.0), minf(bore_r, r1 * 0.9), 10)


## Параболическая антенна: ось dir (вогнутая сторона смотрит по dir), радиус, глубина чаши.
static func dish(kit: MeshKit, center: Vector3, dir: Vector3, radius: float, depth: float, thickness: float = 0.04, segs: int = 24) -> void:
	var prof := PackedVector2Array()
	var n := 6
	for i in n + 1:
		var t := float(i) / float(n)
		prof.append(Vector2(depth * t * t - thickness, radius * t))
	for i in range(n, -1, -1):
		var t := float(i) / float(n)
		prof.append(Vector2(depth * t * t, radius * t))
	var old := kit.xform
	kit.xform = old * Transform3D(basis_y(dir), center)
	kit.add_lathe(prof, segs, false, false, 60.0)
	kit.xform = old


## Облучатель антенны на трёх растяжках: от центра чаши вдоль dir на расстояние focus.
static func dish_feed(kit: MeshKit, center: Vector3, dir: Vector3, radius: float, focus: float) -> void:
	var d := dir.normalized()
	var tip := center + d * focus
	var b := basis_y(d)
	for i in 3:
		var a := float(i) / 3.0 * TAU
		var rim := center + (b.x * cos(a) + b.z * sin(a)) * radius * 0.92 + d * focus * 0.25
		kit.add_tube(PackedVector3Array([rim, tip]), radius * 0.02, 4)
	cyl(kit, tip - d * radius * 0.08, tip + d * radius * 0.05, radius * 0.07, 8)


## Ракета вдоль -Z от хвоста (start): длина, радиус, оперение (fins — число, span — размах).
static func missile(kit: MeshKit, fin_kit: MeshKit, start: Vector3, length: float, radius: float, fins: int = 4, span: float = -1.0, nose: float = 0.18, canards: bool = false) -> void:
	var sp := span if span > 0.0 else radius * 2.4
	var nl := length * nose
	var prof := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.0, radius * 0.8), Vector2(length * 0.03, radius), Vector2(length - nl, radius),
		Vector2(length - nl * 0.55, radius * 0.72), Vector2(length - nl * 0.2, radius * 0.3), Vector2(length, 0.0),
	])
	var old := kit.xform
	kit.xform = old * forward_xform(start)
	kit.add_lathe(prof, 12, false, false, 50.0)
	kit.xform = old
	for i in fins:
		var a := float(i) / float(fins) * TAU + PI * 0.25
		var dir := Vector3(cos(a), sin(a), 0.0)
		var basis := Basis(dir.cross(Vector3(0.0, 0.0, 1.0)), dir, Vector3(0.0, 0.0, 1.0))
		var fo := fin_kit.xform
		fin_kit.xform = fo * Transform3D(basis, start + dir * (radius + sp * 0.5 * 0.5) + Vector3(0.0, 0.0, -length * 0.07))
		fin_kit.add_prism(PackedVector2Array([Vector2(length * 0.06, -sp * 0.25), Vector2(-length * 0.07, -sp * 0.25), Vector2(-length * 0.03, sp * 0.25), Vector2(length * 0.04, sp * 0.25)]), 0.012)
		fin_kit.xform = fo
		if canards:
			fin_kit.xform = fo * Transform3D(basis, start + dir * (radius + sp * 0.12) + Vector3(0.0, 0.0, -length * 0.72))
			fin_kit.add_prism(PackedVector2Array([Vector2(length * 0.03, -sp * 0.12), Vector2(-length * 0.03, -sp * 0.12), Vector2(-length * 0.012, sp * 0.12), Vector2(length * 0.02, sp * 0.12)]), 0.01)
			fin_kit.xform = fo


# --- Мачты, леера, мелкие детали -------------------------------------------------------------------------
## Решётчатая мачта (ферма): legs стоек от base до top, ширина w0 → w1, bays пролётов с раскосами.
static func lattice(kit: MeshKit, base: Vector3, top: Vector3, w0: float, w1: float, legs: int = 4, bays: int = 5, r: float = 0.05) -> void:
	var axis := top - base
	var b := basis_y(axis)
	var corner := func(level: float, i: int) -> Vector3:
		var w := lerpf(w0, w1, level) * 0.5
		var a := float(i) / float(legs) * TAU + PI / float(legs)
		return base + axis * level + (b.x * cos(a) + b.z * sin(a)) * w * 1.41
	for i in legs:
		kit.add_tube(PackedVector3Array([corner.call(0.0, i), corner.call(1.0, i)]), r, 5)
	for s in bays + 1:
		var lv := float(s) / float(bays)
		for i in legs:
			kit.add_tube(PackedVector3Array([corner.call(lv, i), corner.call(lv, (i + 1) % legs)]), r * 0.6, 4)
		if s < bays:
			var lv2 := float(s + 1) / float(bays)
			for i in legs:
				kit.add_tube(PackedVector3Array([corner.call(lv, i), corner.call(lv2, (i + 1) % legs)]), r * 0.5, 4)


## Леерное ограждение вдоль ломаной pts (на палубе): стойки через spacing, два леера.
static func railing(kit: MeshKit, pts: PackedVector3Array, height: float = 1.0, spacing: float = 1.6, r: float = 0.022) -> void:
	if pts.size() < 2:
		return
	var top := PackedVector3Array()
	var mid := PackedVector3Array()
	for p in pts:
		top.append(p + Vector3.UP * height)
		mid.append(p + Vector3.UP * height * 0.5)
	kit.add_tube(top, r, 4)
	kit.add_tube(mid, r * 0.8, 4)
	var carry := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var t := carry
		while t < seg:
			var p := a.lerp(b, t / seg)
			kit.add_tube(PackedVector3Array([p, p + Vector3.UP * height]), r * 1.1, 4)
			t += spacing
		carry = t - seg
	var last := pts[pts.size() - 1]
	kit.add_tube(PackedVector3Array([last, last + Vector3.UP * height]), r * 1.1, 4)


## Люк: низкий цилиндр с ручкой и петлёй.
static func hatch(k: VehicleKit, center: Vector3, r: float, open_deg: float = 0.0) -> void:
	var old := k.body.xform
	k.body.xform = old * Transform3D(Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(-open_deg)), center)
	k.body.add_lathe(PackedVector2Array([Vector2(0.0, r), Vector2(0.05, r), Vector2(0.07, r * 0.9), Vector2(0.075, 0.0)]), 16, true, false, 35.0)
	k.body.xform = old
	box(k.metal, center + Vector3(0.0, 0.1, -r * 0.3), Vector3(r * 0.5, 0.03, 0.03))
	box(k.dark, center + Vector3(0.0, 0.04, r * 0.95), Vector3(r * 0.6, 0.06, 0.08))


## Фара: корпус и стекло, смотрит по dir.
static func headlight(k: VehicleKit, center: Vector3, dir: Vector3, r: float) -> void:
	var d := dir.normalized()
	var old := k.dark.xform
	k.dark.xform = old * Transform3D(basis_y(d), center)
	k.dark.add_lathe(PackedVector2Array([Vector2(-r * 1.2, 0.0), Vector2(-r * 1.2, r * 0.7), Vector2(-r * 0.3, r * 1.08), Vector2(0.0, r * 1.08)]), 12, false, false, 50.0)
	k.dark.xform = old
	k.lamp.add_disc(center + d * 0.004, d, r, 12)


## Перископ / прибор наблюдения: коробка со стеклом, смотрит по dir.
static func periscope(k: VehicleKit, base: Vector3, dir: Vector3, w: float = 0.2) -> void:
	var yaw := atan2(-dir.x, -dir.z)
	var old := k.body.xform
	k.body.xform = old * Transform3D(Basis(Vector3.UP, yaw), base)
	k.body.add_box(Vector3(0.0, w * 0.35, 0.0), Vector3(w, w * 0.7, w * 0.8))
	k.body.xform = old
	var go := k.glass.xform
	k.glass.xform = go * Transform3D(Basis(Vector3.UP, yaw), base)
	k.glass.add_box(Vector3(0.0, w * 0.45, -w * 0.41), Vector3(w * 0.8, w * 0.3, 0.01))
	k.glass.xform = go


## Гранатомёты дымовых гранат: count стволов веером, направление dir (горизонтальное).
static func smoke_launchers(k: VehicleKit, base: Vector3, dir: Vector3, count: int = 4, spread_deg: float = 16.0, r: float = 0.045) -> void:
	var d := dir.normalized()
	for i in count:
		var ang := deg_to_rad((float(i) - float(count - 1) * 0.5) * spread_deg)
		var dd := d.rotated(Vector3.UP, ang)
		var up := (dd + Vector3.UP * 0.45).normalized()
		var p := base + Vector3.UP * float(i % 2) * 0.02 + dd.cross(Vector3.UP).normalized() * (float(i) - float(count - 1) * 0.5) * r * 2.3
		cyl(k.dark, p, p + up * 0.26, r, 8)


## Мешки с песком: кольцо (дуга) из мешков вокруг center, радиус, высота (слоёв), разрыв вокруг gap_dir.
static func sandbags(k: VehicleKit, center: Vector3, radius: float, layers: int = 3, gap_dir: Vector3 = Vector3.ZERO, gap_deg: float = 40.0) -> void:
	var circumference := TAU * radius
	var per_layer := int(circumference / 0.62)
	var gap_yaw := atan2(gap_dir.x, gap_dir.z) if gap_dir != Vector3.ZERO else 999.0
	for l in layers:
		for i in per_layer:
			var a := (float(i) + (0.5 if l % 2 == 1 else 0.0)) / float(per_layer) * TAU
			if gap_yaw < 100.0 and absf(wrapf(a - gap_yaw, -PI, PI)) < deg_to_rad(gap_deg * 0.5):
				continue
			var p := center + Vector3(sin(a), 0.0, cos(a)) * radius + Vector3.UP * (0.12 + float(l) * 0.2)
			var old := k.cloth.xform
			k.cloth.xform = old * Transform3D(Basis(Vector3.UP, a + PI * 0.5), p)
			k.cloth.add_blob(Vector3.ZERO, Vector3(0.32, 0.11, 0.2), 1, 0.08, i * 7 + l, Color.WHITE, Color.WHITE)
			k.cloth.xform = old


## Фигура члена расчёта (каска, торс, руки, ноги): pos — точка между ступнями, yaw — поворот.
static func crew(k: VehicleKit, pos: Vector3, yaw: float, seated: bool = false, helmet: String = "") -> void:
	var b := Basis(Vector3.UP, yaw)
	var place := func(p: Vector3) -> Vector3:
		return pos + b * p
	var hip_y := 0.45 if seated else 0.9
	var old_c := k.cloth.xform
	# Ноги.
	for s: float in [-1.0, 1.0]:
		if seated:
			k.cloth.add_tube(PackedVector3Array([place.call(Vector3(s * 0.11, hip_y, 0.05)), place.call(Vector3(s * 0.12, hip_y, -0.38)), place.call(Vector3(s * 0.12, 0.05, -0.45))]), 0.075, 6)
		else:
			k.cloth.add_tube(PackedVector3Array([place.call(Vector3(s * 0.11, hip_y, 0.0)), place.call(Vector3(s * 0.12, 0.48, -0.03)), place.call(Vector3(s * 0.12, 0.05, 0.0))]), 0.075, 6)
		box(k.dark, place.call(Vector3(s * 0.12, 0.04, -0.08 if not seated else -0.5)), Vector3(0.11, 0.08, 0.26), Vector3(0.0, rad_to_deg(yaw), 0.0))
	# Торс и голова.
	k.cloth.xform = old_c * Transform3D(b, place.call(Vector3(0.0, hip_y + 0.32, 0.0)))
	k.cloth.add_blob(Vector3.ZERO, Vector3(0.2, 0.33, 0.14), 1, 0.03, 3, Color.WHITE, Color.WHITE)
	k.cloth.xform = old_c
	for s: float in [-1.0, 1.0]:
		k.cloth.add_tube(PackedVector3Array([place.call(Vector3(s * 0.21, hip_y + 0.55, 0.0)), place.call(Vector3(s * 0.24, hip_y + 0.3, -0.12)), place.call(Vector3(s * 0.14, hip_y + 0.35, -0.36))]), 0.055, 5)
	var head: Vector3 = place.call(Vector3(0.0, hip_y + 0.78, 0.0))
	k.dark.add_blob(head, Vector3(0.1, 0.12, 0.11), 1, 0.0, 5, Color.WHITE, Color.WHITE)
	var old_d := k.dark.xform
	k.dark.xform = old_d * Transform3D(b, head + Vector3.UP * 0.05)
	match helmet:
		"de":
			k.dark.add_lathe(PackedVector2Array([Vector2(-0.08, 0.17), Vector2(-0.02, 0.15), Vector2(0.06, 0.13), Vector2(0.12, 0.08), Vector2(0.15, 0.0)]), 12, false, false, 60.0)
		"us", "uk":
			k.dark.add_lathe(PackedVector2Array([Vector2(-0.02, 0.19), Vector2(0.0, 0.18), Vector2(0.01, 0.13), Vector2(0.09, 0.11), Vector2(0.14, 0.0)]), 12, false, false, 60.0)
		_:
			k.dark.add_lathe(PackedVector2Array([Vector2(-0.04, 0.15), Vector2(0.03, 0.14), Vector2(0.1, 0.1), Vector2(0.14, 0.0)]), 12, false, false, 60.0)
	k.dark.xform = old_d


## Антенна-штырь высотой h с основанием.
static func whip(k: VehicleKit, base: Vector3, h: float, lean: Vector3 = Vector3.ZERO) -> void:
	cyl(k.dark, base, base + Vector3.UP * 0.12, 0.05, 8)
	k.dark.add_tube(PackedVector3Array([base + Vector3.UP * 0.1, base + (Vector3.UP + lean).normalized() * h]), 0.012, 4, false, 0.005)


## Выхлопная решётка / жалюзи: ряд планок на плоскости (центр, размеры, число планок, нормаль вверх).
static func grille(k: VehicleKit, center: Vector3, size: Vector2, slats: int, along_z: bool = true) -> void:
	box(k.dark, center + Vector3(0.0, -0.005, 0.0), Vector3(size.x, 0.02, size.y))
	for i in slats:
		var t := (float(i) + 0.5) / float(slats) - 0.5
		if along_z:
			box(k.body, center + Vector3(t * size.x, 0.02, 0.0), Vector3(size.x / float(slats) * 0.45, 0.03, size.y))
		else:
			box(k.body, center + Vector3(0.0, 0.02, t * size.y), Vector3(size.x, 0.03, size.y / float(slats) * 0.45))
