class_name TouchControls
extends Control
## Сенсорное управление (Android, iOS): плавающий виртуальный джойстик слева (движение / рули),
## зона обзора справа (перетаскивание вращает камеру), кнопки оружия, газа, ловушек и паузы.
## В тактическом режиме: касание — поставить метку удара, перетаскивание — двигать карту,
## кнопки «ПУСК» и «ОТМЕНА». Поддерживается мультитач (индексы пальцев). Кнопки размещаются внутри
## безопасной зоны экрана (GameSettings.safe_rect), чтобы не уходить под вырез камеры iPhone.

signal pause_pressed

const STICK_RADIUS := 95.0

var controller: PlayerController = null
var category: int = GameDB.Category.GROUND
var tactical: bool = false

var _stick_index: int = -1
var _stick_origin: Vector2 = Vector2.ZERO
var _stick_pos: Vector2 = Vector2.ZERO
var _look_index: int = -1
var _look_last: Vector2 = Vector2.ZERO
var _look_moved: float = 0.0
var _look_accum: Vector2 = Vector2.ZERO
var _buttons: Array[Dictionary] = []
var _font: Font = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	configure(GameDB.Category.GROUND, null)


## Набор кнопок под тип техники.
func configure(p_category: int, vehicle: Vehicle) -> void:
	category = p_category
	_buttons.clear()
	_add_button("pause", "II", Vector2(0.0, 0.0), 30.0, "tl", Vector2(52.0, 52.0))
	if tactical:
		_add_button("launch", "ПУСК", Vector2.ZERO, 62.0, "br", Vector2(125.0, 135.0))
		_add_button("cancel", "ОТМЕНА", Vector2.ZERO, 46.0, "br", Vector2(270.0, 95.0))
		queue_redraw()
		return
	match category:
		GameDB.Category.AIR:
			var a := vehicle as Aircraft
			_add_button("fire", a.slot_label("primary") if a != null else "ОГОНЬ", Vector2.ZERO, 62.0, "br", Vector2(125.0, 135.0))
			if a != null and a.slots.has("secondary"):
				_add_button("secondary", a.slot_label("secondary"), Vector2.ZERO, 46.0, "br", Vector2(265.0, 100.0))
			if a != null and a.flares != null:
				_add_button("flares", "ЛТЦ", Vector2.ZERO, 40.0, "br", Vector2(250.0, 230.0))
			if a != null and a.slots.has("special"):
				_add_button("special", "КАРТА", Vector2.ZERO, 42.0, "br", Vector2(115.0, 285.0))
			_add_button("thr_up", "ГАЗ+", Vector2.ZERO, 36.0, "bl", Vector2(60.0, 360.0))
			_add_button("thr_down", "ГАЗ−", Vector2.ZERO, 36.0, "bl", Vector2(60.0, 270.0))
		_:
			# Наземная ПВО и флот: подписи кнопок — по вооружению машины.
			var labels: Dictionary = vehicle.weapon_labels() if vehicle != null else {"fire": "ОГОНЬ"}
			_add_button("fire", str(labels.get("fire", "ОГОНЬ")), Vector2.ZERO, 62.0, "br", Vector2(125.0, 135.0))
			if str(labels.get("secondary", "")) != "":
				_add_button("secondary", str(labels["secondary"]), Vector2.ZERO, 46.0, "br", Vector2(265.0, 100.0))
			if str(labels.get("special", "")) != "":
				_add_button("special", str(labels["special"]), Vector2.ZERO, 44.0, "br", Vector2(115.0, 285.0))
			_add_button("zoom", "ЗУМ", Vector2.ZERO, 36.0, "br", Vector2(250.0, 230.0))
	queue_redraw()


func set_tactical(active: bool) -> void:
	tactical = active
	_look_index = -1
	var v: Vehicle = controller.vehicle if controller != null else null
	configure(category, v)


func _add_button(id: String, label: String, _unused: Vector2, radius: float, anchor: String, offset: Vector2) -> void:
	_buttons.append({"id": id, "label": label, "radius": radius, "anchor": anchor, "offset": offset, "held": false, "index": -1, "tapped": false})


func _button_center(b: Dictionary) -> Vector2:
	var o: Vector2 = b["offset"]
	var safe := GameSettings.safe_rect(size)
	match str(b["anchor"]):
		"br":
			return safe.end - o
		"bl":
			return Vector2(safe.position.x + o.x, safe.end.y - o.y)
		_:
			return safe.position + o


