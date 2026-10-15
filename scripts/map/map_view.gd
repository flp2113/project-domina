class_name MapView
extends Node2D

# Configurações do Tabuleiro (casa = 26px nativos × MAP_SPRITE_SCALE)
const MAP_SPRITE_SCALE: int = 3
const TILE_SIZE: float = 26.0 * MAP_SPRITE_SCALE
const CAMERA_ZOOM: float = 1.0
# Nodos/indicadores/peão: ampliação própria (menor que a do cenário). O peão
# usa o sprite 32px na MESMA escala, então encaixa 1:1 no furo do soquete.
const NODE_SPRITE_SCALE: int = MapNodeArt.NODE_SPRITE_SCALE
const PAWN_SPRITE_PX: float = 32.0
const FOREST_MARGIN_COLS: int = 2

const TILES_PER_LAYER: int = 5
const TILES_BETWEEN_NODES: int = 3

@export_group("Linhas")
@export var default_line_color: Color = Color(0.3, 0.35, 0.45, 0.7)
@export var active_line_color: Color = Color(1.0, 0.84, 0.2, 1.0)
@export var active_line_width: float = 6.0

@onready var lines_container = $LinesContainer
@onready var nodes_container = $NodesContainer
@onready var camera: Camera2D = $Camera2D

var generator = MapGenerator.new()
var node_buttons: Dictionary = {}
var node_size_labels: Dictionary = {}
var lines_dictionary: Dictionary = {}

var forest: ForestBackground
var island_base: IslandBase
var player_pawn: MapPlayerPawn
# Nó onde o peão está parado. Parado, o peão NÃO é desenhado à parte: ele já
# vem "assado" no próprio sprite do soquete (ver _socket_with_pawn), então
# o encaixe é exato em qualquer resolução/escala de janela. Só durante o
# salto o peão avulso aparece.
var pawn_rest_node: MapNode = null
var is_traveling: bool = false

var inventory_ui: InventoryUI
var hud_bar: HUDBar

func _ready() -> void:
	randomize()
	z_index = 0
	var sky := SpaceBackground.new()   # céu estrelado atrás do mapa
	sky.floater_alpha = 0.55           # ilhas/peças discretas (há texto por cima)
	add_child(sky)
	_setup_map_ui()
	_setup_player_pawn()

	if camera != null:
		camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)

	if RunManager.map_data.is_empty():
		RunManager.map_data = generator.generate_map()
		_position_nodes(RunManager.map_data)
		if not RunManager.map_data.is_empty() and not RunManager.map_data[0].is_empty():
			RunManager.current_node = RunManager.map_data[0][0]

	_build_forest(RunManager.map_data)
	_draw_lines(RunManager.map_data)
	_instantiate_node_ui(RunManager.map_data)
	_restore_visited_connections()

	if RunManager.current_node != null:
		player_pawn.set_initial_position(RunManager.current_node.position, TILE_SIZE)
		pawn_rest_node = RunManager.current_node
		player_pawn.visible = false
		_set_current_node(RunManager.current_node, false)

func _setup_player_pawn() -> void:
	player_pawn = MapPlayerPawn.new()
	player_pawn.piece_px = PAWN_SPRITE_PX * NODE_SPRITE_SCALE
	add_child(player_pawn)

func _setup_map_ui() -> void:
	# Instancia a barra lateral padronizada
	hud_bar = HUDBar.new()
	add_child(hud_bar)
	hud_bar.open_laws_requested.connect(toggle_inventory)
	hud_bar.open_cards_requested.connect(func(): inventory_ui.open_on_tab(InventoryUI.Tab.CARDS))

	# Grimório de Leis (inventário)
	var canvas = CanvasLayer.new()
	canvas.name = "MapInventoryLayer"
	canvas.layer = 110
	add_child(canvas)

	inventory_ui = InventoryUI.new()
	canvas.add_child(inventory_ui)
	inventory_ui.setup()

	hud_bar.refresh_cards_inventory_count()

func toggle_inventory() -> void:
	if inventory_ui:
		inventory_ui.toggle_visibility()

