class_name SettingsPanel
extends PanelContainer
## Панель настроек: звук, управление (чувствительность, инверсия, режим управления самолётом,
## сенсорное управление), графика (качество, полноэкранный режим, FPS). Используется в главном меню
## и в меню паузы. Изменения сохраняются в user://settings.cfg.

signal closed

var _volume: HSlider
var _sensitivity: HSlider
var _invert: CheckButton
var _mouse_aim: CheckButton
var _touch: OptionButton
var _quality: OptionButton
var _fullscreen: CheckButton
var _fps: CheckButton


func _ready() -> void:
	custom_minimum_size = Vector2(560.0, 0.0)
	add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.NEON_DIM, UITheme.PANEL_SOLID))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var title := UITheme.make_label("НАСТРОЙКИ", 30, UITheme.NEON)
	UITheme.glow_label(title, UITheme.NEON, 2, 8)
	box.add_child(title)
	box.add_child(UITheme.separator())
	box.add_child(UITheme.make_label("ЗВУК", 15, UITheme.ACCENT))
	_volume = _slider(box, "Громкость", 0.0, 1.0, GameSettings.master_volume)
	box.add_child(UITheme.make_label("УПРАВЛЕНИЕ", 15, UITheme.ACCENT))
	_sensitivity = _slider(box, "Чувствительность мыши / обзора", 0.2, 3.0, GameSettings.mouse_sensitivity)
	_invert = _check(box, "Инверсия оси Y", GameSettings.invert_y)
	_mouse_aim = _check(box, "Самолёт: наведение мышью (иначе — прямое управление)", GameSettings.aircraft_mouse_aim)
	_touch = _option(box, "Сенсорное управление", GameSettings.TOUCH_MODE_NAMES, GameSettings.touch_mode)
	box.add_child(UITheme.make_label("ГРАФИКА", 15, UITheme.ACCENT))
	_quality = _option(box, "Качество графики", GameSettings.QUALITY_NAMES, GameSettings.quality)
	if not GameSettings.is_mobile():
		_fullscreen = _check(box, "Полноэкранный режим", GameSettings.fullscreen)
	_fps = _check(box, "Показывать FPS", GameSettings.show_fps)
	box.add_child(UITheme.make_label("Качество графики применяется со следующего боя.", 13, UITheme.TEXT_DIM))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(buttons)
	var back := UITheme.make_button("ГОТОВО", Vector2(200.0, 48.0), 20)
	back.pressed.connect(_on_close)
	buttons.add_child(back)


func _row(parent: Control, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := UITheme.make_label(label_text, 17, UITheme.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	parent.add_child(row)
	return row


func _slider(parent: Control, label_text: String, min_v: float, max_v: float, value: float) -> HSlider:
	var row := _row(parent, label_text)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(220.0, 32.0)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(_v: float) -> void: _apply())
	row.add_child(s)
	return s


func _check(parent: Control, label_text: String, value: bool) -> CheckButton:
	var row := _row(parent, label_text)
	var c := CheckButton.new()
	c.button_pressed = value
	c.toggled.connect(func(_on: bool) -> void: _apply())
	row.add_child(c)
	return c


func _option(parent: Control, label_text: String, items: Array, selected: int) -> OptionButton:
	var row := _row(parent, label_text)
	var o := OptionButton.new()
	for item in items:
		o.add_item(str(item))
	o.selected = selected
	o.custom_minimum_size = Vector2(220.0, 42.0)
	o.item_selected.connect(func(_i: int) -> void: _apply())
	row.add_child(o)
	return o


func _apply() -> void:
	GameSettings.master_volume = _volume.value
	GameSettings.mouse_sensitivity = _sensitivity.value
	GameSettings.invert_y = _invert.button_pressed
	GameSettings.aircraft_mouse_aim = _mouse_aim.button_pressed
	GameSettings.touch_mode = _touch.selected
	GameSettings.quality = _quality.selected
	if _fullscreen != null:
		GameSettings.fullscreen = _fullscreen.button_pressed
	GameSettings.show_fps = _fps.button_pressed
	GameSettings.apply_settings()
	GameSettings.save_settings()


func _on_close() -> void:
	_apply()
	hide()
	closed.emit()
