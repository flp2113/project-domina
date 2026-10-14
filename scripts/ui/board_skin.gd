class_name BoardSkin

# Gera o visual do tabuleiro (moldura de madeira + casinhas) a partir de
# UM ÚNICO sprite de referência 8x8 (assets/sprites/board/board_frame_8x8.png),
# fatiando-o em código: extraímos TODAS as 64 casinhas (cada uma com um
# padrão de veio de madeira diferente — 32 claras + 32 escuras, nenhuma
# repetida no sprite original) e a moldura em 9 pedaços (4 cantos fixos +
# 4 bordas esticáveis), e remontamos isso pra QUALQUER tamanho de tabuleiro
# (6x6, 10x10, 8x10, etc — ver map_generator.POSSIBLE_BOARD_SIZES) variando
# o padrão usado em cada casinha, sem precisar de uma arte nova por tamanho.
#
# Se o arquivo não existir, has_sprite() retorna false e quem chama cai de
# volta pro desenho antigo (retângulos coloridos) — nada quebra se você
# ainda não tiver colocado o sprite.

# Estilos de tabuleiro. Cada um é UM sprite 8x8 fatiado em código e
# remontado pra qualquer tamanho:
#  - SKIN_WOOD: duelos do bioma Floresta (moldura grossa; as 64 casinhas
#    têm veio diferente, então qualquer uma pode ser usada em qualquer lugar).
#  - SKIN_TUTORIAL: duelos do tutorial (moldura fina; a maioria das casinhas
#    é lisa e só algumas têm riscos/manchas — essas "com defeito" entram
#    esparsas e nunca coladas ou repetidas por perto, ver _build_layout).
const SKIN_WOOD := "wood"
const SKIN_TUTORIAL := "tutorial"

# path, moldura (fração do lado da imagem), grade de referência e se o
# estilo usa defeitos esparsos.
const _SKINS := {
	SKIN_WOOD: {"path": "res://assets/sprites/board/board_floresta_8x8.png", "frame_frac": 18.0 / 292.0, "sparse": false, "segmented_frame": true},
	SKIN_TUTORIAL: {"path": "res://assets/sprites/board/board_tutorial_8x8.png", "frame_frac": 8.0 / 272.0, "sparse": true},
}
const _REF_GRID: int = 8

# Convenção: casinha do canto superior-esquerdo (linha 0, coluna 0) da
# arte de referência é CLARA — igual ao padrão de damas e igual ao que
# Board._draw() já assume ((r+c)%2==0 -> clara).
const _TOP_LEFT_IS_LIGHT: bool = true

# Estilo esparso: nota de "sujeira" de cada casinha = nº de pixels do miolo
# diferentes da cor dominante dela. Até _CLEAN_MAX é lisa; acima de
# _HEAVY_MIN é mancha grande; no meio, riscos leves.
const _CLEAN_MAX: int = 4
const _HEAVY_MIN: int = 30
# Chance (em %) de uma casinha receber defeito leve / pesado (sujeito às
# regras de distância — na prática sai bem menos que isso).
const _MINOR_CHANCE: int = 22
const _HEAVY_CHANCE: int = 7
# Distância mínima (em casinhas, Chebyshev) entre duas casinhas com defeito,
# e entre duas usando o MESMO desenho de defeito.
const _DEFECT_GAP: int = 2
const _SAME_VARIANT_GAP: int = 5

static var _skins: Dictionary = {}   # id -> dados carregados
static var _layouts: Dictionary = {} # "id:rows:cols" -> Array[int] (índice do desenho por casinha)

