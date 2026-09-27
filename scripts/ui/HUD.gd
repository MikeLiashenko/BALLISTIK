class_name HUD
extends CanvasLayer
## Интерфейс во время боя:
##  * счёт команд и таймер матча, лента событий (уничтожения);
##  * панель состояния техники: ХП, скорость/высота/тяга, оружие — боезапас и перезарядка;
##  * круговой 3D/2D-радар (RadarWidget) и прицельные символы (HUDOverlay);
##  * предупреждения (ракета, высота, сваливание, выход из зоны), крупные сообщения;
##  * экран возрождения с выбором свободного слота, пауза, настройки, итоги матча, таблица, справка;
##  * сенсорное управление (TouchControls) на мобильных устройствах.

const HELP_TEXT := """[b]УПРАВЛЕНИЕ (ПК)[/b]
[color=#ffb020]Общее:[/color] ЛКМ / Пробел — основное оружие · ПКМ / F — дополнительное · G / СКМ — тактическая карта (баллистика, Х-59) · X — ловушки · Z — зум · T — радар 3D/2D · Tab — счёт · Esc — пауза · F1 — справка
[color=#ffb020]Авиация:[/color] мышь — направление полёта · W/S — газ · A/D — крен · Q/E — рыскание · стрелки — ручное управление · C — камера (наведение мышью / прямое управление)
[color=#ffb020]Наземная ПВО и катера:[/color] W/S — ход · A/D — поворот · мышь — обзор и прицел. ЗРК: удерживайте цель в прицеле до захвата, затем ЛКМ — пуск
[color=#ffb020]Тактическая карта:[/color] ЛКМ — поставить метку · повторный ЛКМ по метке / Enter — пуск · колесо — масштаб · WASD — сдвиг карты · ПКМ / G — выход
[color=#ffb020]Геймпад:[/color] левый стик — движение, правый — обзор, триггеры — оружие, A — карта, B — ловушки"""

var level: BattleLevel = null
var pc: PlayerController = null
var rig: CameraRig = null
var touch_controls: TouchControls = null
var overlay: HUDOverlay = null
var radar: RadarWidget = null

var _root: Control = null
var _top_panel: PanelContainer = null
var _score_labels: Array[Label] = []
var _score_bars: Array[ProgressBar] = []
var _timer_label: Label = null
var _feed_box: VBoxContainer = null
var _message_label: Label = null
var _message_time: float = 0.0
var _warning_label: Label = null
var _status_panel: PanelContainer = null
var _vehicle_label: Label = null
var _hp_bar: ProgressBar = null
var _hp_label: Label = null
var _info_label: Label = null
var _weapons_box: VBoxContainer = null
var _hint_label: Label = null
var _weapon_rows: Array[Dictionary] = []
var _radar_panel: PanelContainer = null
var _fps_label: Label = null
var _help_hint: Label = null
var _help_panel: PanelContainer = null
var _dimmer: ColorRect = null
var _respawn_panel: PanelContainer = null
var _respawn_title: Label = null
var _respawn_timer_label: Label = null
var _slot_selector: SlotSelector = null
var _pause_panel: PanelContainer = null
var _settings_panel: SettingsPanel = null
var _end_panel: PanelContainer = null
var _end_title: Label = null
var _end_details: Label = null
var _scoreboard: PanelContainer = null
var _scoreboard_text: RichTextLabel = null

var _vehicle: Vehicle = null
var _help_timer: float = 12.0
var _warning_sound_timer: float = 0.0
var _last_health: float = -1.0


func setup(p_level: BattleLevel, p_pc: PlayerController, p_rig: CameraRig) -> void:
	level = p_level
	pc = p_pc
	rig = p_rig
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_build()
	GlobalBattleManager.kill_feed.connect(_on_kill_feed)
	GlobalBattleManager.score_changed.connect(func(_t: int, _s: int) -> void: _update_scores())
	GlobalBattleManager.match_ended.connect(_on_match_ended)
	GlobalBattleManager.player_died.connect(_on_player_died)
	GlobalBattleManager.player_spawned.connect(_on_player_spawned)
	GlobalBattleManager.player_hit.connect(_on_player_hit)
	GlobalBattleManager.announcement.connect(show_message)
	pc.tactical_mode_changed.connect(_on_tactical_changed)
	_update_scores()


