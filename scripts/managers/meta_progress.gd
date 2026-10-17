extends Node
# Meta-progressão (autoload "MetaProgress"): tudo que sobrevive entre runs.
#  - COROAS: moeda de meta, ganha ao fim da run (vitória, derrota ou abandono).
#  - Desbloqueios: Leis/Cartas que entram na loot pool (loja, recompensas).
#    O que não está desbloqueado NÃO aparece na run (ver LootTables).
#    Só o conjunto INICIAL vem liberado; o resto sai de MONTES viradas: o
#    jogador escolhe o monte (Cartas: por raridade; Leis: por categoria),
#    paga e sorteia uma peça ainda bloqueada dele.
#  - MOCHILA: Cartas/Leis que o jogador PAGA para levar na próxima run. O
#    preço sai da raridade e SOBE a cada item já na mochila (começar a run
#    com o inventário cheio fica caro). Paga-se de novo a cada run.
# Salvo em user://meta.cfg. O tutorial ignora tudo isso (usa run própria).

signal changed()

const SAVE_PATH: String = "user://meta.cfg"

# Ganho por run
const COROAS_PER_DUEL: int = 3
const COROAS_PER_STRONG: int = 7
const COROAS_BOSS_WIN: int = 30

# Preço de desbloqueio por raridade (0 comum, 1 raro, 2 épico, 3 lendário)
const RULE_UNLOCK_COST: Array[int] = [8, 15, 25, 40]
const CARD_UNLOCK_COST: Array[int] = [6, 12, 20, 32]

# MOCHILA: preço base de LEVAR um item para a próxima run, por raridade
# (0 comum, 1 raro, 2 épico, 3 lendário). Leis pesam mais que cartas.
const CARD_CARRY_COST: Array[int] = [3, 5, 8, 12]
const RULE_CARRY_COST: Array[int] = [4, 7, 11, 16]
# Cada item JÁ na mochila encarece o próximo em +35% do preço base.
const CARRY_ESCALATION: float = 0.35
const BAG_MAX: int = 8
# Kit equipado: as peças dele entram com esse desconto (ainda sobe a escalada).
const KIT_CARRY_DISCOUNT: float = 0.75

# Conjunto INICIAL (já liberado). O resto se desbloqueia nos montes.
const STARTER_CARDS: Array[String] = [
	"second_chance", "lucky_duel", "coin_of_destiny", "heroic_advance", "vision"]
const STARTER_RULES: Array[String] = [
	"early_promotion", "reverse_movement", "optional_capture", "power_center", "ascension_law"]

# Monte de Leis: o preço é a MÉDIA do custo de desbloqueio do que ainda resta
# no monte (o sorteio é uniforme), então um monte com peças raras sai mais caro.

# Kits prontos: comprados uma vez, depois equipados (um por run). Comprar um
# Kit também desbloqueia as peças dele na loot pool.
const KITS: Array[Dictionary] = [
	{"id": "estrategista", "name": "ESTRATEGISTA", "cost": 45,
		"desc": "Enxergue o jogo antes do inimigo.",
		"rules": ["second_move"], "cards": ["vision", "prophecy"]},
	{"id": "massacre", "name": "MASSACRE", "cost": 55,
		"desc": "Capturas em cadeia e avanços violentos.",
		"rules": ["carnage"], "cards": ["heroic_advance", "retaliation"]},
	{"id": "fortaleza", "name": "FORTALEZA", "cost": 60,
		"desc": "Peças difíceis de derrubar.",
		"rules": ["shield"], "cards": ["fortify", "rebuild"]},
]

var coroas: int = 0
var unlocked_rules: Array[String] = []
var unlocked_cards: Array[String] = []
var owned_kits: Array[String] = []
var equipped_kit: String = ""
# Mochila da próxima run: [{"t": "card"|"rule", "id", "paid": int, "kit": String}]
var bag: Array[Dictionary] = []
var oficina_tour_seen: bool = false   # guia do Grimório já exibido
var run_over_tour_seen: bool = false   # mini guia das Coroas (1ª tela de fim de run) já exibido
var alpha_end_seen: bool = false      # mensagem de fim da alpha (1º Chefe derrotado) já exibida
var tutorial_warned: bool = false     # jogador escolheu 'jogar mesmo assim' sem o tutorial (aviso não volta)
var tutorial_done: bool = false       # jogador já concluiu o tutorial até o fim

# Estatísticas da run em andamento (zeradas em RunManager.start_new_run).
var run_duels_won: int = 0
var run_strong_won: int = 0
var run_boss_won: bool = false