static func _ensure_loaded(skin_id: String = SKIN_WOOD) -> void:
	if _skins.has(skin_id):
		return
	var cfg = _SKINS.get(skin_id, null)
	if cfg == null or not ResourceLoader.exists(cfg["path"]):
		_skins[skin_id] = null
		return

	var tex: Texture2D = load(cfg["path"])
	var tex_size = tex.get_size()
	var margin = tex_size.x * cfg["frame_frac"]
	var tile_px = (tex_size.x - 2.0 * margin) / float(_REF_GRID)
	var data := {
		"tex": tex, "size": tex_size, "margin": margin, "tile_px": tile_px,
		"light": [], "dark": [], "sparse": cfg["sparse"],
		"segmented": cfg.get("segmented_frame", false), "edge_detail": [],
	}
	var img: Image = tex.get_image() if cfg["sparse"] else null
	for r in range(_REF_GRID):
		for c in range(_REF_GRID):
			var region = Rect2(margin + c * tile_px, margin + r * tile_px, tile_px, tile_px)
			var is_light = ((r + c) % 2 == 0) == _TOP_LEFT_IS_LIGHT
			var info = _dirt_score(img, region)
			data["light" if is_light else "dark"].append({"region": region, "score": info["score"], "base": info["base"]})
	if data["segmented"]:
		data["edge_detail"] = _edge_detail_scores(tex.get_image(), margin, tile_px)
	if cfg["sparse"]:
		# Casinha com tom de fundo diferente do dominante do grupo conta como
		# "leve" (aparece pouco), mesmo sem riscos — senão vira mancha de cor.
		for key in ["light", "dark"]:
			var tally := {}
			for t in data[key]:
				tally[t["base"]] = tally.get(t["base"], 0) + 1
			var dom := ""
			var dom_n := 0
			for b in tally:
				if tally[b] > dom_n:
					dom_n = tally[b]
					dom = b
			for t in data[key]:
				if t["base"] != dom:
					t["score"] = maxi(t["score"], _CLEAN_MAX + 1)
	_skins[skin_id] = data

# Moldura "segmentada": a borda da arte (8 casinhas de comprimento) é fatiada
# em 8 pedaços de 1 casinha. Num tabuleiro 8x8 saem na ordem original (a arte
# exata); em outros tamanhos os pedaços são sorteados, com os que têm detalhe
# (folhagem, cogumelos) esparsos e nunca colados, e o resto liso — assim os
# detalhes não esticam nem se repetem em fila.
# Nota de detalhe de cada pedaço: [topo, base, esquerda, direita] -> 8 notas.
static func _edge_detail_scores(img: Image, margin: float, tile_px: float) -> Array:
	var w = img.get_width()
	var h = img.get_height()
	var m = int(margin)
	var out: Array = []
	for edge in range(4):
		var arr: Array = []
		for k in range(_REF_GRID):
			var n = 0
			var a = int(margin + k * tile_px)
			var b = int(margin + (k + 1) * tile_px)
			for t in range(a, b):
				for u in range(m):
					var px: Color
					match edge:
						0: px = img.get_pixel(t, u)
						1: px = img.get_pixel(t, h - m + u)
						2: px = img.get_pixel(u, t)
						_: px = img.get_pixel(w - m + u, t)
					if px.a < 0.5:
						continue
					var green = px.g > px.r + 0.04 and px.g > px.b + 0.04
					var red = px.r > px.g + 0.2 and px.r > px.b + 0.2
					if green or red:
						n += 1
			arr.append(n)
		out.append(arr)
	return out

# Qual pedaço (0..7) usar na posição i de uma borda com `count` casinhas.
static func _edge_segment(skin: Dictionary, edge: int, i: int, count: int, prev: Array) -> int:
	if count == _REF_GRID:
		return i
	var scores: Array = skin["edge_detail"][edge]
	var plain: Array = []
	var detailed: Array = []
	for k in range(_REF_GRID):
		if scores[k] <= 6:
			plain.append(k)
		else:
			detailed.append(k)
	var roll = _variant_index(i + 31 * edge, count + 7, 100)
	var last_detail = prev[1]
	if not detailed.is_empty() and roll < 16 and i - last_detail >= 4 and i > 0 and i < count - 1:
		prev[1] = i
		var d = detailed[_variant_index(i, edge + 3, detailed.size())]
		if d == prev[0] and detailed.size() > 1:
			d = detailed[(detailed.find(d) + 1) % detailed.size()]
		prev[0] = d
		return d
	if plain.is_empty():
		return _variant_index(i, edge, _REF_GRID)
	var pick = plain[_variant_index(i * 3 + edge, count * 5 + 1, plain.size())]
	if pick == prev[2] and plain.size() > 1:
		pick = plain[(plain.find(pick) + 1) % plain.size()]
	prev[2] = pick
	return pick