func _input(event: InputEvent) -> void:
	if is_traveling:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.keycode == KEY_I:
			toggle_inventory()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if inventory_ui and inventory_ui.visible:
				inventory_ui.visible = false
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_B:
			# DEBUG: acesso direto à mesa de apostas, sem precisar achar o
			# nó no mapa — só pra facilitar teste, não é um atalho pro
			# jogo normal.
			is_traveling = true
			get_tree().call_deferred("change_scene_to_file", "res://bet_view.tscn")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E:
			# DEBUG: acesso direto a um evento "?" (mesma ideia da tecla B).
			is_traveling = true
			get_tree().call_deferred("change_scene_to_file", "res://event_view.tscn")
			get_viewport().set_input_as_handled()

func _position_nodes(layers: Array[Array]) -> void:
	for layer_index in range(layers.size()):
		var layer = layers[layer_index]
		var total_nodes = layer.size()
		var grid_row = -layer_index * TILES_PER_LAYER
		var start_col = -int((total_nodes - 1) * TILES_BETWEEN_NODES / 2.0)
		# Espalha melhor: camadas mais estreitas que o máximo deslizam 1 casa
		# para a esquerda/direita (começo e chefe ficam no centro), então o mapa
		# não vira uma coluna simétrica.
		if total_nodes > 1 and total_nodes < 4:
			start_col += [-1, 0, 1].pick_random()

		for node_index in range(total_nodes):
			var node: MapNode = layer[node_index]
			var grid_col = start_col + (node_index * TILES_BETWEEN_NODES)

			if (grid_row + grid_col) % 2 == 0:
				grid_col += 1

			node.position = Vector2(grid_col * TILE_SIZE, grid_row * TILE_SIZE)

func _build_forest(layers: Array[Array]) -> void:
	var min_c := 0
	var max_c := 0
	var min_r := 0
	var max_r := 0
	for layer in layers:
		for node in layer:
			var c = int(round(node.position.x / TILE_SIZE))
			var r = int(round(node.position.y / TILE_SIZE))
			min_c = mini(min_c, c)
			max_c = maxi(max_c, c)
			min_r = mini(min_r, r)
			max_r = maxi(max_r, r)
	var half = maxi(4, maxi(-min_c, max_c) + FOREST_MARGIN_COLS)
	forest = ForestBackground.new()
	forest.name = "ForestBackground"
	add_child(forest)
	move_child(forest, 0)
	# Uma coluna a menos de cada lado (antes: só do direito), então a largura
	# fica simétrica em torno do centro; a câmera acompanha o centro do tabuleiro.
	forest.build(layers, TILE_SIZE, MAP_SPRITE_SCALE, -half + 1, half - 1, min_r - 2, max_r + 2)
	if camera != null:
		camera.position.x = forest.world_rect.get_center().x
	# Base rochosa: o mapa é uma ilha flutuando no espaço (atrás do tabuleiro).
	island_base = IslandBase.new()
	island_base.name = "IslandBase"
	add_child(island_base)
	move_child(island_base, 0)
	island_base.build(forest.world_rect, MAP_SPRITE_SCALE, camera)

func _draw_lines(layers: Array[Array]) -> void:
	for layer in layers:
		for node in layer:
			for child in node.children:
				var trail = ForestTrail.new()
				trail.setup(node.position, child.position, MAP_SPRITE_SCALE)
				lines_container.add_child(trail)
				lines_dictionary[_get_connection_key(node, child)] = trail
	_refresh_lines()

# Estado visual de cada caminho: percorrido / selecionado (saindo do nó
# atual) / bloqueado (ramo que ficou pra trás sem ser percorrido) / normal.
func _refresh_lines() -> void:
	var current: MapNode = RunManager.current_node
	var selected_lines: Array[ForestTrail] = []
	var visited_lines: Array[ForestTrail] = []
	for layer in RunManager.map_data:
		for node in layer:
			for child in node.children:
				var key = _get_connection_key(node, child)
				var line: ForestTrail = lines_dictionary.get(key)
				if line == null:
					continue
				var state = "normal"
				if RunManager.visited_connections.has(key):
					state = "percorrido"
				elif current != null and node == current:
					state = "selecionado"
				elif current != null and node.id.x <= current.id.x:
					state = "bloqueado"
				line.set_state(state)
				# Trilhas que se sobrepõem: disponível/percorrida desenha por cima
				# da bloqueada/normal (ordem dentro do LinesContainer, que fica
				# sempre abaixo dos nodos — nada de z_index).
				if state == "selecionado":
					selected_lines.append(line)
				elif state == "percorrido":
					visited_lines.append(line)
	for l in visited_lines:
		lines_container.move_child(l, -1)
	for l in selected_lines:
		lines_container.move_child(l, -1)