# Resumo da última run paga (lido pela tela de fim de run).
# {won, duels, strong, boss, total, before, after}
var last_summary: Dictionary = {}

func _ready() -> void:
	load_data()

# ---------------------------------------------------------------------
# Persistência
# ---------------------------------------------------------------------
func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	coroas = int(cfg.get_value("meta", "coroas", cfg.get_value("meta", "selos", 0)))
	unlocked_rules = _to_str_array(cfg.get_value("meta", "unlocked_rules", []))
	unlocked_cards = _to_str_array(cfg.get_value("meta", "unlocked_cards", []))
	owned_kits = _to_str_array(cfg.get_value("meta", "owned_kits", []))
	equipped_kit = str(cfg.get_value("meta", "equipped_kit", ""))
	bag.clear()
	var raw = cfg.get_value("meta", "bag", [])
	if raw is Array:
		for e in raw:
			if e is Dictionary and e.has("id") and e.has("t"):
				bag.append({"t": str(e["t"]), "id": str(e["id"]), "paid": int(e.get("paid", 0)), "kit": str(e.get("kit", ""))})
	oficina_tour_seen = bool(cfg.get_value("meta", "oficina_tour_seen", false))
	tutorial_done = bool(cfg.get_value("meta", "tutorial_done", false))
	run_over_tour_seen = bool(cfg.get_value("meta", "run_over_tour_seen", false))
	alpha_end_seen = bool(cfg.get_value("meta", "alpha_end_seen", false))
	tutorial_warned = bool(cfg.get_value("meta", "tutorial_warned", false))
	_sanitize()

func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "coroas", coroas)
	cfg.set_value("meta", "unlocked_rules", unlocked_rules)
	cfg.set_value("meta", "unlocked_cards", unlocked_cards)
	cfg.set_value("meta", "owned_kits", owned_kits)
	cfg.set_value("meta", "equipped_kit", equipped_kit)
	cfg.set_value("meta", "bag", bag)
	cfg.set_value("meta", "oficina_tour_seen", oficina_tour_seen)
	cfg.set_value("meta", "tutorial_done", tutorial_done)
	cfg.set_value("meta", "run_over_tour_seen", run_over_tour_seen)
	cfg.set_value("meta", "alpha_end_seen", alpha_end_seen)
	cfg.set_value("meta", "tutorial_warned", tutorial_warned)
	cfg.save(SAVE_PATH)

func _to_str_array(v) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for x in v:
			out.append(str(x))
	return out

# Tira da mochila o que não está mais desbloqueado e confere o kit equipado.
func _sanitize() -> void:
	bag = bag.filter(func(e): return (is_rule_unlocked(e["id"]) if e["t"] == "rule" else is_card_unlocked(e["id"])))
	if equipped_kit != "" and (not owned_kits.has(equipped_kit) or not bag.any(func(e): return e["kit"] == equipped_kit)):
		equipped_kit = ""

func mark_oficina_tour_seen() -> void:
	if not oficina_tour_seen:
		oficina_tour_seen = true
		save_data()

func mark_alpha_end_seen() -> void:
	if not alpha_end_seen:
		alpha_end_seen = true
		save_data()

func mark_run_over_tour_seen() -> void:
	if not run_over_tour_seen:
		run_over_tour_seen = true
		save_data()

func mark_tutorial_warned() -> void:
	if not tutorial_warned:
		tutorial_warned = true
		save_data()

func mark_tutorial_done() -> void:
	if not tutorial_done:
		tutorial_done = true
		save_data()

func reset_all() -> void:
	coroas = 0
	unlocked_rules.clear()
	unlocked_cards.clear()
	owned_kits.clear()
	equipped_kit = ""
	bag.clear()
	oficina_tour_seen = false
	tutorial_done = false
	run_over_tour_seen = false
	alpha_end_seen = false
	tutorial_warned = false
	last_summary = {}
	reset_run_stats()
	save_data()
	changed.emit()

# ---------------------------------------------------------------------
# Desbloqueios
# ---------------------------------------------------------------------
func _tutorial_on() -> bool:
	return TutorialManager != null and TutorialManager.is_active

func is_rule_unlocked(id: String) -> bool:
	return unlocked_rules.has(id) or STARTER_RULES.has(id)

func is_card_unlocked(id: String) -> bool:
	return unlocked_cards.has(id) or STARTER_CARDS.has(id)

