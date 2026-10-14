class_name CardGrandReinforcement
extends ActionCard

func _init() -> void:
	id = "grand_reinforcement"
	icon_path = "res://assets/sprites/cards/icons/grand_reinforcement.png"
	name = "Grande Reforco"
	description = "Se uma fileira sua estiver totalmente vazia de pecas, invoca uma peca comum em cada casa escura dessa fileira."
	rarity = Rarity.LEGENDARY
	target_type = TargetType.EMPTY_TILE

func _is_row_empty_of_allies(board: Board, row: int, human_team: int) -> bool:
	for c in range(board.cols):
		var p: BoardPiece = board.grid[row][c]
		if p != Board.EMPTY and p.owner_team == human_team:
			return false
	return true

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false
	return _is_row_empty_of_allies(board, target_pos.y, human_team)

func execute(board: Board, target_pos: Vector2i, human_team: int, _context: Dictionary = {}) -> void:
	var row = target_pos.y
	for c in range(board.cols):
		var is_dark_tile = (row + c) % 2 == 1
		var is_empty = board.grid[row][c] == Board.EMPTY
		var is_scorched = board.scorched_tiles.has(Vector2i(c, row))
		if is_dark_tile and is_empty and not is_scorched:
			board.grid[row][c] = BoardPiece.new(human_team, false)
