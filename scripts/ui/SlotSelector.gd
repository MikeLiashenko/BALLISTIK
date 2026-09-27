class_name SlotSelector
extends VBoxContainer
## Панель выбора техники по слотам: три вкладки категорий (Авиация / Наземная ПВО / Военный Флот)
## и карточки классов техники. Каждая карточка показывает счётчик занятых мест («МиГ-29 [1/2]»),
## индикаторы слотов и характеристики; если все слоты заняты — кнопка выбора заблокирована.
## Используется в лобби главного меню и на экране возрождения в бою.

signal vehicle_chosen(type_id: String)

var team: int = 0
var compact: bool = false
var selected_type: String = ""
var current_category: int = GameDB.Category.AIR

var _tab_buttons: Dictionary = {}
var _cards_box: HBoxContainer = null
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
	add_theme_constant_override("separation", 12)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	add_child(tabs)
	var group := ButtonGroup.new()
	for cat: int in GameDB.CATEGORY_ORDER:
		var b := UITheme.make_button(str(GameDB.CATEGORY_TITLES[cat]), Vector2(0.0, 52.0 if not compact else 46.0), 20 if not compact else 18)
		b.toggle_mode = true
		b.button_group = group
		b.icon = IconFactory.get_icon(str(GameDB.CATEGORY_ICONS[cat]), 32, UITheme.NEON)
		b.expand_icon = false
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_tab_pressed.bind(cat))
		tabs.add_child(b)
		_tab_buttons[cat] = b
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)
	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 14)
	_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cards_box)
	var first_tab: Button = _tab_buttons[current_category]
	first_tab.button_pressed = true
	_rebuild_cards()


func _on_tab_pressed(cat: int) -> void:
	current_category = cat
	_rebuild_cards()


func _rebuild_cards() -> void:
	for child in _cards_box.get_children():
		child.queue_free()
	_cards.clear()
	for type_id in GameDB.types_in_category(current_category):
		var card := _make_card(type_id)
		_cards_box.add_child(card)
	refresh()


func _make_card(type_id: String) -> PanelContainer:
	var info := GameDB.vehicle_info(type_id)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300.0 if not compact else 260.0, 0.0)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var icon := TextureRect.new()
	icon.texture = IconFactory.get_icon(str(info["icon"]), 64, UITheme.NEON)
	icon.custom_minimum_size = Vector2(56.0, 56.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)
	var name_label := UITheme.make_label(GameDB.vehicle_name(type_id, team), 24 if not compact else 21, UITheme.TEXT)
	titles.add_child(name_label)
	titles.add_child(UITheme.make_label(str(info["role"]).to_upper(), 13, UITheme.ACCENT))
	var counter := UITheme.make_label("", 20, UITheme.NEON)
	box.add_child(counter)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 6)
	box.add_child(pips)
	for i in GameDB.max_slots(type_id):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(26.0, 8.0)
		pips.add_child(pip)
	if not compact:
		var desc := UITheme.make_label(str(info["desc"]), 14, UITheme.TEXT_DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(260.0, 0.0)
		box.add_child(desc)
	box.add_child(UITheme.make_label(str(info["weapons"]), 13, UITheme.TEXT))
	var stats: Array = info["stats"]
	for i in stats.size():
		var row := HBoxContainer.new()
		var lbl := UITheme.make_label(str(GameDB.STAT_NAMES[i]), 12, UITheme.TEXT_DIM)
		lbl.custom_minimum_size = Vector2(104.0, 0.0)
		row.add_child(lbl)
		var bar := UITheme.progress_bar(UITheme.NEON.lerp(UITheme.ACCENT, float(i) / 3.0), 8.0)
		bar.value = float(stats[i])
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		box.add_child(row)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var button := UITheme.make_button("ВЫБРАТЬ", Vector2(0.0, 46.0), 19)
	button.pressed.connect(_on_choose.bind(type_id))
	box.add_child(button)
	_cards[type_id] = {"card": card, "counter": counter, "pips": pips, "button": button}
	return card


func _on_choose(type_id: String) -> void:
	vehicle_chosen.emit(type_id)


func _on_slots_changed(changed_team: int) -> void:
	if changed_team == team and is_inside_tree():
		refresh()


## Обновляет счётчики слотов, индикаторы и доступность кнопок выбора.
func refresh() -> void:
	var me := GlobalBattleManager.player
	for type_id: String in _cards.keys():
		var entry: Dictionary = _cards[type_id]
		var used := GlobalBattleManager.slot_count(team, type_id)
		var max_slots := GlobalBattleManager.slot_max(type_id)
		var mine := me != null and me.vehicle_type == type_id and me.team == team
		var counter: Label = entry["counter"]
		counter.text = "%s [%d/%d]" % [GameDB.vehicle_name(type_id, team), used, max_slots]
		var full := used >= max_slots
		counter.add_theme_color_override("font_color", UITheme.ACCENT if mine else (UITheme.DANGER if full else UITheme.NEON))
		var pips: HBoxContainer = entry["pips"]
		for i in pips.get_child_count():
			var pip := pips.get_child(i) as ColorRect
			pip.color = (UITheme.ACCENT if mine and i == used - 1 else UITheme.NEON) if i < used else Color(0.15, 0.25, 0.3)
		var button: Button = entry["button"]
		if mine:
			button.text = "ВЫБРАНО ✓" if ThemeDB.fallback_font.has_char(0x2713) else "ВЫБРАНО"
			button.disabled = false
		elif full:
			button.text = "СЛОТЫ ЗАНЯТЫ"
			button.disabled = true
		else:
			button.text = "ВЫБРАТЬ"
			button.disabled = false
		var card: PanelContainer = entry["card"]
		card.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.ACCENT if mine else (Color(0.5, 0.2, 0.2, 0.6) if full else UITheme.NEON_DIM)))
	for cat: int in _tab_buttons.keys():
		var b: Button = _tab_buttons[cat]
		var free := 0
		for t in GameDB.types_in_category(cat):
			free += maxi(GlobalBattleManager.slot_max(t) - GlobalBattleManager.slot_count(team, t), 0)
		b.text = "%s (%d)" % [str(GameDB.CATEGORY_TITLES[cat]), free]
		b.tooltip_text = "Свободных слотов в категории: %d" % free
