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

# Cria a peça especial do Guia — uma Dama com cor própria (nem branca nem
# preta), pra ficar visualmente distinta de qualquer time em jogo.
static func make_guide_piece() -> BoardPiece:
	var guide_piece = BoardPiece.new(Board.WHITE, true)
	guide_piece.color_override = Color(0.62, 0.42, 0.85)
	return guide_piece
