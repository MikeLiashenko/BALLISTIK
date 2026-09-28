extends Control
## Главное меню BALLISTIK поверх кинематографичного 3D-фона (MenuBackdrop):
##  * главный экран — название, кнопки «В БОЙ», «АНГАР», «НАСТРОЙКИ», «ВЫХОД», сводка (карта фона,
##    советы), текущий музыкальный трек;
##  * лобби — сторона, карта (превью-миникарты), эпоха авиации, сложность, размер команд, лимиты;
##    выбор техники по слотам с 3D-превью и характеристиками, составы команд;
##  * ангар — вся техника игры в 3D с описанием, вооружением и характеристиками;
##  * настройки и экран подготовки к вылету.

const TIPS := [
	"Поршневые истребители виражат лучше реактивных — не тяните бой на малой скорости с «Зеро».",
	"G — тактическая карта: баллистические ракеты катеров и управляемые ракеты бьют по метке.",
	"Ловушки (X) отводят ракеты с тепловой ГСН. На поршневых самолётах ловушек нет.",
	"Эсминцы — главные цели: торпеды, бомбы и крылатые ракеты наносят им повышенный урон.",
	"ЗРК захватывает цель, пока она в прицеле. Прячьтесь за рельефом — радар не видит сквозь горы.",
	"Бомбы падают в кольцо CCIP: ведите метку на цель и сбрасывайте в момент совмещения.",
	"Выберите технику, занятую ботом своей команды, — бот уступит место.",
	"Уровень «Новобранец» — для спокойного освоения: боты медлят и часто промахиваются.",
]

var _backdrop: MenuBackdrop = null
var _main: Control = null
var _lobby: Control = null
var _hangar: Control = null
var _settings_panel: SettingsPanel = null
var _loading: Control = null
var _title: Label = null
var _now_playing: Label = null
var _eq_bars: Array[ColorRect] = []
var _tip_label: Label = null
var _map_info: Label = null
var _clock: Label = null
var _tip_index: int = 0
var _tip_timer: float = 0.0
var _time: float = 0.0
# Лобби
var _team_buttons: Array[Button] = []
var _map_buttons: Dictionary = {}
var _map_thumbs: Dictionary = {}
var _slot_selector: SlotSelector = null
var _preview: ModelViewer = null
var _preview_name: Label = null
var _preview_sub: Label = null
var _preview_desc: Label = null
var _preview_weapons: Label = null
var _preview_bars: Array[ProgressBar] = []
var _roster: RichTextLabel = null
var _selected_label: Label = null
var _start_button: Button = null
var _size_option: OptionButton = null
var _thumb_thread: Thread = null
# Ангар
var _hangar_viewer: ModelViewer = null
var _hangar_title: Label = null
var _hangar_sub: Label = null
var _hangar_desc: Label = null
var _hangar_weapons: Label = null
var _hangar_bars: Array[ProgressBar] = []
var _hangar_team: int = 0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	GameSettings.apply_viewport_quality(get_viewport())
	_build_background()
	_build_main()
	_build_lobby()
	_build_hangar()
	_settings_panel = SettingsPanel.new()
	_settings_panel.visible = false
	_settings_panel.closed.connect(_show_main)
	add_child(_settings_panel)
	_build_loading()
	MusicPlayer.track_changed.connect(_on_track_changed)
	MusicPlayer.play_menu()
	_on_track_changed(MusicPlayer.current_title)
	_show_main()
	_start_thumbnails()
	if GlobalBattleManager.smoke_test:
		if GlobalBattleManager.smoke_menu:
			_run_menu_tour()
		else:
			_run_smoke_sequence()


func _exit_tree() -> void:
	if _thumb_thread != null and _thumb_thread.is_started():
		_thumb_thread.wait_to_finish()


