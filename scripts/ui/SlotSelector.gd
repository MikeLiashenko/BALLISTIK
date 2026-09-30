class_name SlotSelector
extends VBoxContainer
## Панель выбора техники по слотам: вкладки категорий (Авиация / Наземная ПВО / Военный Флот) и сетка
## карточек. Карточка (целиком кнопка) показывает название, класс и страну, счётчик занятых мест
## («[1/1]»), индикаторы слотов; если места заняты — карточка заблокирована (ботов своей команды игрок
## вытесняет).
## Техника сгруппирована по ролям с лимитом каждой роли в команде (истребители и ударные самолёты;
## ЗСУ, ЗРК и зенитные орудия; катера и корабли); набор зависит от эпохи боя.
## Используется в лобби главного меню и на экране возрождения в бою.

signal vehicle_chosen(type_id: String)
signal vehicle_hovered(type_id: String)

var team: int = 0
var compact: bool = false
var current_category: int = GameDB.Category.AIR

var _tab_buttons: Dictionary = {}
var _grid_box: VBoxContainer = null
var _cards: Dictionary = {}


func setup(p_team: int, p_compact: bool = false) -> void:
	team = p_team
	compact = p_compact
	_build()
	if not GlobalBattleManager.slots_changed.is_connected(_on_slots_changed):
		GlobalBattleManager.slots_changed.connect(_on_slots_changed)
	refresh()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_tab_buttons.clear()
	_cards.clear()
	add_theme_constant_override("separation", 10)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	add_child(tabs)
	var group := ButtonGroup.new()
	for cat: int in GameDB.CATEGORY_ORDER:
		var b := UITheme.make_button(str(GameDB.CATEGORY_TITLES[cat]), Vector2(0.0, 44.0 if not compact else 42.0), 15)
		b.toggle_mode = true
		b.button_group = group
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		UITheme.narrow_button(b)
		b.add_theme_constant_override("h_separation", 6)
		b.icon = IconFactory.get_icon(str(GameDB.CATEGORY_ICONS[cat]), 22, UITheme.NEON)
		b.expand_icon = false
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_tab_pressed.bind(cat))
		tabs.add_child(b)
		_tab_buttons[cat] = b
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_grid_box = VBoxContainer.new()
	_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_grid_box)
	(_tab_buttons[current_category] as Button).button_pressed = true
	_rebuild_cards()


func _on_tab_pressed(cat: int) -> void:
	current_category = cat
	_rebuild_cards()


## Открыть вкладку категории техники.
func show_category(cat: int) -> void:
	(_tab_buttons[cat] as Button).button_pressed = true
	_on_tab_pressed(cat)


func _rebuild_cards() -> void:
	for child in _grid_box.get_children():
		child.queue_free()
	_cards.clear()
	var era := GlobalBattleManager.air_era
	var roles: Array = []
	match current_category:
		GameDB.Category.AIR:
			roles = ["fighter", "strike"]
		GameDB.Category.GROUND:
			roles = ["spaag", "sam", "flak"]
		_:
			roles = ["boat", "ship"]
	var columns := 2 if not compact else 3
	for role: String in roles:
		var types: Array = GameDB.types_with_role(role, era)
		if types.is_empty():
			continue
		var head := UITheme.section_title("%s · лимит в команде %d" % [str(GameDB.ROLE_GROUPS[role]), int(GameDB.ROLE_LIMITS[role])], 13)
		_grid_box.add_child(head)
		var grid := GridContainer.new()
		grid.columns = columns
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid_box.add_child(grid)
		for type_id: String in types:
			grid.add_child(_make_card(type_id))
	refresh()


