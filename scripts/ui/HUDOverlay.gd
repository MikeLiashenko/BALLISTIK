class_name HUDOverlay
extends Control
## Экранный слой прицельных символов, рисуется поверх 3D-сцены:
##  * перекрестье, для самолёта — отметка направления носа (куда сейчас летит машина);
##  * индикатор упреждения (ромб) для автопушек;
##  * рамка захвата цели ракетами с дугой прогресса;
##  * прицел бомбометания CCIP (точка падения бомб);
##  * маркеры техники: противник — красные уголки с дистанцией, свои — голубые с позывным;
##  * предупреждения о ракетах (стрелки по краю экрана), маркер попадания, красная виньетка урона.

var hud: HUD = null
var hit_marker_time: float = 0.0
var kill_marker_time: float = 0.0
var damage_flash: float = 0.0
var nearest_to_crosshair: Vehicle = null
var _font: Font = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	hit_marker_time = maxf(hit_marker_time - delta, 0.0)
	kill_marker_time = maxf(kill_marker_time - delta, 0.0)
	damage_flash = maxf(damage_flash - delta * 1.5, 0.0)
	queue_redraw()


func _cam() -> Camera3D:
	if hud == null or hud.rig == null:
		return null
	return hud.rig.camera


func _project(p: Vector3) -> Variant:
	var cam := _cam()
	if cam == null or cam.is_position_behind(p):
		return null
	return cam.unproject_position(p)