# --- Фон -------------------------------------------------------------------------------------------------
func _build_background() -> void:
	_backdrop = MenuBackdrop.new()
	add_child(_backdrop)
	var side := TextureRect.new()
	side.texture = UITheme.side_gradient()
	side.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	side.stretch_mode = TextureRect.STRETCH_SCALE
	side.anchor_right = 0.62
	side.anchor_bottom = 1.0
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(side)
	var bottom := ColorRect.new()
	bottom.color = Color(0.0, 0.01, 0.02, 0.35)
	bottom.anchor_top = 0.86
	bottom.anchor_right = 1.0
	bottom.anchor_bottom = 1.0
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)


static func _place(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, orr: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob


# --- Главный экран ---------------------------------------------------------------------------------------
func _build_main() -> void:
	_main = Control.new()
	_main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_main)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	_place(left, 0.0, 0.5, 0.0, 0.5, 64.0, -300.0, 620.0, 300.0)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	_main.add_child(left)
	left.add_child(UITheme.make_label("ТАКТИЧЕСКИЙ АВИАСИМУЛЯТОР  ·  ПВО  ·  ФЛОТ", 15, UITheme.ACCENT))
	_title = Label.new()
	_title.text = "BALLISTIK"
	_title.add_theme_font_override("font", UITheme.title_font())
	_title.add_theme_font_size_override("font_size", 100)
	UITheme.glow_label(_title, UITheme.NEON, 4, 22)
	left.add_child(_title)
	var planes := 0
	for t: String in GameDB.VEHICLE_ORDER:
		if GameDB.is_aircraft(t):
			planes += 1
	left.add_child(UITheme.make_label("%d самолётов 1940–2020-х  ·  %d карт  ·  процедурные миры" % [planes, MapPresets.ORDER.size()], 17, UITheme.TEXT_DIM))
	var sep := UITheme.separator(UITheme.NEON_DIM)
	sep.custom_minimum_size = Vector2(540.0, 2.0)
	left.add_child(sep)
	var battle := UITheme.menu_button("В БОЙ", true, Vector2(380.0, 64.0))
	battle.pressed.connect(_show_lobby)
	left.add_child(battle)
	var hangar := UITheme.menu_button("АНГАР")
	hangar.pressed.connect(_show_hangar)
	left.add_child(hangar)
	var settings := UITheme.menu_button("НАСТРОЙКИ")
	settings.pressed.connect(_show_settings)
	left.add_child(settings)
	# На iOS SceneTree.quit() не работает: приложение закрывают жестом системы, кнопка не нужна.
	if not OS.has_feature("ios"):
		var quit := UITheme.menu_button("ВЫХОД")
		quit.pressed.connect(func() -> void: get_tree().quit())
		left.add_child(quit)
	battle.grab_focus.call_deferred()
	var music := HBoxContainer.new()
	music.add_theme_constant_override("separation", 3)
	_place(music, 0.0, 1.0, 0.0, 1.0, 64.0, -58.0, 600.0, -30.0)
	_main.add_child(music)
	for i in 5:
		var bar := ColorRect.new()
		bar.color = UITheme.NEON
		bar.custom_minimum_size = Vector2(4.0, 6.0)
		bar.size_flags_vertical = Control.SIZE_SHRINK_END
		music.add_child(bar)
		_eq_bars.append(bar)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(8.0, 0.0)
	music.add_child(gap)
	_now_playing = UITheme.make_label("", 15, UITheme.TEXT)
	music.add_child(_now_playing)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.glass_panel())
	_place(panel, 1.0, 1.0, 1.0, 1.0, -420.0, -300.0, -40.0, -40.0)
	_main.add_child(panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	panel.add_child(info)
	info.add_child(UITheme.section_title("СВОДКА ОПЕРАЦИИ"))
	_map_info = UITheme.make_label("", 16, UITheme.TEXT)
	_map_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_map_info)
	info.add_child(UITheme.separator())
	info.add_child(UITheme.section_title("СОВЕТ", 13))
	_tip_label = UITheme.make_label("", 14, UITheme.TEXT_DIM)
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.custom_minimum_size = Vector2(330.0, 60.0)
	info.add_child(_tip_label)
	var foot := HBoxContainer.new()
	info.add_child(foot)
	var version := UITheme.make_label("v%s · Godot %s" % [str(ProjectSettings.get_setting("application/config/version", "1.0")), Engine.get_version_info()["string"]], 12, Color(0.45, 0.55, 0.65))
	version.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(version)
	_clock = UITheme.make_label("", 15, UITheme.NEON)
	foot.add_child(_clock)
	_tip_index = randi() % TIPS.size()
	_tip_label.text = TIPS[_tip_index]


