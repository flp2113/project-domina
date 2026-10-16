class_name PieceIconControl
extends Control

# Desenha uma peça de tabuleiro DE VERDADE (mesmo pipeline visual das
# peças em jogo, via PixelRenderer) em vez de depender de uma imagem
# estática — assim qualquer "personagem" feito de uma peça (como o
# Guia do tutorial) sempre bate com o estilo visual real do jogo.

var piece: BoardPiece
var cell_size: float = 96.0

func _ready() -> void:
	custom_minimum_size = Vector2(cell_size, cell_size)

func setup(p_piece: BoardPiece, p_cell_size: float = 96.0) -> void:
	piece = p_piece
	cell_size = p_cell_size
	custom_minimum_size = Vector2(cell_size, cell_size)
	queue_redraw()

func _draw() -> void:
	if piece == null:
		return
	var center = size / 2.0
	PixelRenderer.draw_piece(self, piece, center, cell_size, 1.0)