func _draw() -> void:
	var cam := _cam()
	if cam == null or hud == null:
		return
	var pc := hud.pc
	var v: Vehicle = pc.vehicle if pc != null and pc.has_vehicle() else null
	var center := size * 0.5
	var neon := Color(0.1, 0.9, 1.0)
	var tactical := pc != null and pc.tactical_active
	_draw_unit_markers(cam, v, tactical)
	if tactical:
		_draw_tactical_hint()
		return
	if v == null:
		_draw_vignette()
		return
	# Перекрестье
	var gap := 7.0
	var arm := 12.0
	for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(center + d * gap, center + d * (gap + arm), Color(neon, 0.9), 2.0, true)
	draw_circle(center, 1.8, Color(neon, 0.9))
	# Отметка носа самолёта
	if v.category == GameDB.Category.AIR:
		var nose: Variant = _project(v.get_global_transform_interpolated().origin + v.get_forward() * 800.0)
		if nose != null:
			var np: Vector2 = nose
			draw_arc(np, 11.0, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.85), 1.6, true)
			draw_line(np + Vector2(-20, 0), np + Vector2(-11, 0), Color(1, 1, 1, 0.85), 1.6)
			draw_line(np + Vector2(11, 0), np + Vector2(20, 0), Color(1, 1, 1, 0.85), 1.6)
	# Индикатор упреждения
	var lead := v.get_lead_info()
	if not lead.is_empty():
		var lp: Variant = _project(lead["point"])
		var tgt: Vehicle = lead["target"]
		var tp: Variant = _project(tgt.get_global_transform_interpolated().origin) if is_instance_valid(tgt) else null
		if lp != null:
			var p: Vector2 = lp
			if tp != null:
				draw_dashed_line(tp, p, Color(1.0, 0.69, 0.13, 0.5), 1.2, 6.0)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -9), p + Vector2(9, 0), p + Vector2(0, 9), p + Vector2(-9, 0)]), Color(1.0, 0.69, 0.13, 0.25))
			draw_polyline(PackedVector2Array([p + Vector2(0, -9), p + Vector2(9, 0), p + Vector2(0, 9), p + Vector2(-9, 0), p + Vector2(0, -9)]), Color(1.0, 0.69, 0.13, 0.95), 2.0, true)
	# Рамка захвата
	var lock := v.get_lock_info()
	if not lock.is_empty():
		var lt: Node3D = lock["target"]
		if is_instance_valid(lt):
			var lpos: Variant = _project(lt.global_position)
			var progress := float(lock["progress"])
			if lpos != null:
				var p: Vector2 = lpos
				var locked := progress >= 1.0
				var col := Color(1.0, 0.25, 0.2) if locked else Color(1.0, 0.8, 0.2)
				var s := 26.0 if locked else 34.0 - progress * 8.0
				draw_rect(Rect2(p - Vector2(s, s), Vector2(s, s) * 2.0), Color(col, 0.95), false, 2.0)
				if not locked:
					draw_arc(p, s + 8.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, Color(col, 0.9), 3.0, true)
				else:
					draw_string(_font, p + Vector2(-s, -s - 8.0), "ЗАХВАТ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, col)
	# CCIP бомбардировщика
	if v is Bomber:
		var bomber := v as Bomber
		if bomber.ccip_valid:
			var cp: Variant = _project(bomber.ccip_point)
			if cp != null:
				var p: Vector2 = cp
				draw_arc(p, 16.0, 0.0, TAU, 32, Color(1.0, 0.69, 0.13, 0.95), 2.0, true)
				draw_circle(p, 2.5, Color(1.0, 0.69, 0.13))
				draw_line(center, p, Color(1.0, 0.69, 0.13, 0.35), 1.0, true)
				draw_string(_font, p + Vector2(20.0, 5.0), "CCIP", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(1.0, 0.69, 0.13))
	# Маркер попадания
	if hit_marker_time > 0.0:
		var a := clampf(hit_marker_time / 0.25, 0.0, 1.0)
		var col := Color(1.0, 0.3, 0.25, a) if kill_marker_time > 0.0 else Color(1.0, 1.0, 1.0, a)
		for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(center + d * 10.0, center + d * 20.0, col, 2.5, true)
	# Предупреждение о ракетах
	for m in v.incoming_missiles:
		if not is_instance_valid(m):
			continue
		var mn := m as Node3D
		var dir3 := mn.global_position - cam.global_position
		var local := cam.global_basis.inverse() * dir3
		var dir2 := Vector2(local.x, -local.y).normalized()
		if dir2.length_squared() < 0.001:
			continue
		var edge := center + dir2 * minf(size.x, size.y) * 0.38
		var side := Vector2(-dir2.y, dir2.x)
		draw_colored_polygon(PackedVector2Array([edge + dir2 * 22.0, edge - dir2 * 8.0 + side * 14.0, edge - dir2 * 8.0 - side * 14.0]), Color(1.0, 0.2, 0.15, 0.85))
	_draw_vignette()


func _draw_vignette() -> void:
	if damage_flash <= 0.0:
		return
	var a := clampf(damage_flash, 0.0, 0.6)
	var t := 60.0
	draw_rect(Rect2(0, 0, size.x, t), Color(1.0, 0.1, 0.05, a * 0.5))
	draw_rect(Rect2(0, size.y - t, size.x, t), Color(1.0, 0.1, 0.05, a * 0.5))
	draw_rect(Rect2(0, 0, t, size.y), Color(1.0, 0.1, 0.05, a * 0.5))
	draw_rect(Rect2(size.x - t, 0, t, size.y), Color(1.0, 0.1, 0.05, a * 0.5))


func _draw_unit_markers(cam: Camera3D, v: Vehicle, tactical: bool) -> void:
	var my_team := GlobalBattleManager.player_team
	var eye := cam.global_position
	var center := size * 0.5
	var best: Vehicle = null
	var best_d := 170.0
	var enemy_range := 7000.0 if tactical else 3600.0
	for u in GlobalBattleManager.units:
		if not is_instance_valid(u) or u.is_dead or u == v:
			continue
		var pos := u.get_global_transform_interpolated().origin + Vector3.UP * (u.hit_radius * 0.6 + 2.0)
		var dist := eye.distance_to(pos)
		var enemy := u.team != my_team
		if enemy and dist > enemy_range:
			continue
		if not enemy and dist > (6000.0 if tactical else 900.0):
			continue
		var sp: Variant = _project(pos)
		if sp == null:
			continue
		var p: Vector2 = sp
		if p.x < -20.0 or p.y < -20.0 or p.x > size.x + 20.0 or p.y > size.y + 20.0:
			continue
		if enemy:
			var col := Color(1.0, 0.3, 0.25, 0.9)
			var s := 9.0
			draw_line(p + Vector2(-s, -s), p + Vector2(-s + 4, -s), col, 2.0)
			draw_line(p + Vector2(-s, -s), p + Vector2(-s, -s + 4), col, 2.0)
			draw_line(p + Vector2(s, -s), p + Vector2(s - 4, -s), col, 2.0)
			draw_line(p + Vector2(s, -s), p + Vector2(s, -s + 4), col, 2.0)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -s - 10), p + Vector2(5, -s - 10), p + Vector2(0, -s - 3)]), col)
			var label := GameDB.format_distance(dist)
			if tactical or dist < 1500.0:
				label = "%s  %s" % [GameDB.vehicle_name(u.vehicle_type, u.team), label]
			draw_string(_font, p + Vector2(-30.0, s + 14.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(1.0, 0.55, 0.5, 0.95))
			if not tactical and v != null:
				var dc := p.distance_to(center)
				if dc < best_d:
					best_d = dc
					best = u
		else:
			var col2 := Color(0.3, 0.9, 1.0, 0.85)
			draw_circle(p, 3.5, col2)
			draw_string(_font, p + Vector2(7.0, 4.0), u.pilot_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, col2)
	nearest_to_crosshair = best


func _draw_tactical_hint() -> void:
	var pc := hud.pc
	var text := pc.tactical_info
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18).x
	var pos := Vector2(size.x * 0.5 - w * 0.5, size.y - 70.0)
	draw_rect(Rect2(pos - Vector2(16.0, 26.0), Vector2(w + 32.0, 38.0)), Color(0.02, 0.07, 0.11, 0.8))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(1.0, 0.8, 0.45))