# --- Лобби -----------------------------------------------------------------------------------------------
func _build_lobby() -> void:
	_lobby = MarginContainer.new()
	_lobby.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side_name: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		_lobby.add_theme_constant_override(side_name, 18)
	add_child(_lobby)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_lobby.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)
	var title := UITheme.make_label("ПОДГОТОВКА К БОЮ", 28, UITheme.NEON)
	UITheme.glow_label(title, UITheme.NEON, 2, 10)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_header_hint("СТОРОНА:"))
	var group := ButtonGroup.new()
	for team in 2:
		var b := UITheme.make_button(GameDB.team_name(team), Vector2(140.0, 42.0), 17)
		b.toggle_mode = true
		b.button_group = group
		b.add_theme_color_override("font_color", GameDB.team_color(team))
		b.add_theme_color_override("font_pressed_color", GameDB.team_color(team))
		b.pressed.connect(_on_team_selected.bind(team))
		header.add_child(b)
		_team_buttons.append(b)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)
	body.add_child(_build_lobby_left())
	var center := PanelContainer.new()
	center.add_theme_stylebox_override("panel", UITheme.glass_panel())
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.clip_contents = true
	body.add_child(center)
	_slot_selector = SlotSelector.new()
	_slot_selector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot_selector.vehicle_chosen.connect(_on_vehicle_chosen)
	_slot_selector.vehicle_hovered.connect(_on_vehicle_hovered)
	center.add_child(_slot_selector)
	body.add_child(_build_lobby_right())
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	root.add_child(bottom)
	var back := UITheme.make_button("НАЗАД", Vector2(170.0, 54.0), 19)
	back.pressed.connect(_show_main)
	bottom.add_child(back)
	_selected_label = UITheme.make_label("", 16, UITheme.TEXT)
	_selected_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(_selected_label)
	_start_button = UITheme.menu_button("НАЧАТЬ БОЙ", true, Vector2(280.0, 56.0))
	_start_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_start_button.pressed.connect(_on_start)
	bottom.add_child(_start_button)
	GlobalBattleManager.roster_changed.connect(_refresh_lobby)


