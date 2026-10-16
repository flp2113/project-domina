class_name BoardRenderer
extends Node2D

# Renderização do tabuleiro (peças, seleção, alvos, hazards do boss, highlight
# de cartas de ação), extraída de main.gd.
#
# Em vez de exigir que main.gd chame queue_redraw() no momento exato certo
# (main.gd tinha ~20 pontos de chamada espalhados — fácil esquecer um e gerar
# um bug visual sutil), este nó simplesmente se redesenha a cada frame. Para
# um tabuleiro de damas isso é computacionalmente desprezível, e elimina essa
# classe inteira de bug em troca de um _process trivial.
#
# Lê o estado do host (hoje, main.gd) só para leitura — nunca escreve nele:
# board, board_offset, cell_size, current_duel, selected_tile, selection_pulse,
# valid_moves_for_selected, show_enemy_threats, ai_team, action_cards,
# animating_coronation_tile, moving_piece_tile, piece_spawn_scales.

var host: Node2D
var _mist_tex: GradientTexture2D = null

func setup(p_host: Node2D) -> void:
	host = p_host
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if host == null or host.board == null:
		return

	var board: Board = host.board
	var board_offset: Vector2 = host.board_offset
	var cell_size: float = host.cell_size

	if BoardSkin.has_sprite(board.skin_id):
		# Sprite único 8x8 fatiado em código (moldura + 2 casinhas) e
		# remontado pro tamanho real deste tabuleiro.
		BoardSkin.draw_frame(self, board_offset, board.rows, board.cols, cell_size, board.frame_tint, board.skin_id)
		BoardSkin.draw_tiles(self, board_offset, board.rows, board.cols, cell_size, board.light_tile_tint, board.dark_tile_tint, board.skin_id)
	else:
		for r in range(board.rows):
			for c in range(board.cols):
				var rect = Rect2(board_offset.x + c * cell_size, board_offset.y + r * cell_size, cell_size, cell_size)
				var base_color = board.light_tile_color if (r + c) % 2 == 0 else board.dark_tile_color
				draw_rect(rect, base_color)
				draw_rect(rect, board.grid_border_color, false, 1.0)

	for pos in board.scorched_tiles.keys():
		var tile_rect = Rect2(board_offset.x + pos.x * cell_size, board_offset.y + pos.y * cell_size, cell_size, cell_size)
		draw_rect(tile_rect, Color(1.0, 0.3, 0.05, 0.5))
		PixelRenderer.draw_pixel_corners(self, tile_rect, Color(1.0, 0.75, 0.1, 0.95), 8.0, 2.5)

	_draw_fire_tiles(board, board_offset, cell_size)

	if board.rule_pipeline != null and (board.rule_pipeline.has_rule("sacred_zone") or board.rule_pipeline.has_rule("power_center")):
		var center_color = Color(0.85, 0.55, 1.0, 0.4) if board.rule_pipeline.has_rule("sacred_zone") else Color(1.0, 0.85, 0.3, 0.4)
		var center_border = Color(0.9, 0.6, 1.0, 0.9) if board.rule_pipeline.has_rule("sacred_zone") else Color(1.0, 0.9, 0.4, 0.9)
		for r in range(board.rows):
			for c in range(board.cols):
				if board.is_center_tile(r, c):
					var center_rect = Rect2(board_offset.x + c * cell_size, board_offset.y + r * cell_size, cell_size, cell_size)
					draw_rect(center_rect, center_color)
					PixelRenderer.draw_pixel_corners(self, center_rect, center_border, 8.0, 2.0)

	if host.current_duel is DuelBoss and host.current_duel.law_id == DuelBoss.LAW_FROG:
		# Só desenha o destaque vermelho DEPOIS que as moscas terminarem de
		# pousar — antes disso, hazard_tiles já está preenchido mas as
		# moscas ainda estão voando pra lá, então mostrar o vermelho antes
		# da hora entrega a casa antes da mosca sequer ter chegado.
		var flies_still_landing = host.frog_animation_view != null and host.frog_animation_view.is_spawning_flies
		if not flies_still_landing:
			for pos in host.current_duel.hazard_tiles:
				var hazard_rect = Rect2(board_offset.x + pos.x * cell_size, board_offset.y + pos.y * cell_size, cell_size, cell_size)
				draw_rect(hazard_rect, Color(0.85, 0.1, 0.2, 0.35))
				PixelRenderer.draw_pixel_corners(self, hazard_rect, Color(1.0, 0.2, 0.3, 0.85), 8.0, 2.0)

	if host.selected_tile != Vector2i(-1, -1):
		var selected_rect = Rect2(board_offset.x + host.selected_tile.x * cell_size, board_offset.y + host.selected_tile.y * cell_size, cell_size, cell_size)
		PixelRenderer.draw_pixel_selected_tile(self, selected_rect, host.selection_pulse)

	# Indicador de captura obrigatória: só aparece quando o jogador
	# está REALMENTE sendo forçado a capturar (respeita regras como
	# Captura Opcional, que tornam a captura não-obrigatória mesmo
	# disponível) — marca as peças que podem realizá-la com um contorno
	# grosso e pulsante. Continua visível mesmo depois do jogador
	# selecionar outra peça, pra sempre dar pra ver quem tem a captura
	# disponível.
	if host.current_turn == host.human_team:
		var capture_mandatory = true
		if board.rule_pipeline != null:
			capture_mandatory = board.rule_pipeline.is_capture_mandatory(host.human_team, board.human_team_color)

		if capture_mandatory:
			var all_moves = board.get_all_valid_moves(host.human_team)
			var must_capture_from: Dictionary = {}
			for m in all_moves:
				if m.get("is_capture", false) and not m.get("optional", false):
					must_capture_from[m["from"]] = true
			if not must_capture_from.is_empty():
				var pulse_alpha = 0.6 + 0.4 * host.selection_pulse
				for from_pos in must_capture_from.keys():
					var must_rect = Rect2(board_offset.x + from_pos.x * cell_size, board_offset.y + from_pos.y * cell_size, cell_size, cell_size)
					PixelRenderer.draw_pixel_corners(self, must_rect, Color(1.0, 0.65, 0.05, pulse_alpha), 12.0, 4.0)

	for m in host.valid_moves_for_selected:
		var target_rect = Rect2(board_offset.x + m["to"].x * cell_size, board_offset.y + m["to"].y * cell_size, cell_size, cell_size)
		PixelRenderer.draw_pixel_move_target(self, target_rect, m["is_capture"], host.selection_pulse)

	if host.show_enemy_threats:
		var enemy_moves = board.get_all_valid_moves(host.ai_team)
		for em in enemy_moves:
			var threat_rect = Rect2(board_offset.x + em["to"].x * cell_size, board_offset.y + em["to"].y * cell_size, cell_size, cell_size)
			var threat_col = Color(1.0, 0.2, 0.2, 0.4) if em["is_capture"] else Color(1.0, 0.8, 0.2, 0.25)
			draw_rect(threat_rect, threat_col)
			PixelRenderer.draw_pixel_corners(self, threat_rect, Color(1.0, 0.2, 0.2, 0.9), 6.0, 2.0)

	if not host.predicted_ai_move.is_empty():
		var from_pos: Vector2i = host.predicted_ai_move["from"]
		var to_pos: Vector2i = host.predicted_ai_move["to"]
		var prophecy_color = Color(0.85, 0.4, 1.0, 0.9)
		var from_rect = Rect2(board_offset.x + from_pos.x * cell_size, board_offset.y + from_pos.y * cell_size, cell_size, cell_size)
		var to_rect = Rect2(board_offset.x + to_pos.x * cell_size, board_offset.y + to_pos.y * cell_size, cell_size, cell_size)
		draw_rect(from_rect, Color(prophecy_color.r, prophecy_color.g, prophecy_color.b, 0.3))
		draw_rect(to_rect, Color(prophecy_color.r, prophecy_color.g, prophecy_color.b, 0.3))
		PixelRenderer.draw_pixel_corners(self, from_rect, prophecy_color, 8.0, 2.5)
		PixelRenderer.draw_pixel_corners(self, to_rect, prophecy_color, 8.0, 2.5)
		var line_from = board_offset + Vector2(from_pos.x * cell_size + cell_size / 2.0, from_pos.y * cell_size + cell_size / 2.0)
		var line_to = board_offset + Vector2(to_pos.x * cell_size + cell_size / 2.0, to_pos.y * cell_size + cell_size / 2.0)
		draw_line(line_from, line_to, prophecy_color, 3.0)

	if host.action_cards != null and host.action_cards.has_selected_card():
		for r in range(board.rows):
			for c in range(board.cols):
				var pos = Vector2i(c, r)
				if host.action_cards.is_target_valid(pos):
					var tile_rect = Rect2(board_offset.x + c * cell_size, board_offset.y + r * cell_size, cell_size, cell_size)
					draw_rect(tile_rect, Color(0.2, 0.8, 1.0, 0.25 * host.selection_pulse))
					PixelRenderer.draw_pixel_corners(self, tile_rect, Color(0.3, 0.9, 1.0, 0.95), 8.0, 2.0)

	for r in range(board.rows):
		for c in range(board.cols):
			var pos = Vector2i(c, r)
			var piece_obj: BoardPiece = board.grid[r][c]

			if pos == host.animating_coronation_tile or pos == host.moving_piece_tile:
				continue

			if piece_obj != Board.EMPTY:
				# Peças do chefe somem na névoa; árvores e as suas continuam visíveis.
				if piece_obj.owner_team == host.ai_team and host.current_duel != null and host.current_duel.is_fogged(pos):
					continue
				var center = board_offset + Vector2(c * cell_size + cell_size / 2.0, r * cell_size + cell_size / 2.0)
				var scale_factor = host.piece_spawn_scales.get(pos, 1.0)
				PixelRenderer.draw_piece(self, piece_obj, center, cell_size, scale_factor)
				_draw_piece_status(piece_obj, center, cell_size * scale_factor)

	_draw_night_and_status(board, board_offset, cell_size)

