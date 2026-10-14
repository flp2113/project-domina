class_name ForestBackground
extends Node2D

# Fundo procedural do mapa da floresta: um tabuleiro de casas (alternando
# claras = grama/madeira e escuras = terra/musgo) com moldura de madeira,
# árvores e detalhes espalhados (mais árvores nas bordas, nada em cima das
# trilhas) e uma clareira sob cada nó. Tudo é gerado a partir dos sprites de
# res://assets/sprites/map/forest/ com uma semente derivada do próprio mapa,
# então o mesmo mapa sempre gera o mesmo fundo.

const DIR := "res://assets/sprites/map/forest/"
const BOARD_DIR := "tabuleiro/"
const NATIVE_TILE: int = 26
const FRAME: int = 10
const FRAME_CORNER: int = 12
const FRAME_SRC_COLS: int = 9
const FRAME_SRC_ROWS: int = 13

# Arte do tabuleiro da floresta (cream/ameixa): casas + detalhes pequenos em
# res://assets/sprites/map/forest/tabuleiro/<pasta>/<nome>.png
const LIGHT_TILES: Array[String] = [
	"casas/casa_clara_grama", "casas/casa_clara_grama", "casas/casa_clara_tabuas",
	"casas/casa_madeira_textura_1", "casas/casa_madeira_textura_2", "casas/casa_madeira_textura_3",
	"casas/casa_madeira_textura_4", "casas/casa_madeira_textura_5", "casas/casa_madeira_textura_6",
]
const DARK_TILES: Array[String] = ["casas/casa_escura"]

# Árvores e arbustos (já vêm com a sombra e o chão da cor da casa).
const TREES_LIGHT: Array[String] = [
	"arvores/arvore_copa_1_chao_claro", "arvores/arvore_copa_3_chao_claro",
	"arvores/arvore_copa_6_chao_claro", "arvores/arvore_copa_3_chao_claro",
]
const TREES_DARK: Array[String] = [
	"arvores/arvore_copa_2_chao_escuro", "arvores/arvore_copa_4_chao_escuro",
	"arvores/arvore_copa_5_chao_escuro", "arvores/arvore_copa_4_chao_escuro",
]
const BUSHES_LIGHT: Array[String] = ["arvores/arbusto_4_chao_claro"]
const BUSHES_DARK: Array[String] = [
	"arvores/arbusto_1_chao_escuro", "arvores/arbusto_2_chao_escuro",
	"arvores/arbusto_3_chao_escuro", "arvores/arbusto_5_chao_escuro",
]

# Mato: sorteado à parte (e várias vezes por casa) pra casa ficar bem verde.
const GRASS_LIGHT: Array[String] = [
	"vegetacao/tufo_grama_claro_1", "vegetacao/tufo_grama_claro_2", "vegetacao/tufo_grama_claro_alto",
	"vegetacao/samambaia_clara", "vegetacao/moitinha_clara", "vegetacao/trevo",
	"vegetacao/grama_fresta", "vegetacao/flor_branca_clara",
]
const GRASS_DARK: Array[String] = [
	"vegetacao/tufo_grama_escuro_1", "vegetacao/tufo_grama_escuro_2", "vegetacao/tufo_grama_escuro_3",
	"vegetacao/tufo_grama_escuro_alto", "vegetacao/samambaia", "vegetacao/moita_pequena",
	"vegetacao/flor_branca", "vegetacao/flor_vermelha",
]
const GRASS_ATTEMPTS: int = 4
const GRASS_CHANCE: float = 0.55

# Peças "grandes" (tocos, moitas, pedras): mais comuns perto da borda lateral.
# Separadas por cor da casa pra o contorno ficar tom sobre tom.
const BIG_LIGHT: Array[String] = [
	"madeira/toco_cortado_chao_claro", "vegetacao/moita_grande", "vegetacao/samambaia_grande",
	"madeira/tora_deitada", "vegetacao/moita", "pedras/pedra_grande",
]
const BIG_DARK: Array[String] = [
	"madeira/toco_cortado_chao_escuro", "vegetacao/moita_grande", "vegetacao/samambaia_grande",
	"madeira/tronco_caido", "vegetacao/moita_frutos", "pedras/pedra_grande",
]
const SMALL_LIGHT: Array[String] = [
	"vegetacao/tufo_grama_claro_1", "vegetacao/tufo_grama_claro_2", "vegetacao/tufo_grama_claro_alto",
	"vegetacao/flor_branca_clara", "vegetacao/samambaia_clara", "vegetacao/moitinha_clara",
	"pedras/pedrinha_clara", "vegetacao/trevo", "folhas/folha_verde_clara", "folhas/folha_seca",
	"vegetacao/grama_fresta", "cogumelos/cogumelo", "madeira/galho_1", "madeira/no_madeira",
]
const SMALL_DARK: Array[String] = [
	"vegetacao/tufo_grama_escuro_1", "vegetacao/tufo_grama_escuro_2", "vegetacao/tufo_grama_escuro_3",
	"vegetacao/tufo_grama_escuro_alto", "vegetacao/flor_branca", "vegetacao/flor_vermelha",
	"vegetacao/samambaia", "vegetacao/moita_pequena", "pedras/pedra", "pedras/pedrinha",
	"folhas/folha_verde_1", "folhas/folha_verde_2", "folhas/folha_seca_2", "folhas/folhas_mistas",
	"cogumelos/cogumelos_duplo", "madeira/galho_2", "madeira/raiz", "madeira/rachadura",
	"madeira/toco_pequeno", "madeira/toco_em_pe",
]

