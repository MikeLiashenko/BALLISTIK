extends Control
## Главное меню «Командный центр» (Tactical UI): тёмный неоновый интерфейс поверх 3D-сетки радара,
## крупное название BALLISTIK, кнопки «В БОЙ», «НАСТРОЙКИ», «ВЫХОД».
## Лобби: выбор стороны и параметров боя, выбор техники по лимитированным слотам команды
## (вкладки Авиация / Наземная ПВО / Военный Флот, счётчики «МиГ-29 [1/2]»), состав команд.

const SCANLINE_SHADER := """
shader_type canvas_item;

void fragment() {
	float scan = 0.5 + 0.5 * sin(UV.y * 1400.0);
	float vig = smoothstep(0.95, 0.3, length(UV - vec2(0.5)));
	COLOR = vec4(0.0, 0.02, 0.04, scan * 0.06 + (1.0 - vig) * 0.7);
}
"""

var _bg: SubViewportContainer = null
var _main_panel: Control = null
var _lobby_panel: Control = null
var _settings_panel: SettingsPanel = null
var _loading: Control = null
var _slot_selector: SlotSelector = null
var _roster: RichTextLabel = null
var _selected_label: Label = null
var _start_button: Button = null
var _team_buttons: Array[Button] = []
var _clock: Label = null
var _title: Label = null
var _status_dot: Label = null
var _time: float = 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	GameSettings.apply_viewport_quality(get_viewport())
	_build_background()
	_build_main_panel()
	_build_lobby_panel()
	_settings_panel = SettingsPanel.new()
	_settings_panel.visible = false
	_settings_panel.closed.connect(_show_main)
	add_child(_settings_panel)
	_build_loading()
	_show_main()
	if GlobalBattleManager.smoke_test:
		_run_smoke_sequence()


# --- Фон ---------------------------------------------------------------------------------------------------
func _build_background() -> void:
	var base := ColorRect.new()
	base.color = UITheme.BG
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	_bg = SubViewportContainer.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.stretch = true
	_bg.stretch_shrink = 2 if GameSettings.quality == 0 else 1
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_2X if GameSettings.quality >= 2 else Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_bg.add_child(vp)
	vp.add_child(MenuRadarScene.new())
	var shader := Shader.new()
	shader.code = SCANLINE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var overlay := ColorRect.new()
	overlay.material = mat
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)