func _make_card(type_id: String) -> Button:
	var info := GameDB.vehicle_info(type_id)
	# Вся карточка — кнопка: крупная цель для мыши, пальца и фокуса геймпада.
	var card := Button.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 72.0)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.focus_mode = Control.FOCUS_ALL
	card.pressed.connect(_on_choose.bind(type_id))
	card.mouse_entered.connect(func() -> void: vehicle_hovered.emit(type_id))
	card.focus_entered.connect(func() -> void: vehicle_hovered.emit(type_id))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10.0
	row.offset_right = -10.0
	row.offset_top = 6.0
	row.offset_bottom = -6.0
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var icon := TextureRect.new()
	icon.texture = IconFactory.get_icon(str(info.get("icon", "fighter")), 64, UITheme.NEON)
	icon.custom_minimum_size = Vector2(40.0, 40.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var name_label := _card_label(GameDB.vehicle_name(type_id, team), 16, UITheme.TEXT)
	texts.add_child(name_label)
	var sub := GameDB.vehicle_role(type_id)
	var nation := GameDB.nation_name(type_id)
	if nation != "":
		sub = "%s · %s" % [sub, nation]
	texts.add_child(_card_label(sub.to_upper(), 11, UITheme.TEXT_DIM))
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 6)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(status)
	var counter := _card_label("", 13, UITheme.NEON)
	counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(counter)
	var state := _card_label("", 11, UITheme.NEON)
	state.clip_text = false
	state.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(state)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 3)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(pips)
	for i in GameDB.max_slots(type_id):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(12.0, 5.0)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	_cards[type_id] = {"card": card, "counter": counter, "pips": pips, "state": state}
	return card


func _card_label(text: String, font_size: int, color: Color) -> Label:
	var l := UITheme.make_label(text, font_size, color)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _style_card(card: Button, mine: bool, blocked: bool) -> void:
	var normal := UITheme.card_style(mine, blocked)
	var hover := UITheme.card_style(mine, blocked)
	hover.bg_color = hover.bg_color.lightened(0.07)
	hover.border_color = UITheme.ACCENT if mine else UITheme.NEON
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = UITheme.NEON
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(8)
	for state_name: String in ["normal", "disabled"]:
		card.add_theme_stylebox_override(state_name, normal)
	for state_name: String in ["hover", "pressed", "hover_pressed"]:
		card.add_theme_stylebox_override(state_name, hover)
	card.add_theme_stylebox_override("focus", focus)


func _on_choose(type_id: String) -> void:
	vehicle_chosen.emit(type_id)


func _on_slots_changed(changed_team: int) -> void:
	if changed_team == team and is_inside_tree():
		refresh()


## Обновляет счётчики слотов, индикаторы и доступность кнопок выбора.
func refresh() -> void:
	var gbm := GlobalBattleManager
	var me := gbm.player
	for type_id: String in _cards.keys():
		var entry: Dictionary = _cards[type_id]
		var used := gbm.slot_count(team, type_id)
		var max_slots := gbm.slot_max(type_id)
		var mine := me != null and me.vehicle_type == type_id and me.team == team
		var role := GameDB.role_of(type_id)
		var bot_held := false
		for p in gbm.get_slot_holders(team, type_id):
			if not p.is_human:
				bot_held = true
		var role_blocked := gbm.role_full(team, role) and not (me != null and me.vehicle_type != "" and GameDB.role_of(me.vehicle_type) == role)
		var full := used >= max_slots or role_blocked
		var counter: Label = entry["counter"]
		counter.text = "[%d/%d]%s" % [used, max_slots, "  · лимит роли" if role_blocked and used < max_slots else ""]
		counter.add_theme_color_override("font_color", UITheme.ACCENT if mine else (UITheme.DANGER if full and not bot_held else UITheme.NEON))
		var pips: HBoxContainer = entry["pips"]
		for i in pips.get_child_count():
			(pips.get_child(i) as ColorRect).color = (UITheme.ACCENT if mine else UITheme.NEON) if i < used else Color(0.15, 0.25, 0.3)
		var can_bump := me != null and me.team == team and not me.has_live_vehicle() and (bot_held or role_blocked)
		var blocked := full and not can_bump and not mine
		var state: Label = entry["state"]
		if mine:
			state.text = "ВЫБРАНО"
			state.add_theme_color_override("font_color", UITheme.ACCENT)
		elif blocked:
			state.text = "ЗАНЯТО"
			state.add_theme_color_override("font_color", UITheme.DANGER)
		elif full:
			state.text = "ЗАМЕНИТЬ БОТА"
			state.add_theme_color_override("font_color", UITheme.NEON)
		else:
			state.text = ""
		var card: Button = entry["card"]
		card.disabled = blocked
		card.tooltip_text = "Место занято" if blocked else "Выбрать технику"
		_style_card(card, mine, blocked)
	var era := gbm.air_era
	for cat: int in _tab_buttons.keys():
		var free := 0
		for t in GameDB.types_in_category(cat, era):
			if gbm.is_slot_free(team, t):
				free += 1
		var b: Button = _tab_buttons[cat]
		b.text = str(GameDB.CATEGORY_TITLES[cat])
		b.tooltip_text = "Доступных типов техники: %d" % free