# Resultado público: retângulo (coords do mundo) ocupado pela moldura.
var world_rect: Rect2 = Rect2()

var _tile: float = 78.0
var _scale: int = 3
var _tiles: Array = []      # [Texture2D, Rect2, flip_h, flip_v]
var _decor: Array = []      # [Texture2D, Vector2 centro, y_ordem]
var _clearings: Array = []  # [Texture2D, Vector2 centro]
var _board_rect: Rect2 = Rect2()
var _frame_tex: Texture2D = null

static var _tex_cache: Dictionary = {}

static func _tex(sub: String) -> Texture2D:
	if not _tex_cache.has(sub):
		var path = DIR + sub + ".png"
		_tex_cache[sub] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[sub]

# layers: RunManager.map_data (Array[Array] de MapNode já posicionados).
func build(layers: Array, tile_px: float, sprite_scale: int, min_col: int, max_col: int, min_row: int, max_row: int) -> void:
	_tile = tile_px
	_scale = sprite_scale
	_tiles.clear()
	_decor.clear()
	_clearings.clear()
	_frame_tex = _tex("moldura")

	var rng = RandomNumberGenerator.new()
	rng.seed = _layout_seed(layers)

	_board_rect = Rect2(
		Vector2(min_col * _tile - _tile / 2.0, min_row * _tile - _tile / 2.0),
		Vector2((max_col - min_col + 1) * _tile, (max_row - min_row + 1) * _tile))
	var pad = float(FRAME * _scale)
	world_rect = _board_rect.grow(pad)

	# Segmentos das trilhas e posições dos nós (pra manter decoração longe).
	var segments: Array = []
	var node_points: Array = []
	for layer in layers:
		for node in layer:
			node_points.append([node.position, node.type == MapNode.NodeType.Chefe])
			for child in node.children:
				segments.append([node.position, child.position])

	var half_cols = maxf(float(max_col), float(-min_col))
	for r in range(min_row, max_row + 1):
		for c in range(min_col, max_col + 1):
			var center = Vector2(c * _tile, r * _tile)
			var rect = Rect2(center - Vector2(_tile, _tile) / 2.0, Vector2(_tile, _tile))
			var is_light = ((r + c) % 2 + 2) % 2 == 0
			var pool = LIGHT_TILES if is_light else DARK_TILES
			var tex = _tex(BOARD_DIR + pool[rng.randi() % pool.size()])
			if tex != null:
				_tiles.append([tex, rect, rng.randf() < 0.5, rng.randf() < 0.5])

			var d_path = _distance_to_paths(center, segments)
			var d_node = _distance_to_nodes(center, node_points)
			var edge_w = clampf(absf(float(c)) / maxf(half_cols, 1.0), 0.0, 1.0)

			# Árvore (mais comum quanto mais perto da borda lateral); se não
			# vier árvore, às vezes um arbusto ou uma peça grande (toco, moita...).
			var p_tree = 0.06 + 0.40 * edge_w * edge_w
			var placed_tree = false
			if d_path > 1.4 * _tile and d_node > 1.6 * _tile and rng.randf() < p_tree:
				var trees = TREES_LIGHT if is_light else TREES_DARK
				var t = _tex(BOARD_DIR + trees[rng.randi() % trees.size()])
				if t != null:
					_decor.append([t, _snap(center + _jitter(rng, 0.12)), center.y])
					placed_tree = true
			elif d_path > 0.9 * _tile and d_node > 1.3 * _tile and rng.randf() < 0.07 + 0.10 * edge_w:
				var pool_big: Array[String] = []
				pool_big.append_array(BUSHES_LIGHT if is_light else BUSHES_DARK)
				pool_big.append_array(BIG_LIGHT if is_light else BIG_DARK)
				var bt = _tex(BOARD_DIR + pool_big[rng.randi() % pool_big.size()])
				if bt != null:
					_decor.append([bt, _snap(center + _jitter(rng, 0.2)), center.y])
					placed_tree = true

			# Detalhes pequenos (até 2 por casa), só fora da trilha/clareira.
			if not placed_tree and d_path > 0.75 * _tile and d_node > 1.1 * _tile:
				var smalls = SMALL_LIGHT if is_light else SMALL_DARK
				for attempt in range(3):
					if rng.randf() < 0.30:
						var st = _tex(BOARD_DIR + smalls[rng.randi() % smalls.size()])
						if st != null:
							var pos = _snap(center + _jitter(rng, 0.34))
							_decor.append([st, pos, pos.y])
				var grass = GRASS_LIGHT if is_light else GRASS_DARK
				for attempt in range(GRASS_ATTEMPTS):
					if rng.randf() < GRASS_CHANCE:
						var gt = _tex(BOARD_DIR + grass[rng.randi() % grass.size()])
						if gt != null:
							var gpos = _snap(center + _jitter(rng, 0.36))
							_decor.append([gt, gpos, gpos.y])

	_decor.sort_custom(func(a, b): return a[2] < b[2])

	for np in node_points:
		var ct = _tex("decoracao/clareira_boss" if np[1] else "decoracao/clareira_nodo")
		if ct != null:
			_clearings.append([ct, np[0]])

	queue_redraw()

