class_name MapNode
extends RefCounted

enum NodeType {
	Começo,
	Duelo,
	DueloForte,
	Evento,
	Loja,
	Melhoria,
	Chefe,
	Aposta
}

var id: Vector2i
var type: NodeType = NodeType.Duelo
var position: Vector2 = Vector2.ZERO
var parents: Array[MapNode] = []
var children: Array[MapNode] = []

# Armazena Vector2i(linhas, colunas)
var board_size: Vector2i = Vector2i(8, 8)

func get_size_text() -> String:
	return "%dx%d" % [board_size.x, board_size.y]