# Terra Queimada: chamas animadas (spritesheet 8 frames de 64x64, loop a 8 fps)
# sobre as casas em fogo. Cada casa começa num frame diferente pra não piscarem
# em uníssono.
const FIRE_SHEET: String = "res://assets/sprites/fx/chama_sheet.png"
const FIRE_FRAMES: int = 8
const FIRE_FRAME_PX: int = 64
const FIRE_FPS: float = 8.0
var _fire_tex: Texture2D = null

func _draw_fire_tiles(board: Board, board_offset: Vector2, cell_size: float) -> void:
	if _fire_tex == null and ResourceLoader.exists(FIRE_SHEET):
		_fire_tex = load(FIRE_SHEET)
	var t = Time.get_ticks_msec() / 1000.0
	for pos in board.fire_tiles.keys():
		var rect = Rect2(board_offset.x + pos.x * cell_size, board_offset.y + pos.y * cell_size, cell_size, cell_size)
		# Brasa escura sob as chamas: a casa fica avermelhada e legível.
		draw_rect(rect, Color(0.45, 0.1, 0.08, 0.5 + 0.06 * sin(t * 6.0 + pos.x + pos.y)))
		if _fire_tex != null:
			var f: int = (int(t * FIRE_FPS) + pos.x * 3 + pos.y * 5) % FIRE_FRAMES
			var src := Rect2(f * FIRE_FRAME_PX, 0, FIRE_FRAME_PX, FIRE_FRAME_PX)
			draw_texture_rect_region(_fire_tex, rect, src)
		PixelRenderer.draw_pixel_corners(self, rect, Color(1.0, 0.55, 0.1, 0.95), 8.0, 2.5)