# --- Главная панель ------------------------------------------------------------------------------------------
func _build_main_panel() -> void:
	_main_panel = MarginContainer.new()
	_main_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		_main_panel.add_theme_constant_override(side, 56)
	add_child(_main_panel)
	var row := HBoxContainer.new()
	_main_panel.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_theme_constant_override("separation", 14)
	row.add_child(left)
	var tag := UITheme.make_label("◢ КОМАНДНЫЙ ЦЕНТР · ТАКТИЧЕСКОЕ УПРАВЛЕНИЕ" if ThemeDB.fallback_font.has_char(0x25E2) else "КОМАНДНЫЙ ЦЕНТР · ТАКТИЧЕСКОЕ УПРАВЛЕНИЕ", 16, UITheme.ACCENT)
	left.add_child(tag)
	_title = Label.new()
	_title.text = "BALLISTIK"
	_title.add_theme_font_override("font", UITheme.title_font())
	_title.add_theme_font_size_override("font_size", 112)
	UITheme.glow_label(_title, UITheme.NEON, 5, 26)
	left.add_child(_title)
	left.add_child(UITheme.make_label("АВИАЦИЯ  ·  НАЗЕМНАЯ ПВО  ·  ВОЕННЫЙ ФЛОТ  ·  БАЛЛИСТИКА", 18, UITheme.TEXT_DIM))
	var sep := UITheme.separator(UITheme.NEON_DIM)
	sep.custom_minimum_size = Vector2(560.0, 2.0)
	left.add_child(sep)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	left.add_child(buttons)
	var battle := UITheme.make_button("В БОЙ", Vector2(380.0, 66.0), 28)
	battle.add_theme_stylebox_override("normal", UITheme.button_style(UITheme.ACCENT, Color(0.14, 0.1, 0.02, 0.92), 6))
	battle.add_theme_stylebox_override("hover", UITheme.button_style(UITheme.ACCENT, Color(0.25, 0.17, 0.03, 0.95), 16))
	battle.add_theme_color_override("font_color", UITheme.ACCENT)
	battle.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.6))
	battle.pressed.connect(_show_lobby)
	buttons.add_child(battle)
	var settings := UITheme.make_button("НАСТРОЙКИ", Vector2(380.0, 56.0), 22)
	settings.pressed.connect(_show_settings)
	buttons.add_child(settings)
	var quit := UITheme.make_button("ВЫХОД", Vector2(380.0, 56.0), 22)
	quit.pressed.connect(func() -> void: get_tree().quit())
	buttons.add_child(quit)
	battle.grab_focus.call_deferred()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var right := VBoxContainer.new()
	right.size_flags_vertical = Control.SIZE_SHRINK_END
	right.add_theme_constant_override("separation", 4)
	row.add_child(right)
	_clock = UITheme.make_label("", 30, UITheme.NEON, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(_clock)
	var status := PanelContainer.new()
	status.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.NEON_DIM, Color(0.02, 0.06, 0.09, 0.75)))
	right.add_child(status)
	var sbox := VBoxContainer.new()
	sbox.add_theme_constant_override("separation", 2)
	status.add_child(sbox)
	_status_dot = UITheme.make_label("● СИСТЕМЫ: НОРМА" if ThemeDB.fallback_font.has_char(0x25CF) else "СИСТЕМЫ: НОРМА", 16, UITheme.SUCCESS)
	sbox.add_child(_status_dot)
	for line: String in ["СВЯЗЬ С ПОДРАЗДЕЛЕНИЯМИ: УСТАНОВЛЕНА", "РЛС ОБЗОРА: АКТИВНА", "БОЕВАЯ ГОТОВНОСТЬ: ПОЛНАЯ"]:
		sbox.add_child(UITheme.make_label(line, 14, UITheme.TEXT_DIM))
	var version := "v%s · Godot %s" % [str(ProjectSettings.get_setting("application/config/version", "1.0")), Engine.get_version_info()["string"]]
	sbox.add_child(UITheme.make_label(version, 12, Color(0.4, 0.5, 0.6)))


