class_name Board
extends RefCounted

signal piece_destroyed(grid_pos: Vector2i, piece: BoardPiece)
# Uma Lei (ex: Escudo) impediu a captura desta peça — a peça continua no tabuleiro.
signal capture_prevented(grid_pos: Vector2i, piece: BoardPiece)

const EMPTY: BoardPiece = null
const NEUTRAL: int = 0
const WHITE: int = 1
const BLACK: int = 2

var rows: int = 8
var cols: int = 8
var grid: Array = []

var human_team_color: int = WHITE
var ai_team_color: int = BLACK
var rule_pipeline: RulePipeline = null

# true nos tabuleiros clonados pra simulação (IA / Profecia). Simulações NÃO
# disparam eventos nem consomem efeitos das Leis: elas compartilham o mesmo
# RulePipeline do jogo real, e Leis têm estado (cargas, escudo usado) e
# efeitos externos (ouro) que não podem vazar de uma jogada hipotética.
var is_simulation: bool = false

# true se o ÚLTIMO make_move foi uma captura que uma Lei (Escudo) impediu.
var last_capture_prevented: bool = false

# Peça que acabou de ser salva por uma Lei (Escudo): o time atacante não pode
# encadear uma nova captura nela no resto do turno (uma Dama que pousou além
# dela a recapturaria na hora). Expira quando o outro time se move.
var _protected_piece: BoardPiece = null
var _protected_attacker_team: int = 0

# Casas bloqueadas (Fortificar): Vector2i(col, row) -> turnos restantes.
var scorched_tiles: Dictionary = {}

# Casas em chamas (Terra Queimada): Vector2i(col, row) -> turnos restantes.
# Diferente de scorched_tiles (que BLOQUEIA a casa), aqui a casa é livre para
# andar, mas qualquer peça que POUSE nela é destruída.
var fire_tiles: Dictionary = {}

# Dama Voadora: peça que ainda pode fazer um 2º movimento neste turno.
var extra_move_piece: BoardPiece = null

# Time que, ENQUANTO durar, pode andar 2 casas (caminho livre) além do passo
# normal — usado pela Noite da Coruja. 0 = ninguém.
var night_boost_team: int = 0

# Movimentos bônus concedidos por cartas (Investida Heroica, Recuar), válidos
# só até o próximo movimento: Vector2i(col, row) da peça -> {"dirs", "distance"}.
var bonus_moves: Dictionary = {}

var light_tile_color: Color = Color(0.92, 0.92, 0.94)
var dark_tile_color: Color = Color(0.18, 0.20, 0.26)
var grid_border_color: Color = Color(0.12, 0.14, 0.18, 0.4)

# Tingimento multiplicado sobre o sprite de madeira (BoardSkin), branco =
# sem alteração. Usado só quando existe assets/sprites/board/board_frame_8x8.png;
# quando não existe, o desenho cai de volta pras cores acima (retângulos
# lisos) e esses tints são ignorados.
# Estilo visual do tabuleiro (ver BoardSkin): madeira nos duelos da Floresta,
# "tutorial" nos duelos do tutorial.
var skin_id: String = BoardSkin.SKIN_WOOD
var light_tile_tint: Color = Color(1, 1, 1)
var dark_tile_tint: Color = Color(1, 1, 1)
var frame_tint: Color = Color(1, 1, 1)

func _init(p_rows: int = 8, p_cols: int = 8) -> void:
	rows = p_rows
	cols = p_cols
	grid = []
	for r in range(rows):
		var row_arr = []
		for c in range(cols):
			row_arr.append(EMPTY)
		grid.append(row_arr)

func set_rule_pipeline(pipeline: RulePipeline) -> void:
	rule_pipeline = pipeline

