class_name LawBoard
extends Control

# Quadro de Leis (2 colunas x 3 linhas) usado pela HUD do jogador e pela do
# inimigo. Desenha o sprite law_board.png (386x543, com 8 px transparentes
# ao redor — o controle ocupa só o CORPO de 370x527) e expõe 6 slots
# quadrados posicionados nas 6 células do quadro.

const TEXTURE_PATH := "res://assets/sprites/ui/law_board.png"
const _ART_SIZE := Vector2(386, 543)
const _BODY := Rect2(0, 0, 386, 543)
const _SLOT_ART_SIZE: float = 160.0
# Cantos superiores esquerdos dos 6 slots (px da arte), em ordem de leitura —
# centralizados nos 6 encaixes do sprite (157x157 em x=22/208, y=19/193/367).
const _SLOT_ORIGINS: Array[Vector2] = [
	Vector2(20.5, 17.5), Vector2(206.5, 17.5),
	Vector2(20.5, 191.5), Vector2(206.5, 191.5),
	Vector2(20.5, 365.5), Vector2(206.5, 365.5),
]

var slots: Array[Control] = []
var slot_size: float = 0.0

# board_height = altura final do corpo do quadro em px; a largura sai da
# proporção do sprite. tint permite diferenciar o quadro do inimigo.
func _init(board_height: float, tint: Color = Color.WHITE) -> void:
	var k = board_height / _BODY.size.y
	custom_minimum_size = _BODY.size * k
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_size = _SLOT_ART_SIZE * k

	if ResourceLoader.exists(TEXTURE_PATH):
		var bg = TextureRect.new()
		# expand_mode ANTES do size: senão o TextureRect trava no tamanho nativo
		# da textura e o quadro não consegue ficar MENOR que a arte (k < 1),
		# desalinhando os slots em relação ao desenho.
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.texture = load(TEXTURE_PATH)
		bg.position = -_BODY.position * k
		bg.size = _ART_SIZE * k
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg.modulate = tint
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
	else:
		var bg = Panel.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.add_theme_stylebox_override("panel", PixelUI.make_wood_panel())
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)

	for origin in _SLOT_ORIGINS:
		var slot = Control.new()
		slot.position = (origin - _BODY.position) * k
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		slot.size = Vector2(slot_size, slot_size)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(slot)
		slots.append(slot)
