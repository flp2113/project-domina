extends Node

var current_board_size: Vector2i = Vector2i(8, 8)
var current_node_type: int = 1
var gold: int = 0

var map_data: Array[Array] = []
var current_node: MapNode = null
var visited_connections: Array[String] = []

# RunManager é a fonte única da verdade para as Leis (RuleCard) ativas no run.
# A validação de limite (6) e de incompatibilidade entre leis vive só aqui dentro,
# no RulePipeline — nenhum outro lugar do jogo deve manter sua própria cópia
# dessa lista. Consumidores que precisam de um RulePipeline "ao vivo" (ex: o
# duelo em main.gd) devem escutar o sinal `rules_updated` e reconstruir o
# pipeline do duelo a partir de `active_rules`, em vez de duplicar chamadas
# de add/remove em duas listas paralelas.
var rule_pipeline: RulePipeline = RulePipeline.new()

var active_rules: Array[RuleCard]:
	get:
		return rule_pipeline.active_rules

var player_deck: Array[ActionCard] = []

# Lei do chefe da floresta sorteada para ESTE run (id; "" = ainda não sorteada).
# Fica fixa durante o run (derrota/retentativa enfrentam a mesma) e muda no próximo.
var forest_boss_law_id: String = ""

func get_forest_boss_law_id(options: Array) -> String:
	if forest_boss_law_id == "" or not options.has(forest_boss_law_id):
		forest_boss_law_id = options[randi() % options.size()]
	return forest_boss_law_id

signal rules_updated()

func _ready():
	start_new_run()
	if player_deck.is_empty():
		_init_default_deck()

func can_add_rule(rule: RuleCard) -> bool:
	return rule_pipeline.can_add_rule(rule)

func can_add_card_to_deck() -> bool:
	return player_deck.size() < MAX_PLAYER_DECK_SIZE

func add_rule(rule: RuleCard) -> bool:
	var added = rule_pipeline.add_rule(rule)
	if added:
		rules_updated.emit()
	return added

func remove_rule(rule_id: String) -> void:
	rule_pipeline.remove_rule(rule_id)
	rules_updated.emit()

func start_new_run():
	gold = 10000
	current_board_size = Vector2i(8, 8)
	current_node_type = 1
	map_data = []
	current_node = null
	visited_connections = []
	forest_boss_law_id = ""
	rule_pipeline.clear_rules()
	_init_default_deck()
	

func _init_default_deck() -> void:
	player_deck.clear()
	player_deck.append(CardSecondChance.new())
	player_deck.append(CardLuckyDuel.new())
	player_deck.append(CardCoinOfDestiny.new())
	
func add_gold(amount: int) -> void:
	gold += amount

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false

const MAX_PLAYER_DECK_SIZE: int = 20

# Ponto único de entrada pra adicionar uma carta ao inventário do jogador —
# respeita o limite máximo de 20 cartas. Devolve false (e não adiciona
# nada) se o inventário já estiver cheio.
func add_card_to_deck(card: ActionCard) -> bool:
	if not can_add_card_to_deck():
		return false
	player_deck.append(card)
	return true