func _restore_visited_connections() -> void:
	_refresh_lines()

func _get_connection_key(parent: MapNode, child: MapNode) -> String:
	return str(parent.id) + "->" + str(child.id)

const _NODE_SPRITES: Dictionary = {
	MapNode.NodeType.Começo: "nodo_inicio",
	MapNode.NodeType.Duelo: "nodo_batalha",
	MapNode.NodeType.DueloForte: "nodo_elite",
	MapNode.NodeType.Chefe: "nodo_boss",
	MapNode.NodeType.Loja: "nodo_loja",
	MapNode.NodeType.Evento: "nodo_evento",
	MapNode.NodeType.Melhoria: "nodo_estrela",
	MapNode.NodeType.Aposta: "nodo_desafio",
}

var node_art: Dictionary = {}        # MapNode -> {"base": TextureRect, "ind": TextureRect}
var _hovered_node: MapNode = null

func _map_sprite(file: String) -> Texture2D:
	return MapNodeArt.sprite(file)

func _make_map_rect(tex: Texture2D) -> TextureRect:
	return MapNodeArt.make_rect(tex)

func _instantiate_node_ui(layers: Array[Array]) -> void:
	for layer in layers:
		for node in layer:
			var is_boss = node.type == MapNode.NodeType.Chefe
			var base_tex = _map_sprite(_NODE_SPRITES.get(node.type, "nodo_batalha"))
			var node_px: Vector2 = base_tex.get_size() if base_tex != null else Vector2(64, 64)

			# Botão invisível só pra receber o clique/hover; o visual são
			# os sprites por cima (ignoram o mouse).
			var btn = Button.new()
			btn.text = ""
			btn.flat = true
			btn.focus_mode = Control.FOCUS_NONE
			for st in ["normal", "hover", "pressed", "disabled", "focus"]:
				btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
			btn.custom_minimum_size = node_px
			btn.size = node_px
			btn.position = node.position - (btn.size / 2.0)
			btn.pressed.connect(_on_node_clicked.bind(node))
			btn.mouse_entered.connect(_on_node_hover.bind(node, true))
			btn.mouse_exited.connect(_on_node_hover.bind(node, false))
			nodes_container.add_child(btn)
			node_buttons[node] = btn

			var base = _make_map_rect(base_tex)
			base.size = node_px
			btn.add_child(base)

			# Indicador (anel/cadeado/check) centralizado no nó.
			var ind = _make_map_rect(_map_sprite("ind_disponivel_boss" if is_boss else "ind_disponivel"))
			btn.add_child(ind)

			node_art[node] = {"base": base, "ind": ind}

			# Só duelos mostram o tamanho do tabuleiro, logo abaixo do nó.
			if node.type in [MapNode.NodeType.Duelo, MapNode.NodeType.DueloForte, MapNode.NodeType.Chefe]:
				var size_label = Label.new()
				size_label.text = node.get_size_text()
				size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				size_label.add_theme_font_size_override("font_size", 32)
				size_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
				size_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
				size_label.add_theme_constant_override("outline_size", 7)
				size_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				size_label.size = Vector2(node_px.x, 40)
				size_label.position = Vector2(0, node_px.y + 6)
				btn.add_child(size_label)
				node_size_labels[node] = size_label

func _on_node_hover(node: MapNode, entered: bool) -> void:
	_hovered_node = node if entered else (null if _hovered_node == node else _hovered_node)
	_update_nodes_visual_state()

func _is_node_completed(node: MapNode) -> bool:
	if node == RunManager.current_node:
		return false
	for layer in RunManager.map_data:
		for other in layer:
			for child in other.children:
				if (other == node or child == node) and RunManager.visited_connections.has(_get_connection_key(other, child)):
					return true
	return false

func _set_current_node(node: MapNode, animate_line: bool = true) -> void:
	if RunManager.current_node and RunManager.current_node != node:
		var key = _get_connection_key(RunManager.current_node, node)
		if not RunManager.visited_connections.has(key):
			RunManager.visited_connections.append(key)
		if animate_line:
			_highlight_connection(RunManager.current_node, node)

	RunManager.current_node = node
	_update_nodes_visual_state()
	_move_camera_to_node(node)

