extends RefCounted
const FONT := preload("res://assets/fonts/TensionSansSC.ttf")
const INK := Color("e5edf0")
const MUTED := Color("99b1bd")
const MINT := Color("6ee3c1")
const ORANGE := Color("ffad59")
const PAPER := Color("e9efeb")
const DARK := Color("162c39")

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = 17
	return t

static func panel(color: Color, padding: int = 20, radius: int = 12, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(padding)
	s.set_border_width_all(1)
	s.border_color = border
	s.shadow_color = Color(0,0.015,0.025,0.25)
	s.shadow_size = 12
	s.shadow_offset = Vector2(0,5)
	return s

static func text(value: String, size: int, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_color_override("font_shadow_color",Color(0.02,0.06,0.08,0.8))
	l.add_theme_constant_override("shadow_offset_y",2)
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	return l

static func button(value: String, callback: Callable, accent: bool = false) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size.y = 36
	b.focus_mode = Control.FOCUS_NONE
	var base := ORANGE if accent else Color("213e4e")
	b.add_theme_stylebox_override("normal",panel(base,9,12))
	b.add_theme_stylebox_override("hover",panel(base.lightened(0.14),9,12,MINT))
	b.add_theme_stylebox_override("pressed",panel(base.darkened(0.10),9,12))
	b.add_theme_color_override("font_color",DARK if accent else INK)
	b.add_theme_color_override("font_hover_color",DARK if accent else INK)
	b.add_theme_color_override("font_pressed_color",DARK if accent else INK)
	b.pressed.connect(callback)
	return b
