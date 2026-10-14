class_name MainMenu
extends Control

const MAP_SCENE_PATH: String = "res://map_view.tscn"
const TUTORIAL_MAP_SCENE_PATH: String = "res://tutorial_map_view.tscn"

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "MenuUILayer"
	add_child(canvas)

	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	# Fundo decorativo — mesmo tabuleiro xadrez sutil usado no mapa, só
	# pra não ficar uma tela totalmente vazia atrás do título.
	var board_bg = ColorRect.new()
	board_bg.color = Color(0.08, 0.09, 0.13, 1.0)
	board_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(board_bg)

	var center_box = VBoxContainer.new()
	center_box.set_anchors_preset(Control.PRESET_CENTER)
	center_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 22)
	canvas.add_child(center_box)

	var title = Label.new()
	title.text = "DOMINA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	title.add_theme_constant_override("outline_size", 12)
	center_box.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "um roguelite de damas"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
	center_box.add_child(subtitle)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(10, 30)
	center_box.add_child(spacer)

	var play_btn = _make_menu_button("JOGAR", Color(0.12, 0.22, 0.16), Color(0.3, 0.9, 0.4))
	play_btn.pressed.connect(_on_play_pressed)
	center_box.add_child(play_btn)

	var tutorial_btn = _make_menu_button("TUTORIAL", Color(0.12, 0.16, 0.24), Color(0.35, 0.7, 1.0))
	tutorial_btn.pressed.connect(_on_tutorial_pressed)
	center_box.add_child(tutorial_btn)

	var quit_btn = _make_menu_button("SAIR", Color(0.2, 0.1, 0.12), Color(0.8, 0.3, 0.35))
	quit_btn.pressed.connect(_on_quit_pressed)
	center_box.add_child(quit_btn)

func _make_menu_button(text: String, bg_color: Color, border_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(360, 68)
	btn.add_theme_font_size_override("font_size", 28)
	PixelUI.skin_button(btn, border_color)
	return btn

func _on_play_pressed() -> void:
	if RunManager != null:
		RunManager.start_new_run()
	get_tree().call_deferred("change_scene_to_file", MAP_SCENE_PATH)

func _on_tutorial_pressed() -> void:
	if TutorialManager != null:
		TutorialManager.start_tutorial()
	get_tree().call_deferred("change_scene_to_file", TUTORIAL_MAP_SCENE_PATH)

func _on_quit_pressed() -> void:
	get_tree().quit()
