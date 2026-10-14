class_name MapGenerator
extends Node

@export var layers_count: int = 5
@export var max_nodes_per_layer: int = 3
@export var min_nodes_per_layer: int = 2

# Lista com tabuleiros quadrados e retangulares: Vector2i(Linhas, Colunas)
const POSSIBLE_BOARD_SIZES: Array[Vector2i] = [
	Vector2i(6, 6),
	Vector2i(8, 8),
	Vector2i(10, 10),
	Vector2i(4, 8),
	Vector2i(6, 8),
	Vector2i(8, 6),
	Vector2i(8, 10)
]

func generate_map() -> Array[Array]:
	var layers: Array[Array] = []
	
	# 1. Criar os nós por camada
	for layer_index in range(layers_count):
		var current_layer: Array[MapNode] = []
		var nodes_in_this_layer = 1
		
		if layer_index > 0 and layer_index < layers_count - 1:
			nodes_in_this_layer = randi_range(min_nodes_per_layer, max_nodes_per_layer)
			
		for node_index in range(nodes_in_this_layer):
			var node = MapNode.new()
			node.id = Vector2i(layer_index, node_index)
			_assign_type(node, layer_index)
			current_layer.append(node)
			
		layers.append(current_layer)
		
	# 2. Conectar as camadas
	_connect_layers(layers)
	
	return layers

func _assign_type(node: MapNode, layer: int) -> void:
	if layer == 0:
		node.type = MapNode.NodeType.Começo
		node.board_size = Vector2i(8, 8)
	elif layer == layers_count - 1:
		node.type = MapNode.NodeType.Chefe
		node.board_size = Vector2i(10, 10) # Chefe em tabuleiro maior
	elif layer == 8:
		node.type = MapNode.NodeType.Melhoria
	else:
		var roll = randf()
		if roll < 0.45:
			node.type = MapNode.NodeType.Duelo
		elif roll < 0.65:
			node.type = MapNode.NodeType.Evento
		elif roll < 0.80:
			node.type = MapNode.NodeType.Loja
		elif roll < 0.92:
			node.type = MapNode.NodeType.DueloForte
		else:
			node.type = MapNode.NodeType.Aposta

	# Sorteia qualquer formato retangular ou quadrado da lista para os combates
	if node.type in [MapNode.NodeType.Duelo, MapNode.NodeType.DueloForte]:
		node.board_size = POSSIBLE_BOARD_SIZES.pick_random()

func _connect_layers(layers: Array[Array]) -> void:
	for i in range(layers.size() - 1):
		var current_layer = layers[i]
		var next_layer = layers[i + 1]
		
		var min_target_idx = 0 
		
		for node_idx in range(current_layer.size()):
			var node = current_layer[node_idx]
			
			var ratio = float(node_idx) / float(max(1, current_layer.size() - 1))
			var ideal_target = int(round(ratio * (next_layer.size() - 1)))
			
			var start_idx = max(min_target_idx, ideal_target - 1)
			var max_reach = ideal_target + 1
			
			if node_idx == current_layer.size() - 1:
				max_reach = next_layer.size() - 1
				
			var end_idx = clamp(max_reach, start_idx, next_layer.size() - 1)
			
			var num_connections = randi_range(1, 2)
			if start_idx == end_idx:
				num_connections = 1
				
			var highest_child_idx = start_idx
			
			for step in range(num_connections):
				var target_idx = clamp(start_idx + step, 0, end_idx)
				var target_node = next_layer[target_idx]
				
				if not node.children.has(target_node):
					node.children.append(target_node)
					target_node.parents.append(node)
					
				highest_child_idx = max(highest_child_idx, target_idx)
			
			min_target_idx = highest_child_idx

	for i in range(1, layers.size()):
		var next_layer = layers[i]
		var current_layer = layers[i - 1]
		
		for target_idx in range(next_layer.size()):
			var target = next_layer[target_idx]
			
			if target.parents.is_empty():
				var ratio = float(target_idx) / float(max(1, next_layer.size() - 1))
				var parent_idx = clamp(int(round(ratio * (current_layer.size() - 1))), 0, current_layer.size() - 1)
				var parent = current_layer[parent_idx]
				
				parent.children.append(target)
				target.parents.append(parent)