# --- Построение интерфейса --------------------------------------------------------------------------------
func _build() -> void:
	_root = Control.new()
	_root.name = "HUDRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.get_theme()
	add_child(_root)
	overlay = HUDOverlay.new()
	overlay.hud = self
	_root.add_child(overlay)
	_build_top_bar()
	_feed_box = VBoxContainer.new()
	_feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed_box.add_theme_constant_override("separation", 2)
	_root.add_child(_feed_box)
	_message_label = UITheme.make_label("", 30, UITheme.NEON, HORIZONTAL_ALIGNMENT_CENTER)
	UITheme.glow_label(_message_label, UITheme.NEON, 3, 10)
	_root.add_child(_message_label)
	_warning_label = UITheme.make_label("", 26, UITheme.DANGER, HORIZONTAL_ALIGNMENT_CENTER)
	UITheme.glow_label(_warning_label, UITheme.DANGER, 3, 10)
	_root.add_child(_warning_label)
	_build_status_panel()
	_radar_panel = PanelContainer.new()
	_radar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radar_panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.NEON_DIM, Color(0.02, 0.06, 0.09, 0.55)))
	radar = RadarWidget.new()
	radar.custom_minimum_size = Vector2(250.0, 250.0)
	_radar_panel.add_child(radar)
	_root.add_child(_radar_panel)
	_fps_label = UITheme.make_label("", 14, UITheme.TEXT_DIM)
	_root.add_child(_fps_label)
	_help_hint = UITheme.make_label("F1 — управление · G — тактическая карта · T — режим радара", 15, UITheme.TEXT_DIM)
	_root.add_child(_help_hint)
	touch_controls = TouchControls.new()
	touch_controls.controller = pc
	touch_controls.visible = GameSettings.is_touch_enabled()
	touch_controls.pause_pressed.connect(open_pause)
	_root.add_child(touch_controls)
	if touch_controls.visible:
		_help_hint.text = "Джойстик — движение · правая половина экрана — обзор · кнопки — оружие"
	_dimmer = ColorRect.new()
	_dimmer.color = Color(0.0, 0.02, 0.04, 0.55)
	_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dimmer.visible = false
	_root.add_child(_dimmer)
	_build_respawn_panel()
	_build_pause_panel()
	_build_end_panel()
	_build_scoreboard()
	_build_help_panel()
	_settings_panel = SettingsPanel.new()
	_settings_panel.visible = false
	_settings_panel.closed.connect(_on_settings_closed)
	_root.add_child(_settings_panel)


func _build_top_bar() -> void:
	_top_panel = PanelContainer.new()
	_top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.NEON_DIM, Color(0.02, 0.06, 0.09, 0.7)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	_top_panel.add_child(row)
	for team in 2:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		var l := UITheme.make_label("", 22, GameDB.team_color(team), HORIZONTAL_ALIGNMENT_CENTER)
		l.custom_minimum_size = Vector2(170.0, 0.0)
		col.add_child(l)
		var bar := UITheme.progress_bar(GameDB.team_color(team), 6.0)
		col.add_child(bar)
		_score_labels.append(l)
		_score_bars.append(bar)
		if team == 0:
			row.add_child(col)
			_timer_label = UITheme.make_label("00:00", 28, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
			_timer_label.custom_minimum_size = Vector2(110.0, 0.0)
			row.add_child(_timer_label)
		else:
			row.add_child(col)
	_root.add_child(_top_panel)


func _build_status_panel() -> void:
	_status_panel = PanelContainer.new()
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.NEON_DIM, Color(0.02, 0.06, 0.09, 0.72)))
	_status_panel.custom_minimum_size = Vector2(340.0, 0.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_status_panel.add_child(box)
	_vehicle_label = UITheme.make_label("", 20, UITheme.NEON)
	box.add_child(_vehicle_label)
	var hp_row := HBoxContainer.new()
	box.add_child(hp_row)
	hp_row.add_child(UITheme.make_label("ХП", 15, UITheme.TEXT_DIM))
	_hp_bar = UITheme.progress_bar(UITheme.SUCCESS, 12.0)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row.add_child(_hp_bar)
	_hp_label = UITheme.make_label("", 15, UITheme.TEXT)
	_hp_label.custom_minimum_size = Vector2(76.0, 0.0)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_row.add_child(_hp_label)
	_info_label = UITheme.make_label("", 15, UITheme.TEXT)
	box.add_child(_info_label)
	box.add_child(UITheme.separator())
	_weapons_box = VBoxContainer.new()
	_weapons_box.add_theme_constant_override("separation", 3)
	box.add_child(_weapons_box)
	_hint_label = UITheme.make_label("", 14, UITheme.ACCENT)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(300.0, 0.0)
	box.add_child(_hint_label)
	_root.add_child(_status_panel)


func _centered_panel(min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	p.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.NEON_DIM, UITheme.PANEL_SOLID))
	p.visible = false
	_root.add_child(p)
	return p


