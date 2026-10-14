class_name CardCorrupt
extends ActionCard

func _init() -> void:
	id = "corrupt"
	icon_path = "res://assets/sprites/cards/icons/corrupt.png"
	name = "Corromper"
	description = "Rouba permanentemente uma peca comum inimiga isolada (sem nenhum aliado dela adjacente) para o seu lado."
	rarity = Rarity.EPIC
	target_type = TargetType.ENEMY_PIECE

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false

	var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if piece.is_king:
		return false

	# Precisa estar isolada: nenhuma peça do MESMO dono adjacente na diagonal
	var dirs = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	for d in dirs:
		var nr = target_pos.y + d.y
		var nc = target_pos.x + d.x
		if board.is_valid_pos(nr, nc):
			var neighbor: BoardPiece = board.grid[nr][nc]
			if neighbor != Board.EMPTY and neighbor.owner_team == piece.owner_team:
				return false

	return true

func execute(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> void:
	var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if piece == Board.EMPTY:
		return

	piece.owner_team = human_team

	# Se a peça corrompida já estiver na fileira de promoção do NOVO dono,
	# ela vira Dama na hora — mesma regra de quando uma peça anda até lá
	# normalmente (Board.make_move usa a mesma lógica).
	var promotion_row = 0 if (human_team == board.human_team_color) else (board.rows - 1)
	if target_pos.y == promotion_row:
		piece.is_king = true

	var main_node = context.get("main")
	if main_node and "king_animation_view" in main_node and main_node.king_animation_view != null:
		_play_corrupt_animation(main_node, target_pos, piece)

# Função separada (não aguardada por execute) porque ActionCard.execute()
# não é assíncrona — mas ainda precisamos aguardar a animação pra saber a
# hora certa de limpar animating_coronation_tile.
func _play_corrupt_animation(main_node, target_pos: Vector2i, piece: BoardPiece) -> void:
	# É essa flag que faz o BoardRenderer parar de desenhar a peça pelo
	# caminho normal enquanto a animação cuida dela — sem isso, as duas
	# renderizações brigam ao mesmo tempo (o "efeito estranho").
	main_node.animating_coronation_tile = target_pos

	var center = main_node.board_offset + Vector2(
		target_pos.x * main_node.cell_size + main_node.cell_size / 2.0,
		target_pos.y * main_node.cell_size + main_node.cell_size / 2.0
	)
	await main_node.king_animation_view.play_coronation(center, main_node.cell_size, piece)

	main_node.animating_coronation_tile = Vector2i(-1, -1)