func set_theme_for_duel(is_hard_or_boss: bool) -> void:
	if is_hard_or_boss:
		light_tile_color = Color(0.24, 0.16, 0.18)
		dark_tile_color = Color(0.12, 0.08, 0.09)
		grid_border_color = Color(0.35, 0.10, 0.12, 0.6)
		# Escurece e puxa pro vermelho sobre o sprite de madeira, sem
		# apagar a textura (tint multiplicativo, não substitui a cor).
		light_tile_tint = Color(0.85, 0.55, 0.55)
		dark_tile_tint = Color(0.55, 0.30, 0.32)
		frame_tint = Color(0.9, 0.65, 0.65)
	else:
		light_tile_color = Color(0.90, 0.91, 0.94)
		dark_tile_color = Color(0.16, 0.18, 0.24)
		grid_border_color = Color(0.08, 0.10, 0.14, 0.4)
		light_tile_tint = Color(1, 1, 1)
		dark_tile_tint = Color(1, 1, 1)
		frame_tint = Color(1, 1, 1)

func clear_board() -> void:
	for r in range(rows):
		for c in range(cols):
			grid[r][c] = EMPTY
	scorched_tiles.clear()
	fire_tiles.clear()
	extra_move_piece = null
	bonus_moves.clear()
	night_boost_team = 0

# Concede à peça em `pos` a possibilidade de andar `distance` casas (caminho
# livre) nas direções `dirs` neste turno, além dos movimentos normais.
func grant_bonus_move(pos: Vector2i, dirs: Array[Vector2i], distance: int = 1) -> void:
	bonus_moves[pos] = {"dirs": dirs.duplicate(), "distance": distance}

func clear_bonus_moves() -> void:
	bonus_moves.clear()

# Chamado uma vez por rodada completa: desconta 1 turno de cada casa
# bloqueada e libera as que chegaram a zero.
func tick_scorched_tiles() -> void:
	for pos in scorched_tiles.keys():
		scorched_tiles[pos] -= 1
		if scorched_tiles[pos] <= 0:
			scorched_tiles.erase(pos)
	for pos in fire_tiles.keys():
		fire_tiles[pos] -= 1
		if fire_tiles[pos] <= 0:
			fire_tiles.erase(pos)

# Chamado ao fim do turno de `team`: desconta os efeitos temporários DAS PEÇAS
# DELE (Emboscada, Herdeiro). Devolve eventos [{"type", "pos"}] pra a UI avisar.
func tick_piece_effects(team: int) -> Array:
	var events: Array = []
	for r in range(rows):
		for c in range(cols):
			var p: BoardPiece = grid[r][c]
			if p == EMPTY or p.owner_team != team:
				continue
			if p.rooted_turns > 0:
				p.rooted_turns -= 1
			if p.shield_turns > 0:
				p.shield_turns -= 1
			if p.temp_king_turns > 0:
				p.temp_king_turns -= 1
				if p.temp_king_turns == 0:
					p.is_king = false
					events.append({"type": "heir_expired", "pos": Vector2i(c, r)})
	return events

func get_max_deployment_rows() -> int:
	var total_rows = rows
	if total_rows <= 6:
		return 1
	elif total_rows <= 8:
		return 3
	elif total_rows <= 10:
		return 4
	return 5

func setup_match(human_team: int, ai_team: int) -> void:
	clear_board()
	human_team_color = human_team
	ai_team_color = ai_team
	
	var max_rows = get_max_deployment_rows()
	
	for r in range(max_rows):
		for c in range(cols):
			if (r + c) % 2 == 1:
				grid[r][c] = BoardPiece.new(ai_team, false)

	var player_start_row = rows - max_rows
	for r in range(player_start_row, rows):
		for c in range(cols):
			if (r + c) % 2 == 1:
				grid[r][c] = BoardPiece.new(human_team, false)

func is_valid_pos(r: int, c: int) -> bool:
	return r >= 0 and r < rows and c >= 0 and c < cols

func is_center_tile(r: int, c: int) -> bool:
	@warning_ignore("integer_division")
	var mid_r = rows / 2
	@warning_ignore("integer_division")
	var mid_c = cols / 2
	return (r == mid_r or r == mid_r - 1) and (c == mid_c or c == mid_c - 1)