func rule_unlock_cost(rule: RuleCard) -> int:
	return RULE_UNLOCK_COST[clampi(int(rule.rarity), 0, 3)]

# ---- Montes de desbloqueio ----
# Cartas: um monte por RARIDADE (0..3). Leis: um monte por CATEGORIA (RuleCard.Category).
func locked_cards(rarity: int) -> Array[ActionCard]:
	var out: Array[ActionCard] = []
	for c in LootTables.get_all_action_cards():
		if int(c.rarity) == rarity and not is_card_unlocked(c.id):
			out.append(c)
	return out

func locked_rules(category: int) -> Array[RuleCard]:
	var out: Array[RuleCard] = []
	for r in LootTables.get_all_rules():
		if int(r.category) == category and not is_rule_unlocked(r.id):
			out.append(r)
	return out

func card_pile_price(rarity: int) -> int:
	return CARD_UNLOCK_COST[clampi(rarity, 0, 3)]

func rule_pile_price(category: int) -> int:
	var items := locked_rules(category)
	if items.is_empty():
		return 0
	var sum := 0
	for r in items:
		sum += rule_unlock_cost(r)
	return int(round(float(sum) / float(items.size())))

# Compra o monte e devolve o id sorteado ("" = falhou: sem Coroas ou monte vazio).
func draw_card_pile(rarity: int) -> String:
	var items := locked_cards(rarity)
	var price := card_pile_price(rarity)
	if items.is_empty() or coroas < price:
		return ""
	var pick: ActionCard = items[randi() % items.size()]
	coroas -= price
	unlocked_cards.append(pick.id)
	save_data()
	changed.emit()
	return pick.id

func draw_rule_pile(category: int) -> String:
	var items := locked_rules(category)
	var price := rule_pile_price(category)
	if items.is_empty() or coroas < price:
		return ""
	var pick: RuleCard = items[randi() % items.size()]
	coroas -= price
	unlocked_rules.append(pick.id)
	save_data()
	changed.emit()
	return pick.id

# ---------------------------------------------------------------------
# Mochila da próxima run + Kits
# ---------------------------------------------------------------------
func get_kit(id: String) -> Dictionary:
	for k in KITS:
		if k["id"] == id:
			return k
	return {}

func bag_has(t: String, id: String) -> bool:
	return bag.any(func(e): return e["t"] == t and e["id"] == id)

func bag_count(t: String = "") -> int:
	if t == "":
		return bag.size()
	return bag.filter(func(e): return e["t"] == t).size()

func bag_total_paid() -> int:
	var n := 0
	for e in bag:
		n += int(e["paid"])
	return n

func _base_carry(t: String, rarity: int) -> int:
	var table: Array[int] = RULE_CARRY_COST if t == "rule" else CARD_CARRY_COST
	return table[clampi(rarity, 0, 3)]

func _escalate(base: int, already: int) -> int:
	return int(round(float(base) * (1.0 + CARRY_ESCALATION * float(already))))

# Preço de LEVAR este item agora (já com a escalada da mochila atual).
func carry_price(t: String, rarity: int) -> int:
	return _escalate(_base_carry(t, rarity), bag.size())

func _rarity_of(t: String, id: String) -> int:
	if t == "rule":
		for r in LootTables.get_all_rules():
			if r.id == id:
				return int(r.rarity)
	else:
		for c in LootTables.get_all_action_cards():
			if c.id == id:
				return int(c.rarity)
	return 0

func _unlocked(t: String, id: String) -> bool:
	return is_rule_unlocked(id) if t == "rule" else is_card_unlocked(id)

func add_to_bag(t: String, id: String) -> bool:
	if bag_has(t, id) or not _unlocked(t, id) or bag.size() >= BAG_MAX:
		return false
	var price := carry_price(t, _rarity_of(t, id))
	if coroas < price:
		return false
	coroas -= price
	bag.append({"t": t, "id": id, "paid": price, "kit": ""})
	save_data()
	changed.emit()
	return true

# Tira da mochila devolvendo o que foi pago por ele.
func remove_from_bag(t: String, id: String) -> void:
	for i in range(bag.size()):
		if bag[i]["t"] == t and bag[i]["id"] == id:
			coroas += int(bag[i]["paid"])
			var kit_id: String = bag[i]["kit"]
			bag.remove_at(i)
			if kit_id != "" and equipped_kit == kit_id:
				equipped_kit = ""   # kit incompleto deixa de contar como equipado
			save_data()
			changed.emit()
			return

