class_name BoardPiece
extends RefCounted

const TEXTURE_WHITE_PATH: String = "res://assets/sprites/pieces/white.png"
const TEXTURE_BLACK_PATH: String = "res://assets/sprites/pieces/black.png"
const TEXTURE_WHITE_KING_PATH: String = "res://assets/sprites/pieces/white-king.png"
const TEXTURE_BLACK_KING_PATH: String = "res://assets/sprites/pieces/black-king.png"

var owner_team: int = Board.WHITE
var is_king: bool = false
var color_override: Color = Color.TRANSPARENT
# Árvore da floresta (chefe): peça neutra (owner_team = Board.NEUTRAL) que não
# anda, bloqueia a casa e pode ser capturada por qualquer lado (opcionalmente).
var is_tree: bool = false

static func make_tree() -> BoardPiece:
	var t = BoardPiece.new(Board.NEUTRAL, false)
	t.is_tree = true
	return t

func _init(p_owner: int = Board.WHITE, p_is_king: bool = false) -> void:
	owner_team = p_owner
	is_king = p_is_king

func get_texture() -> String:
	if owner_team == Board.WHITE:
		return TEXTURE_WHITE_KING_PATH if is_king else TEXTURE_WHITE_PATH
	elif owner_team == Board.BLACK:
		return TEXTURE_BLACK_KING_PATH if is_king else TEXTURE_BLACK_PATH
	return ""

func clone() -> BoardPiece:
	var copy = BoardPiece.new(owner_team, is_king)
	copy.color_override = color_override
	copy.is_tree = is_tree
	return copy