func get_all_valid_moves(team: int) -> Array:
	var moves: Array = []
	var captures: Array = []

	for r in range(rows):
		for c in range(cols):
			var piece: BoardPiece = grid[r][c]
			if piece != EMPTY and piece.owner_team == team:
				# get_piece_captures também devolve "saltos camarada" (Lei Salto
				# Camarada), que NÃO são capturas: não podem tornar a captura
				# obrigatória, valem como movimentos comuns.
				for m in get_piece_captures(r, c):
					# Capturar árvore é opcional: nunca torna a captura obrigatória.
					if m["is_capture"] and not m.get("optional", false):
						captures.append(m)
					else:
						moves.append(m)
				moves.append_array(get_piece_moves(r, c))

	var capture_mandatory = true
	if rule_pipeline != null:
		capture_mandatory = rule_pipeline.is_capture_mandatory(team, human_team_color)

	if capture_mandatory and not captures.is_empty():
		return captures

	return captures + moves

func get_piece_captures(r: int, c: int) -> Array:
	var captures: Array = []
	var piece_obj: BoardPiece = grid[r][c]
	if piece_obj == EMPTY:
		return captures

	if piece_obj.rooted_turns > 0:
		return captures

	var is_king: bool = piece_obj.is_king
	var moves_up: bool = (piece_obj.owner_team == human_team_color)

	var capture_dirs: Array[Vector2i] = []
	var can_capture_backwards = is_king

	if rule_pipeline != null and rule_pipeline.can_capture_backwards(piece_obj, human_team_color):
		can_capture_backwards = true

	if can_capture_backwards:
		capture_dirs.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])
	else:
		if moves_up:
			capture_dirs.append_array([Vector2i(-1, -1), Vector2i(1, -1)])
		else:
			capture_dirs.append_array([Vector2i(-1, 1), Vector2i(1, 1)])

	if is_king:
		var lands_before: bool = rule_pipeline != null and rule_pipeline.king_lands_before_victim(piece_obj, human_team_color)
		# Dama voadora: captura uma peça inimiga a qualquer distância na
		# diagonal (desde que o caminho até ela esteja livre) e pode pousar
		# em qualquer casa vazia logo depois dela, não só na adjacente.
		for d in capture_dirs:
			var dist = 1
			while true:
				var cr = r + d.y * dist
				var cc = c + d.x * dist
				if not is_valid_pos(cr, cc) or scorched_tiles.has(Vector2i(cc, cr)):
					break
				var occupant: BoardPiece = grid[cr][cc]
				if occupant == EMPTY:
					dist += 1
					continue
				if occupant.owner_team == piece_obj.owner_team:
					break
				if occupant == _protected_piece and piece_obj.owner_team == _protected_attacker_team:
					break
				var captured_pos = Vector2i(cc, cr)
				var landing_dist = dist + 1
				while true:
					var lr = r + d.y * landing_dist
					var lc = c + d.x * landing_dist
					if not is_valid_pos(lr, lc) or scorched_tiles.has(Vector2i(lc, lr)) or grid[lr][lc] != EMPTY:
						break
					captures.append({
						"from": Vector2i(c, r),
						"to": Vector2i(lc, lr),
						"is_capture": true,
						"captured": captured_pos,
						"optional": occupant.is_tree
					})
					landing_dist += 1
				# Lei do Peso: também pode pousar na casa logo ANTES da vítima
				# (precisa ter andado pelo menos 1 casa livre).
				if lands_before and dist >= 2:
					captures.append({
						"from": Vector2i(c, r),
						"to": Vector2i(c + d.x * (dist - 1), r + d.y * (dist - 1)),
						"is_capture": true,
						"captured": captured_pos,
						"optional": occupant.is_tree
					})
				break
		return captures

	var can_hop_allies: bool = (rule_pipeline != null and rule_pipeline.can_hop_allies(piece_obj, human_team_color))
	var has_power_center = rule_pipeline != null and rule_pipeline.has_rule("power_center")
	var has_iron_crown = rule_pipeline != null and rule_pipeline.has_rule("iron_crown")

	# Alcance de salto (1 = peça adjacente). Leis como Sangue e Fúria Vingativa
	# aumentam: o inimigo pode estar a até `reach` casas na diagonal, com o
	# caminho até ele livre, e a peça pousa na casa logo depois dele.
	var reach: int = 1
	if rule_pipeline != null:
		reach = max(1, rule_pipeline.filter_capture_reach(piece_obj, 1, human_team_color, self))

	for d in capture_dirs:
		for dist in range(1, reach + 1):
			var cap_r: int = r + d.y * dist
			var cap_c: int = c + d.x * dist
			var landing_r: int = r + d.y * (dist + 1)
			var landing_c: int = c + d.x * (dist + 1)

			if not is_valid_pos(cap_r, cap_c) or scorched_tiles.has(Vector2i(cap_c, cap_r)):
				break

			var target: BoardPiece = grid[cap_r][cap_c]
			if target == EMPTY:
				continue # casa livre: o alcance estendido continua pra frente

			# Primeira peça no caminho: ou é capturável aqui, ou bloqueia a linha.
			if not is_valid_pos(landing_r, landing_c) or grid[landing_r][landing_c] != EMPTY or scorched_tiles.has(Vector2i(landing_c, landing_r)):
				break

			if target == _protected_piece and piece_obj.owner_team == _protected_attacker_team:
				break

			if target.owner_team != piece_obj.owner_team:
				# Validação RulePowerCenter: Alvo aliado no centro imune a peças inimigas comuns
				if has_power_center and target.owner_team == human_team_color and is_center_tile(cap_r, cap_c) and not is_king:
					break

				# Validação RuleIronCrown: Damas inimigas imunes a peças não-damas
				if has_iron_crown and target.owner_team != human_team_color and target.is_king and not is_king:
					break

				captures.append({
					"from": Vector2i(c, r),
					"to": Vector2i(landing_c, landing_r),
					"is_capture": true,
					"captured": Vector2i(cap_c, cap_r),
					"optional": target.is_tree
				})
			elif can_hop_allies and dist == 1:
				captures.append({
					"from": Vector2i(c, r),
					"to": Vector2i(landing_c, landing_r),
					"is_capture": false,
					"captured": Vector2i(-1, -1)
				})
			break

	return captures