# Marcas de status na peça: bolha azul = escudo (Lei do Luto); grade violeta = imobilizada (Emboscada);
# selo dourado com número = Dama temporária (Herdeiro, turnos restantes).
func _draw_piece_status(piece: BoardPiece, center: Vector2, size: float) -> void:
	if piece.rooted_turns > 0:
		var half = size * 0.34
		var col = Color(0.62, 0.42, 0.85, 0.95)
		for i in range(3):
			var x = center.x - half + half * i
			draw_line(Vector2(x, center.y - half), Vector2(x, center.y + half), col, 3.0)
		draw_rect(Rect2(center - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), col, false, 3.0)
	if piece.shield_turns > 0:
		# Escudo (Lei do Luto): bolha azul pulsante + contorno ao redor da peça.
		var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0)
		var rad = size * 0.46
		draw_circle(center, rad, Color(0.35, 0.65, 1.0, 0.16 + 0.1 * pulse))
		draw_arc(center, rad, 0, TAU, 32, Color(0.55, 0.8, 1.0, 0.75 + 0.25 * pulse), 3.0)
		# Selo de escudo no canto inferior esquerdo.
		var sc = center + Vector2(-size * 0.3, size * 0.3)
		var s = size * 0.13
		var shield_pts = PackedVector2Array([sc + Vector2(-s, -s), sc + Vector2(s, -s), sc + Vector2(s, s * 0.2), sc + Vector2(0, s * 1.3), sc + Vector2(-s, s * 0.2)])
		draw_colored_polygon(shield_pts, Color(0.3, 0.6, 0.95))
		draw_polyline(PackedVector2Array([shield_pts[0], shield_pts[1], shield_pts[2], shield_pts[3], shield_pts[4], shield_pts[0]]), Color(0.9, 0.97, 1.0), 2.0)
	if piece.temp_king_turns > 0:
		var badge = center + Vector2(size * 0.3, -size * 0.3)
		draw_circle(badge, size * 0.15, Color(0.14, 0.1, 0.17))
		draw_arc(badge, size * 0.15, 0, TAU, 16, Color(0.85, 0.65, 0.25), 2.0)
		var font = ThemeDB.fallback_font
		# Centraliza de verdade: caixa de largura = diâmetro do círculo, e a
		# linha de base calculada pela altura real da fonte.
		var fs = int(size * 0.2)
		var txt = str(piece.temp_king_turns)
		var r = size * 0.15
		var base_y = badge.y + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0
		draw_string(font, Vector2(badge.x - r, base_y), txt, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1.0, 0.9, 0.5))