# Nº de pixels do miolo da casinha que fogem da cor dominante dela.
static func _dirt_score(img: Image, region: Rect2) -> Dictionary:
	if img == null:
		return {"score": 0, "base": ""}
	var inset = int(round(region.size.x * 0.0625))
	var x0 = int(region.position.x) + inset
	var y0 = int(region.position.y) + inset
	var x1 = int(region.end.x) - inset
	var y1 = int(region.end.y) - inset
	var counts := {}
	var total := 0
	for y in range(y0, y1):
		for x in range(x0, x1):
			var col = img.get_pixel(x, y).to_html()
			counts[col] = counts.get(col, 0) + 1
			total += 1
	var best := 0
	var best_col := ""
	for k in counts:
		if counts[k] > best:
			best = counts[k]
			best_col = k
	return {"score": total - best, "base": best_col}

# Escolhe, de forma determinística (mesma casinha sempre cai no mesmo
# padrão — sem "piscar" a cada redraw), qual das variações do pool usar
# pra posição (r, c). Mistura linha e coluna pra não repetir o mesmo
# padrão em listras/colunas inteiras.
static func _variant_index(r: int, c: int, count: int) -> int:
	if count <= 1:
		return 0
	var h = (r * 73856093) ^ (c * 19349663)
	if h < 0:
		h = -h
	return h % count

static func has_sprite(skin_id: String = SKIN_WOOD) -> bool:
	_ensure_loaded(skin_id)
	return _skins[skin_id] != null

# Espessura da moldura (em pixels de tela) pro cell_size atual — usada por
# quem centraliza o tabuleiro na viewport, já que a moldura cresce PRA
# FORA do retângulo das casinhas (ver draw_frame).
static func get_frame_px(cell_size: float, skin_id: String = SKIN_WOOD) -> float:
	_ensure_loaded(skin_id)
	var d = _skins[skin_id]
	if d == null:
		return 0.0
	return cell_size * (d["margin"] / d["tile_px"])

# Monta (e guarda) qual desenho cada casinha usa, só pro estilo esparso.
# Determinístico por (estilo, linhas, colunas): não pisca entre redraws.
# Regras: lisas são a regra; defeito leve/pesado só com sorteio baixo, nunca
# a menos de _DEFECT_GAP casinhas de outro defeito, e o mesmo desenho de
# defeito só reaparece a _SAME_VARIANT_GAP ou mais de distância. Quando
# vários servem, escolhe o desenho menos usado até agora.
static func _build_layout(skin_id: String, rows: int, cols: int) -> Array:
	_ensure_loaded(skin_id)
	var key = "%s:%d:%d" % [skin_id, rows, cols]
	if _layouts.has(key):
		return _layouts[key]
	var d = _skins[skin_id]
	var out: Array = []
	out.resize(rows * cols)
	var defect_at := {}   # Vector2i -> índice do desenho (dentro do pool)
	var use_count := {}   # "L3"/"D7" -> vezes usado
	for r in range(rows):
		for c in range(cols):
			var is_light = (r + c) % 2 == 0
			var pool: Array = d["light" if is_light else "dark"]
			var roll = _variant_index(r + 11, c + 5, 100)
			var want = 0  # 0 lisa, 1 leve, 2 pesada
			if roll < _HEAVY_CHANCE:
				want = 2
			elif roll < _MINOR_CHANCE:
				want = 1
			var pick := -1
			if want > 0 and _defect_clear(defect_at, r, c, _DEFECT_GAP):
				pick = _pick_variant(pool, want, is_light, r, c, defect_at, use_count)
			if pick < 0:
				pick = _pick_clean(pool, is_light, r, c, use_count)
			else:
				defect_at[Vector2i(c, r)] = pick
			out[r * cols + c] = pick
	_layouts[key] = out
	return out

static func _defect_clear(defect_at: Dictionary, r: int, c: int, gap: int) -> bool:
	for dr in range(-gap, gap + 1):
		for dc in range(-gap, gap + 1):
			if defect_at.has(Vector2i(c + dc, r + dr)):
				return false
	return true