func get_piece_moves(r: int, c: int) -> Array:
	var moves: Array = []
	var piece_obj: BoardPiece = grid[r][c]
	if piece_obj == EMPTY:
		return moves

	if piece_obj.rooted_turns > 0:
		return moves

	var is_king: bool = piece_obj.is_king
	var moves_up: bool = (piece_obj.owner_team == human_team_color)

	var directions: Array[Vector2i] = []
	if is_king:
		directions.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])
	else:
		if moves_up:
			directions.append_array([Vector2i(-1, -1), Vector2i(1, -1)])
		else:
			directions.append_array([Vector2i(-1, 1), Vector2i(1, 1)])

	if rule_pipeline != null:
		var filtered = rule_pipeline.filter_move_directions(piece_obj, directions, human_team_color, self)
		directions = Array(filtered, TYPE_VECTOR2I, "", null)

	if is_king:
		# Dama voadora: anda quantas casas quiser em linha reta na diagonal,
		# parando na primeira casa ocupada (ou "queimada") no caminho.
		# Lei do Peso limita o alcance (max_range > 0).
		var max_range: int = 0
		if rule_pipeline != null:
			max_range = rule_pipeline.filter_king_range(piece_obj, human_team_color)
		for d in directions:
			var dist = 1
			while true:
				if max_range > 0 and dist > max_range:
					break
				var nr: int = r + (d.y * dist)
				var nc: int = c + (d.x * dist)
				if not is_valid_pos(nr, nc) or scorched_tiles.has(Vector2i(nc, nr)) or grid[nr][nc] != EMPTY:
					break
				moves.append({
					"from": Vector2i(c, r),
					"to": Vector2i(nc, nr),
					"is_capture": false,
					"captured": Vector2i(-1, -1)
				})
				dist += 1
		return moves

	var step_dist: int = 1
	if rule_pipeline != null:
		step_dist = rule_pipeline.filter_step_distance(piece_obj, step_dist, human_team_color, self)

	for d in directions:
		var nr: int = r + (d.y * step_dist)
		var nc: int = c + (d.x * step_dist)

		if is_valid_pos(nr, nc) and grid[nr][nc] == EMPTY and not scorched_tiles.has(Vector2i(nc, nr)):
			moves.append({
				"from": Vector2i(c, r),
				"to": Vector2i(nc, nr),
				"is_capture": false,
				"captured": Vector2i(-1, -1)
			})

	if night_boost_team != 0 and piece_obj.owner_team == night_boost_team:
		_append_double_steps(r, c, directions, moves)

	_append_bonus_moves(r, c, moves)
	return moves

