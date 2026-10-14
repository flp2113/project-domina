class_name RuleCardTooltip
extends CanvasLayer

var panel: PanelContainer
var title_label: Label
var category_label: Label
var divider: ColorRect
var desc_label: Label

const TOOLTIP_WIDTH: float = 420.0

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

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	title_label = Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	title_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	title_label.add_theme_constant_override("outline_size", 8)
	vbox.add_child(title_label)

	category_label = Label.new()
	category_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	category_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(category_label)

	divider = ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 3)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(divider)

	desc_label = Label.new()
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.custom_minimum_size = Vector2(TOOLTIP_WIDTH - 36.0, 0)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 22)
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.93, 0.98))
	desc_label.add_theme_constant_override("line_spacing", 4)
	vbox.add_child(desc_label)

func show_tooltip(rule: RuleCard, screen_pos: Vector2) -> void:
	if rule == null:
		hide_tooltip()
		return

	var cat_color: Color = RuleCard.get_category_color(rule.category)

	# Atualiza o StyleBox do painel com a cor temática da regra na borda
	panel.add_theme_stylebox_override(
		"panel",
		PixelUI.make_pixel_panel(Color(0.06, 0.08, 0.12, 0.98), cat_color, 18)
	)

	# Atualiza o divisor com a cor temática correspondente
	divider.color = Color(cat_color.r, cat_color.g, cat_color.b, 0.75)

	title_label.text = rule.name.to_upper()
	category_label.text = "[ %s ]" % RuleCard.get_category_name(rule.category)
	category_label.add_theme_color_override("font_color", cat_color)
	desc_label.text = rule.description

	panel.modulate = Color.TRANSPARENT
	visible = true
	panel.reset_size()

	await get_tree().process_frame

	if not visible:
		return

	var vp_size = panel.get_viewport_rect().size
	var box_w = panel.size.x
	var box_h = panel.size.y
	var margin = 18.0

	var target_x = screen_pos.x + 20.0
	var target_y = screen_pos.y + 20.0

	if target_x + box_w > vp_size.x - margin:
		target_x = screen_pos.x - box_w - 20.0

	if target_y + box_h > vp_size.y - margin:
		target_y = screen_pos.y - box_h - 10.0

	target_x = clampf(target_x, margin, max(margin, vp_size.x - box_w - margin))
	target_y = clampf(target_y, margin, max(margin, vp_size.y - box_h - margin))

	panel.position = Vector2(target_x, target_y)
	panel.modulate = Color.WHITE

func hide_tooltip() -> void:
	visible = false
	panel.modulate = Color.TRANSPARENT
