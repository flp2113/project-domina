class_name ActionCard
extends Resource

enum TargetType {
	NONE,
	ALLY_PIECE,
	ENEMY_PIECE,
	EMPTY_TILE
}

enum Rarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

@export var id: String = ""
@export var name: String = ""
# Ícone da carta (um PNG por carta, 64x64). Vazio/inexistente = quadro vazio com "?".
@export_file("*.png") var icon_path: String = ""
@export_multiline var description: String = ""
@export var target_type: TargetType = TargetType.NONE

@export var rarity: Rarity = Rarity.COMMON:
	set(value):
		rarity = value
		_cost_gold = get_cost_by_rarity(value)

var _cost_gold: int = 4
@export var cost_gold: int:
	get:
		return get_cost_by_rarity(rarity)
	set(value):
		_cost_gold = value

static func get_cost_by_rarity(r: Rarity) -> int:
	match r:
		Rarity.COMMON:    return 10
		Rarity.RARE:      return 15
		Rarity.EPIC:      return 20
		Rarity.LEGENDARY: return 30
	return 4

func can_play(_board: Board, _human_team: int, _context: Dictionary = {}) -> bool:
	return true

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, _context: Dictionary = {}) -> bool:
	if not board.is_valid_pos(target_pos.y, target_pos.x):
		return false

	match target_type:
		TargetType.NONE:
			return true
		TargetType.ALLY_PIECE:
			var p = board.grid[target_pos.y][target_pos.x]
			return p != Board.EMPTY and p.owner_team == human_team
		TargetType.ENEMY_PIECE:
			var p = board.grid[target_pos.y][target_pos.x]
			return p != Board.EMPTY and p.owner_team != human_team and not p.is_tree
		TargetType.EMPTY_TILE:
			var is_dark_tile = (target_pos.y + target_pos.x) % 2 == 1
			var is_empty = board.grid[target_pos.y][target_pos.x] == Board.EMPTY
			var is_scorched = board.scorched_tiles.has(target_pos)
			return is_dark_tile and is_empty and not is_scorched
	return false

func execute(_board: Board, _target_pos: Vector2i, _human_team: int, _context: Dictionary = {}) -> void:
	pass

static func get_rarity_weight(r: Rarity) -> int:
	match r:
		Rarity.COMMON:    return 60
		Rarity.RARE:      return 28
		Rarity.EPIC:      return 10
		Rarity.LEGENDARY: return 2
	return 50

static func get_rarity_name(r: Rarity) -> String:
	match r:
		Rarity.COMMON:    return "COMUM"
		Rarity.RARE:      return "RARA"
		Rarity.EPIC:      return "ÉPICA"
		Rarity.LEGENDARY: return "LENDÁRIA"
	return "COMUM"
