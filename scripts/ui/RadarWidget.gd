class_name RadarWidget
extends Control
## Круговой радар в углу экрана. Два режима (клавиша T / кнопка геймпада Y):
##  * 3D — наклонная плоскость-эллипс; каждая цель стоит на «ножке», длина которой показывает
##    превышение или принижение относительно игрока (классический трёхмерный сканер);
##  * 2D — плоский круговой индикатор; высота воздушных целей подписана числом (сотни метров).
## Символы: самолёты — треугольники (по курсу), корабли и катера — квадраты, ПВО и наземная
## техника — круги, сооружения — ромбы. Свои — голубые, противник — красные, нейтральные — серые.

var mode_3d: bool = true
var range_m: float = 4000.0
var owner_vehicle: Vehicle = null
var fallback_camera: Camera3D = null

var _sweep: float = 0.0
var _font: Font = null


func _ready() -> void:
	custom_minimum_size = Vector2(250.0, 250.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	_sweep = fposmod(_sweep + delta * TAU / 2.4, TAU)
	queue_redraw()


func _ellipse_points(c: Vector2, rx: float, ry: float, segments: int = 56) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments + 1:
		var a := float(i) / float(segments) * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.46
	var ry := r * (0.52 if mode_3d else 1.0)
	var center := Vector3.ZERO
	var yaw := 0.0
	if owner_vehicle != null and is_instance_valid(owner_vehicle) and not owner_vehicle.is_dead:
		center = owner_vehicle.get_global_transform_interpolated().origin
		yaw = GameDB.yaw_of(GameDB.flat(owner_vehicle.get_forward()))
	elif fallback_camera != null:
		center = fallback_camera.global_position
		yaw = GameDB.yaw_of(GameDB.flat(-fallback_camera.global_basis.z))
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var bg := _ellipse_points(c, r, ry)
	draw_colored_polygon(bg, Color(0.02, 0.07, 0.11, 0.78))
	for k: float in [0.33, 0.66, 1.0]:
		draw_polyline(_ellipse_points(c, r * k, ry * k), Color(0.1, 0.9, 1.0, 0.18 if k < 1.0 else 0.55), 1.5, true)
	draw_line(c + Vector2(-r, 0.0), c + Vector2(r, 0.0), Color(0.1, 0.9, 1.0, 0.15), 1.0)
	draw_line(c + Vector2(0.0, -ry), c + Vector2(0.0, ry), Color(0.1, 0.9, 1.0, 0.15), 1.0)
	# Луч развёртки со шлейфом
	for i in 14:
		var a0 := _sweep - float(i) * 0.045
		var a1 := a0 - 0.045
		var alpha := 0.22 * (1.0 - float(i) / 14.0)
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(sin(a0) * r, -cos(a0) * ry), c + Vector2(sin(a1) * r, -cos(a1) * ry)]), Color(0.1, 0.9, 1.0, alpha))
	draw_line(c, c + Vector2(sin(_sweep) * r, -cos(_sweep) * ry), Color(0.4, 1.0, 1.0, 0.8), 2.0, true)
	# Сооружения
	for b in GlobalBattleManager.structures:
		if not is_instance_valid(b) or b.is_dead or b.team < 0:
			continue
		var rel := b.global_position - center
		var p2 := Vector2(rel.dot(right), -rel.dot(fwd)) / range_m
		if p2.length() > 1.0:
			continue
		var p := c + Vector2(p2.x * r, p2.y * ry)
		var col := _team_color(b.team, 0.45)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -3.5), p + Vector2(3.5, 0), p + Vector2(0, 3.5), p + Vector2(-3.5, 0)]), col)
	# Техника
	for v in GlobalBattleManager.units:
		if not is_instance_valid(v) or v.is_dead or v == owner_vehicle:
			continue
		var pos3 := v.get_global_transform_interpolated().origin
		var rel := pos3 - center
		var p2 := Vector2(rel.dot(right), -rel.dot(fwd)) / range_m
		var dist_k := p2.length()
		if dist_k > 1.0:
			if v.category == GameDB.Category.AIR and dist_k < 1.5 and v.team != _my_team():
				var edge := c + Vector2(p2.x / dist_k * r, p2.y / dist_k * ry)
				draw_circle(edge, 2.5, _team_color(v.team, 0.7))
			continue
		var base := c + Vector2(p2.x * r, p2.y * ry)
		var sweep_angle := atan2(p2.x, -p2.y)
		var since := fposmod(_sweep - sweep_angle, TAU)
		var brightness := 0.5 + 0.5 * exp(-since * 1.6)
		var col := _team_color(v.team, brightness)
		var p := base
		if mode_3d:
			var dy := clampf((pos3.y - center.y) / range_m * r * 1.4, -r * 0.8, r * 0.8)
			p = base - Vector2(0.0, dy)
			draw_line(base, p, Color(col, 0.6), 1.2, true)
			draw_circle(base, 1.5, Color(col, 0.6))
		match v.category:
			GameDB.Category.AIR:
				var heading := GameDB.yaw_of(GameDB.flat(v.get_forward())) - yaw
				var dir := Vector2(-sin(heading), -cos(heading))
				var side := Vector2(-dir.y, dir.x)
				draw_colored_polygon(PackedVector2Array([p + dir * 7.0, p - dir * 4.0 + side * 4.5, p - dir * 4.0 - side * 4.5]), col)
				if not mode_3d or absf(pos3.y - center.y) > 150.0:
					draw_string(_font, p + Vector2(6.0, -4.0), str(int(pos3.y / 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(col, 0.9))
			GameDB.Category.NAVAL:
				var half := 6.0 if v.vehicle_type == "warship" else 4.0
				draw_rect(Rect2(p - Vector2(half, half), Vector2(half, half) * 2.0), col)
			_:
				draw_circle(p, 4.2, col)
	# Игрок в центре
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(5, 5), c + Vector2(0, 2), c + Vector2(-5, 5)]), Color(1.0, 1.0, 1.0, 0.95))
	var label := "РЛС %s · %s" % [GameDB.format_distance(range_m), "3D" if mode_3d else "2D"]
	draw_string(_font, Vector2(c.x - r, c.y + ry + 18.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.1, 0.9, 1.0, 0.8))
	draw_string(_font, Vector2(c.x - 4.0, c.y - ry - 6.0), "N" if absf(wrapf(yaw, -PI, PI)) < 0.2 else "", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.1, 0.9, 1.0, 0.8))


func _my_team() -> int:
	if owner_vehicle != null and is_instance_valid(owner_vehicle):
		return owner_vehicle.team
	return GlobalBattleManager.player_team


func _team_color(team: int, alpha: float) -> Color:
	if team < 0:
		return Color(0.7, 0.7, 0.66, alpha)
	if team == _my_team():
		return Color(0.25, 0.9, 1.0, alpha)
	return Color(1.0, 0.3, 0.25, alpha)