func _build_respawn_panel() -> void:
	_respawn_panel = _centered_panel(Vector2(900.0, 0.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_respawn_panel.add_child(box)
	_respawn_title = UITheme.make_label("ВЫБОР ТЕХНИКИ", 30, UITheme.NEON)
	UITheme.glow_label(_respawn_title, UITheme.NEON, 2, 8)
	box.add_child(_respawn_title)
	_respawn_timer_label = UITheme.make_label("", 18, UITheme.ACCENT)
	box.add_child(_respawn_timer_label)
	_slot_selector = SlotSelector.new()
	_slot_selector.custom_minimum_size = Vector2(860.0, 330.0)
	box.add_child(_slot_selector)
	_slot_selector.setup(GlobalBattleManager.player_team, true)
	_slot_selector.vehicle_chosen.connect(_on_slot_chosen)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	var menu := UITheme.make_button("МЕНЮ", Vector2(160.0, 44.0), 18)
	menu.pressed.connect(open_pause)
	row.add_child(menu)


func _build_pause_panel() -> void:
	_pause_panel = _centered_panel(Vector2(420.0, 0.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_pause_panel.add_child(box)
	var title := UITheme.make_label("ПАУЗА", 34, UITheme.NEON, HORIZONTAL_ALIGNMENT_CENTER)
	UITheme.glow_label(title, UITheme.NEON, 2, 10)
	box.add_child(title)
	var buttons: Array = [
		["ПРОДОЛЖИТЬ", resume],
		["НАСТРОЙКИ", _open_settings],
		["СМЕНИТЬ ТЕХНИКУ", _change_vehicle],
		["ВЫЙТИ В МЕНЮ", _quit_to_menu],
	]
	for entry: Array in buttons:
		var b := UITheme.make_button(str(entry[0]), Vector2(380.0, 54.0), 21)
		b.pressed.connect(entry[1])
		box.add_child(b)


func _build_end_panel() -> void:
	_end_panel = _centered_panel(Vector2(620.0, 0.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_end_panel.add_child(box)
	_end_title = UITheme.make_label("", 46, UITheme.NEON, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_end_title)
	_end_details = UITheme.make_label("", 17, UITheme.TEXT)
	_end_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_end_details)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var again := UITheme.make_button("РЕВАНШ", Vector2(250.0, 54.0), 21)
	again.pressed.connect(func() -> void:
		get_tree().paused = false
		GlobalBattleManager.restart_match()
	)
	row.add_child(again)
	var menu := UITheme.make_button("В МЕНЮ", Vector2(250.0, 54.0), 21)
	menu.pressed.connect(_quit_to_menu)
	row.add_child(menu)


func _build_scoreboard() -> void:
	_scoreboard = _centered_panel(Vector2(760.0, 0.0))
	_scoreboard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scoreboard_text = RichTextLabel.new()
	_scoreboard_text.bbcode_enabled = true
	_scoreboard_text.fit_content = true
	_scoreboard_text.scroll_active = false
	_scoreboard_text.custom_minimum_size = Vector2(720.0, 0.0)
	_scoreboard_text.add_theme_font_size_override("normal_font_size", 17)
	_scoreboard_text.add_theme_font_size_override("bold_font_size", 19)
	_scoreboard_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scoreboard.add_child(_scoreboard_text)


func _build_help_panel() -> void:
	_help_panel = _centered_panel(Vector2(900.0, 0.0))
	_help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size = Vector2(860.0, 0.0)
	text.add_theme_font_size_override("normal_font_size", 17)
	text.add_theme_font_size_override("bold_font_size", 21)
	text.text = HELP_TEXT
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_panel.add_child(text)


# --- Кадр ---------------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	_layout()
	_update_status()
	_update_warnings(delta)
	_update_respawn()
	_timer_label.text = GameDB.format_time(GlobalBattleManager.time_left)
	_message_time -= delta
	_message_label.modulate.a = clampf(_message_time, 0.0, 1.0)
	_help_timer -= delta
	_help_hint.visible = _help_timer > 0.0
	_fps_label.visible = GameSettings.show_fps
	if GameSettings.show_fps:
		_fps_label.text = "FPS %d" % Engine.get_frames_per_second()
	radar.owner_vehicle = pc.vehicle if pc.has_vehicle() else null
	radar.fallback_camera = rig.camera
	_dimmer.visible = is_menu_open() and not _respawn_panel.visible
	touch_controls.visible = GameSettings.is_touch_enabled() and not is_menu_open()


func _layout() -> void:
	var s := _root.size
	_top_panel.position = Vector2((s.x - _top_panel.size.x) * 0.5, 10.0)
	_feed_box.position = Vector2(s.x - _feed_box.size.x - 16.0, 14.0)
	_message_label.size = Vector2(s.x, 40.0)
	_message_label.position = Vector2(0.0, s.y * 0.2)
	_warning_label.size = Vector2(s.x, 40.0)
	_warning_label.position = Vector2(0.0, s.y * 0.3)
	var touch_on := touch_controls.visible
	if touch_on:
		_status_panel.position = Vector2(16.0, 100.0)
		_radar_panel.position = Vector2(s.x - _radar_panel.size.x - 16.0, 70.0 + _feed_box.size.y)
	else:
		_status_panel.position = Vector2(16.0, s.y - _status_panel.size.y - 16.0)
		_radar_panel.position = Vector2(s.x - _radar_panel.size.x - 16.0, s.y - _radar_panel.size.y - 16.0)
	_fps_label.position = Vector2(16.0, 12.0)
	_help_hint.position = Vector2((s.x - _help_hint.size.x) * 0.5, s.y - 34.0)
	for p: Control in [_respawn_panel, _pause_panel, _end_panel, _scoreboard, _help_panel, _settings_panel]:
		p.position = ((s - p.size) * 0.5).max(Vector2.ZERO)


func on_player_vehicle(v: Vehicle) -> void:
	_vehicle = v
	_last_health = v.health
	for child in _weapons_box.get_children():
		child.queue_free()
	_weapon_rows.clear()
	for w in v.weapons:
		var row := HBoxContainer.new()
		var name_l := UITheme.make_label(w.display_name, 14, UITheme.TEXT)
		name_l.custom_minimum_size = Vector2(150.0, 0.0)
		row.add_child(name_l)
		var ammo_l := UITheme.make_label("", 14, UITheme.NEON)
		ammo_l.custom_minimum_size = Vector2(96.0, 0.0)
		row.add_child(ammo_l)
		var bar := UITheme.progress_bar(UITheme.ACCENT, 7.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		_weapons_box.add_child(row)
		_weapon_rows.append({"weapon": w, "ammo": ammo_l, "bar": bar})
	var range_m := 5000.0
	if v.category == GameDB.Category.AIR:
		range_m = 8000.0
	elif v.vehicle_type == "sam":
		range_m = 7000.0
	radar.range_m = range_m
	touch_controls.configure(v.category, v)
	if not v.health_changed.is_connected(_on_player_health_changed):
		v.health_changed.connect(_on_player_health_changed)


func _update_status() -> void:
	var has := pc.has_vehicle()
	_status_panel.visible = has
	if not has:
		return
	var v := pc.vehicle
	_vehicle_label.text = "%s · %s" % [v.get_display_name(), GameDB.vehicle_role(v.vehicle_type)]
	_hp_bar.value = clampf(v.health / v.max_health, 0.0, 1.0)
	var hp_col := UITheme.SUCCESS if _hp_bar.value > 0.55 else (UITheme.ACCENT if _hp_bar.value > 0.25 else UITheme.DANGER)
	_hp_bar.add_theme_stylebox_override("fill", UITheme.flat(hp_col, hp_col, 0, 3))
	_hp_label.text = "%d/%d" % [int(maxf(v.health, 0.0)), int(v.max_health)]
	_info_label.text = "\n".join(v.get_hud_lines())
	for row in _weapon_rows:
		var w: Weapon = row["weapon"]
		var ammo: Label = row["ammo"]
		var bar: ProgressBar = row["bar"]
		ammo.text = w.get_ammo_text()
		bar.value = w.get_ready_ratio()
		ammo.add_theme_color_override("font_color", UITheme.NEON if w.can_fire() else UITheme.TEXT_DIM)
	_hint_label.text = v.hud_hint


func _update_warnings(delta: float) -> void:
	_warning_sound_timer -= delta
	var text := ""
	if pc.has_vehicle() and not get_tree().paused:
		var v := pc.vehicle
		var blink := fmod(GameDB.now(), 0.6) < 0.4
		if not v.incoming_missiles.is_empty():
			text = ("!! РАКЕТА — ЛОВУШКИ (ЛТЦ) !!" if touch_controls.visible else "!! РАКЕТА — ЛОВУШКИ (X) !!") if v.category == GameDB.Category.AIR else "!! РАКЕТА !!"
			if _warning_sound_timer <= 0.0:
				_warning_sound_timer = 0.6
				SoundFX.play_ui("warning", -10.0)
		elif v is Aircraft and (v as Aircraft).ground_warning:
			text = "ВЫСОТА! НАБЕРИТЕ ВЫСОТУ"
		elif v is Aircraft and (v as Aircraft).stall_warning:
			text = "СВАЛИВАНИЕ — ДАЙТЕ ГАЗ"
		elif v.out_of_bounds_time > 0.0:
			text = "ВЕРНИТЕСЬ В ЗОНУ БОЯ: %d с" % int(ceil(maxf(Vehicle.OUT_OF_BOUNDS_GRACE - v.out_of_bounds_time, 0.0)))
		elif v.spawn_protection > 0.0:
			text = "ЗАЩИТА ПОСЛЕ ПОЯВЛЕНИЯ"
			blink = true
		if not blink:
			text = ""
	_warning_label.text = text


func _update_respawn() -> void:
	var gbm := GlobalBattleManager
	var need := gbm.match_running and not gbm.match_over and not pc.has_vehicle() and gbm.player != null and not gbm.smoke_test
	if need and not _respawn_panel.visible and not _pause_panel.visible and not _settings_panel.visible:
		_respawn_panel.visible = true
		_slot_selector.refresh()
		pc.update_mouse_mode()
	elif not need and _respawn_panel.visible:
		_respawn_panel.visible = false
		pc.update_mouse_mode()
	if _respawn_panel.visible:
		var p := gbm.player
		if p.vehicle_type == "":
			_respawn_timer_label.text = "Выберите свободный слот техники"
		elif p.respawn_timer > 0.0:
			_respawn_timer_label.text = "%s · вылет через %.1f с" % [GameDB.vehicle_name(p.vehicle_type, p.team), p.respawn_timer]
		else:
			_respawn_timer_label.text = "Вылет..."


# --- События ------------------------------------------------------------------------------------------------
func show_message(text: String, color: Color = UITheme.NEON, duration: float = 3.0) -> void:
	_message_label.text = text
	UITheme.glow_label(_message_label, color, 3, 10)
	_message_time = duration


func _on_kill_feed(text: String, color: Color) -> void:
	var l := UITheme.make_label(text, 15, color, HORIZONTAL_ALIGNMENT_RIGHT)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	_feed_box.add_child(l)
	while _feed_box.get_child_count() > 6:
		var old := _feed_box.get_child(0)
		_feed_box.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(7.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


func _update_scores() -> void:
	var gbm := GlobalBattleManager
	for team in 2:
		_score_labels[team].text = "%s  %d" % [GameDB.team_name(team), gbm.scores[team]]
		_score_bars[team].value = clampf(float(gbm.scores[team]) / float(maxi(gbm.score_limit, 1)), 0.0, 1.0)


func _on_player_hit(target: Node, damage: float, killed: bool) -> void:
	overlay.hit_marker_time = 0.25
	if killed:
		overlay.kill_marker_time = 0.4
		var value := 0
		var what := "ЦЕЛЬ"
		if target is Vehicle:
			value = GameDB.score_for_vehicle((target as Vehicle).vehicle_type)
			what = (target as Vehicle).get_display_name()
		elif target is Building:
			value = (target as Building).score_value
			what = (target as Building).display_name
		show_message("УНИЧТОЖЕНО: %s  +%d" % [what.to_upper(), value], UITheme.ACCENT, 2.5)
	elif damage > 0.0 and randf() < 0.3:
		SoundFX.play_ui("beep", -22.0, 2.0)


func _on_player_health_changed(_v: Vehicle, health: float, _max: float) -> void:
	if _last_health >= 0.0 and health < _last_health:
		overlay.damage_flash = minf(overlay.damage_flash + 0.35, 0.9)
		rig.add_trauma(0.15)
	_last_health = health


func _on_player_died(killer: Dictionary) -> void:
	_vehicle = null
	if bool(killer.get("recall", false)):
		_respawn_title.text = "СМЕНА ТЕХНИКИ"
	elif int(killer.get("team", -1)) >= 0:
		_respawn_title.text = "ВЫ УНИЧТОЖЕНЫ: %s [%s]" % [str(killer.get("attacker_name", "?")), str(killer.get("vehicle_label", ""))]
		show_message("ТЕХНИКА ПОТЕРЯНА", UITheme.DANGER, 2.5)
	else:
		_respawn_title.text = "ТЕХНИКА ПОТЕРЯНА"
		show_message("ТЕХНИКА ПОТЕРЯНА", UITheme.DANGER, 2.5)
	UITheme.glow_label(_respawn_title, UITheme.NEON, 2, 8)


func _on_player_spawned(_v: Vehicle) -> void:
	_respawn_panel.visible = false
	show_message("В БОЙ!", UITheme.NEON, 1.5)


func _on_slot_chosen(type_id: String) -> void:
	if GlobalBattleManager.request_player_slot(type_id):
		SoundFX.play_ui("ui_confirm", -6.0)
	else:
		SoundFX.play_ui("warning", -10.0)
	_slot_selector.refresh()


func _on_tactical_changed(active: bool) -> void:
	touch_controls.set_tactical(active)
	if active:
		show_message("ТАКТИЧЕСКАЯ КАРТА — УКАЖИТЕ ТОЧКУ УДАРА", UITheme.ACCENT, 2.5)


func _on_match_ended(winner: int) -> void:
	var gbm := GlobalBattleManager
	var my := gbm.player_team
	if winner < 0:
		_end_title.text = "НИЧЬЯ"
		UITheme.glow_label(_end_title, UITheme.TEXT, 3, 12)
	elif winner == my:
		_end_title.text = "ПОБЕДА"
		UITheme.glow_label(_end_title, UITheme.SUCCESS, 3, 14)
	else:
		_end_title.text = "ПОРАЖЕНИЕ"
		UITheme.glow_label(_end_title, UITheme.DANGER, 3, 14)
	var lines := PackedStringArray()
	lines.append("Счёт: %s %d — %d %s" % [GameDB.team_name(0), gbm.scores[0], gbm.scores[1], GameDB.team_name(1)])
	if gbm.player != null:
		lines.append("Ваш результат: уничтожено %d · потеряно %d · очки %d" % [gbm.player.kills, gbm.player.deaths, gbm.player.score])
	lines.append("")
	lines.append("Лучшие участники:")
	var sorted := gbm.participants.duplicate()
	sorted.sort_custom(func(a: Participant, b: Participant) -> bool: return a.score > b.score)
	for i in mini(5, sorted.size()):
		var p: Participant = sorted[i]
		lines.append("  %d. %s (%s) — %d очк., %d/%d" % [i + 1, p.name, GameDB.team_name(p.team), p.score, p.kills, p.deaths])
	_end_details.text = "\n".join(lines)
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(func() -> void:
		_close_all_panels()
		_end_panel.visible = true
		get_tree().paused = true
		MusicPlayer.play_menu()
		pc.update_mouse_mode()
	)


# --- Меню --------------------------------------------------------------------------------------------------
func is_menu_open() -> bool:
	return _respawn_panel.visible or _pause_panel.visible or _end_panel.visible or _settings_panel.visible


func target_near_crosshair() -> Vehicle:
	if overlay == null:
		return null
	var v: Variant = overlay.get("nearest_to_crosshair")
	if v != null and is_instance_valid(v) and not (v as Vehicle).is_dead:
		return v as Vehicle
	return null


func _close_all_panels() -> void:
	for p: Control in [_respawn_panel, _pause_panel, _settings_panel, _scoreboard, _help_panel]:
		p.visible = false


func open_pause() -> void:
	if _end_panel.visible:
		return
	if pc.tactical_active:
		pc.exit_tactical()
	_respawn_panel.visible = false
	_pause_panel.visible = true
	get_tree().paused = true
	MusicPlayer.duck(true)
	pc.update_mouse_mode()


func resume() -> void:
	_pause_panel.visible = false
	_settings_panel.visible = false
	get_tree().paused = false
	MusicPlayer.duck(false)
	pc.update_mouse_mode()


func _open_settings() -> void:
	_pause_panel.visible = false
	_settings_panel.visible = true


func _on_settings_closed() -> void:
	_pause_panel.visible = true
	touch_controls.visible = GameSettings.is_touch_enabled()


func _change_vehicle() -> void:
	resume()
	GlobalBattleManager.recall_player_vehicle()


func _quit_to_menu() -> void:
	get_tree().paused = false
	GlobalBattleManager.return_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if pc.tactical_active:
			pc.exit_tactical()
		elif _settings_panel.visible:
			_settings_panel.visible = false
			_on_settings_closed()
		elif _end_panel.visible:
			pass
		elif _pause_panel.visible:
			resume()
		else:
			open_pause()
	elif event.is_action_pressed("scoreboard"):
		_refresh_scoreboard()
		_scoreboard.visible = true
	elif event.is_action_released("scoreboard"):
		_scoreboard.visible = false
	elif event.is_action_pressed("help"):
		_help_panel.visible = not _help_panel.visible
	elif event.is_action_pressed("radar_mode"):
		radar.mode_3d = not radar.mode_3d


func _refresh_scoreboard() -> void:
	var gbm := GlobalBattleManager
	var t := "[center][b]СЧЁТ  %s %d — %d %s[/b]  ·  лимит %d  ·  %s[/center]\n" % [GameDB.team_name(0), gbm.scores[0], gbm.scores[1], GameDB.team_name(1), gbm.score_limit, GameDB.format_time(gbm.time_left)]
	for team in 2:
		var hex := GameDB.team_color(team).to_html(false)
		t += "\n[color=#%s][b]%s[/b][/color]\n" % [hex, GameDB.team_name(team)]
		t += "[table=6][cell][color=#8aa][b]Позывной  [/b][/color][/cell][cell][color=#8aa][b]Техника  [/b][/color][/cell][cell][color=#8aa][b]Очки  [/b][/color][/cell][cell][color=#8aa][b]Уничт.  [/b][/color][/cell][cell][color=#8aa][b]Потери  [/b][/color][/cell][cell][color=#8aa][b]Статус[/b][/color][/cell]"
		var members := gbm.get_team_participants(team)
		members.sort_custom(func(a: Participant, b: Participant) -> bool: return a.score > b.score)
		for p in members:
			var status := "в бою" if p.alive else "ожидание"
			var who := "%s (вы)" % p.name if p.is_player else p.name
			t += "[cell]%s  [/cell][cell]%s  [/cell][cell]%d[/cell][cell]%d[/cell][cell]%d[/cell][cell]%s[/cell]" % [who, p.get_vehicle_label(), p.score, p.kills, p.deaths, status]
		t += "[/table]\n"
	_scoreboard_text.text = t
