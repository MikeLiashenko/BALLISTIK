class_name UITheme
extends RefCounted
## Тёмная неоновая тема «командного пункта»: цвета, стили панелей и кнопок, шрифты.
## Всё создаётся в коде (StyleBoxFlat, FontVariation на базе встроенного шрифта).

const BG := Color(0.02, 0.035, 0.06)
const PANEL := Color(0.03, 0.08, 0.12, 0.86)
const PANEL_SOLID := Color(0.035, 0.075, 0.11, 0.97)
const NEON := Color(0.1, 0.9, 1.0)
const NEON_DIM := Color(0.1, 0.9, 1.0, 0.35)
const ACCENT := Color(1.0, 0.69, 0.13)
const DANGER := Color(1.0, 0.26, 0.24)
const SUCCESS := Color(0.35, 1.0, 0.55)
const TEXT := Color(0.82, 0.93, 1.0)
const TEXT_DIM := Color(0.55, 0.68, 0.78)

static var _theme: Theme = null
static var _title_font: FontVariation = null
static var _bold_font: FontVariation = null


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = bold_font()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "Button", button_style(NEON_DIM, Color(0.03, 0.1, 0.15, 0.9)))
	t.set_stylebox("hover", "Button", button_style(NEON, Color(0.05, 0.18, 0.25, 0.95), 10))
	t.set_stylebox("pressed", "Button", button_style(ACCENT, Color(0.12, 0.1, 0.03, 0.95), 12))
	t.set_stylebox("disabled", "Button", button_style(Color(0.35, 0.4, 0.45, 0.35), Color(0.05, 0.06, 0.07, 0.8)))
	t.set_stylebox("focus", "Button", button_style(ACCENT, Color(0.0, 0.0, 0.0, 0.0)))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1.0, 1.0, 1.0))
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.5, 0.55))
	t.set_color("font_focus_color", "Button", Color(1.0, 1.0, 1.0))
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_stylebox("background", "ProgressBar", flat(Color(0.05, 0.1, 0.14, 0.9), Color(0.1, 0.9, 1.0, 0.25), 1, 3))
	t.set_stylebox("fill", "ProgressBar", flat(NEON, NEON, 0, 3))
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_stylebox("slider", "HSlider", flat(Color(0.05, 0.12, 0.17), NEON_DIM, 1, 3, 4))
	t.set_stylebox("grabber_area", "HSlider", flat(NEON, NEON, 0, 3, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(ACCENT, ACCENT, 0, 3, 4))
	t.set_stylebox("normal", "OptionButton", button_style(NEON_DIM, Color(0.03, 0.1, 0.15, 0.9)))
	t.set_stylebox("hover", "OptionButton", button_style(NEON, Color(0.05, 0.18, 0.25, 0.95)))
	t.set_stylebox("pressed", "OptionButton", button_style(ACCENT, Color(0.12, 0.1, 0.03, 0.95)))
	t.set_stylebox("focus", "OptionButton", button_style(ACCENT, Color(0.0, 0.0, 0.0, 0.0)))
	t.set_stylebox("panel", "PopupMenu", flat(PANEL_SOLID, NEON_DIM, 1, 4, 6))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", ACCENT)
	t.set_stylebox("hover", "PopupMenu", flat(Color(0.06, 0.2, 0.28), NEON_DIM, 0, 2, 4))
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color(1.0, 1.0, 1.0))
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_stylebox("normal", "CheckButton", flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 4))
	t.set_stylebox("hover", "CheckButton", flat(Color(0.05, 0.15, 0.2, 0.6), Color(0, 0, 0, 0), 0, 3, 4))
	t.set_stylebox("pressed", "CheckButton", flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 4))
	t.set_stylebox("focus", "CheckButton", flat(Color(0, 0, 0, 0), NEON_DIM, 1, 3, 4))
	t.set_stylebox("panel", "TooltipPanel", flat(PANEL_SOLID, NEON_DIM, 1, 4, 6))
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	_theme = t
	return _theme


## Жирный шрифт интерфейса на основе встроенного шрифта движка (без внешних файлов).
static func bold_font() -> FontVariation:
	if _bold_font != null:
		return _bold_font
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = 0.35
	f.spacing_glyph = 1
	_bold_font = f
	return f


## Шрифт заголовка BALLISTIK: усиленный, с разрядкой.
static func title_font() -> FontVariation:
	if _title_font != null:
		return _title_font
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = 1.1
	f.spacing_glyph = 14
	_title_font = f
	return f


static func flat(bg: Color, border: Color, border_width: int = 1, radius: int = 4, margin: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s


static func panel_style(border: Color = NEON_DIM, bg: Color = PANEL) -> StyleBoxFlat:
	var s := flat(bg, border, 1, 6, 14)
	s.shadow_color = Color(border, 0.18)
	s.shadow_size = 8
	return s


static func button_style(border: Color, bg: Color, glow: int = 0) -> StyleBoxFlat:
	var s := flat(bg, border, 2, 4, 10)
	s.content_margin_left = 18.0
	s.content_margin_right = 18.0
	if glow > 0:
		s.shadow_color = Color(border, 0.35)
		s.shadow_size = glow
	return s


static func make_label(text: String, font_size: int = 18, color: Color = TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func make_button(text: String, min_size: Vector2 = Vector2(260.0, 54.0), font_size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			SoundFX.play_ui("ui_hover", -18.0)
	)
	b.pressed.connect(func() -> void:
		SoundFX.play_ui("ui_click", -8.0)
	)
	return b


## Неоновая подсветка текста (контур + свечение тенью).
static func glow_label(l: Label, color: Color, outline: int = 4, glow_size: int = 12) -> void:
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(color, 0.45))
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(color, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", glow_size)


static func progress_bar(color: Color = NEON, height: float = 10.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0.0
	p.max_value = 1.0
	p.step = 0.001
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0.0, height)
	p.add_theme_stylebox_override("fill", flat(color, color, 0, 3))
	return p


static func separator(color: Color = NEON_DIM) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0.0, 2.0)
	return r
