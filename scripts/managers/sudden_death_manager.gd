class_name SuddenDeathManager
extends Node2D

signal sudden_death_triggered()
signal match_finished_by_points(won: bool, message: String)

# true só na chamada de check_conditions()/process_turn_end() que ATIVA a
# Morte Súbita pela primeira vez — quem chama pode conferir isso logo
# depois e aguardar (await) a resolução de qualquer Lei associada, em vez
# de confiar só no sinal (sinais não fazem quem emite esperar handlers
# assíncronos terminarem, o que deixava a IA jogar antes da animação
# de moedas da Lei do Empate Impossível acabar).
var just_triggered: bool = false

var max_turns: int = 10
var is_active: bool = false
var turns_left: int = 6
var initial_kings_count: int = 0
# Pausa: quantos fechamentos de turno ainda NÃO descontam o relógio.
var pause_ticks: int = 0

# Preenchidos pelo main: contagem visual dos pontos no fim da Morte Súbita.
var tally_view: ScoreTallyView = null
var tally_board_offset: Vector2 = Vector2.ZERO
var tally_cell_size: float = 64.0

func reset() -> void:
	is_active = false
	turns_left = max_turns
	initial_kings_count = 0
	pause_ticks = 0
	queue_redraw()

func configure(max_dim: int = 8) -> void:
	max_turns = max(4, max_dim + 2)
	turns_left = max_turns

func start_immediately() -> void:
	is_active = true
	turns_left = max_turns
	just_triggered = true
	sudden_death_triggered.emit()
	queue_redraw()

func set_initial_kings_baseline(board: Board) -> void:
	initial_kings_count = _count_total_kings(board)

func _count_total_kings(board: Board) -> int:
	# Damas "isentas" (Lei da Guarda Real) não contam: senão a Dama inicial
	# do inimigo ativaria a Morte Súbita logo no começo.
	var total = 0
	for r in range(board.rows):
		for c in range(board.cols):
			var p: BoardPiece = board.grid[r][c]
			if p != Board.EMPTY and p.is_king and not p.sd_exempt:
				total += 1
	return total

func check_conditions(board: Board, human_team: int, ai_team: int) -> void:
	if is_active:
		return

	var human_count = board.count_pieces(human_team)
	var ai_count = board.count_pieces(ai_team)
	var current_kings = _count_total_kings(board)

	var new_king_promoted = current_kings > initial_kings_count

	if human_count == 1 or ai_count == 1 or new_king_promoted:
		is_active = true
		turns_left = max_turns
		just_triggered = true
		sudden_death_triggered.emit()
		queue_redraw()

# Assíncrona: aguarde (await) — a contagem visual roda antes do resultado.
func process_turn_end(board: Board, human_team: int, ai_team: int) -> bool:
	check_conditions(board, human_team, ai_team)

	if not is_active:
		return false

	if pause_ticks > 0:
		pause_ticks -= 1
		queue_redraw()
		return false

	turns_left -= 1
	queue_redraw()

	if turns_left <= 0:
		await _resolve_points(board, human_team, ai_team)
		return true

	return false

func _resolve_points(board: Board, human_team: int, ai_team: int) -> void:
	var human_score = 0
	var ai_score = 0

	if tally_view != null:
		var res: Dictionary = await tally_view.play(board, tally_board_offset, tally_cell_size, human_team, ai_team)
		human_score = res["human"]
		ai_score = res["ai"]
		var won_v = human_score >= ai_score
		var t_v = "MORTE SUBITA ENCERRADA!\n"
		match_finished_by_points.emit(won_v, t_v + ("VITORIA POR PONTOS (%d x %d)" if won_v else "DERROTA POR PONTOS (%d x %d)") % [human_score, ai_score])
		return

	for r in range(board.rows):
		for c in range(board.cols):
			var piece: BoardPiece = board.grid[r][c]
			if piece != Board.EMPTY:
				var val = 3 if piece.is_king else 1
				if piece.owner_team == human_team:
					human_score += val
				elif piece.owner_team == ai_team:
					ai_score += val

	var won = human_score >= ai_score
	var title = "MORTE SUBITA ENCERRADA!\n"
	var msg = title + ("VITORIA POR PONTOS (%d x %d)" if won else "DERROTA POR PONTOS (%d x %d)") % [human_score, ai_score]
	
	match_finished_by_points.emit(won, msg)

func _draw() -> void:
	if is_active:
		# Canto fixo da tela — não depende mais da posição/tamanho do
		# tabuleiro, então não precisa reservar espaço nenhum acima dele.
		var banner_w = 340.0
		var banner_h = 50.0
		var banner_rect = Rect2(20.0, 20.0, banner_w, banner_h)

		draw_rect(banner_rect, Color(0.08, 0.02, 0.03, 0.96))

		var shadow_rect = Rect2(banner_rect.position + Vector2(2, 3), banner_rect.size)
		draw_rect(shadow_rect, Color(0, 0, 0, 0.4), false, 2.0)
		draw_rect(banner_rect, Color(0.9, 0.15, 0.2, 0.95), false, 2.5)

		PixelRenderer.draw_pixel_corners(self, banner_rect, Color(1.0, 0.4, 0.45, 1.0), 10.0, 2.5)

		var font = ThemeDB.fallback_font
		var msg = "MORTE SUBITA: %d TURNOS RESTANTES" % turns_left
		if pause_ticks > 0:
			msg = "MORTE SUBITA: %d TURNOS - PAUSADA" % turns_left
		var text_pos = Vector2(banner_rect.position.x, banner_rect.position.y + 33)

		draw_string(font, text_pos + Vector2(2, 2), msg, HORIZONTAL_ALIGNMENT_CENTER, banner_rect.size.x, 18, Color(0.05, 0.05, 0.05, 1.0))
		draw_string(font, text_pos, msg, HORIZONTAL_ALIGNMENT_CENTER, banner_rect.size.x, 18, Color(1.0, 0.35, 0.35, 1.0))