## Подпись в шапке экрана поверх яркого 3D-фона: с тёмной обводкой, чтобы читалась на небе.
func _header_hint(text: String) -> Label:
	var l := UITheme.make_label(text, 15, UITheme.TEXT)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.04, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _build_lobby_left() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.glass_panel())
	panel.custom_minimum_size = Vector2(292.0, 0.0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(UITheme.section_title("КАРТА"))
	var group := ButtonGroup.new()
	var ids: Array[String] = [MapPresets.RANDOM_ID]
	ids.append_array(MapPresets.ORDER)
	for map_id in ids:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0.0, 56.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_ALL
		for state: String in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, UITheme.card_style(state == "pressed") if state != "focus" else StyleBoxEmpty.new())
		b.pressed.connect(_on_map_selected.bind(map_id))
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 6.0
		row.offset_right = -6.0
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		var thumb := TextureRect.new()
		thumb.custom_minimum_size = Vector2(56.0, 40.0)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if map_id == MapPresets.RANDOM_ID:
			thumb.texture = IconFactory.get_icon("radar", 64, UITheme.NEON)
			thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(thumb)
		var texts := VBoxContainer.new()
		texts.add_theme_constant_override("separation", 0)
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(texts)
		var name_l := UITheme.make_label(MapPresets.map_name(map_id), 14, UITheme.TEXT)
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_l.clip_text = true
		name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		texts.add_child(name_l)
		var sub := "Любая из %d карт" % MapPresets.ORDER.size() if map_id == MapPresets.RANDOM_ID else str(MapPresets.get_map(map_id).get("subtitle", ""))
		var sub_l := UITheme.make_label(sub, 11, UITheme.TEXT_DIM)
		sub_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub_l.clip_text = true
		sub_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		texts.add_child(sub_l)
		box.add_child(b)
		_map_buttons[map_id] = b
		_map_thumbs[map_id] = thumb
	box.add_child(UITheme.separator())
	box.add_child(UITheme.section_title("ПАРАМЕТРЫ БОЯ"))
	_add_option(box, "Авиация", GameDB.ERA_NAMES, GameSettings.air_era, _on_era)
	_add_option(box, "Боты", _difficulty_names(), GameSettings.difficulty, _on_difficulty)
	var sizes: Array = []
	for n in range(3, 17):
		sizes.append("%d на %d" % [n, n])
	_size_option = _add_option(box, "Размер команд", sizes, GameSettings.team_size - 3, _on_team_size)
	_add_option(box, "Лимит очков", ["500", "1000", "2000"], maxi([500, 1000, 2000].find(GameSettings.score_limit), 0), _on_score_limit)
	_add_option(box, "Время", ["10 мин", "15 мин", "20 мин", "30 мин"], maxi([10, 15, 20, 30].find(GameSettings.time_limit_min), 0), _on_time_limit)
	return panel