static func _pick_variant(pool: Array, want: int, is_light: bool, r: int, c: int, defect_at: Dictionary, use_count: Dictionary) -> int:
	var best := -1
	var best_n := 1 << 30
	var start = _variant_index(r, c, pool.size())
	for k in range(pool.size()):
		var i = (start + k) % pool.size()
		var sc: int = pool[i]["score"]
		var kind = 0 if sc <= _CLEAN_MAX else (2 if sc >= _HEAVY_MIN else 1)
		if kind != want:
			continue
		# Mesmo desenho por perto? Pula.
		var near := false
		for dr in range(-_SAME_VARIANT_GAP, _SAME_VARIANT_GAP + 1):
			for dc in range(-_SAME_VARIANT_GAP, _SAME_VARIANT_GAP + 1):
				var p = Vector2i(c + dc, r + dr)
				if defect_at.has(p) and defect_at[p] == i and ((p.y + p.x) % 2 == 0) == is_light:
					near = true
		if near:
			continue
		var n = use_count.get(_vkey(is_light, i), 0)
		if n < best_n:
			best_n = n
			best = i
	if best >= 0:
		use_count[_vkey(is_light, best)] = best_n + 1
	return best

static func _pick_clean(pool: Array, is_light: bool, r: int, c: int, use_count: Dictionary) -> int:
	var cleans: Array = []
	for i in range(pool.size()):
		if pool[i]["score"] <= _CLEAN_MAX:
			cleans.append(i)
	if cleans.is_empty():
		return _variant_index(r, c, pool.size())
	return cleans[_variant_index(r, c, cleans.size())]

static func _vkey(is_light: bool, i: int) -> String:
	return ("L%d" if is_light else "D%d") % i

# Desenha as N x M casinhas. Estilo "wood": qualquer uma das 64 variações,
# escolhida por hash. Estilo "tutorial": maioria lisa + defeitos esparsos
# (ver _build_layout). tint_light/tint_dark multiplicam a cor (branco = sem
# alteração; usado pra rebater o tema difícil/chefe sem perder a textura).
static func draw_tiles(canvas: CanvasItem, board_offset: Vector2, rows: int, cols: int, cell_size: float, tint_light: Color = Color.WHITE, tint_dark: Color = Color.WHITE, skin_id: String = SKIN_WOOD) -> void:
	_ensure_loaded(skin_id)
	var d = _skins[skin_id]
	if d == null:
		return
	var layout: Array = _build_layout(skin_id, rows, cols) if d["sparse"] else []

	for r in range(rows):
		for c in range(cols):
			var rect = Rect2(board_offset.x + c * cell_size, board_offset.y + r * cell_size, cell_size, cell_size)
			var is_light = (r + c) % 2 == 0
			var pool: Array = d["light" if is_light else "dark"]
			var idx = layout[r * cols + c] if d["sparse"] else _variant_index(r, c, pool.size())
			var tint = tint_light if is_light else tint_dark
			canvas.draw_texture_rect_region(d["tex"], rect, pool[idx]["region"], tint)

