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

	# Fundo: universo com estrelas (procedural, atrás de tudo).
	add_child(SpaceBackground.new())

	var center_box = VBoxContainer.new()
	center_box.set_anchors_preset(Control.PRESET_CENTER)
	center_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 22)
	canvas.add_child(center_box)

	center_box.add_child(_make_logo())

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

# Logo em pixel art: escolhe entre a versão grande (640x256) e a pequena (320x128)
# a que der o maior tamanho com ESCALA INTEIRA que caiba na tela (sem borrar).
func _make_logo() -> Control:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var max_w: float = vp.x * 0.7
	var max_h: float = vp.y * 0.36
	var best_tex: Texture2D = null
	var best_scale: int = 1
	var best_w: float = 0.0
	for path in ["res://assets/sprites/ui/logo_domina.png", "res://assets/sprites/ui/logo_domina_pequena.png"]:
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		var k: int = maxi(1, int(minf(max_w / tex.get_width(), max_h / tex.get_height())))
		var w: float = tex.get_width() * k
		if w * k > 0 and w > best_w and tex.get_height() * k <= max_h * 1.05:
			best_tex = tex
			best_scale = k
			best_w = w
	if best_tex == null:
		var fallback = Label.new()
		fallback.text = "DOMINA"
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 84)
		return fallback
	var logo = TextureRect.new()
	logo.texture = best_tex
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_SCALE
	logo.custom_minimum_size = Vector2(best_tex.get_width() * best_scale, best_tex.get_height() * best_scale)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return logo

func _make_menu_button(text: String, bg_color: Color, border_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(360, 68)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