# Escuridão da Noite da Coruja (sobre peças já desenhadas, com as peças do
# chefe encobertas pela névoa) + texto de status acima do tabuleiro.
func _draw_night_and_status(board: Board, board_offset: Vector2, cell_size: float) -> void:
	if host.current_duel == null:
		return
	var dark: float = host.current_duel.get_darkness()
	var area = Rect2(board_offset, Vector2(board.cols * cell_size, board.rows * cell_size))
	if dark > 0.0:
		draw_rect(area, Color(0.04, 0.05, 0.16, dark))
		# Névoa: cobre TODA casa distante das suas peças por igual (vazia ou
		# não), com bruma que se move — não dá pra deduzir onde há peças.
		var t = Time.get_ticks_msec() / 1000.0
		for r in range(board.rows):
			for c in range(board.cols):
				var f: float = host.current_duel.fog_strength(Vector2i(c, r))
				if f <= 0.0:
					continue
				var fr = Rect2(board_offset.x + c * cell_size, board_offset.y + r * cell_size, cell_size, cell_size)
				draw_rect(fr, Color(0.42, 0.48, 0.66, f * 0.6))
				for k in range(2):
					var ph = t * 0.3 + (c * 1.7 + r * 2.3) + k * 3.1
					var off = Vector2(sin(ph) * 0.25, cos(ph * 0.8) * 0.2) * cell_size
					var sz = Vector2.ONE * cell_size * (1.7 + 0.4 * k)
					var br = Rect2(fr.get_center() + off - sz / 2.0, sz)
					var clipped = br.intersection(area) # a bruma não vaza pra moldura
					if clipped.size.x > 0.0 and clipped.size.y > 0.0:
						var src = Rect2((clipped.position - br.position) / sz * 128.0, clipped.size / sz * 128.0)
						draw_texture_rect_region(_get_mist_tex(), clipped, src, Color(0.8, 0.85, 1.0, f * 0.55))
	var status: String = host.current_duel.get_status_text()
	if status != "":
		var font = ThemeDB.fallback_font
		var pos = board_offset + Vector2(0, -12)
		draw_string(font, pos + Vector2(2, 2), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0, 0, 0, 0.8))
		draw_string(font, pos, status, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.85, 0.82, 1.0) if dark > 0.0 else Color(1.0, 0.9, 0.5))

# Bolha de bruma com borda suave (gradiente radial, criado uma vez).
func _get_mist_tex() -> GradientTexture2D:
	if _mist_tex == null:
		var g = Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		g.offsets = PackedFloat32Array([0.0, 1.0])
		_mist_tex = GradientTexture2D.new()
		_mist_tex.gradient = g
		_mist_tex.fill = GradientTexture2D.FILL_RADIAL
		_mist_tex.fill_from = Vector2(0.5, 0.5)
		_mist_tex.fill_to = Vector2(1.0, 0.5)
		_mist_tex.width = 128
		_mist_tex.height = 128
	return _mist_tex
