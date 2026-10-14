class_name ActionCardTooltip
extends CanvasLayer

var panel: PanelContainer
var title_label: Label
var rarity_label: Label
var divider: ColorRect
var desc_label: Label

# Largura substancialmente maior para acomodar textos legíveis
const TOOLTIP_WIDTH: float = 440.0

func _init() -> void:
	layer = 150
	visible = false

func _ready() -> void:
	layer = 150
	visible = false
	_build_ui()

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var header_hbox = HBoxContainer.new()
	header_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header_hbox)

	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 28) # Título gigante
	title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.40))
	title_label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 1.0))
	title_label.add_theme_constant_override("outline_size", 10)
	header_hbox.add_child(title_label)

	rarity_label = Label.new()
	rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rarity_label.add_theme_font_size_override("font_size", 20)
	header_hbox.add_child(rarity_label)

	divider = ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 3)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(divider)

	desc_label = Label.new()
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.custom_minimum_size = Vector2(TOOLTIP_WIDTH - 40.0, 0)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 22) # Efeito ampliado
	desc_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	desc_label.add_theme_constant_override("line_spacing", 6)
	vbox.add_child(desc_label)

func show_tooltip(card: ActionCard, screen_pos: Vector2) -> void:
	if card == null:
		hide_tooltip()
		return

	var rar_color: Color = ActionCardVisual.get_rarity_color(card.rarity)

	panel.add_theme_stylebox_override(
		"panel",
		PixelUI.make_pixel_panel(Color(0.05, 0.07, 0.11, 0.98), rar_color, 18)
	)
	divider.color = Color(rar_color.r, rar_color.g, rar_color.b, 0.85)

	title_label.text = card.name.to_upper()
	rarity_label.text = "[ %s ]" % ActionCard.get_rarity_name(card.rarity)
	rarity_label.add_theme_color_override("font_color", rar_color)
	desc_label.text = card.description

	panel.modulate = Color.TRANSPARENT
	visible = true
	panel.reset_size()

	await get_tree().process_frame

	if not visible:
		return

	var vp_size = panel.get_viewport_rect().size
	var box_w = panel.size.x
	var box_h = panel.size.y
	var margin = 20.0

	var target_x = screen_pos.x - (box_w / 2.0)
	var target_y = screen_pos.y - box_h - 20.0

	target_x = clampf(target_x, margin, max(margin, vp_size.x - box_w - margin))
	target_y = clampf(target_y, margin, max(margin, vp_size.y - box_h - margin))

	panel.position = Vector2(target_x, target_y)
	panel.modulate = Color.WHITE

func hide_tooltip() -> void:
	visible = false
	panel.modulate = Color.TRANSPARENT
