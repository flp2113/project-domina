class_name MapNode
extends RefCounted

enum NodeType {
	Começo,
	Duelo,
	DueloForte,
	Evento,
	Loja,
	Chefe,
	Aposta,
	Altar
}

var id: Vector2i
var type: NodeType = NodeType.Duelo
var position: Vector2 = Vector2.ZERO
var parents: Array[MapNode] = []
var children: Array[MapNode] = []

# Armazena Vector2i(linhas, colunas)
var board_size: Vector2i = Vector2i(8, 8)

# Disposição inicial das peças (ver Board.layout_cells); só duelos comuns/fortes sorteiam.
var board_layout: String = Board.LAYOUT_CLASSIC

func has_special_layout() -> bool:
	return board_layout != Board.LAYOUT_CLASSIC

func get_layout_text() -> String:
	return Board.layout_name(board_layout) if has_special_layout() else ""

func get_size_text() -> String:
	return "%dx%d" % [board_size.x, board_size.y]