# Desenha a moldura de madeira em volta do retângulo do tabuleiro, como um
# 9-slice manual: os 4 cantos são desenhados no tamanho original (sem
# esticar, pra não deformar o entalhe), e as 4 bordas esticam só no eixo
# que acompanha o tamanho do tabuleiro.
static func draw_frame(canvas: CanvasItem, board_offset: Vector2, rows: int, cols: int, cell_size: float, tint: Color = Color.WHITE, skin_id: String = SKIN_WOOD) -> void:
	_ensure_loaded(skin_id)
	var d = _skins[skin_id]
	if d == null:
		return
	var _texture: Texture2D = d["tex"]
	var _tex_size: Vector2 = d["size"]
	var m: float = d["margin"]
	var frame_px = cell_size * (m / d["tile_px"])

	var board_size = Vector2(cols * cell_size, rows * cell_size)
	var outer_pos = board_offset - Vector2(frame_px, frame_px)
	var outer_size = board_size + Vector2(frame_px * 2.0, frame_px * 2.0)

	var w = _tex_size.x
	var h = _tex_size.y

	var src_tl = Rect2(0.0, 0.0, m, m)
	var src_tr = Rect2(w - m, 0.0, m, m)
	var src_bl = Rect2(0.0, h - m, m, m)
	var src_br = Rect2(w - m, h - m, m, m)
	var src_top = Rect2(m, 0.0, w - 2.0 * m, m)
	var src_bottom = Rect2(m, h - m, w - 2.0 * m, m)
	var src_left = Rect2(0.0, m, m, h - 2.0 * m)
	var src_right = Rect2(w - m, m, m, h - 2.0 * m)

	# Cantos (tamanho fixo, sem esticar).
	canvas.draw_texture_rect_region(_texture, Rect2(outer_pos, Vector2(frame_px, frame_px)), src_tl, tint)
	canvas.draw_texture_rect_region(_texture, Rect2(outer_pos + Vector2(outer_size.x - frame_px, 0.0), Vector2(frame_px, frame_px)), src_tr, tint)
	canvas.draw_texture_rect_region(_texture, Rect2(outer_pos + Vector2(0.0, outer_size.y - frame_px), Vector2(frame_px, frame_px)), src_bl, tint)
	canvas.draw_texture_rect_region(_texture, Rect2(outer_pos + outer_size - Vector2(frame_px, frame_px), Vector2(frame_px, frame_px)), src_br, tint)

	# Bordas.
	if d["segmented"]:
		_draw_segmented_edges(canvas, d, outer_pos, outer_size, rows, cols, cell_size, frame_px, tint)
		return
	# Bordas (esticam no eixo que acompanha o tamanho do tabuleiro).
	canvas.draw_texture_rect_region(_texture, Rect2(outer_pos + Vector2(frame_px, 0.0), Vector2(outer_size.x - 2.0 * frame_px, frame_px)), src_top, tint)
	canvas.draw_texture_rect_region(_texture, Rect2(outer_pos + Vector2(frame_px, outer_size.y - frame_px), Vector2(outer_size.x - 2.0 * frame_px, frame_px)), src_bottom, tint)
	canvas.draw_texture_rect_region(_texture, Rect2(outer_pos + Vector2(0.0, frame_px), Vector2(frame_px, outer_size.y - 2.0 * frame_px)), src_left, tint)
	canvas.draw_texture_rect_region(_texture, Rect2(outer_pos + Vector2(outer_size.x - frame_px, frame_px), Vector2(frame_px, outer_size.y - 2.0 * frame_px)), src_right, tint)


# Bordas da moldura segmentada: um pedaço por casinha (ver _edge_segment).
static func _draw_segmented_edges(canvas: CanvasItem, d: Dictionary, outer_pos: Vector2, outer_size: Vector2, rows: int, cols: int, cell_size: float, frame_px: float, tint: Color) -> void:
	var tex: Texture2D = d["tex"]
	var m: float = d["margin"]
	var tp: float = d["tile_px"]
	var w = d["size"].x
	var h = d["size"].y
	for edge in range(4):
		var count = cols if edge < 2 else rows
		var prev := [-1, -100, -1]
		for i in range(count):
			var k = _edge_segment(d, edge, i, count, prev)
			var along = m + float(k) * tp
			var dst: Rect2
			var src: Rect2
			match edge:
				0:
					dst = Rect2(outer_pos + Vector2(frame_px + i * cell_size, 0.0), Vector2(cell_size, frame_px))
					src = Rect2(along, 0.0, tp, m)
				1:
					dst = Rect2(outer_pos + Vector2(frame_px + i * cell_size, outer_size.y - frame_px), Vector2(cell_size, frame_px))
					src = Rect2(along, h - m, tp, m)
				2:
					dst = Rect2(outer_pos + Vector2(0.0, frame_px + i * cell_size), Vector2(frame_px, cell_size))
					src = Rect2(0.0, along, m, tp)
				_:
					dst = Rect2(outer_pos + Vector2(outer_size.x - frame_px, frame_px + i * cell_size), Vector2(frame_px, cell_size))
					src = Rect2(w - m, along, m, tp)
			canvas.draw_texture_rect_region(tex, dst, src, tint)