# --- Лобби -----------------------------------------------------------------------------------------------------
func _build_lobby_panel() -> void:
	_lobby_panel = MarginContainer.new()
	_lobby_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		_lobby_panel.add_theme_constant_override(side, 26)
	add_child(_lobby_panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	_lobby_panel.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := UITheme.make_label("ЛОББИ · ВЫБОР ТЕХНИКИ", 28, UITheme.NEON)
	UITheme.glow_label(title, UITheme.NEON, 2, 10)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UITheme.make_label("СТОРОНА:", 17, UITheme.TEXT_DIM))
	var group := ButtonGroup.new()
	for team in 2:
		var b := UITheme.make_button(GameDB.team_name(team), Vector2(150.0, 44.0), 18)
		b.toggle_mode = true
		b.button_group = group
		b.add_theme_color_override("font_color", GameDB.team_color(team))
		b.add_theme_color_override("font_pressed_color", GameDB.team_color(team))
		b.pressed.connect(_on_team_selected.bind(team))
		header.add_child(b)
		_team_buttons.append(b)
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 18)
	root.add_child(options)
	_add_option(options, "Сложность ботов", _difficulty_names(), GameSettings.difficulty, _on_difficulty)
	var sizes: Array = []
	for n in range(3, GameDB.total_slots() + 1):
		sizes.append("%d на %d" % [n, n])
	_add_option(options, "Размер команд", sizes, GameSettings.team_size - 3, _on_team_size)
	_add_option(options, "Лимит очков", ["500", "1000", "2000"], [500, 1000, 2000].find(GameSettings.score_limit), _on_score_limit)
	_add_option(options, "Время", ["10 мин", "15 мин", "20 мин"], [10, 15, 20].find(GameSettings.time_limit_min), _on_time_limit)
	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 16)
	root.add_child(main)
	_slot_selector = SlotSelector.new()
	_slot_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_selector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot_selector.vehicle_chosen.connect(_on_vehicle_chosen)
	main.add_child(_slot_selector)
	var roster_panel := PanelContainer.new()
	roster_panel.custom_minimum_size = Vector2(300.0, 0.0)
	main.add_child(roster_panel)
	_roster = RichTextLabel.new()
	_roster.bbcode_enabled = true
	_roster.scroll_active = true
	_roster.add_theme_font_size_override("normal_font_size", 16)
	_roster.add_theme_font_size_override("bold_font_size", 18)
	roster_panel.add_child(_roster)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	root.add_child(bottom)
	var back := UITheme.make_button("НАЗАД", Vector2(200.0, 56.0), 20)
	back.pressed.connect(_show_main)
	bottom.add_child(back)
	_selected_label = UITheme.make_label("", 18, UITheme.TEXT)
	_selected_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(_selected_label)
	_start_button = UITheme.make_button("НАЧАТЬ БОЙ", Vector2(300.0, 60.0), 24)
	_start_button.add_theme_stylebox_override("normal", UITheme.button_style(UITheme.ACCENT, Color(0.14, 0.1, 0.02, 0.92), 6))
	_start_button.add_theme_stylebox_override("hover", UITheme.button_style(UITheme.ACCENT, Color(0.25, 0.17, 0.03, 0.95), 16))
	_start_button.add_theme_color_override("font_color", UITheme.ACCENT)
	_start_button.pressed.connect(_on_start)
	bottom.add_child(_start_button)
	GlobalBattleManager.roster_changed.connect(_refresh_lobby)


func _add_option(parent: Control, label: String, items: Array, selected: int, callback: Callable) -> void:
	var box := HBoxContainer.new()
	box.add_child(UITheme.make_label(label, 16, UITheme.TEXT_DIM))
	var o := OptionButton.new()
	for item in items:
		o.add_item(str(item))
	o.selected = maxi(selected, 0)
	o.custom_minimum_size = Vector2(150.0, 40.0)
	o.item_selected.connect(callback)
	box.add_child(o)
	parent.add_child(box)


func _difficulty_names() -> Array:
	var names: Array = []
	for d: Dictionary in GameDB.DIFFICULTY_LEVELS:
		names.append(d["name"])
	return names


func _build_loading() -> void:
	_loading = ColorRect.new()
	(_loading as ColorRect).color = Color(0.01, 0.02, 0.035, 0.94)
	_loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading.visible = false
	add_child(_loading)
	var l := UITheme.make_label("ГЕНЕРАЦИЯ АРЕНЫ...", 36, UITheme.NEON, HORIZONTAL_ALIGNMENT_CENTER)
	UITheme.glow_label(l, UITheme.NEON, 3, 14)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	_loading.add_child(l)


# --- Переходы между экранами ------------------------------------------------------------------------------------
func _show_main() -> void:
	_main_panel.visible = true
	_lobby_panel.visible = false
	_settings_panel.visible = false


func _show_settings() -> void:
	_main_panel.visible = false
	_lobby_panel.visible = false
	_settings_panel.visible = true


func _show_lobby() -> void:
	GlobalBattleManager.prepare_lobby()
	_main_panel.visible = false
	_settings_panel.visible = false
	_lobby_panel.visible = true
	_rebuild_selector()


func _rebuild_selector() -> void:
	_slot_selector.setup(GlobalBattleManager.player_team, false)
	for team in 2:
		_team_buttons[team].set_pressed_no_signal(team == GlobalBattleManager.player_team)
	_refresh_lobby()