func _update_nodes_visual_state() -> void:
	for node in node_buttons:
		var btn: Button = node_buttons[node]
		var art: Dictionary = node_art[node]
		var base: TextureRect = art["base"]
		var ind: TextureRect = art["ind"]
		var size_label: Label = node_size_labels.get(node)
		var boss_suffix = "_boss" if node.type == MapNode.NodeType.Chefe else ""
		var sprite_name: String = _NODE_SPRITES.get(node.type, "nodo_batalha")
		var ind_name = ""
		var base_mod = Color.WHITE
		var label_col = Color(1.0, 0.92, 0.7)

		# Nodos "de encaixe": o peão do jogador assenta no soquete do nó atual.
		# Concluído = soquete com o símbolo apagado + check; caminho que ficou
		# pra trás = soquete vazio, sem cor, com cadeado; os demais seguem
		# com o símbolo escurecido até ficarem alcançáveis.
		var overlay_name = ""
		if node == RunManager.current_node:
			ind_name = "ind_atual"
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif RunManager.current_node and node in RunManager.current_node.children:
			ind_name = "ind_selecionado" if node == _hovered_node else "ind_disponivel"
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
		elif _is_node_completed(node):
			overlay_name = "ind_concluido"
			base_mod = Color(0.7, 0.66, 0.62)
			label_col = Color(0.6, 0.55, 0.5)
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif RunManager.current_node and node.id.x <= RunManager.current_node.id.x:
			sprite_name += "_escura"
			overlay_name = "ind_bloqueado"
			base_mod = Color(0.62, 0.62, 0.66)
			label_col = Color(0.5, 0.45, 0.42)
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			base_mod = Color(0.62, 0.6, 0.62)
			label_col = Color(0.6, 0.55, 0.5)
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if overlay_name != "":
			ind_name = overlay_name

		base.modulate = base_mod
		MapNodeArt.apply(btn, base, ind, _NODE_SPRITES.get(node.type, "nodo_batalha"), sprite_name, ind_name, overlay_name, boss_suffix, node == pawn_rest_node)
		if size_label:
			size_label.add_theme_color_override("font_color", label_col)
	_refresh_lines()

func _on_node_clicked(node: MapNode) -> void:
	if is_traveling:
		return

	if inventory_ui and inventory_ui.visible:
		inventory_ui.visible = false

	is_traveling = true
	# O peão sai do soquete: passa a ser desenhado avulso durante o salto.
	player_pawn.position = RunManager.current_node.position if RunManager.current_node != null else node.position
	pawn_rest_node = null
	player_pawn.visible = true
	_set_current_node(node, true)
	
	await player_pawn.jump_to_node(node.position, TILE_SIZE)

	# Chegou: o peão volta a ficar "encaixado" no sprite do soquete.
	pawn_rest_node = node
	player_pawn.visible = false
	_update_nodes_visual_state()
	
	RunManager.current_board_size = node.board_size
	RunManager.current_node_type = node.type
	
	match node.type:
		MapNode.NodeType.Duelo, MapNode.NodeType.DueloForte, MapNode.NodeType.Chefe:
			get_tree().call_deferred("change_scene_to_file", "res://main.tscn")
		MapNode.NodeType.Loja:
			get_tree().call_deferred("change_scene_to_file", "res://shop_view.tscn")
		MapNode.NodeType.Aposta:
			get_tree().call_deferred("change_scene_to_file", "res://bet_view.tscn")
		MapNode.NodeType.Evento:
			get_tree().call_deferred("change_scene_to_file", "res://event_view.tscn")
		_:
			is_traveling = false

func _highlight_connection(_parent: MapNode, _child: MapNode) -> void:
	# O estado (percorrido/selecionado/bloqueado) vem de _refresh_lines().
	_refresh_lines()

func _camera_target_y(target_y: float) -> float:
	if forest == null:
		return target_y
	var half_h = get_viewport_rect().size.y / (2.0 * CAMERA_ZOOM)
	var r = forest.world_rect
	if island_base != null:
		r.size.y += island_base.extra_height()   # deixa a base rochosa à vista
	if r.size.y <= half_h * 2.0:
		return r.get_center().y
	return clampf(target_y, r.position.y + half_h, r.end.y - half_h)

func _move_camera_to_node(target_node: MapNode) -> void:
	var tween = create_tween()
	tween.tween_property(camera, "position:y", _camera_target_y(target_node.position.y), 0.85)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