func _layout_seed(layers: Array) -> int:
	var s = ""
	for layer in layers:
		for node in layer:
			s += "%d,%d,%d;" % [int(node.position.x), int(node.position.y), int(node.type)]
	return hash(s)

func _jitter(rng: RandomNumberGenerator, amount: float) -> Vector2:
	return Vector2(rng.randf_range(-amount, amount), rng.randf_range(-amount, amount)) * _tile

func _snap(p: Vector2) -> Vector2:
	return (p / float(_scale)).round() * float(_scale)

func _distance_to_paths(p: Vector2, segments: Array) -> float:
	var best = INF
	for seg in segments:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var q = Geometry2D.get_closest_point_to_segment(p, a, b)
		best = minf(best, p.distance_to(q))
	return best

func _distance_to_nodes(p: Vector2, node_points: Array) -> float:
	var best = INF
	for np in node_points:
		best = minf(best, p.distance_to(np[0]))
	return best

func _draw() -> void:
	if _board_rect.size == Vector2.ZERO:
		return
	# Fora do tabuleiro: verde-escuro quase preto.
	draw_rect(Rect2(Vector2(-6000, -6000), Vector2(12000, 12000)), Color(0.04, 0.06, 0.04))

	for t in _tiles:
		var tex: Texture2D = t[0]
		var rect: Rect2 = t[1]
		var half = rect.size / 2.0
		draw_set_transform(rect.position + half, 0.0, Vector2(-1.0 if t[2] else 1.0, -1.0 if t[3] else 1.0))
		draw_texture_rect(tex, Rect2(-half, rect.size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for c in _clearings:
		var ctex: Texture2D = c[0]
		var sz = ctex.get_size() * float(_scale)
		draw_texture_rect(ctex, Rect2(_snap(c[1]) - sz / 2.0, sz), false)

	for d in _decor:
		var dtex: Texture2D = d[0]
		var dsz = dtex.get_size() * float(_scale)
		draw_texture_rect(dtex, Rect2(d[1] - dsz / 2.0, dsz), false)

	_draw_frame()

func _draw_frame() -> void:
	if _frame_tex == null:
		return
	var S = float(_scale)
	var fw = float(FRAME) * S
	var cols = int(round(_board_rect.size.x / _tile))
	var rows = int(round(_board_rect.size.y / _tile))
	var outer = world_rect
	var tw = float(NATIVE_TILE)
	var tex_w = float(_frame_tex.get_width())
	var tex_h = float(_frame_tex.get_height())

	for i in range(cols):
		var sx = float(FRAME) + tw * float(i % FRAME_SRC_COLS)
		var dx = _board_rect.position.x + float(i) * _tile
		draw_texture_rect_region(_frame_tex, Rect2(dx, outer.position.y, _tile, fw), Rect2(sx, 0, tw, float(FRAME)))
		draw_texture_rect_region(_frame_tex, Rect2(dx, _board_rect.end.y, _tile, fw), Rect2(sx, tex_h - float(FRAME), tw, float(FRAME)))
	for j in range(rows):
		var sy = float(FRAME) + tw * float(j % FRAME_SRC_ROWS)
		var dy = _board_rect.position.y + float(j) * _tile
		draw_texture_rect_region(_frame_tex, Rect2(outer.position.x, dy, fw, _tile), Rect2(0, sy, float(FRAME), tw))
		draw_texture_rect_region(_frame_tex, Rect2(_board_rect.end.x, dy, fw, _tile), Rect2(tex_w - float(FRAME), sy, float(FRAME), tw))

	# Cantos (12x12 nativos, sobrepõem 2 px do tabuleiro).
	var cs = float(FRAME_CORNER)
	var cd = cs * S
	draw_texture_rect_region(_frame_tex, Rect2(outer.position, Vector2(cd, cd)), Rect2(0, 0, cs, cs))
	draw_texture_rect_region(_frame_tex, Rect2(Vector2(outer.end.x - cd, outer.position.y), Vector2(cd, cd)), Rect2(tex_w - cs, 0, cs, cs))
	draw_texture_rect_region(_frame_tex, Rect2(Vector2(outer.position.x, outer.end.y - cd), Vector2(cd, cd)), Rect2(0, tex_h - cs, cs, cs))
	draw_texture_rect_region(_frame_tex, Rect2(outer.end - Vector2(cd, cd), Vector2(cd, cd)), Rect2(tex_w - cs, tex_h - cs, cs, cs))