func _build_lobby_right() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.glass_panel())
	panel.custom_minimum_size = Vector2(300.0, 0.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var view_panel := PanelContainer.new()
	var view_style := UITheme.glass_panel(Color(0.4, 0.8, 1.0, 0.14), Color(0.02, 0.04, 0.06, 0.94))
	view_style.set_content_margin_all(2.0)
	view_style.shadow_size = 0
	view_panel.add_theme_stylebox_override("panel", view_style)
	box.add_child(view_panel)
	_preview = ModelViewer.new()
	_preview.custom_minimum_size = Vector2(266.0, 170.0)
	view_panel.add_child(_preview)
	_preview_name = UITheme.make_label("", 20, UITheme.TEXT)
	_preview_name.clip_text = true
	_preview_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(_preview_name)
	_preview_sub = UITheme.make_label("", 12, UITheme.ACCENT)
	_preview_sub.clip_text = true
	_preview_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(_preview_sub)
	_preview_desc = UITheme.make_label("", 13, UITheme.TEXT_DIM)
	_preview_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_desc.custom_minimum_size = Vector2(270.0, 0.0)
	box.add_child(_preview_desc)
	_preview_weapons = UITheme.make_label("", 12, UITheme.TEXT)
	_preview_weapons.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_weapons.custom_minimum_size = Vector2(270.0, 0.0)
	box.add_child(_preview_weapons)
	_preview_bars = _stat_bars(box)
	box.add_child(UITheme.separator())
	_roster = RichTextLabel.new()
	_roster.bbcode_enabled = true
	_roster.scroll_active = true
	_roster.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roster.custom_minimum_size = Vector2(270.0, 90.0)
	_roster.add_theme_font_size_override("normal_font_size", 13)
	_roster.add_theme_font_size_override("bold_font_size", 14)
	box.add_child(_roster)
	return panel


func _stat_bars(parent: Control) -> Array[ProgressBar]:
	var bars: Array[ProgressBar] = []
	for i in GameDB.STAT_NAMES.size():
		var row := HBoxContainer.new()
		var lbl := UITheme.make_label(str(GameDB.STAT_NAMES[i]), 12, UITheme.TEXT_DIM)
		lbl.custom_minimum_size = Vector2(112.0, 0.0)
		row.add_child(lbl)
		var bar := UITheme.progress_bar(UITheme.NEON.lerp(UITheme.ACCENT, float(i) / 3.0), 7.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		parent.add_child(row)
		bars.append(bar)
	return bars


func _add_option(parent: Control, label: String, items: Array, selected: int, callback: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	var l := UITheme.make_label(label, 14, UITheme.TEXT_DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var o := OptionButton.new()
	for item in items:
		o.add_item(str(item))
	o.selected = clampi(selected, 0, items.size() - 1)
	o.fit_to_longest_item = false
	o.clip_text = true
	o.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	o.custom_minimum_size = Vector2(150.0, 36.0)
	o.add_theme_font_size_override("font_size", 14)
	o.item_selected.connect(callback)
	row.add_child(o)
	parent.add_child(row)
	return o


func _difficulty_names() -> Array:
	var names: Array = []
	for d: Dictionary in GameDB.DIFFICULTY_LEVELS:
		names.append(d["name"])
	return names


# --- Ангар -------------------------------------------------------------------------------------------------
func _build_hangar() -> void:
	_hangar = MarginContainer.new()
	_hangar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side_name: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		_hangar.add_theme_constant_override(side_name, 18)
	add_child(_hangar)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_hangar.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := UITheme.make_label("АНГАР", 28, UITheme.NEON)
	UITheme.glow_label(title, UITheme.NEON, 2, 10)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_header_hint("ОКРАСКА:"))
	var group := ButtonGroup.new()
	for team in 2:
		var b := UITheme.make_button(GameDB.team_name(team), Vector2(130.0, 40.0), 16)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = team == 0
		b.add_theme_color_override("font_color", GameDB.team_color(team))
		b.pressed.connect(func() -> void:
			_hangar_team = team
			_show_hangar_vehicle(_hangar_viewer.current_type)
		)
		header.add_child(b)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)
	var list_panel := PanelContainer.new()
	list_panel.add_theme_stylebox_override("panel", UITheme.glass_panel())
	list_panel.custom_minimum_size = Vector2(290.0, 0.0)
	body.add_child(list_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var sections := [["ПОРШНЕВЫЕ ИСТРЕБИТЕЛИ", "fighter", "prop"], ["РЕАКТИВНЫЕ ИСТРЕБИТЕЛИ", "fighter", "jet"], ["УДАРНЫЕ САМОЛЁТЫ", "strike", ""], ["ПВО И ФЛОТ", "", ""]]
	var list_group := ButtonGroup.new()
	var first := ""
	for sec: Array in sections:
		list.add_child(UITheme.section_title(str(sec[0]), 13))
		for t: String in GameDB.VEHICLE_ORDER:
			var info := GameDB.vehicle_info(t)
			var role := str(sec[1])
			var era := str(sec[2])
			if role == "" and GameDB.is_aircraft(t):
				continue
			if role != "" and GameDB.role_of(t) != role:
				continue
			if era != "" and str(info.get("era", "")) != era:
				continue
			var b := UITheme.make_button(GameDB.vehicle_name(t, 0), Vector2(0.0, 36.0), 15)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.toggle_mode = true
			b.button_group = list_group
			b.icon = IconFactory.get_icon(str(info.get("icon", "fighter")), 24, UITheme.NEON)
			b.pressed.connect(_show_hangar_vehicle.bind(t))
			list.add_child(b)
			if first == "":
				first = t
				b.button_pressed = true
	var view_panel := PanelContainer.new()
	view_panel.add_theme_stylebox_override("panel", UITheme.glass_panel(Color(0.4, 0.8, 1.0, 0.18), Color(0.02, 0.04, 0.06, 0.94)))
	view_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(view_panel)
	_hangar_viewer = ModelViewer.new()
	view_panel.add_child(_hangar_viewer)
	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", UITheme.glass_panel())
	info_panel.custom_minimum_size = Vector2(320.0, 0.0)
	body.add_child(info_panel)
	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 8)
	info_panel.add_child(info_box)
	_hangar_title = UITheme.make_label("", 24, UITheme.TEXT)
	info_box.add_child(_hangar_title)
	_hangar_sub = UITheme.make_label("", 13, UITheme.ACCENT)
	_hangar_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_box.add_child(_hangar_sub)
	_hangar_desc = UITheme.make_label("", 14, UITheme.TEXT_DIM)
	_hangar_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hangar_desc.custom_minimum_size = Vector2(290.0, 0.0)
	info_box.add_child(_hangar_desc)
	info_box.add_child(UITheme.section_title("ВООРУЖЕНИЕ", 13))
	_hangar_weapons = UITheme.make_label("", 13, UITheme.TEXT)
	_hangar_weapons.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hangar_weapons.custom_minimum_size = Vector2(290.0, 0.0)
	info_box.add_child(_hangar_weapons)
	info_box.add_child(UITheme.section_title("ХАРАКТЕРИСТИКИ", 13))
	_hangar_bars = _stat_bars(info_box)
	info_box.add_child(UITheme.make_label("Перетащите модель мышью · колесо — масштаб", 12, UITheme.TEXT_DIM))
	var bottom := HBoxContainer.new()
	root.add_child(bottom)
	var back := UITheme.make_button("НАЗАД", Vector2(170.0, 52.0), 19)
	back.pressed.connect(_show_main)
	bottom.add_child(back)
	_hangar.set_meta("first", first)


func _vehicle_text(type_id: String) -> Dictionary:
	var info := GameDB.vehicle_info(type_id)
	var sub := GameDB.vehicle_role(type_id)
	var nation := GameDB.nation_name(type_id)
	if nation != "":
		sub += " · " + nation
	var extra := ""
	if GameDB.is_aircraft(type_id):
		var fl: Dictionary = info.get("flight", {})
		extra = "Макс. скорость %d км/ч · прочность %d" % [int(float(fl.get("max", 0.0)) * 3.6), int(float(info.get("hp", 0.0)))]
		sub += " · " + ("реактивный" if str(info.get("era", "")) == "jet" else "поршневой")
	return {"name": GameDB.vehicle_name(type_id, _hangar_team), "sub": sub, "desc": str(info.get("desc", "")), "weapons": str(info.get("weapons", "")), "extra": extra, "stats": info.get("stats", [0.5, 0.5, 0.5, 0.5])}


func _show_hangar_vehicle(type_id: String) -> void:
	if type_id == "":
		return
	var tx := _vehicle_text(type_id)
	_hangar_viewer.show_vehicle(type_id, _hangar_team)
	_hangar_title.text = str(tx["name"])
	_hangar_sub.text = str(tx["sub"]).to_upper()
	_hangar_desc.text = str(tx["desc"])
	_hangar_weapons.text = str(tx["weapons"]) + ("\n" + str(tx["extra"]) if str(tx["extra"]) != "" else "")
	var stats: Array = tx["stats"]
	for i in _hangar_bars.size():
		_hangar_bars[i].value = float(stats[i]) if i < stats.size() else 0.0


# --- Экран подготовки ---------------------------------------------------------------------------------------
func _build_loading() -> void:
	_loading = ColorRect.new()
	(_loading as ColorRect).color = Color(0.01, 0.02, 0.035, 0.96)
	_loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading.visible = false
	add_child(_loading)
	var l := UITheme.make_label("ПОДГОТОВКА К ВЫЛЕТУ…", 34, UITheme.NEON, HORIZONTAL_ALIGNMENT_CENTER)
	UITheme.glow_label(l, UITheme.NEON, 3, 14)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	_loading.add_child(l)


# --- Переходы между экранами ------------------------------------------------------------------------------
func _show_only(screen: Control) -> void:
	for s: Control in [_main, _lobby, _hangar, _settings_panel]:
		s.visible = s == screen


func _show_main() -> void:
	_show_only(_main)


func _show_settings() -> void:
	_show_only(_settings_panel)
	_settings_panel.position = ((size - _settings_panel.size) * 0.5).max(Vector2.ZERO)


func _show_hangar() -> void:
	_show_only(_hangar)
	if _hangar_viewer.current_type == "":
		_show_hangar_vehicle(str(_hangar.get_meta("first", "bf109")))


func _show_lobby() -> void:
	GlobalBattleManager.prepare_lobby()
	_show_only(_lobby)
	_rebuild_selector()
	var sel := GameSettings.map_id
	if _map_buttons.has(sel):
		(_map_buttons[sel] as Button).set_pressed_no_signal(true)


func _rebuild_selector() -> void:
	_slot_selector.setup(GlobalBattleManager.player_team, false)
	for team in 2:
		_team_buttons[team].set_pressed_no_signal(team == GlobalBattleManager.player_team)
	_refresh_lobby()


func _refresh_lobby() -> void:
	if _lobby == null or not _lobby.visible:
		return
	var gbm := GlobalBattleManager
	var t := ""
	for team in 2:
		var hex := GameDB.team_color(team).to_html(false)
		var mine := " (вы)" if team == gbm.player_team else ""
		t += "[color=#%s][b]%s%s[/b][/color]\n" % [hex, GameDB.team_name(team), mine]
		for p in gbm.get_team_participants(team):
			var who := "[color=#ffb020]Вы[/color]" if p.is_player else p.name
			var label := p.get_vehicle_label() if p.vehicle_type != "" else "[color=#667]—[/color]"
			t += "  %s — %s\n" % [who, label]
	_roster.text = t
	var chosen := gbm.player.vehicle_type if gbm.player != null else ""
	_start_button.disabled = chosen == ""
	var map_text := MapPresets.map_name(GameSettings.map_id)
	if chosen == "":
		_selected_label.text = "Карта: %s · выберите технику." % map_text
		if _preview.current_type == "":
			var fighters := GameDB.types_with_role("fighter", gbm.air_era)
			if not fighters.is_empty():
				_on_vehicle_hovered(fighters[0])
	else:
		var cat := GameDB.category_of(chosen)
		_selected_label.text = "Карта: %s · %s — старт: %s" % [map_text, GameDB.vehicle_name(chosen, gbm.player_team), str(GameDB.CATEGORY_SPAWN[cat])]
		_on_vehicle_hovered(chosen)
	_slot_selector.refresh()


func _on_vehicle_hovered(type_id: String) -> void:
	if _preview == null or not _lobby.visible:
		return
	var tx := _vehicle_text(type_id)
	_preview.show_vehicle(type_id, GlobalBattleManager.player_team)
	_preview_name.text = GameDB.vehicle_name(type_id, GlobalBattleManager.player_team)
	_preview_sub.text = str(tx["sub"]).to_upper()
	_preview_desc.text = str(tx["desc"])
	_preview_weapons.text = str(tx["weapons"])
	var stats: Array = tx["stats"]
	for i in _preview_bars.size():
		_preview_bars[i].value = float(stats[i]) if i < stats.size() else 0.0


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


func _on_map_selected(map_id: String) -> void:
	GameSettings.map_id = map_id
	GameSettings.save_settings()
	GlobalBattleManager.map_choice = map_id
	_refresh_lobby()


func _on_era(index: int) -> void:
	GameSettings.air_era = index
	GameSettings.save_settings()
	GlobalBattleManager.prepare_lobby()
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
	GameSettings.time_limit_min = [10, 15, 20, 30][index]
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


# --- Превью карт (фоновый поток) -----------------------------------------------------------------------------
func _start_thumbnails() -> void:
	var missing: Array[String] = []
	for map_id: String in MapPresets.ORDER:
		if MapPreview.has_thumbnail(map_id, 256):
			(_map_thumbs[map_id] as TextureRect).texture = MapPreview.thumbnail(map_id, 256)
		else:
			missing.append(map_id)
	if missing.is_empty() or (GlobalBattleManager.smoke_test and not GlobalBattleManager.smoke_menu):
		return
	_thumb_thread = Thread.new()
	_thumb_thread.start(func() -> Dictionary:
		var result := {}
		for map_id in missing:
			result[map_id] = MapPreview.thumbnail_image(map_id, 256)
		return result
	)


func _poll_thumbnails() -> void:
	if _thumb_thread == null or _thumb_thread.is_alive():
		return
	var images: Dictionary = _thumb_thread.wait_to_finish()
	_thumb_thread = null
	for map_id: String in images.keys():
		var tex := ImageTexture.create_from_image(images[map_id])
		MapPreview.store_thumbnail(map_id, 256, tex)
		if _map_thumbs.has(map_id):
			(_map_thumbs[map_id] as TextureRect).texture = tex


# --- Анимация ---------------------------------------------------------------------------------------------------
func _on_track_changed(title: String) -> void:
	if _now_playing != null:
		_now_playing.text = ("♪  " if ThemeDB.fallback_font.has_char(0x266A) else "") + title


func _process(delta: float) -> void:
	_time += delta
	_poll_thumbnails()
	if _clock != null:
		var t := Time.get_time_dict_from_system()
		_clock.text = "%02d:%02d" % [int(t["hour"]), int(t["minute"])]
	if _title != null:
		_title.modulate.a = 1.0 if fmod(_time, 6.0) > 0.1 else 0.8
	for i in _eq_bars.size():
		var h := 5.0 + 11.0 * absf(sin(_time * (3.1 + float(i) * 1.7) + float(i)))
		_eq_bars[i].custom_minimum_size = Vector2(4.0, h)
	_tip_timer += delta
	if _tip_timer > 9.0 and _tip_label != null:
		_tip_timer = 0.0
		_tip_index = (_tip_index + 1) % TIPS.size()
		_tip_label.text = TIPS[_tip_index]
	if _map_info != null and _backdrop != null:
		var preset := MapPresets.get_map(_backdrop.map_id)
		_map_info.text = "%s\n%s" % [str(preset.get("name", "")), str(preset.get("subtitle", ""))]
	if _settings_panel != null and _settings_panel.visible:
		_settings_panel.position = ((size - _settings_panel.size) * 0.5).max(Vector2.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _lobby.visible or _settings_panel.visible or _hangar.visible:
			_show_main()
			get_viewport().set_input_as_handled()


# --- Автотест ----------------------------------------------------------------------------------------------------
## Обход экранов меню со скриншотами (--smoke-test --smoke-menu --shots=DIR).
func _run_menu_tour() -> void:
	await get_tree().create_timer(3.0).timeout
	GlobalBattleManager.save_screenshot()
	_show_lobby()
	await get_tree().create_timer(4.5).timeout
	GlobalBattleManager.save_screenshot()
	var fighters := GameDB.types_with_role("fighter", GlobalBattleManager.air_era)
	if not fighters.is_empty():
		GlobalBattleManager.request_player_slot(fighters[1 % fighters.size()])
		_refresh_lobby()
	await get_tree().create_timer(1.5).timeout
	GlobalBattleManager.save_screenshot()
	_show_hangar()
	await get_tree().create_timer(1.8).timeout
	GlobalBattleManager.save_screenshot()
	_show_settings()
	await get_tree().create_timer(0.8).timeout
	GlobalBattleManager.save_screenshot()
	get_tree().quit(0)


func _run_smoke_sequence() -> void:
	await get_tree().create_timer(1.6).timeout
	_show_lobby()
	var wanted := GameDB.resolve_id(GlobalBattleManager.smoke_vehicle)
	if wanted == "" or not GlobalBattleManager.request_player_slot(wanted):
		var free := GlobalBattleManager.free_slot_types(GlobalBattleManager.player_team)
		if not free.is_empty():
			GlobalBattleManager.request_player_slot(free[0])
	_refresh_lobby()
	await get_tree().create_timer(1.4).timeout
	_on_start()