# Passo duplo (Noite da Coruja): 2 casas na diagonal com as duas livres.
func _append_double_steps(r: int, c: int, dirs: Array[Vector2i], moves: Array) -> void:
	for d in dirs:
		var mid = Vector2i(c + d.x, r + d.y)
		var dest = Vector2i(c + d.x * 2, r + d.y * 2)
		if not is_valid_pos(dest.y, dest.x) or not is_valid_pos(mid.y, mid.x):
			continue
		if grid[mid.y][mid.x] != EMPTY or grid[dest.y][dest.x] != EMPTY:
			continue
		if scorched_tiles.has(mid) or scorched_tiles.has(dest):
			continue
		var listed = false
		for m in moves:
			if m["to"] == dest:
				listed = true
				break
		if listed:
			continue
		moves.append({"from": Vector2i(c, r), "to": dest, "is_capture": false, "captured": Vector2i(-1, -1)})

# Movimentos extras de cartas (ver grant_bonus_move). Só vale se todas as
# casas do caminho estiverem livres; ignora destinos que já existem na lista.
func _append_bonus_moves(r: int, c: int, moves: Array) -> void:
	var bonus = bonus_moves.get(Vector2i(c, r))
	if bonus == null:
		return

	var distance: int = bonus["distance"]
	for d in bonus["dirs"]:
		var path_clear = true
		for step in range(1, distance + 1):
			var pr: int = r + d.y * step
			var pc: int = c + d.x * step
			if not is_valid_pos(pr, pc) or grid[pr][pc] != EMPTY or scorched_tiles.has(Vector2i(pc, pr)):
				path_clear = false
				break
		if not path_clear:
			continue

		var dest = Vector2i(c + d.x * distance, r + d.y * distance)
		var already_listed = false
		for m in moves:
			if m["to"] == dest:
				already_listed = true
				break
		if already_listed:
			continue

		moves.append({
			"from": Vector2i(c, r),
			"to": dest,
			"is_capture": false,
			"captured": Vector2i(-1, -1)
		})