func _refresh_lobby() -> void:
	if _lobby_panel == null or not _lobby_panel.visible:
		return
	var gbm := GlobalBattleManager
	var t := ""
	for team in 2:
		var hex := GameDB.team_color(team).to_html(false)
		var mine := " (ваша сторона)" if team == gbm.player_team else ""
		t += "[color=#%s][b]%s%s[/b][/color]\n" % [hex, GameDB.team_name(team), mine]
		for p in gbm.get_team_participants(team):
			var who := "[color=#ffb020]Вы[/color]" if p.is_player else p.name
			var label := p.get_vehicle_label() if p.vehicle_type != "" else "[color=#667]не выбрано[/color]"
			t += "  %s — %s\n" % [who, label]
		t += "\n"
	t += "[color=#8aa]Слоты на команду: МиГ-29 ×2, Су-24М ×1, Гепард ×2, ЗРК ×1, катера ×3. Боты занимают свободные слоты сами.[/color]"
	_roster.text = t
	var chosen := gbm.player.vehicle_type if gbm.player != null else ""
	_start_button.disabled = chosen == ""
	if chosen == "":
		_selected_label.text = "Выберите технику со свободным слотом."
	else:
		var cat := GameDB.category_of(chosen)
		_selected_label.text = "Выбрано: %s — старт: %s" % [GameDB.vehicle_name(chosen, gbm.player_team), str(GameDB.CATEGORY_SPAWN[cat])]
	_slot_selector.refresh()


func _on_vehicle_chosen(type_id: String) -> void:
	if GlobalBattleManager.request_player_slot(type_id):
		SoundFX.play_ui("ui_confirm", -6.0)
	else:
		SoundFX.play_ui("warning", -10.0)
	_refresh_lobby()


func _on_team_selected(team: int) -> void:
	if team == GlobalBattleManager.player_team:
		return
	GlobalBattleManager.set_player_team(team)
	_rebuild_selector()


func _on_difficulty(index: int) -> void:
	GameSettings.difficulty = index
	GameSettings.save_settings()
	GlobalBattleManager.difficulty = index


func _on_team_size(index: int) -> void:
	GameSettings.team_size = index + 3
	GameSettings.save_settings()
	GlobalBattleManager.prepare_lobby()
	_rebuild_selector()


func _on_score_limit(index: int) -> void:
	GameSettings.score_limit = [500, 1000, 2000][index]
	GameSettings.save_settings()
	GlobalBattleManager.score_limit = GameSettings.score_limit


func _on_time_limit(index: int) -> void:
	GameSettings.time_limit_min = [10, 15, 20][index]
	GameSettings.save_settings()
	GlobalBattleManager.time_limit = float(GameSettings.time_limit_min) * 60.0


func _on_start() -> void:
	if GlobalBattleManager.player == null or GlobalBattleManager.player.vehicle_type == "":
		return
	_loading.visible = true
	SoundFX.play_ui("ui_confirm", -4.0)
	await get_tree().process_frame
	await get_tree().process_frame
	GlobalBattleManager.start_battle()


# --- Анимация ---------------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	_time += delta
	if _clock != null:
		var t := Time.get_time_dict_from_system()
		_clock.text = "%02d:%02d:%02d" % [int(t["hour"]), int(t["minute"]), int(t["second"])]
	if _title != null:
		var flicker := 1.0 if fmod(_time, 5.0) > 0.12 else 0.75
		_title.modulate = Color(1.0, 1.0, 1.0, flicker)
	if _status_dot != null:
		_status_dot.modulate.a = 0.55 + 0.45 * absf(sin(_time * 2.0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _lobby_panel.visible or _settings_panel.visible:
			_show_main()
			get_viewport().set_input_as_handled()


# --- Автотест ----------------------------------------------------------------------------------------------------
func _run_smoke_sequence() -> void:
	await get_tree().create_timer(1.6).timeout
	_show_lobby()
	var wanted := GlobalBattleManager.smoke_vehicle
	if wanted == "" or not GlobalBattleManager.request_player_slot(wanted):
		var free := GlobalBattleManager.free_slot_types(GlobalBattleManager.player_team)
		if not free.is_empty():
			GlobalBattleManager.request_player_slot(free[0])
	_refresh_lobby()
	await get_tree().create_timer(2.4).timeout
	_on_start()