# --- Состояние для PlayerController -----------------------------------------------------------------------
func is_held(id: String) -> bool:
	for b in _buttons:
		if str(b["id"]) == id:
			return bool(b["held"])
	return false


func consume_tap(id: String) -> bool:
	for b in _buttons:
		if str(b["id"]) == id and bool(b["tapped"]):
			b["tapped"] = false
			return true
	return false


func stick_active() -> bool:
	return _stick_index >= 0


func stick_vector() -> Vector2:
	if _stick_index < 0:
		return Vector2.ZERO
	return ((_stick_pos - _stick_origin) / STICK_RADIUS).limit_length(1.0)


func consume_look_delta() -> Vector2:
	var d := _look_accum
	_look_accum = Vector2.ZERO
	return d


func throttle_axis() -> float:
	return (1.0 if is_held("thr_up") else 0.0) - (1.0 if is_held("thr_down") else 0.0)


# --- Обработка касаний ------------------------------------------------------------------------------------------
func _to_local(pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * pos


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		var pos := _to_local(st.position)
		if st.pressed:
			for b in _buttons:
				if pos.distance_to(_button_center(b)) <= float(b["radius"]) * 1.15:
					b["held"] = true
					b["index"] = st.index
					b["tapped"] = true
					_on_button_pressed(str(b["id"]))
					get_viewport().set_input_as_handled()
					queue_redraw()
					return
			if not tactical and pos.x < size.x * 0.42 and _stick_index < 0:
				_stick_index = st.index
				_stick_origin = pos
				_stick_pos = pos
			elif _look_index < 0:
				_look_index = st.index
				_look_last = pos
				_look_moved = 0.0
		else:
			for b in _buttons:
				if int(b["index"]) == st.index:
					b["held"] = false
					b["index"] = -1
			if st.index == _stick_index:
				_stick_index = -1
			if st.index == _look_index:
				if tactical and _look_moved < 14.0 and controller != null:
					controller.tactical_click(st.position)
				_look_index = -1
		get_viewport().set_input_as_handled()
		queue_redraw()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		var pos := _to_local(sd.position)
		if sd.index == _stick_index:
			_stick_pos = pos
		elif sd.index == _look_index:
			var d := pos - _look_last
			_look_last = pos
			_look_moved += d.length()
			if tactical:
				if controller != null:
					controller.tactical_pan(d)
			else:
				_look_accum += d
		get_viewport().set_input_as_handled()
		queue_redraw()


func _on_button_pressed(id: String) -> void:
	match id:
		"pause":
			pause_pressed.emit()
		"special":
			if controller != null:
				controller.enter_tactical()
		"launch":
			if controller != null:
				controller.tactical_launch()
		"cancel":
			if controller != null:
				controller.exit_tactical()


# --- Отрисовка --------------------------------------------------------------------------------------------------
func _draw() -> void:
	var neon := Color(0.1, 0.9, 1.0)
	if not tactical:
		var safe := GameSettings.safe_rect(size)
		var base := _stick_origin if _stick_index >= 0 else Vector2(safe.position.x + 165.0, safe.end.y - 165.0)
		draw_circle(base, STICK_RADIUS, Color(0.02, 0.08, 0.12, 0.35))
		draw_arc(base, STICK_RADIUS, 0.0, TAU, 48, Color(neon, 0.5), 2.0, true)
		var knob := base + stick_vector() * STICK_RADIUS
		draw_circle(knob, 34.0, Color(neon, 0.35 if _stick_index >= 0 else 0.18))
		draw_arc(knob, 34.0, 0.0, TAU, 32, Color(neon, 0.8), 2.0, true)
	for b in _buttons:
		var c := _button_center(b)
		var r := float(b["radius"])
		var held := bool(b["held"])
		var col := Color(1.0, 0.69, 0.13) if held else neon
		draw_circle(c, r, Color(0.02, 0.08, 0.12, 0.55 if held else 0.35))
		draw_arc(c, r, 0.0, TAU, 40, Color(col, 0.9), 2.5, true)
		var label := str(b["label"])
		var fs := 18 if r >= 45.0 else 14
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
		draw_string(_font, c + Vector2(-w * 0.5, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)


func _process(_delta: float) -> void:
	if _stick_index >= 0 or _look_index >= 0:
		queue_redraw()