func make_move(move_dict: Dictionary) -> bool:
	var from_pos: Vector2i = move_dict["from"]
	var to_pos: Vector2i = move_dict["to"]
	var is_cap: bool = move_dict.get("is_capture", false)

	# Bônus de cartas valem só até o próximo movimento.
	bonus_moves.clear()
	last_capture_prevented = false

	var piece: BoardPiece = grid[from_pos.y][from_pos.x]
	grid[from_pos.y][from_pos.x] = EMPTY
	grid[to_pos.y][to_pos.x] = piece

	if _protected_piece != null and piece.owner_team != _protected_attacker_team:
		_protected_piece = null

	# Em simulação nenhuma Lei é consultada nem notificada (ver is_simulation).
	var pipeline: RulePipeline = null if is_simulation else rule_pipeline

	if is_cap:
		var cap_pos: Vector2i = move_dict["captured"]
		var cap_piece: BoardPiece = grid[cap_pos.y][cap_pos.x]

		# Lei Escudo (ou qualquer Lei com try_prevent_capture): a peça sobrevive
		# e o salto acontece mesmo assim — o atacante pousa, a vítima fica.
		if cap_piece.is_tree:
			# Árvore: cai sem Leis, sem eventos de captura e sem ouro.
			grid[cap_pos.y][cap_pos.x] = EMPTY
			piece_destroyed.emit(cap_pos, cap_piece)
		elif pipeline != null and pipeline.try_prevent_capture(cap_piece, human_team_color, self):
			last_capture_prevented = true
			_protected_piece = cap_piece
			_protected_attacker_team = piece.owner_team
			capture_prevented.emit(cap_pos, cap_piece)
		else:
			grid[cap_pos.y][cap_pos.x] = EMPTY
			piece_destroyed.emit(cap_pos, cap_piece)

			if pipeline != null:
				# Dispara evento de captura
				pipeline.emit_event(&"piece_captured", {
					"attacker": piece,
					"victim": cap_piece,
					"attacker_pos": to_pos,
					"victim_pos": cap_pos
				}, self)
				# Dispara evento de peça perdida
				pipeline.emit_event(&"piece_lost", {
					"piece": cap_piece,
					"pos": cap_pos
				}, self)
	else:
		if pipeline != null:
			pipeline.emit_event(&"step_moved", {
				"piece": piece,
				"from": from_pos,
				"to": to_pos
			}, self)

	# Terra Queimada: quem POUSA numa casa em chamas é destruído.
	if fire_tiles.has(to_pos):
		grid[to_pos.y][to_pos.x] = EMPTY
		piece_destroyed.emit(to_pos, piece)
		return false

	# Herdeiro que chega ao fim do tabuleiro vira Dama de verdade.
	if piece.is_king and piece.temp_king_turns > 0:
		var end_row = 0 if piece.owner_team == human_team_color else rows - 1
		if to_pos.y == end_row:
			piece.temp_king_turns = 0

	var promoted = false
	if not piece.is_king:
		var target_promotion_row = 0 if (piece.owner_team == human_team_color) else (rows - 1)
		var reached_end = (to_pos.y == target_promotion_row)
		var custom_promo = false

		if pipeline != null:
			custom_promo = pipeline.should_promote_to_king(piece, to_pos, human_team_color, self)

		if reached_end or custom_promo:
			piece.is_king = true
			promoted = true
			if pipeline != null:
				pipeline.emit_event(&"on_promotion", {
					"piece": piece,
					"pos": to_pos
				}, self)

	return promoted

func count_pieces(team: int, kings_only: bool = false) -> int:
	var count = 0
	for r in range(rows):
		for c in range(cols):
			var p: BoardPiece = grid[r][c]
			if p != EMPTY and p.owner_team == team:
				if not kings_only or p.is_king:
					count += 1
	return count

func evaluate_for_team(team: int) -> int:
	var score = 0
	var enemy_team = BLACK if team == WHITE else WHITE

	for r in range(rows):
		for c in range(cols):
			var p: BoardPiece = grid[r][c]
			if p != EMPTY:
				var val = 50 if p.is_king else 10
				if p.owner_team == team:
					score += val
				elif p.owner_team == enemy_team:
					score -= val

	return score

func clone() -> Board:
	var new_b = Board.new(rows, cols)
	new_b.human_team_color = human_team_color
	new_b.ai_team_color = ai_team_color
	new_b.rule_pipeline = rule_pipeline
	new_b.is_simulation = true
	new_b.scorched_tiles = scorched_tiles.duplicate()
	new_b.fire_tiles = fire_tiles.duplicate()
	new_b.bonus_moves = bonus_moves.duplicate(true)
	new_b.night_boost_team = night_boost_team

	for r in range(rows):
		for c in range(cols):
			var p: BoardPiece = grid[r][c]
			if p != EMPTY:
				new_b.grid[r][c] = p.clone()

	return new_b