func clear_bag() -> void:
	coroas += bag_total_paid()
	bag.clear()
	equipped_kit = ""
	save_data()
	changed.emit()

func buy_kit(id: String) -> bool:
	var k := get_kit(id)
	if k.is_empty() or owned_kits.has(id) or coroas < int(k["cost"]):
		return false
	coroas -= int(k["cost"])
	owned_kits.append(id)
	for rid in k["rules"]:
		if not unlocked_rules.has(rid):
			unlocked_rules.append(rid)
	for cid in k["cards"]:
		if not unlocked_cards.has(cid):
			unlocked_cards.append(cid)
	save_data()
	changed.emit()
	return true

# Itens do kit que ainda não estão na mochila: [{t, id}]
func _kit_items(k: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rid in k["rules"]:
		if not bag_has("rule", rid):
			out.append({"t": "rule", "id": rid})
	for cid in k["cards"]:
		if not bag_has("card", cid):
			out.append({"t": "card", "id": cid})
	return out

# Preço total de levar o kit agora (escalada sequencial + desconto).
func kit_carry_price(id: String) -> int:
	var k := get_kit(id)
	if k.is_empty():
		return 0
	var total := 0
	var n := bag.size()
	for it in _kit_items(k):
		total += int(round(float(_escalate(_base_carry(it["t"], _rarity_of(it["t"], it["id"])), n)) * KIT_CARRY_DISCOUNT))
		n += 1
	return total

func toggle_kit(id: String) -> bool:
	var k := get_kit(id)
	if k.is_empty() or not owned_kits.has(id):
		return false
	if equipped_kit == id:
		# desequipar: devolve só o que o kit trouxe
		for i in range(bag.size() - 1, -1, -1):
			if bag[i]["kit"] == id:
				coroas += int(bag[i]["paid"])
				bag.remove_at(i)
		equipped_kit = ""
		save_data()
		changed.emit()
		return true
	var items := _kit_items(k)
	if bag.size() + items.size() > BAG_MAX or coroas < kit_carry_price(id):
		return false
	for it in items:
		var price := int(round(float(carry_price(it["t"], _rarity_of(it["t"], it["id"]))) * KIT_CARRY_DISCOUNT))
		coroas -= price
		bag.append({"t": it["t"], "id": it["id"], "paid": price, "kit": id})
	equipped_kit = id
	save_data()
	changed.emit()
	return true

# Entrega a mochila a uma run NOVA (chamado por JOGAR depois de
# RunManager.start_new_run) e esvazia: a próxima run paga de novo.
func consume_bag_into_run() -> void:
	if _tutorial_on():
		return
	for e in bag:
		if e["t"] == "rule":
			for rule in LootTables.get_all_rules():
				if rule.id == e["id"]:
					RunManager.add_rule(rule)
		else:
			for card in LootTables.get_all_action_cards():
				if card.id == e["id"] and not RunManager.player_deck.any(func(c): return c.id == card.id):
					RunManager.add_card_to_deck(card)
	bag.clear()
	equipped_kit = ""
	save_data()
	changed.emit()

# ---------------------------------------------------------------------
# Ganho de Coroas
# ---------------------------------------------------------------------
func reset_run_stats() -> void:
	run_duels_won = 0
	run_strong_won = 0
	run_boss_won = false

func register_duel_win(node_type: int) -> void:
	if _tutorial_on():
		return
	if node_type == MapNode.NodeType.Chefe:
		run_boss_won = true
	elif node_type == MapNode.NodeType.DueloForte:
		run_strong_won += 1
	else:
		run_duels_won += 1

# Quanto a run vale agora (sem pagar). O Chefe derrotado já está contado.
func preview_run_coroas() -> int:
	if _tutorial_on():
		return 0
	var total := run_duels_won * COROAS_PER_DUEL + run_strong_won * COROAS_PER_STRONG
	if run_boss_won:
		total += COROAS_BOSS_WIN
	return total

# Paga as Coroas da run, guarda o resumo em last_summary e zera as estatísticas
# (não paga duas vezes). `won` = a run terminou com o Chefe derrotado.
func settle_run(won: bool = false) -> int:
	var amount := preview_run_coroas()
	last_summary = {
		"won": won, "duels": run_duels_won, "strong": run_strong_won,
		"boss": run_boss_won, "total": amount, "before": coroas, "after": coroas + amount,
	}
	if amount > 0:
		coroas += amount
		save_data()
		changed.emit()
	reset_run_stats()
	return amount
